part of '../customer_detail_page.dart';

extension _CustomerDetailOverview on _CustomerDetailPageState {
  Widget _buildLatestRecordPreview() {
    final latest = _records.isNotEmpty ? _records.first : null;
    return _buildSectionShell(
      icon: Icons.notes_outlined,
      iconColor: const Color(0xFF2563EB),
      title: '最近记录',
      trailing: TextButton(
        onPressed: _showAddRecordSheet,
        child: const Text('新增'),
      ),
      child: latest == null
          ? Text(
              '暂无沟通记录。创建第一条记录后，客户画像和下次拜访建议会自动更新。',
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: Colors.grey[700],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(latest.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 8),
                Text(
                  latest.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
                if (latest.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildCountChip('${latest.images.length} 张图片附件'),
                ],
              ],
            ),
    );
  }
}
