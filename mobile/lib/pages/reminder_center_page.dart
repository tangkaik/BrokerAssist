import 'package:flutter/material.dart';

import '../models/models.dart';
import '../widgets/customer_avatar.dart';
import 'home_widgets.dart';

class ReminderCenterPage extends StatefulWidget {
  final List<ReminderOccurrence> initialReminders;
  final Set<String> initialCompletedReminderIds;
  final Future<void> Function(String customerId)? onOpenCustomer;
  final Future<Set<String>> Function()? onRefreshCompletedReminderIds;
  final Future<void> Function(ReminderOccurrence reminder)? onCompleteReminder;
  final Future<void> Function(ReminderOccurrence reminder)? onReopenReminder;

  const ReminderCenterPage({
    super.key,
    this.initialReminders = const [],
    this.initialCompletedReminderIds = const {},
    this.onOpenCustomer,
    this.onRefreshCompletedReminderIds,
    this.onCompleteReminder,
    this.onReopenReminder,
  });

  @override
  State<ReminderCenterPage> createState() => _ReminderCenterPageState();
}

class _ReminderCenterPageState extends State<ReminderCenterPage> {
  late List<ReminderOccurrence> _reminders;
  final Set<String> _completedReminderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _reminders = [...widget.initialReminders];
    _completedReminderIds.addAll(widget.initialCompletedReminderIds);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ReminderGroups.from(_reminders);
    return Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        title: const Text('今日提醒'),
        backgroundColor: HomeColors.background,
        foregroundColor: HomeColors.ink,
        elevation: 0,
      ),
      body: groups.isEmpty
          ? const _EmptyReminders()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _ReminderGroupSection(
                  group: group,
                  completedReminderIds: _completedReminderIds,
                  onOpenCustomer: _openCustomer,
                  onComplete: _completeReminder,
                  onReopen: _reopenReminder,
                );
              },
            ),
    );
  }

  Future<void> _completeReminder(ReminderOccurrence reminder) async {
    await widget.onCompleteReminder?.call(reminder);
    if (!mounted) return;
    setState(() {
      _completedReminderIds.add(reminder.id);
    });
  }

  Future<void> _reopenReminder(ReminderOccurrence reminder) async {
    await widget.onReopenReminder?.call(reminder);
    if (!mounted) return;
    setState(() {
      _completedReminderIds.remove(reminder.id);
    });
  }

  Future<void> _openCustomer(String customerId) async {
    await widget.onOpenCustomer?.call(customerId);
    final latestCompletedIds =
        await widget.onRefreshCompletedReminderIds?.call();
    if (!mounted || latestCompletedIds == null) return;
    setState(() {
      _completedReminderIds
        ..clear()
        ..addAll(latestCompletedIds);
    });
  }
}

class _ReminderGroupSection extends StatelessWidget {
  final ReminderGroupSummary group;
  final Set<String> completedReminderIds;
  final Future<void> Function(String customerId)? onOpenCustomer;
  final Future<void> Function(ReminderOccurrence reminder) onComplete;
  final Future<void> Function(ReminderOccurrence reminder) onReopen;

  const _ReminderGroupSection({
    required this.group,
    required this.completedReminderIds,
    required this.onOpenCustomer,
    required this.onComplete,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HomeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(group.type), color: _colorFor(group.type)),
              const SizedBox(width: 8),
              Text(
                '${group.title} · ${group.count}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...group.reminders.map(
            (reminder) => _ReminderRow(
              reminder: reminder,
              isCompleted: completedReminderIds.contains(reminder.id),
              onOpenCustomer: onOpenCustomer,
              onComplete: onComplete,
              onReopen: onReopen,
            ),
          ),
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

class _ReminderRow extends StatelessWidget {
  final ReminderOccurrence reminder;
  final bool isCompleted;
  final Future<void> Function(String customerId)? onOpenCustomer;
  final Future<void> Function(ReminderOccurrence reminder) onComplete;
  final Future<void> Function(ReminderOccurrence reminder) onReopen;

  const _ReminderRow({
    required this.reminder,
    required this.isCompleted,
    required this.onOpenCustomer,
    required this.onComplete,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    final customerName = reminder.customerName;
    final titleColor = isCompleted ? Colors.grey[500] : HomeColors.ink;
    final bodyColor = isCompleted ? Colors.grey[400] : Colors.grey[600];
    final canOpenCustomer = reminder.customerId != null && onOpenCustomer != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: canOpenCustomer
                  ? () async => onOpenCustomer?.call(reminder.customerId!)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (customerName != null)
                    CustomerAvatar(name: customerName, radius: 18)
                  else
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.card_giftcard_outlined,
                        size: 20,
                        color: HomeColors.amber,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName ?? reminder.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reminder.body,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: bodyColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7F5F2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  reminder.dueLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: HomeColors.teal,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (reminder.customerId != null) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  '查看客户',
                                  style: TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCompleted)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '已完成',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: '撤回完成',
                  onPressed: () => onReopen(reminder),
                  icon: const Icon(Icons.keyboard_return),
                  color: Colors.grey[500],
                ),
              ],
            )
          else
            IconButton(
              tooltip: '完成提醒',
              onPressed: () => onComplete(reminder),
              icon: const Icon(Icons.check_circle_outline),
              color: const Color(0xFFDC2626),
            ),
        ],
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 54,
              color: Colors.grey[350],
            ),
            const SizedBox(height: 12),
            const Text(
              '今天没有需要处理的提醒',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '生日、节日和缴费提醒会在这里汇总。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
