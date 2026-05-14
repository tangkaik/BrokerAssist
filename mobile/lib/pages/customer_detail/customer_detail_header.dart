part of '../customer_detail_page.dart';

extension _CustomerDetailHeader on _CustomerDetailPageState {
  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomerAvatar(
                avatarUrl: _customer!.avatar,
                name: _customer!.name,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customer!.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBasicInfoLine(),
                    if (_customer!.phone != null &&
                        _customer!.phone!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _copyText('电话', _customer!.phone!),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.phone,
                              size: 15,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _customer!.phone!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_displayTags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _displayTags
                            .take(3)
                            .map(_buildTextTag)
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: _showAddRecordSheet,
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: '新增沟通记录',
              ),
            ],
          ),
          if (_locationDisplay.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildTag(_locationDisplay, Icons.location_on),
          ],
        ],
      ),
    );
  }

  Widget _buildBasicInfoLine() {
    final items = <String>[
      if (_customer!.gender != null) _displayGender(_customer!.gender!),
      if (_customer!.age != null) '${_customer!.age}岁',
      if (_customer?.createdAt != null)
        '${_customer!.createdAt.month}/${_customer!.createdAt.day} 创建',
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((item) => _buildSubtleTextPill(item)).toList(),
    );
  }

  Widget _buildPriorityPanel() {
    final items = _priorityItems;
    return _buildSectionShell(
      icon: Icons.flag_outlined,
      iconColor: _detailPrimary,
      title: '今日重点',
      child: Column(
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) const Divider(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, size: 18, color: item.color),
                const SizedBox(width: 10),
                Expanded(
                  child: MarkdownBody(
                    data: item.text,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.black87,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.w800),
                      listBullet: const TextStyle(fontSize: 14, height: 1.45),
                      h1: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      h2: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      h3: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<_PriorityItem> get _priorityItems {
    final items = <_PriorityItem>[];
    final customer = _customer;
    if (customer == null) return items;

    if (_adviceText.trim().isNotEmpty) {
      items.add(
        _PriorityItem(
          icon: Icons.lightbulb_outline,
          color: _detailPrimary,
          text: _firstLine(_adviceText, maxLength: 82),
        ),
      );
    }
    if (customer.birthday?.isNotEmpty == true) {
      items.add(
        _PriorityItem(
          icon: Icons.cake_outlined,
          color: _detailPrimary,
          text: '生日：${customer.birthday}，可提前准备关怀或问候',
        ),
      );
    }
    final seasonalReminder = _seasonalCareReminder;
    if (seasonalReminder.isNotEmpty) {
      items.add(
        _PriorityItem(
          icon: Icons.card_giftcard_outlined,
          color: _detailAccent,
          text: seasonalReminder,
        ),
      );
    }
    if (_records.isNotEmpty) {
      items.add(
        _PriorityItem(
          icon: Icons.history,
          color: _detailAccent,
          text: '最近沟通：${_formatDate(_records.first.createdAt)}',
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        const _PriorityItem(
          icon: Icons.add_comment_outlined,
          color: Color(0xFF6B7280),
          text: '先补充一条沟通记录，系统会自动更新画像和下次拜访建议',
        ),
      );
    }
    return items.take(4).toList();
  }

  List<String> get _displayTags {
    final customer = _customer;
    if (customer == null) return const [];
    final duplicateLabels = <String>{
      if (customer.gender != null) _displayGender(customer.gender!),
      if (customer.age != null) '${customer.age}岁',
    };
    return _extractProfileTags(
      customer,
    ).where((tag) => !duplicateLabels.contains(tag.trim())).take(4).toList();
  }

  List<String> _extractProfileTags(Customer customer) {
    final source = [
      customer.summary ?? '',
      _adviceText,
      ...customer.tags,
    ].join('\n');
    final normalized = source
        .replaceAll(RegExp(r'[#*_`>\-\[\]（）()：:，,。；;、\n\r]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final candidates = <String>[
      '高净值',
      '预算有限',
      '保障意识强',
      '保障意识待培养',
      '重视家庭保障',
      '关注子女教育',
      '关注养老规划',
      '医疗险优先',
      '重疾保障缺口',
      '首次投保',
      '已有保单',
      '续费敏感',
      '决策谨慎',
      '行动力强',
      '单身白领',
      '企业高管',
      '自雇经营',
      '年轻客户',
      '家庭客户',
      '风险偏好稳健',
    ];

    final tags = <String>[];
    for (final keyword in candidates) {
      if (normalized.contains(keyword)) {
        tags.add(keyword);
      }
    }

    for (final tag in customer.tags) {
      final cleaned = tag.trim();
      if (cleaned.isNotEmpty && !tags.contains(cleaned)) {
        tags.add(cleaned);
      }
    }

    final fallbackPhrases = RegExp(r'[\u4e00-\u9fa5A-Za-z0-9]{2,8}')
        .allMatches(normalized)
        .map((match) => match.group(0) ?? '')
        .where((word) => !_profileTagStopWords.contains(word))
        .where((word) => !RegExp(r'^\d+$').hasMatch(word))
        .toList();
    for (final phrase in fallbackPhrases) {
      if (tags.length >= 4) break;
      if (!tags.contains(phrase)) {
        tags.add(phrase);
      }
    }

    if (tags.isEmpty) {
      tags.addAll(customer.tags.where((tag) => tag.trim().isNotEmpty));
    }
    return tags;
  }

  String get _seasonalCareReminder {
    final month = DateTime.now().month;
    final festival = switch (month) {
      1 || 2 => '春节/元宵',
      5 || 6 => '端午',
      9 => '中秋',
      10 => '国庆',
      12 => '元旦/春节',
      _ => '下一个节日',
    };
    return '节日关怀：可提前一周为 $festival 准备问候或礼物建议';
  }

  Widget _buildTextTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _detailPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _detailPrimary.withValues(alpha: 0.18)),
      ),
      child: Text(
        tag,
        style: const TextStyle(
          color: _detailPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSubtleTextPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF667085),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
