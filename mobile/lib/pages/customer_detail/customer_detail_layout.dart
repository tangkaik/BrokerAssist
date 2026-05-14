part of '../customer_detail_page.dart';

extension _CustomerDetailLayout on _CustomerDetailPageState {
  Widget _buildBody() {
    if (_customer == null) {
      return const Center(child: Text('客户信息加载失败'));
    }

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _buildInfoCard(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _CustomerDetailTabHeaderDelegate(
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        const Tab(text: '概览'),
                        Tab(text: '记录 ${_records.length}'),
                        const Tab(text: '产品服务'),
                        const Tab(text: '建议'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildRecordsTab(),
            _buildProductServiceTab(),
            _buildSuggestionTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabScrollView(List<Widget> children) {
    return RefreshIndicator(
      onRefresh: _loadCustomerData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      ),
    );
  }

  Widget _buildOverviewTab() {
    return _buildTabScrollView([
      _buildPriorityPanel(),
      const SizedBox(height: 16),
      _buildSummarySection(),
      const SizedBox(height: 16),
      _buildLatestRecordPreview(),
      const SizedBox(height: 16),
      _buildDeleteButton(),
    ]);
  }

  Widget _buildRecordsTab() {
    return _buildTabScrollView([
      Row(
        children: [
          const Icon(Icons.history, color: _detailAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '沟通记录 (${_records.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: _detailAccent),
            onPressed: () => _showAddRecordSheet(),
            tooltip: '新增沟通记录',
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildRecordsList(),
    ]);
  }

  Widget _buildProductServiceTab() {
    return _buildTabScrollView([
      _buildSectionShell(
        icon: Icons.inventory_2_outlined,
        iconColor: _detailAccent,
        title: '产品服务',
        subtitle: '用于管理客户已购买、正在推进或需要续约的产品与服务。',
        child: _buildEmptyProductServiceState(),
      ),
    ]);
  }

  Widget _buildSuggestionTab() {
    return _buildTabScrollView([
      _buildNextStepSuggestionSection(),
      const SizedBox(height: 16),
      _buildSectionShell(
        icon: Icons.card_giftcard_outlined,
        iconColor: _detailPrimary,
        title: '关怀建议',
        subtitle: '节日、生日、重要节点的关怀建议会放在这里。',
        child: Text(
          '后续会结合客户画像、沟通记录、客户等级和行业特点，自动生成礼物、问候和回访建议。',
          style: TextStyle(fontSize: 14, height: 1.65, color: Colors.grey[700]),
        ),
      ),
    ]);
  }
}

class _CustomerDetailTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CustomerDetailTabHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(bottom: BorderSide(color: _detailBorder)),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_CustomerDetailTabHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
