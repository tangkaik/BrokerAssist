import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class ReminderCompletionStore {
  ReminderCompletionStore({required this.userId});

  final String userId;

  String get _storageKey => 'reminders:completed:$userId';

  Future<bool> isCompleted(ReminderOccurrence reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_storageKey) ?? const [];
    return completed.contains(reminder.completionKey(userId));
  }

  Future<void> markCompleted(ReminderOccurrence reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_storageKey) ?? const [];
    final key = reminder.completionKey(userId);
    if (completed.contains(key)) return;
    await prefs.setStringList(_storageKey, [...completed, key]);
  }

  Future<void> unmarkCompleted(ReminderOccurrence reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_storageKey) ?? const [];
    final key = reminder.completionKey(userId);
    await prefs.setStringList(
      _storageKey,
      completed.where((item) => item != key).toList(),
    );
  }

  Future<List<ReminderOccurrence>> filterActive(
    List<ReminderOccurrence> reminders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = (prefs.getStringList(_storageKey) ?? const []).toSet();
    return reminders
        .where(
          (reminder) => !completed.contains(reminder.completionKey(userId)),
        )
        .toList();
  }
}
