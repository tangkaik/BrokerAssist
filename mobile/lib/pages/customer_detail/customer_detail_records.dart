part of '../customer_detail_page.dart';

extension _CustomerDetailRecords on _CustomerDetailPageState {
  Widget _buildRecordsList() {
    if (_records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12),
              Text('暂无沟通记录', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Column(children: _records.map(_buildRecordItem).toList());
  }

  Widget _buildRecordItem(Record record) {
    final shareText = _recordShareText(record);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        (record.type == 'manual' || record.type == 'text')
                            ? Icons.edit
                            : Icons.mic,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (record.type == 'manual' || record.type == 'text')
                            ? '手动记录'
                            : '语音记录',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${record.createdAt.month}/${record.createdAt.day} '
                  '${_pad(record.createdAt.hour)}:${_pad(record.createdAt.minute)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.content,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
            if (record.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildRecordImages(record),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPlainIconAction(
                  icon: Icons.copy_outlined,
                  tooltip: '复制',
                  onTap: () => _copyText('拜访记录', shareText),
                ),
                _buildPlainIconAction(
                  icon: Icons.ios_share_outlined,
                  tooltip: '分享',
                  onTap: () => _shareText('拜访记录', shareText),
                ),
                _buildPlainIconAction(
                  icon: Icons.edit_outlined,
                  tooltip: '编辑',
                  onTap: () => _showEditRecordSheet(record),
                ),
                _buildPlainIconAction(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  tooltip: '删除',
                  onTap: () => _showDeleteRecordDialog(record),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordImages(Record record) {
    return Column(
      children: record.images.map((image) {
        final imageUrl = _resolveMediaUrl(image.url);
        final isAnalyzing = _analyzingImageUrls.contains(image.url);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showImagePreview(imageUrl, image.name),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 96,
                          height: 96,
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: isAnalyzing
                                ? null
                                : () => _analyzeRecordImage(
                                    recordId: record.id,
                                    imageUrl: image.url,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: isAnalyzing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (image.visionAnswer?.isNotEmpty == true)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '已识别',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            image.name.isNotEmpty ? image.name : '记录图片',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (isAnalyzing)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (image.visionAnswer?.isNotEmpty == true)
                      _buildVisionAnswerBox(
                        image.visionAnswer!,
                        expanded: _expandedVisionImageUrls.contains(image.url),
                        onToggle: () => _toggleVisionImageExpanded(image.url),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAnalyzing ? '正在识别图片...' : '暂未识别，点图片右上角星标开始识别',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisionAnswerBox(
    String answer, {
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    const visionExpandThreshold = 220;
    final needsToggle = answer.length > visionExpandThreshold;
    final displayText = needsToggle && !expanded
        ? '${answer.substring(0, visionExpandThreshold)}...'
        : answer;
    final looksLikeTable = _looksLikeTableText(answer);
    final markdownWidget = MarkdownBody(
      data: displayText,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 12,
          height: 1.55,
          color: Colors.grey[800],
          fontFamily: looksLikeTable ? 'monospace' : null,
        ),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        listBullet: TextStyle(
          fontSize: 12,
          height: 1.55,
          color: Colors.grey[800],
        ),
        h1: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        code: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        blockquote: TextStyle(
          fontSize: 12,
          height: 1.55,
          color: Colors.grey[700],
          backgroundColor: const Color(0x00000000),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0EAE4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '识别结果',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D6C63),
            ),
          ),
          const SizedBox(height: 6),
          if (looksLikeTable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 320),
                child: markdownWidget,
              ),
            )
          else
            markdownWidget,
          if (needsToggle) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  expanded ? '收起 ▲' : '展开全部 ▼',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const int _expandThreshold = 150;

  Widget _buildExpandableText(
    String text,
    bool expanded,
    VoidCallback onToggle,
  ) {
    final needsToggle = text.length > _expandThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: needsToggle && !expanded
              ? '${text.substring(0, _expandThreshold)}...'
              : text,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.black87,
            ),
            strong: const TextStyle(fontWeight: FontWeight.w700),
            h1: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            h3: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        if (needsToggle)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onToggle,
              child: Text(
                expanded ? '收起 ▲' : '展开全部 ▼',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  bool _looksLikeTableText(String text) {
    final lines = text.split('\n');
    final pipeHeavyLines = lines.where((line) => line.contains('|')).length;
    return pipeHeavyLines >= 2 ||
        text.contains('---|') ||
        text.contains('|---');
  }

  Widget _buildPlainIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildEditableExistingImages({
    required List<RecordImage> keptImages,
    required ValueChanged<RecordImage> onRemove,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keptImages.map((image) {
        final imageUrl = _resolveMediaUrl(image.url);
        return _buildImageTile(
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
          onTap: () => _showImagePreview(imageUrl, image.name),
          onRemove: () => onRemove(image),
        );
      }).toList(),
    );
  }

  Widget _buildEditableNewImages({
    required List<XFile> imageFiles,
    required ValueChanged<XFile> onRemove,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: imageFiles.map((image) {
        return _buildImageTile(
          child: Image.file(File(image.path), fit: BoxFit.cover),
          onTap: () => showLocalImagePreview(context, image),
          onRemove: () => onRemove(image),
        );
      }).toList(),
    );
  }

  Widget _buildImageTile({
    required Widget child,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: 88, height: 88, child: child),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
