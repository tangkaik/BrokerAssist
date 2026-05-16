import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:broker_assist/models/models.dart';
import 'package:broker_assist/services/reminder_completion_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderCompletionStore', () {
    test('完成状态只隐藏同一天同一条提醒', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReminderCompletionStore(userId: 'u1');
      final reminder = ReminderOccurrence(
        id: 'birthday:c1:2026-01-01',
        type: ReminderType.birthday,
        occurrenceDate: DateTime(2026, 1, 1),
        title: '王芳生日提醒',
        body: '王芳生日还有 3 天',
        dueLabel: '还有 3 天',
        sourceKey: 'birthday',
        customerId: 'c1',
        customerName: '王芳',
      );
      final otherDayReminder = ReminderOccurrence(
        id: 'birthday:c1:2026-01-02',
        type: ReminderType.birthday,
        occurrenceDate: DateTime(2026, 1, 2),
        title: '王芳生日提醒',
        body: '王芳生日还有 3 天',
        dueLabel: '还有 3 天',
        sourceKey: 'birthday',
        customerId: 'c1',
        customerName: '王芳',
      );

      expect(await store.isCompleted(reminder), isFalse);

      await store.markCompleted(reminder);

      expect(await store.isCompleted(reminder), isTrue);
      expect(await store.isCompleted(otherDayReminder), isFalse);
      expect(await store.filterActive([reminder, otherDayReminder]), [
        otherDayReminder,
      ]);

      await store.unmarkCompleted(reminder);

      expect(await store.isCompleted(reminder), isFalse);
      expect(await store.filterActive([reminder, otherDayReminder]), [
        reminder,
        otherDayReminder,
      ]);
    });
  });
}
