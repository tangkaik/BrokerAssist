# 本地提醒通知实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在移动端实现第一版本地系统提醒，包括首页今日提醒卡片、提醒详情页、客户列表提醒徽标和本地通知排程。

**Architecture:** 提醒规则先做成纯 Dart 服务，输入客户、沟通记录和行业，输出统一的提醒 occurrence。UI 层只消费 occurrence，不直接写规则。本地通知服务负责权限、初始化、按类型合并排程，后续可替换为服务端推送。

**Tech Stack:** Flutter、Dart、SharedPreferences、flutter_local_notifications、timezone、flutter_test。

---

### Task 1: 提醒模型和规则引擎

**Files:**
- Create: `mobile/lib/models/reminder_models.dart`
- Create: `mobile/lib/services/reminder_engine.dart`
- Modify: `mobile/lib/models/models.dart`
- Test: `mobile/test/reminder_engine_test.dart`

- [x] **Step 1: Write failing tests**

Create tests that assert:

```dart
test('生日提前3天生成提醒并跨年计算', () {
  final customer = Customer(
    id: 'c1',
    name: '王芳',
    birthday: '1988-01-02',
    createdAt: DateTime(2025, 1, 1),
  );
  final reminders = ReminderEngine(today: DateTime(2025, 12, 30)).build(
    customers: [customer],
    recordsByCustomerId: const {},
    industryKey: 'insurance',
  );
  expect(reminders.single.type, ReminderType.birthday);
  expect(reminders.single.customerId, 'c1');
});

test('保单缴费只识别明确日期', () {
  final customer = Customer(
    id: 'c1',
    name: '王芳',
    summary: '保单缴费日是 2026-06-01',
    createdAt: DateTime(2025, 1, 1),
  );
  final reminders = ReminderEngine(today: DateTime(2026, 5, 29)).build(
    customers: [customer],
    recordsByCustomerId: const {},
    industryKey: 'insurance',
  );
  expect(reminders.any((r) => r.type == ReminderType.policyPayment), isTrue);
});

test('模糊缴费文本不生成保单缴费提醒', () {
  final customer = Customer(
    id: 'c1',
    name: '王芳',
    summary: '客户担心缴费压力，之前买过一份寿险',
    createdAt: DateTime(2025, 1, 1),
  );
  final reminders = ReminderEngine(today: DateTime(2026, 5, 29)).build(
    customers: [customer],
    recordsByCustomerId: const {},
    industryKey: 'insurance',
  );
  expect(reminders.where((r) => r.type == ReminderType.policyPayment), isEmpty);
});
```

- [x] **Step 2: Run failing tests**

Run: `flutter test test/reminder_engine_test.dart`

Expected: fail because reminder models and engine do not exist.

- [x] **Step 3: Implement model and engine**

Add `ReminderType`, `ReminderOccurrence`, `ReminderGroupSummary`, and `ReminderEngine`. Engine rules:

- Birthday reminders: 3 days before next birthday.
- Festival reminders: predefined Chinese festivals, 7/3/1 days before.
- Policy payment reminders: insurance only, explicit dates near words such as `缴费`、`续费`、`到期`、`保费`.
- Build reminders for today by default.

- [x] **Step 4: Run tests**

Run: `flutter test test/reminder_engine_test.dart`

Expected: all tests pass.

### Task 2: 完成状态和本地通知服务

**Files:**
- Create: `mobile/lib/services/reminder_completion_store.dart`
- Create: `mobile/lib/services/local_notification_service.dart`
- Modify: `mobile/pubspec.yaml`
- Modify: platform notification config if required by plugin
- Test: `mobile/test/reminder_completion_store_test.dart`

- [x] **Step 1: Write failing tests**

Test that completing a reminder key hides that same user/date/type/target reminder and does not hide a different date.

- [x] **Step 2: Add dependencies and services**

Add:

```yaml
flutter_local_notifications: ^21.0.0
timezone: ^0.11.0
```

Implement `ReminderCompletionStore` using SharedPreferences and `LocalNotificationService` using `flutter_local_notifications`. The service schedules one notification per date/type group at 09:00.

- [x] **Step 3: Run tests**

Run: `flutter test test/reminder_completion_store_test.dart`

Expected: pass.

### Task 3: 首页今日提醒卡片和详情页

**Files:**
- Create: `mobile/lib/pages/reminder_center_page.dart`
- Create: `mobile/lib/widgets/today_reminder_card.dart`
- Modify: `mobile/lib/pages/home_page.dart`
- Modify: `mobile/lib/pages/home_widgets.dart`
- Test: `mobile/test/reminder_widgets_test.dart`

- [x] **Step 1: Write widget tests**

Test that the home card renders at most 3 preview rows and that the detail page groups reminders by type.

- [x] **Step 2: Implement UI**

Add the card to existing-user home below stats and before quick actions. Add a detail page with grouped reminders, `查看客户`, and explicit `完成`.

- [x] **Step 3: Run widget tests**

Run: `flutter test test/reminder_widgets_test.dart`

Expected: pass.

### Task 4: 客户列表徽标和 app lifecycle refresh

**Files:**
- Modify: `mobile/lib/pages/customer_list_page.dart`
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/pages/create_customer_page.dart`
- Modify: `mobile/lib/pages/edit_customer_page.dart`
- Modify: `mobile/lib/pages/draft_record_page.dart`
- Test: `mobile/test/reminder_engine_test.dart`

- [x] **Step 1: Add reminder badge calculation**

Customer list loads today's reminders and shows badges for matching customers.

- [x] **Step 2: Refresh reminder schedule**

Initialize notification service in `main()`. Refresh local schedule on app start, after login, after customer changes, and after record changes.

- [x] **Step 3: Verify**

Run:

```bash
flutter test
flutter analyze
```

Expected: all tests pass and analyzer reports no issues.

## Self Review

- Spec coverage: Plan covers local notification scheduling, home card, reminder detail page, completion behavior, customer list badges, predefined industry rules, and conservative policy payment detection.
- Placeholder scan: No placeholder tasks remain; all tasks name concrete files and expected checks.
- Type consistency: Model names are stable across tasks: `ReminderType`, `ReminderOccurrence`, `ReminderEngine`, `ReminderCompletionStore`, and `LocalNotificationService`.
