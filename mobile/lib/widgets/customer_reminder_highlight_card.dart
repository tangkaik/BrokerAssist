import 'package:flutter/material.dart';

import '../models/models.dart';

class CustomerReminderHighlightCard extends StatelessWidget {
  final List<ReminderOccurrence> reminders;
  final bool isCompleted;
  final VoidCallback onAcknowledge;

  const CustomerReminderHighlightCard({
    super.key,
    required this.reminders,
    this.isCompleted = false,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final first = reminders.first;
    final extraCount = reminders.length - 1;
    final body = extraCount > 0
        ? '${first.body}，另有 $extraCount 条提醒。'
        : first.body;
    final backgroundColor = isCompleted
        ? const Color(0xFFF8FAFC)
        : const Color(0xFFFFF7F7);
    final borderColor = isCompleted
        ? const Color(0xFFE2E8F0)
        : const Color(0xFFFECACA);
    final iconColor = isCompleted
        ? const Color(0xFF64748B)
        : const Color(0xFFDC2626);
    final titleColor = isCompleted
        ? const Color(0xFF475569)
        : const Color(0xFF991B1B);
    final badgeText = isCompleted ? '已完成' : '已提醒';
    final badgeTextColor = isCompleted
        ? const Color(0xFF475569)
        : const Color(0xFFB91C1C);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isCompleted ? null : onAcknowledge,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: iconColor,
                    ),
                  ),
                  if (!isCompleted)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
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
                            '今日提醒',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (!isCompleted) ...[
                      const SizedBox(height: 8),
                      Text(
                        '点击后标为已完成',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
