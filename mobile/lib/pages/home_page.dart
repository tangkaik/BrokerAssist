import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/industry_settings.dart';
import '../widgets/industry_picker.dart';
import 'ai_chat_page.dart';
import 'edit_customer_page.dart';
import 'api_settings_page.dart';
import 'customer_list_page.dart';
import 'draft_record_page.dart';
import 'home_widgets.dart';

/// 首页：根据客户数据切换新用户启动页和日常工作入口。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _error;
  List<Customer> _recentCustomers = const [];
  int _customerTotal = 0;
  int _staleContactCount = 0;
  bool _showedInitialIndustryPicker = false;

  bool get _hasCustomers => _customerTotal > 0 || _recentCustomers.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        apiService.searchCustomers(
          page: 1,
          pageSize: 5,
          sortBy: 'updated_at',
          sortOrder: 'desc',
        ),
        apiService.getSummaryStats(),
      ]);

      if (!mounted) return;

      final customerRes = results[0] as ApiResponse<PaginatedData<Customer>>;
      final statsRes = results[1] as ApiResponse<Map<String, dynamic>>;

      setState(() {
        _isLoading = false;
        if (customerRes.success && customerRes.data != null) {
          _recentCustomers = customerRes.data!.items;
          _customerTotal = customerRes.data!.total;
        } else if (statsRes.success) {
          _customerTotal = 0;
        } else {
          _error = customerRes.error?.message ?? '暂时无法加载首页数据';
          return;
        }

        if (statsRes.success && statsRes.data != null) {
          _staleContactCount =
              (statsRes.data!['stale_contact_count'] as int?) ?? 0;
        }

        _maybeShowInitialIndustryPicker();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '暂时无法加载首页数据';
      });
    }
  }

  void _maybeShowInitialIndustryPicker() {
    // 只有真正的新用户（0客户 + 未选过行业）才弹窗
    if (_showedInitialIndustryPicker ||
        _hasCustomers ||
        IndustrySettings.hasSelectedIndustry) {
      return;
    }
    _showedInitialIndustryPicker = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final selected = await showIndustryPicker(
        context,
        current: IndustrySettings.current,
        title: '先选择你的行业',
        subtitle: '这个选择会决定首页文案和 AI 画像/建议的业务视角。请按你当前主要服务的客户类型选择，之后不可修改。',
        requireSelection: true,
      );
      await IndustrySettings.save(selected ?? IndustryOption.generic);
    });
  }

  Future<void> _showQuickCreateCustomerSheet(BuildContext context) async {
    final customerId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const QuickCreateCustomerSheet(),
    );
    if (customerId != null && mounted) {
      _loadHomeData();
      if (!context.mounted) return;
      _promptCompleteProfile(context, customerId);
    }
  }

  void _promptCompleteProfile(BuildContext context, String customerId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('客户已创建'),
        content: const Text('要现在完善更多信息（年龄、地址等），还是先去记录沟通？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openDraftRecord(context);
            },
            child: const Text('去记录沟通'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditCustomerPage(),
                  settings: RouteSettings(arguments: customerId),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: HomeColors.teal),
            child: const Text('完善信息'),
          ),
        ],
      ),
    );
  }

  void _openCustomersWithFilter(BuildContext context, String filter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerListPage(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: GestureDetector(
          onLongPress: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ApiSettingsPage()),
          ),
          child: ValueListenableBuilder<IndustryOption>(
            valueListenable: IndustrySettings.selected,
            builder: (context, industry, _) =>
                WorkspaceTitle(industry: industry),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loadHomeData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        backgroundColor: HomeColors.background,
        foregroundColor: HomeColors.ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _loadHomeData, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const HomeLoadingView();
    }

    if (_error != null && !_hasCustomers) {
      return HomeErrorView(message: _error!, onRetry: _loadHomeData);
    }

    if (_hasCustomers) {
      return ExistingUserHome(
        recentCustomers: _recentCustomers,
        customerTotal: _customerTotal,
        staleContactCount: _staleContactCount,
        onStartRecord: () => _openDraftRecord(context),
        onQuickCreateCustomer: () => _showQuickCreateCustomerSheet(context),
        onOpenCustomers: () => _openCustomers(context),
        onTapCustomers: () => _openCustomers(context),
        onTapStaleContact: () =>
            _openCustomersWithFilter(context, 'stale-contact'),
      );
    }

    return NewUserHome(
      onStartRecord: () => _openDraftRecord(context),
      onCreateCustomer: () => _showQuickCreateCustomerSheet(context),
      onOpenAI: () => _openAI(context),
    );
  }
}

void _openDraftRecord(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DraftRecordPage()),
  );
}

void _openCustomers(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CustomerListPage()),
  );
}

void _openAI(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AIChatPage()),
  );
}
