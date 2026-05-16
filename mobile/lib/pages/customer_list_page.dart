import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinyin/pinyin.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/reminder_data_service.dart';
import '../theme/brand_colors.dart';
import '../utils/customer_search.dart';
import '../widgets/customer_avatar.dart';
import 'home_widgets.dart';
import 'customer_detail_page.dart';

/// 客户列表页
///
/// 功能：
/// - 显示客户列表
/// - 支持模糊搜索（按姓名、标签）
/// - 支持多种排序方式
/// - 点击跳转详情
class CustomerListPage extends StatefulWidget {
  final String? initialFilter;

  const CustomerListPage({super.key, this.initialFilter});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

/// 排序选项
class _SortOption {
  final String label;
  final String sortBy;
  final String sortOrder;
  final IconData icon;

  const _SortOption({
    required this.label,
    required this.sortBy,
    required this.sortOrder,
    required this.icon,
  });
}

class _CustomerListPageState extends State<CustomerListPage> {
  /// 客户列表
  List<Customer> _customers = [];
  List<ReminderOccurrence> _todayReminders = [];

  /// 加载状态
  bool _isLoading = true;

  /// 加载更多状态
  bool _isLoadingMore = false;

  /// 错误信息
  String? _error;

  /// 搜索关键词
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';

  /// 搜索防抖
  Timer? _debounceTimer;

  /// 当前排序
  String _sortBy = 'updated_at';
  String _sortOrder = 'desc';

  /// 分页
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _pageSize = 20;

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 排序选项列表
  final List<_SortOption> _sortOptions = const [
    _SortOption(
      label: '最近更新',
      sortBy: 'updated_at',
      sortOrder: 'desc',
      icon: Icons.access_time,
    ),
    _SortOption(
      label: '姓名 A-Z',
      sortBy: 'name',
      sortOrder: 'asc',
      icon: Icons.sort_by_alpha,
    ),
    _SortOption(
      label: '姓名 Z-A',
      sortBy: 'name',
      sortOrder: 'desc',
      icon: Icons.sort_by_alpha,
    ),
    _SortOption(
      label: '最早创建',
      sortBy: 'created_at',
      sortOrder: 'asc',
      icon: Icons.calendar_today,
    ),
    _SortOption(
      label: '最新创建',
      sortBy: 'created_at',
      sortOrder: 'desc',
      icon: Icons.calendar_today,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCustomers();
  }

  String get _filterLabel {
    switch (widget.initialFilter) {
      case 'stale-summary':
        return '画像待更新';
      case 'stale-contact':
        return '超期未联系';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (isPinyinLikeKeyword(_keyword)) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreCustomers();
      }
    }
  }

  /// 加载客户列表（支持搜索和排序）
  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final useLocalPinyinSearch = isPinyinLikeKeyword(_keyword);
      final results = await Future.wait([
        apiService.searchCustomers(
          keyword: _keyword.isEmpty || useLocalPinyinSearch ? null : _keyword,
          page: 1,
          pageSize: useLocalPinyinSearch ? 200 : _pageSize,
          sortBy: _sortBy,
          sortOrder: _sortOrder,
          summaryStatus: widget.initialFilter == 'stale-summary'
              ? 'stale,failed'
              : null,
          staleContact: widget.initialFilter == 'stale-contact',
        ),
        ReminderDataService.loadTodayReminders(),
      ]);
      final response = results[0] as ApiResponse<PaginatedData<Customer>>;
      final reminders = results[1] as List<ReminderOccurrence>;

      setState(() {
        _isLoading = false;
        _todayReminders = reminders;
        if (response.success && response.data != null) {
          _customers = useLocalPinyinSearch
              ? response.data!.items
                    .where(
                      (customer) => customerMatchesKeyword(customer, _keyword),
                    )
                    .toList()
              : response.data!.items;
          _hasMore =
              !useLocalPinyinSearch && response.data!.items.length >= _pageSize;
          // 前端按拼音排序（后端返回的是Unicode排序）
          _sortCustomers();
        } else {
          _error = response.error?.message ?? '未知错误';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _loadMoreCustomers() async {
    if (_isLoadingMore || !_hasMore) return;
    if (isPinyinLikeKeyword(_keyword)) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final response = await apiService.searchCustomers(
        keyword: _keyword.isEmpty ? null : _keyword,
        page: _currentPage,
        pageSize: _pageSize,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        summaryStatus: widget.initialFilter == 'stale-summary'
            ? 'stale,failed'
            : null,
        staleContact: widget.initialFilter == 'stale-contact',
      );

      setState(() {
        _isLoadingMore = false;
        if (response.success && response.data != null) {
          _customers.addAll(response.data!.items);
          _hasMore = response.data!.items.length >= _pageSize;
          _sortCustomers();
        } else {
          _currentPage--;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
    }
  }

  /// 按拼音排序客户列表
  void _sortCustomers() {
    if (_sortBy == 'name') {
      _customers.sort((a, b) {
        // 获取拼音首字母
        final pinyinA = PinyinHelper.getPinyinE(a.name);
        final pinyinB = PinyinHelper.getPinyinE(b.name);
        // 比较拼音
        final result = pinyinA.compareTo(pinyinB);
        return _sortOrder == 'asc' ? result : -result;
      });
    }
    // 其他排序方式（updated_at, created_at）由后端处理
  }

  /// 搜索输入变化（防抖）
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _keyword = value.trim());
        _loadCustomers();
      }
    });
  }

  /// 清空搜索
  void _clearSearch() {
    _searchController.clear();
    setState(() => _keyword = '');
    _loadCustomers();
  }

  Future<void> _showQuickCreate() async {
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
      _loadCustomers();
    }
  }

  /// 切换排序
  void _changeSort(_SortOption option) {
    setState(() {
      _sortBy = option.sortBy;
      _sortOrder = option.sortOrder;
    });
    _loadCustomers();
    Navigator.pop(context);
  }

  /// 显示排序选择器
  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '排序方式',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ..._sortOptions.map((option) {
                final isSelected =
                    _sortBy == option.sortBy && _sortOrder == option.sortOrder;
                return ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: BrandColors.primary)
                      : null,
                  selected: isSelected,
                  onTap: () => _changeSort(option),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 获取当前排序标签
  String get _currentSortLabel {
    final option = _sortOptions.firstWhere(
      (o) => o.sortBy == _sortBy && o.sortOrder == _sortOrder,
      orElse: () => _sortOptions.first,
    );
    return option.label;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filterLabel.isNotEmpty ? '客户列表 · $_filterLabel' : '客户列表'),
        backgroundColor: BrandColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.white),
            onPressed: _showQuickCreate,
            tooltip: '新建客户',
          ),
          // 排序按钮
          TextButton.icon(
            onPressed: _showSortBottomSheet,
            icon: const Icon(Icons.sort, color: Colors.white),
            label: Text(
              _currentSortLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          _buildSearchBar(),

          const Divider(height: 1),

          // 结果数量提示
          if (!_isLoading && _customers.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text(
                _keyword.isEmpty
                    ? '共 ${_customers.length} 位客户'
                    : '找到 ${_customers.length} 位客户',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),

          // 列表区
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// 搜索框
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: '搜索姓名、拼音、首字母或标签...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          suffixIcon: _keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // 加载中
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('加载中...'),
          ],
        ),
      );
    }

    // 错误状态
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCustomers,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 空列表（搜索无结果）
    if (_customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _keyword.isEmpty ? Icons.people_outline : Icons.search_off,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                _filterLabel.isNotEmpty
                    ? '无满足"$_filterLabel"条件的客户'
                    : (_keyword.isEmpty ? '暂无客户' : '未找到 "$_keyword"'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              if (_keyword.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '在首页录入第一条记录开始使用',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ] else ...[
                const SizedBox(height: 8),
                TextButton(onPressed: _clearSearch, child: const Text('清除搜索')),
              ],
            ],
          ),
        ),
      );
    }

    // 客户列表
    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _customers.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final customer = _customers[index];
          return _CustomerListItem(
            customer: customer,
            reminders: _todayReminders
                .where((reminder) => reminder.customerId == customer.id)
                .toList(),
            onChanged: _loadCustomers,
          );
        },
      ),
    );
  }
}

/// 客户列表项
class _CustomerListItem extends StatelessWidget {
  final Customer customer;
  final List<ReminderOccurrence> reminders;
  final VoidCallback onChanged;

  const _CustomerListItem({
    required this.customer,
    required this.reminders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CustomerAvatar(
        avatarUrl: customer.avatar,
        name: customer.name,
        radius: 20,
      ),
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [Text(customer.name), ..._badgeTypes.map(_ReminderBadge.new)],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customer.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                children: customer.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (customer.summary != null && customer.summary!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                customer.summary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
      trailing: customer.lastContactAt != null
          ? Text(
              _formatDate(customer.lastContactAt!),
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      onTap: () async {
        final changed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerDetailPage(),
            settings: RouteSettings(arguments: customer.id),
          ),
        );
        if (changed == true && context.mounted) {
          onChanged();
        }
      },
    );
  }

  List<ReminderType> get _badgeTypes {
    final types = <ReminderType>[];
    for (final reminder in reminders) {
      if (!types.contains(reminder.type)) {
        types.add(reminder.type);
      }
    }
    return types.take(3).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _ReminderBadge extends StatelessWidget {
  final ReminderType type;

  const _ReminderBadge(this.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _foregroundColor),
          const SizedBox(width: 3),
          Text(
            type.badgeLabel,
            style: TextStyle(
              fontSize: 11,
              color: _foregroundColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    switch (type) {
      case ReminderType.birthday:
        return Icons.cake_outlined;
      case ReminderType.policyPayment:
        return Icons.receipt_long_outlined;
      case ReminderType.festivalGift:
      case ReminderType.festivalCare:
        return Icons.card_giftcard_outlined;
    }
  }

  Color get _foregroundColor {
    switch (type) {
      case ReminderType.birthday:
        return HomeColors.teal;
      case ReminderType.policyPayment:
        return HomeColors.navy;
      case ReminderType.festivalGift:
      case ReminderType.festivalCare:
        return HomeColors.amber;
    }
  }

  Color get _backgroundColor => _foregroundColor.withValues(alpha: 0.1);
}
