import 'package:flutter/material.dart';

import '../models/models.dart';
import '../pages/home_widgets.dart';

class TodayReminderCard extends StatelessWidget {
  final List<ReminderGroupSummary> groups;
  final VoidCallback onTap;
  final bool isLoading;

  const TodayReminderCard({
    super.key,
    required this.groups,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final reminderCount = groups.fold<int>(0, (sum, group) => sum + group.count);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HomeColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F5F2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: HomeColors.teal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '今日提醒',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: HomeColors.ink,
                          ),
                        ),
                      ),
                      const Text(
                        '查看全部',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.teal,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: HomeColors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    Text(
                      '正在整理今天的提醒...',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    )
                  else if (groups.isEmpty)
                    Text(
                      '今天没有需要处理的提醒。',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    )
                  else
                    ...groups.take(3).map(_ReminderPreviewRow.new),
                ],
              ),
            ),
            if (!isLoading && reminderCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: _ReminderCountBadge(count: reminderCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCountBadge extends StatelessWidget {
  final int count;

  const _ReminderCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE11D48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _ReminderPreviewRow extends StatelessWidget {
  final ReminderGroupSummary group;

  const _ReminderPreviewRow(this.group);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(_iconFor(group.type), size: 17, color: _colorFor(group.type)),
          const SizedBox(width: 8),
          Expanded(child: _MarkdownLiteText(group.previewText)),
        ],
      ),
    );
  }

  IconData _iconFor(ReminderType type) {
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

  Color _colorFor(ReminderType type) {
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
}

class _MarkdownLiteText extends StatelessWidget {
  final String text;

  const _MarkdownLiteText(this.text);

  @override
  Widget build(BuildContext context) {
    final match = RegExp(r'^\*\*(.+?)\*\*(.*)$').firstMatch(text);
    if (match == null) {
      return Text(text, style: const TextStyle(fontSize: 13, height: 1.35));
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: match.group(2)),
        ],
      ),
      style: const TextStyle(fontSize: 13, height: 1.35, color: HomeColors.ink),
    );
  }
}
