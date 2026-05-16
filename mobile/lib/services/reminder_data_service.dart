import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api.dart';
import 'auth_session.dart';
import 'industry_settings.dart';
import 'local_notification_service.dart';
import 'reminder_completion_store.dart';
import 'reminder_engine.dart';

class ReminderDataService {
  static const int customerScanLimit = 100;
  static const int recordScanLimit = 20;
  static const int scheduleWindowDays = 30;
  static final ValueNotifier<int> todayReminderCount = ValueNotifier<int>(0);

  static Future<List<ReminderOccurrence>> loadTodayReminders() async {
    final statuses = await loadTodayReminderStatuses(updateCount: true);
    return statuses
        .where((item) => !item.isCompleted)
        .map((item) => item.reminder)
        .toList();
  }

  static Future<List<ReminderOccurrenceStatus>> loadTodayReminderStatuses({
    bool updateCount = false,
  }) async {
    if (!AuthSession.isLoggedIn) {
      if (updateCount) todayReminderCount.value = 0;
      return const [];
    }

    try {
      final customers = await _loadCustomersForReminderScan();
      final records = await _loadRecordsByCustomer(customers);
      final reminders = ReminderEngine(today: DateTime.now()).build(
        customers: customers,
        recordsByCustomerId: records,
        reminderRules: IndustrySettings.current.reminderRules,
      );
      final store = _completionStore();
      final statuses = <ReminderOccurrenceStatus>[];
      for (final reminder in reminders) {
        statuses.add(
          ReminderOccurrenceStatus(
            reminder: reminder,
            isCompleted: await store.isCompleted(reminder),
          ),
        );
      }
      if (updateCount) {
        todayReminderCount.value = statuses
            .where((item) => !item.isCompleted)
            .length;
      }
      return statuses;
    } catch (_) {
      if (updateCount) todayReminderCount.value = 0;
      return const [];
    }
  }

  static Future<int> refreshTodayReminderCount() async {
    final reminders = await loadTodayReminders();
    return reminders.length;
  }

  static Future<void> refreshLocalNotificationSchedule() async {
    if (!AuthSession.isLoggedIn) return;

    try {
      final customers = await _loadCustomersForReminderScan();
      final records = await _loadRecordsByCustomer(customers);
      final reminders = <ReminderOccurrence>[];
      final today = DateTime.now();
      for (var offset = 0; offset < scheduleWindowDays; offset++) {
        final day = today.add(Duration(days: offset));
        reminders.addAll(
          ReminderEngine(today: day).build(
            customers: customers,
            recordsByCustomerId: records,
            reminderRules: IndustrySettings.current.reminderRules,
          ),
        );
      }

      final active = await _completionStore().filterActive(reminders);
      await LocalNotificationService.instance.requestPermission();
      await LocalNotificationService.instance.refreshSchedules(active);
    } catch (_) {
      return;
    }
  }

  static Future<void> markCompleted(ReminderOccurrence reminder) async {
    await _completionStore().markCompleted(reminder);
    await refreshLocalNotificationSchedule();
    await refreshTodayReminderCount();
  }

  static Future<void> reopenReminder(ReminderOccurrence reminder) async {
    await _completionStore().unmarkCompleted(reminder);
    await refreshLocalNotificationSchedule();
    await refreshTodayReminderCount();
  }

  static Future<List<Customer>> _loadCustomersForReminderScan() async {
    final response = await apiService.searchCustomers(
      page: 1,
      pageSize: customerScanLimit,
      sortBy: 'updated_at',
      sortOrder: 'desc',
    );
    if (!response.success || response.data == null) return const [];
    return response.data!.items;
  }

  static Future<Map<String, List<Record>>> _loadRecordsByCustomer(
    List<Customer> customers,
  ) async {
    final result = <String, List<Record>>{};
    if (customers.isEmpty) return result;

    for (final customer in customers) {
      try {
        final response = await apiService.getCustomerRecords(
          customerId: customer.id,
          limit: recordScanLimit,
        );
        if (response.success && response.data != null) {
          result[customer.id] = response.data!.items;
        }
      } catch (error) {
        debugPrint('加载${customer.name}的提醒记录失败: $error');
      }
    }
    return result;
  }

  static ReminderCompletionStore _completionStore() {
    return ReminderCompletionStore(userId: AuthSession.currentUser!.id);
  }
}
