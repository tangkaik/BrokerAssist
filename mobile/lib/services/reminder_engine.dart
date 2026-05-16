import '../models/models.dart';
import 'industry_settings.dart';

class ReminderEngine {
  ReminderEngine({DateTime? today}) : today = _dayOnly(today ?? DateTime.now());

  final DateTime today;

  List<ReminderOccurrence> build({
    required List<Customer> customers,
    required Map<String, List<Record>> recordsByCustomerId,
    required IndustryReminderRules reminderRules,
  }) {
    final reminders = <ReminderOccurrence>[];

    for (final customer in customers) {
      if (reminderRules.birthdayEnabled) {
        final birthdayReminder = _birthdayReminder(customer);
        if (birthdayReminder != null) reminders.add(birthdayReminder);
      }

      if (reminderRules.keyDateEnabled) {
        final keyDateReminder = _keyDateReminder(
          customer,
          recordsByCustomerId[customer.id] ?? const [],
          reminderRules,
        );
        if (keyDateReminder != null) reminders.add(keyDateReminder);
      }
    }

    if (reminderRules.festivalEnabled) {
      reminders.addAll(_festivalReminders(reminderRules));
    }
    reminders.sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      return (a.customerName ?? a.title).compareTo(b.customerName ?? b.title);
    });
    return reminders;
  }

  static List<ReminderGroupSummary> groupForToday(
    List<ReminderOccurrence> reminders, {
    DateTime? today,
  }) {
    final day = _dayOnly(today ?? DateTime.now());
    final grouped = <ReminderType, List<ReminderOccurrence>>{};
    for (final reminder in reminders) {
      if (!_sameDay(reminder.occurrenceDate, day)) continue;
      grouped.putIfAbsent(reminder.type, () => []).add(reminder);
    }

    final groups = grouped.entries
        .map(
          (entry) => ReminderGroupSummary(
            type: entry.key,
            occurrenceDate: day,
            reminders: entry.value,
          ),
        )
        .toList();
    groups.sort((a, b) => a.type.index.compareTo(b.type.index));
    return groups;
  }

  ReminderOccurrence? _birthdayReminder(Customer customer) {
    final birthday = _parseBirthday(customer.birthday);
    if (birthday == null) return null;

    final nextBirthday = _nextAnnualDate(birthday.month, birthday.day);
    final reminderDate = nextBirthday.subtract(const Duration(days: 3));
    if (!_sameDay(reminderDate, today)) return null;

    return ReminderOccurrence(
      id: 'birthday:${customer.id}:${_dateKey(reminderDate)}',
      type: ReminderType.birthday,
      occurrenceDate: reminderDate,
      title: '${customer.name}生日提醒',
      body: '${customer.name} 的生日还有 3 天，可以提前准备问候或礼物。',
      dueLabel: '还有 3 天',
      sourceKey: 'birthday',
      customerId: customer.id,
      customerName: customer.name,
    );
  }

  ReminderOccurrence? _keyDateReminder(
    Customer customer,
    List<Record> records,
    IndustryReminderRules rules,
  ) {
    final sourceText = [
      customer.summary ?? '',
      ...records.map((record) => record.content),
      ...records.expand(
        (record) => record.images.map((image) => image.visionAnswer ?? ''),
      ),
    ].where((item) => item.trim().isNotEmpty).join('\n');
    final keyDate = _detectKeyDate(sourceText, rules.keyDateKeywords);
    if (keyDate == null) return null;

    const leadDays = 3;
    final reminderDate = keyDate.subtract(const Duration(days: leadDays));
    if (!_sameDay(reminderDate, today)) return null;

    return ReminderOccurrence(
      id: 'policy_payment:${customer.id}:${_dateKey(reminderDate)}',
      type: ReminderType.policyPayment,
      occurrenceDate: reminderDate,
      title: _formatTemplate(
        rules.keyDateTitleTemplate,
        customer: customer.name,
        days: leadDays,
      ),
      body: _formatTemplate(
        rules.keyDateBodyTemplate,
        customer: customer.name,
        days: leadDays,
      ),
      dueLabel: '还有 $leadDays 天',
      sourceKey: rules.keyDateSourceKey,
      customerId: customer.id,
      customerName: customer.name,
      groupTitle: rules.keyDateGroupTitle,
    );
  }

  List<ReminderOccurrence> _festivalReminders(IndustryReminderRules rules) {
    final reminders = <ReminderOccurrence>[];

    for (final festival in _festivals) {
      final date = DateTime(today.year, festival.month, festival.day);
      for (final leadDays in const [7, 3, 1]) {
        final reminderDate = date.subtract(Duration(days: leadDays));
        if (!_sameDay(reminderDate, today)) continue;
        reminders.add(
          ReminderOccurrence(
            id: 'festival:${festival.name}:${today.year}:$leadDays',
            type: ReminderType.festivalCare,
            occurrenceDate: reminderDate,
            title: '${festival.name}提醒',
            body: _formatTemplate(
              rules.festivalBodyTemplate,
              festival: festival.name,
              days: leadDays,
            ),
            dueLabel: '还有 $leadDays 天',
            sourceKey: 'festival',
            groupTitle: rules.festivalGroupTitle,
          ),
        );
      }
    }
    return reminders;
  }

  DateTime? _detectKeyDate(String text, List<String> keywords) {
    if (text.trim().isEmpty) return null;
    if (keywords.isEmpty) return null;
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ');

    final explicitDatePattern = RegExp(
      r'(\d{4})[-/年.](\d{1,2})[-/月.](\d{1,2})日?',
    );
    for (final match in explicitDatePattern.allMatches(normalized)) {
      if (!_nearKeyword(normalized, match.start, match.end, keywords)) continue;
      return _safeDate(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
    }

    final monthDayPattern = RegExp(r'(\d{1,2})月(\d{1,2})日?');
    for (final match in monthDayPattern.allMatches(normalized)) {
      if (!_nearKeyword(normalized, match.start, match.end, keywords)) continue;
      final month = int.parse(match.group(1)!);
      final day = int.parse(match.group(2)!);
      var date = _safeDate(today.year, month, day);
      if (date == null) continue;
      if (date.isBefore(today)) {
        date = _safeDate(today.year + 1, month, day);
      }
      return date;
    }

    return null;
  }

  bool _nearKeyword(String text, int start, int end, List<String> keywords) {
    final left = start - 12 < 0 ? 0 : start - 12;
    final right = end + 12 > text.length ? text.length : end + 12;
    final window = text.substring(left, right);
    return keywords.any(window.contains);
  }

  String _formatTemplate(
    String template, {
    String? customer,
    String? festival,
    required int days,
  }) {
    return template
        .replaceAll('{customer}', customer ?? '')
        .replaceAll('{festival}', festival ?? '')
        .replaceAll('{days}', days.toString());
  }

  DateTime _nextAnnualDate(int month, int day) {
    var next = _safeDate(today.year, month, day);
    next ??= DateTime(today.year, 3, 1);
    if (next.isBefore(today)) {
      next = _safeDate(today.year + 1, month, day);
      next ??= DateTime(today.year + 1, 3, 1);
    }
    return next;
  }

  DateTime? _parseBirthday(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return _dayOnly(date);
  }
}

class _Festival {
  final String name;
  final int month;
  final int day;

  const _Festival(this.name, this.month, this.day);
}

const _festivals = [
  _Festival('春节', 2, 17),
  _Festival('端午节', 6, 19),
  _Festival('中秋节', 9, 25),
  _Festival('国庆节', 10, 1),
];

DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dateKey(DateTime date) {
  final day = _dayOnly(date);
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
