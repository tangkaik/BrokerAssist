part of '../customer_detail_page.dart';

extension _CustomerDetailSuggestions on _CustomerDetailPageState {
  Widget _buildSummarySection() {
    final summary = _customer?.summary?.trim() ?? '';
    final hasSummary = summary.isNotEmpty;
    final isUpdating = _customer?.summaryStatus == 'updating';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.summarize, color: _detailAccent),
                      SizedBox(width: 8),
                      Text(
                        '客户画像',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUpdating)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  onPressed: _openCustomerAI,
                  icon: const Icon(Icons.smart_toy_outlined),
                  tooltip: '问 AI',
                ),
                IconButton(
                  onPressed: _isRefreshingSummary || isUpdating
                      ? null
                      : _refreshSummary,
                  icon: _isRefreshingSummary
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                IconButton(
                  onPressed: hasSummary
                      ? () => _copyText('客户画像', summary)
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: '复制',
                ),
                IconButton(
                  onPressed: hasSummary
                      ? () => _shareText('客户画像', summary)
                      : null,
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: '分享',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasSummary)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: _buildExpandableText(
                  summary,
                  _summaryExpanded,
                  _toggleSummaryExpanded,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text('暂无客户画像', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '新增记录后会自动更新，也可以手动刷新',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStepSuggestionSection() {
    final hasAdvice = _adviceText.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: _detailPrimary),
                      SizedBox(width: 8),
                      Text(
                        '下次拜访建议',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openCustomerAI,
                  icon: const Icon(Icons.smart_toy_outlined),
                  tooltip: '问 AI',
                ),
                IconButton(
                  onPressed: _isRefreshingAdvice ? null : _refreshAdvice,
                  icon: _isRefreshingAdvice
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                IconButton(
                  onPressed: hasAdvice
                      ? () => _copyText('下次拜访建议', _adviceText)
                      : null,
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: '复制',
                ),
                IconButton(
                  onPressed: hasAdvice
                      ? () => _shareText('下次拜访建议', _adviceText)
                      : null,
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: '分享',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3FAF8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFE4DD)),
              ),
              child: hasAdvice
                  ? _buildExpandableText(
                      _adviceText,
                      _adviceExpanded,
                      _toggleAdviceExpanded,
                    )
                  : Text(
                      '根据客户画像和最近沟通记录，生成下一次拜访前最值得关注的问题、开场方式和跟进重点。',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.65,
                        color: Colors.grey[700],
                      ),
                    ),
            ),
            if (_adviceUpdatedAt != null && _adviceUpdatedAt!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '上次生成：${_adviceUpdatedAt!.replaceFirst('T', ' ').split('.').first}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ] else if (!hasAdvice) ...[
              const SizedBox(height: 8),
              Text(
                '新增记录后会自动更新，也可以手动刷新',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
