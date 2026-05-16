import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:broker_assist/models/models.dart';
import 'package:broker_assist/main.dart';
import 'package:broker_assist/pages/reminder_center_page.dart';
import 'package:broker_assist/widgets/today_reminder_card.dart';

ReminderOccurrence _reminder({
  required String id,
  required ReminderType type,
  String? customerId,
  String? customerName,
}) {
  return ReminderOccurrence(
    id: id,
    type: type,
    occurrenceDate: DateTime(2026, 1, 1),
    title: customerName == null ? '端午节提醒' : '$customerName提醒',
    body: customerName == null ? '端午节还有 7 天' : '$customerName 需要跟进',
    dueLabel: type == ReminderType.festivalGift ? '还有 7 天' : '还有 3 天',
    sourceKey: type.name,
    customerId: customerId,
    customerName: customerName,
  );
}

void main() {
  testWidgets('首页 Tab 有提醒时显示数字徽标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeTabIconWithBadge(
            icon: Icons.home_outlined,
            count: 3,
            selected: false,
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('首页 Tab 无提醒时不显示数字徽标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeTabIconWithBadge(
            icon: Icons.home_outlined,
            count: 0,
            selected: false,
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
  });

  testWidgets('今日提醒卡片最多展示3条预览', (tester) async {
    final groups = [
      ReminderGroupSummary(
        type: ReminderType.birthday,
        occurrenceDate: DateTime(2026, 1, 1),
        reminders: [
          _reminder(
            id: 'r1',
            type: ReminderType.birthday,
            customerId: 'c1',
            customerName: '王芳',
          ),
        ],
      ),
      ReminderGroupSummary(
        type: ReminderType.policyPayment,
        occurrenceDate: DateTime(2026, 1, 1),
        reminders: [
          _reminder(
            id: 'r2',
            type: ReminderType.policyPayment,
            customerId: 'c2',
            customerName: '李明',
          ),
        ],
      ),
      ReminderGroupSummary(
        type: ReminderType.festivalGift,
        occurrenceDate: DateTime(2026, 1, 1),
        reminders: [_reminder(id: 'r3', type: ReminderType.festivalGift)],
      ),
      ReminderGroupSummary(
        type: ReminderType.festivalCare,
        occurrenceDate: DateTime(2026, 1, 1),
        reminders: [_reminder(id: 'r4', type: ReminderType.festivalCare)],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayReminderCard(groups: groups, onTap: () {}),
        ),
      ),
    );

    expect(find.text('今日提醒'), findsOneWidget);
    expect(find.text('查看全部'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('生日关怀'), findsOneWidget);
    expect(find.textContaining('保单缴费'), findsOneWidget);
    expect(find.textContaining('节日礼品'), findsOneWidget);
    expect(find.textContaining('节日关怀'), findsNothing);
  });

  testWidgets('今日提醒卡片无提醒时不显示红点数字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayReminderCard(groups: const [], onTap: () {}),
        ),
      ),
    );

    expect(find.text('今天没有需要处理的提醒。'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('提醒详情页完成后保留在列表并支持撤回', (tester) async {
    final reminders = [
      _reminder(
        id: 'r1',
        type: ReminderType.birthday,
        customerId: 'c1',
        customerName: '王芳',
      ),
      _reminder(
        id: 'r2',
        type: ReminderType.policyPayment,
        customerId: 'c2',
        customerName: '李明',
      ),
    ];
    final completed = <String>[];
    final reopened = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderCenterPage(
          initialReminders: reminders,
          onOpenCustomer: (_) async {},
          onCompleteReminder: (reminder) async {
            completed.add(reminder.id);
          },
          onReopenReminder: (reminder) async {
            reopened.add(reminder.id);
          },
        ),
      ),
    );

    expect(find.text('今日提醒'), findsOneWidget);
    expect(find.text('生日关怀 · 1'), findsOneWidget);
    expect(find.text('保单缴费 · 1'), findsOneWidget);
    expect(find.text('王芳'), findsOneWidget);
    expect(find.text('李明'), findsOneWidget);

    await tester.tap(find.byTooltip('完成提醒').first);
    await tester.pumpAndSettle();

    expect(completed, ['r1']);
    expect(find.text('王芳'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.byTooltip('撤回完成'), findsOneWidget);
    expect(find.text('李明'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return), findsOneWidget);
    final completedTitle = tester.widget<Text>(find.text('王芳'));
    expect(completedTitle.style?.decoration, isNull);

    await tester.tap(find.byTooltip('撤回完成'));
    await tester.pumpAndSettle();

    expect(reopened, ['r1']);
    expect(find.text('已完成'), findsNothing);
  });

  testWidgets('提醒详情页初始已完成提醒仍然显示', (tester) async {
    final reminders = [
      _reminder(
        id: 'r1',
        type: ReminderType.birthday,
        customerId: 'c1',
        customerName: '王芳',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderCenterPage(
          initialReminders: reminders,
          initialCompletedReminderIds: const {'r1'},
          onOpenCustomer: (_) async {},
        ),
      ),
    );

    expect(find.text('王芳'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.byTooltip('撤回完成'), findsOneWidget);
  });

  testWidgets('从客户详情返回后刷新完成状态', (tester) async {
    final reminders = [
      _reminder(
        id: 'r1',
        type: ReminderType.birthday,
        customerId: 'c1',
        customerName: '王芳',
      ),
    ];
    var completedIds = <String>{};

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderCenterPage(
          initialReminders: reminders,
          onOpenCustomer: (_) async {
            completedIds = {'r1'};
          },
          onRefreshCompletedReminderIds: () async => completedIds,
        ),
      ),
    );

    expect(find.text('已完成'), findsNothing);

    await tester.tap(find.text('查看客户'));
    await tester.pumpAndSettle();

    expect(find.text('已完成'), findsOneWidget);
  });

  testWidgets('点击提醒内容区域可进入客户详情', (tester) async {
    final reminders = [
      _reminder(
        id: 'r1',
        type: ReminderType.policyPayment,
        customerId: 'c1',
        customerName: '王芳',
      ),
    ];
    final openedCustomers = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderCenterPage(
          initialReminders: reminders,
          onOpenCustomer: (customerId) async {
            openedCustomers.add(customerId);
          },
        ),
      ),
    );

    await tester.tap(find.text('王芳'));
    await tester.pumpAndSettle();

    expect(openedCustomers, ['c1']);
  });

  testWidgets('提醒详情页未完成显示红色勾，完成后显示灰色文字', (tester) async {
    final reminders = [
      _reminder(
        id: 'r1',
        type: ReminderType.birthday,
        customerId: 'c1',
        customerName: '王芳',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ReminderCenterPage(
          initialReminders: reminders,
          onOpenCustomer: (_) async {},
          onCompleteReminder: (_) async {},
        ),
      ),
    );

    final activeButton = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((button) => button.tooltip == '完成提醒');
    expect(activeButton.color, const Color(0xFFDC2626));

    await tester.tap(find.byTooltip('完成提醒'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(find.text('已完成'), findsOneWidget);
  });
}
