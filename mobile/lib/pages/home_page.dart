import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api.dart';
import '../services/industry_settings.dart';
import '../widgets/customer_avatar.dart';
import '../widgets/industry_picker.dart';
import 'ai_chat_page.dart';
import 'create_customer_page.dart';
import 'customer_list_page.dart';
import 'draft_record_page.dart';

/// 首页：根据客户数据切换新用户启动页和日常工作入口。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _background = Color(0xFFF6F7F9);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _teal = Color(0xFF0F766E);
  static const Color _navy = Color(0xFF1E3A5F);
  static const Color _amber = Color(0xFFD97706);

  bool _isLoading = true;
  String? _error;
  List<Customer> _recentCustomers = const [];
  int _customerTotal = 0;
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
      final response = await apiService.searchCustomers(
        page: 1,
        pageSize: 5,
        sortBy: 'updated_at',
        sortOrder: 'desc',
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (response.success && response.data != null) {
          _recentCustomers = response.data!.items;
          _customerTotal = response.data!.total;
          _maybeShowInitialIndustryPicker();
        } else {
          _error = response.error?.message ?? '暂时无法加载首页数据';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '暂时无法加载首页数据';
      });
    }
  }

  void _maybeShowInitialIndustryPicker() {
    if (_showedInitialIndustryPicker || IndustrySettings.hasSelectedIndustry) {
      return;
    }
    _showedInitialIndustryPicker = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final selected = await showIndustryPicker(
        context,
        current: IndustrySettings.current,
        title: '先选择你的行业',
        subtitle: '默认可以选择通用。选定后，首页和后续 AI 画像会按这个方向组织。',
        requireSelection: true,
      );
      await IndustrySettings.save(selected ?? IndustryOption.generic);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        titleSpacing: 20,
        title: GestureDetector(
          onLongPress: () => Navigator.pushNamed(context, '/api-settings'),
          child: ValueListenableBuilder<IndustryOption>(
            valueListenable: IndustrySettings.selected,
            builder: (context, industry, _) =>
                _WorkspaceTitle(industry: industry),
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
        backgroundColor: _background,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHomeData,
          child: _isLoading
              ? const _HomeLoadingView()
              : _error != null && !_hasCustomers
              ? _HomeErrorView(message: _error!, onRetry: _loadHomeData)
              : _hasCustomers
              ? _ExistingUserHome(
                  recentCustomers: _recentCustomers,
                  customerTotal: _customerTotal,
                )
              : const _NewUserHome(),
        ),
      ),
    );
  }
}

class _WorkspaceTitle extends StatelessWidget {
  final IndustryOption industry;

  const _WorkspaceTitle({required this.industry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          industry.workspaceLabel,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F5F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                industry.label,
                style: const TextStyle(
                  color: _HomePageState._teal,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NewUserHome extends StatelessWidget {
  const _NewUserHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _StartRecordCard(
          title: '记录第一次沟通',
          subtitle: '录音、文字或图片都可以，先记下来再归档到客户。',
          primaryLabel: '开始记录',
          secondaryLabel: '直接新建客户',
          onPrimary: () => _openDraftRecord(context),
          onSecondary: () => _openCreateCustomer(context),
        ),
        const SizedBox(height: 14),
        _EmptyGuideCard(
          title: '还没有客户',
          body: '先记录一次沟通，系统会自动整理客户画像、待补信息和下一步动作。',
          items: const [
            _GuideItem(Icons.chat_bubble_outline_rounded, '今天和客户聊了什么'),
            _GuideItem(Icons.psychology_alt_outlined, '客户有什么需求或顾虑'),
            _GuideItem(Icons.event_available_outlined, '下一步约了什么时间'),
          ],
        ),
        const SizedBox(height: 14),
        _AiStarterCard(text: '问 AI：如何整理第一个客户？', onTap: () => _openAI(context)),
      ],
    );
  }
}

class _ExistingUserHome extends StatelessWidget {
  final List<Customer> recentCustomers;
  final int customerTotal;

  const _ExistingUserHome({
    required this.recentCustomers,
    required this.customerTotal,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _StartRecordCard(
          title: '记录一次沟通',
          subtitle: '把新拜访、电话、聊天截图或资料先收进来。',
          primaryLabel: '开始记录',
          secondaryLabel: '查看客户',
          onPrimary: () => _openDraftRecord(context),
          onSecondary: () => _openCustomers(context),
        ),
        const SizedBox(height: 14),
        _SectionHeader(
          title: '今日跟进',
          actionLabel: '问 AI',
          onAction: () => _openAI(context),
        ),
        const SizedBox(height: 10),
        _FollowUpList(customers: recentCustomers),
        const SizedBox(height: 14),
        _SectionHeader(
          title: '最近客户',
          subtitle: '共 $customerTotal 位客户',
          actionLabel: '全部',
          onAction: () => _openCustomers(context),
        ),
        const SizedBox(height: 10),
        _RecentCustomerList(customers: recentCustomers),
      ],
    );
  }
}

class _StartRecordCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _StartRecordCard({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _HomePageState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F5F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: _HomePageState._teal,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _HomePageState._ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _HomePageState._muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _CaptureMode(icon: Icons.mic_none_rounded, label: '录音'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _CaptureMode(icon: Icons.notes_rounded, label: '文字'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _CaptureMode(icon: Icons.image_outlined, label: '图片'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(primaryLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: _HomePageState._teal,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _HomePageState._navy,
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: _HomePageState._border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(secondaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaptureMode extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CaptureMode({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _HomePageState._border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _HomePageState._navy, size: 21),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _HomePageState._ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGuideCard extends StatelessWidget {
  final String title;
  final String body;
  final List<_GuideItem> items;

  const _EmptyGuideCard({
    required this.title,
    required this.body,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _HomePageState._border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _HomePageState._ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: _HomePageState._muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '可以这样开始',
            style: TextStyle(
              color: _HomePageState._ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _GuideRow(item: item)),
        ],
      ),
    );
  }
}

class _GuideItem {
  final IconData icon;
  final String label;

  const _GuideItem(this.icon, this.label);
}

class _GuideRow extends StatelessWidget {
  final _GuideItem item;

  const _GuideRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: _HomePageState._amber, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                color: _HomePageState._ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiStarterCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _AiStarterCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF102A43),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.smart_toy_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _HomePageState._ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _HomePageState._muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _FollowUpList extends StatelessWidget {
  final List<Customer> customers;

  const _FollowUpList({required this.customers});

  @override
  Widget build(BuildContext context) {
    final items = customers.take(3).toList();
    if (items.isEmpty) {
      return const _MutedPanel(text: '还没有足够的客户记录生成跟进建议。');
    }

    return Column(
      children: [
        for (final customer in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FollowUpRow(customer: customer),
          ),
      ],
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  final Customer customer;

  const _FollowUpRow({required this.customer});

  @override
  Widget build(BuildContext context) {
    final reason = customer.tags.isNotEmpty
        ? '${customer.tags.first} · 建议补充下一步动作'
        : '最近有更新 · 适合继续跟进';

    return _CustomerRowShell(
      onTap: () => _openCustomers(context),
      leading: CustomerAvatar(name: customer.name, radius: 19),
      title: customer.name,
      subtitle: reason,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: _HomePageState._muted,
      ),
    );
  }
}

class _RecentCustomerList extends StatelessWidget {
  final List<Customer> customers;

  const _RecentCustomerList({required this.customers});

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const _MutedPanel(text: '最近客户会在这里显示。');
    }

    return Column(
      children: [
        for (final customer in customers.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CustomerRowShell(
              onTap: () => _openCustomers(context),
              leading: CustomerAvatar(name: customer.name, radius: 19),
              title: customer.name,
              subtitle: customer.tags.isEmpty
                  ? '暂无标签'
                  : customer.tags.join('，'),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: _HomePageState._muted,
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomerRowShell extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _CustomerRowShell({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _HomePageState._border),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _HomePageState._ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _HomePageState._muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _MutedPanel extends StatelessWidget {
  final String text;

  const _MutedPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _HomePageState._border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _HomePageState._muted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 28),
      children: [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            '正在整理首页...',
            style: TextStyle(color: _HomePageState._muted),
          ),
        ),
      ],
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 28),
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          color: _HomePageState._muted,
          size: 40,
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _HomePageState._muted),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

void _openDraftRecord(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DraftRecordPage()),
  );
}

void _openCreateCustomer(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CreateCustomerPage()),
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
