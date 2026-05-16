import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:broker_assist/models/models.dart';
import 'package:broker_assist/widgets/customer_reminder_highlight_card.dart';

ReminderOccurrence _reminder(ReminderType type) {
  return ReminderOccurrence(
    id: 'r-${type.name}',
    type: type,
    occurrenceDate: DateTime(2026, 5, 15),
    title: '提醒',
    body: '周女士的保单缴费需要跟进',
    dueLabel: '还有 3 天',
    sourceKey: type.name,
    customerId: 'c1',
    customerName: '周女士',
  );
}

void main() {
  testWidgets('客户详情提醒卡片统一显示已提醒并支持点击确认', (tester) async {
    var acknowledged = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerReminderHighlightCard(
            reminders: [_reminder(ReminderType.policyPayment)],
            onAcknowledge: () {
              acknowledged = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('今日提醒'), findsOneWidget);
    expect(find.text('已提醒'), findsOneWidget);
    expect(find.text('缴费'), findsNothing);
    expect(find.text('生日'), findsNothing);

    await tester.tap(find.byType(CustomerReminderHighlightCard));
    await tester.pumpAndSettle();

    expect(acknowledged, isTrue);
  });

  testWidgets('客户详情提醒卡片完成后仍显示但变为已完成状态', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerReminderHighlightCard(
            reminders: [_reminder(ReminderType.birthday)],
            isCompleted: true,
            onAcknowledge: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('今日提醒'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('已提醒'), findsNothing);
    expect(find.text('点击后不再高亮'), findsNothing);

    await tester.tap(find.byType(CustomerReminderHighlightCard));
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
  });
}
