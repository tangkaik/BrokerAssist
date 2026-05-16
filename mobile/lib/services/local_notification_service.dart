import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<String?> notificationTapPayload = ValueNotifier<String?>(
    null,
  );

  bool _initialized = false;

  static const int _notificationBaseId = 730000;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        notificationTapPayload.value = response.payload;
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      notificationTapPayload.value =
          launchDetails?.notificationResponse?.payload;
    }
    _initialized = true;
  }

  Future<void> requestPermission() async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> refreshSchedules(List<ReminderOccurrence> reminders) async {
    await initialize();
    await _cancelReminderNotifications();

    final groups = ReminderGroups.from(reminders);
    for (final group in groups) {
      final scheduledAt = _scheduledAt(group.occurrenceDate);
      if (scheduledAt.isBefore(tz.TZDateTime.now(tz.local))) continue;

      await _plugin.zonedSchedule(
        id: _notificationId(group),
        title: group.notificationTitle,
        body: group.notificationBody,
        scheduledDate: scheduledAt,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'broker_assist_reminders',
            '客户提醒',
            channelDescription: '生日、节日、保单缴费等客户提醒',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'reminders:${group.type.name}',
      );
    }
  }

  Future<void> _cancelReminderNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _notificationBaseId &&
          request.id < _notificationBaseId + 100000) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  tz.TZDateTime _scheduledAt(DateTime date) {
    return tz.TZDateTime(tz.local, date.year, date.month, date.day, 9);
  }

  int _notificationId(ReminderGroupSummary group) {
    final date = group.occurrenceDate;
    final dateNumber = date.month * 100 + date.day;
    return _notificationBaseId + dateNumber * 10 + group.type.index;
  }
}
