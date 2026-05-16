import 'package:flutter_test/flutter_test.dart';

import 'package:broker_assist/models/models.dart';
import 'package:broker_assist/services/industry_settings.dart';
import 'package:broker_assist/services/reminder_engine.dart';

Customer _customer({
  required String id,
  required String name,
  String? birthday,
  String? summary,
}) {
  return Customer(
    id: id,
    name: name,
    birthday: birthday,
    summary: summary,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('ReminderEngine', () {
    test('生日提前3天生成提醒并支持跨年', () {
      final reminders = ReminderEngine(today: DateTime(2025, 12, 30)).build(
        customers: [_customer(id: 'c1', name: '王芳', birthday: '1988-01-02')],
        recordsByCustomerId: const {},
        reminderRules: IndustryReminderRules.insurance,
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.type, ReminderType.birthday);
      expect(reminders.single.customerId, 'c1');
      expect(reminders.single.customerName, '王芳');
      expect(reminders.single.dueLabel, '还有 3 天');
    });

    test('保险行业从明确缴费日期生成提前3天提醒', () {
      final reminders = ReminderEngine(today: DateTime(2026, 5, 29)).build(
        customers: [
          _customer(id: 'c1', name: '王芳', summary: '保单缴费日是 2026-06-01'),
        ],
        recordsByCustomerId: const {},
        reminderRules: IndustryReminderRules.insurance,
      );

      final paymentReminders = reminders.where(
        (reminder) => reminder.type == ReminderType.policyPayment,
      );
      expect(paymentReminders, hasLength(1));
      expect(paymentReminders.single.customerId, 'c1');
      expect(paymentReminders.single.sourceKey, 'payment_date_detected');
    });

    test('模糊缴费文本不生成保单缴费提醒', () {
      final reminders = ReminderEngine(today: DateTime(2026, 5, 29)).build(
        customers: [
          _customer(id: 'c1', name: '王芳', summary: '客户担心缴费压力，之前买过一份寿险'),
        ],
        recordsByCustomerId: const {},
        reminderRules: IndustryReminderRules.insurance,
      );

      expect(
        reminders.where(
          (reminder) => reminder.type == ReminderType.policyPayment,
        ),
        isEmpty,
      );
    });

    test('没有配置关键日期规则时不生成关键日期提醒', () {
      final reminders = ReminderEngine(today: DateTime(2026, 5, 29)).build(
        customers: [
          _customer(id: 'c1', name: '王芳', summary: '保单缴费日是 2026-06-01'),
        ],
        recordsByCustomerId: const {},
        reminderRules: IndustryReminderRules.generic,
      );

      expect(
        reminders.where(
          (reminder) => reminder.type == ReminderType.policyPayment,
        ),
        isEmpty,
      );
    });

    test('自定义行业可通过配置生成关键日期提醒', () {
      final rules = IndustryReminderRules(
        keyDateEnabled: true,
        keyDateKeywords: const ['交付', '尾款'],
        keyDateTitleTemplate: '{customer}交付提醒',
        keyDateBodyTemplate: '{customer} 的交付日期还有 {days} 天，请及时跟进。',
        keyDateGroupTitle: '交付跟进',
        keyDateSourceKey: 'delivery_date_detected',
      );

      final reminders = ReminderEngine(today: DateTime(2026, 5, 29)).build(
        customers: [_customer(id: 'c1', name: '王芳', summary: '交付日期是 2026-06-01')],
        recordsByCustomerId: const {},
        reminderRules: rules,
      );

      final keyDateReminders = reminders.where(
        (reminder) => reminder.type == ReminderType.policyPayment,
      );
      expect(keyDateReminders, hasLength(1));
      expect(keyDateReminders.single.title, '王芳交付提醒');
      expect(keyDateReminders.single.groupTitle, '交付跟进');
      expect(keyDateReminders.single.sourceKey, 'delivery_date_detected');
    });

    test('节日提醒按提前7天生成非客户提醒', () {
      final reminders = ReminderEngine(today: DateTime(2026, 2, 10)).build(
        customers: const [],
        recordsByCustomerId: const {},
        reminderRules: IndustryReminderRules.insurance,
      );

      final festivalReminders = reminders.where(
        (reminder) => reminder.type == ReminderType.festivalCare,
      );
      expect(festivalReminders, isNotEmpty);
      expect(festivalReminders.first.customerId, isNull);
      expect(festivalReminders.first.title, contains('春节'));
      expect(festivalReminders.first.dueLabel, '还有 7 天');
    });

    test('按类型汇总提醒用于首页和通知合并', () {
      final reminders = ReminderEngine(today: DateTime(2025, 12, 30)).build(
        customers: [
          _customer(id: 'c1', name: '王芳', birthday: '1988-01-02'),
          _customer(id: 'c2', name: '李明', birthday: '1990-01-02'),
        ],
        recordsByCustomerId: const {},
        reminderRules: IndustryReminderRules.insurance,
      );

      final groups = ReminderEngine.groupForToday(
        reminders,
        today: DateTime(2025, 12, 30),
      );

      expect(groups, hasLength(1));
      expect(groups.single.type, ReminderType.birthday);
      expect(groups.single.count, 2);
      expect(groups.single.previewText, '**生日关怀** · 2 位客户生日还有 3 天');
    });
  });
}
