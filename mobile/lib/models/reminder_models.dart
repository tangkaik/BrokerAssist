enum ReminderType { birthday, festivalGift, festivalCare, policyPayment }

extension ReminderTypeDisplay on ReminderType {
  String get label {
    switch (this) {
      case ReminderType.birthday:
        return '生日关怀';
      case ReminderType.festivalGift:
        return '节日礼品';
      case ReminderType.festivalCare:
        return '节日关怀';
      case ReminderType.policyPayment:
        return '保单缴费';
    }
  }

  String get badgeLabel {
    switch (this) {
      case ReminderType.birthday:
        return '生日';
      case ReminderType.festivalGift:
      case ReminderType.festivalCare:
        return '节日';
      case ReminderType.policyPayment:
        return '缴费';
    }
  }
}

class ReminderOccurrence {
  final String id;
  final ReminderType type;
  final DateTime occurrenceDate;
  final String title;
  final String body;
  final String dueLabel;
  final String sourceKey;
  final String? customerId;
  final String? customerName;
  final String? groupTitle;

  const ReminderOccurrence({
    required this.id,
    required this.type,
    required this.occurrenceDate,
    required this.title,
    required this.body,
    required this.dueLabel,
    required this.sourceKey,
    this.customerId,
    this.customerName,
    this.groupTitle,
  });

  String completionKey(String userId) {
    final dateKey = _dateKey(occurrenceDate);
    return '$userId|$dateKey|${type.name}|${customerId ?? id}';
  }

  static String _dateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class ReminderOccurrenceStatus {
  final ReminderOccurrence reminder;
  final bool isCompleted;

  const ReminderOccurrenceStatus({
    required this.reminder,
    required this.isCompleted,
  });
}

class ReminderGroupSummary {
  final ReminderType type;
  final DateTime occurrenceDate;
  final List<ReminderOccurrence> reminders;

  const ReminderGroupSummary({
    required this.type,
    required this.occurrenceDate,
    required this.reminders,
  });

  int get count => reminders.length;

  String get title => reminders.first.groupTitle ?? type.label;

  String get previewText {
    final first = reminders.first;
    switch (type) {
      case ReminderType.birthday:
        return '**生日关怀** · $count 位客户生日${first.dueLabel}';
      case ReminderType.policyPayment:
        return '**$title** · $count 位客户${first.dueLabel}需跟进';
      case ReminderType.festivalGift:
        return '**$title** · ${first.title}${first.dueLabel}';
      case ReminderType.festivalCare:
        return '**$title** · ${first.title}${first.dueLabel}';
    }
  }

  String get notificationTitle {
    switch (type) {
      case ReminderType.birthday:
        return '今天有 $count 位客户生日即将到来';
      case ReminderType.policyPayment:
        return '今天有 $count 位客户$title需跟进';
      case ReminderType.festivalGift:
      case ReminderType.festivalCare:
        return reminders.first.title;
    }
  }

  String get notificationBody {
    switch (type) {
      case ReminderType.birthday:
        return reminders.take(3).map((item) => item.customerName).join('、');
      case ReminderType.policyPayment:
        return reminders.take(3).map((item) => item.customerName).join('、');
      case ReminderType.festivalGift:
      case ReminderType.festivalCare:
        return reminders.first.body;
    }
  }
}

class ReminderGroups {
  static List<ReminderGroupSummary> from(List<ReminderOccurrence> reminders) {
    final byDateAndType = <String, List<ReminderOccurrence>>{};
    for (final reminder in reminders) {
      final key =
          '${reminder.occurrenceDate.year}-'
          '${reminder.occurrenceDate.month}-'
          '${reminder.occurrenceDate.day}-'
          '${reminder.type.name}';
      byDateAndType.putIfAbsent(key, () => []).add(reminder);
    }

    final groups = byDateAndType.values.map((items) {
      return ReminderGroupSummary(
        type: items.first.type,
        occurrenceDate: items.first.occurrenceDate,
        reminders: items,
      );
    }).toList();
    groups.sort((a, b) {
      final dateCompare = a.occurrenceDate.compareTo(b.occurrenceDate);
      if (dateCompare != 0) return dateCompare;
      return a.type.index.compareTo(b.type.index);
    });
    return groups;
  }
}
