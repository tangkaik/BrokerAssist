# Local Reminder Red Dot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a bottom-navigation badge on the Home tab when today's local reminders are still active, and keep it in sync when reminders are completed.

**Architecture:** Reuse the existing `ReminderDataService.loadTodayReminders()` source of truth. `MainNavigationScreen` owns the Home tab badge count and exposes a refresh callback to `ReminderCenterPage`; reminder completion flows refresh both local schedules and the badge count. UI rendering stays local to `main.dart`.

**Tech Stack:** Flutter, Dart, flutter_test, existing local reminder services.

---

### Task 1: Add Home Tab Badge Rendering

**Files:**
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/reminder_widgets_test.dart`

- [ ] **Step 1: Write failing widget test**

Add a small widget test that pumps `MainNavigationScreen` behind a logged-in session is too expensive because it loads API data. Instead extract a pure badge widget from `main.dart` and test it directly:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/reminder_widgets_test.dart`

Expected: fail because `HomeTabIconWithBadge` does not exist.

- [ ] **Step 3: Implement badge widget and use it in bottom navigation**

In `mobile/lib/main.dart`, add `HomeTabIconWithBadge` and use it for the Home destination icon and selectedIcon. Badge text is hidden at zero, `99+` above 99.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/reminder_widgets_test.dart`

Expected: pass.

### Task 2: Keep Badge Count In Sync

**Files:**
- Modify: `mobile/lib/main.dart`

- [ ] **Step 1: Add reminder count state**

Add `_homeReminderCount` to `_MainNavigationScreenState`, load it from `ReminderDataService.loadTodayReminders()`, and refresh on init/resume.

- [ ] **Step 2: Refresh after reminder completion**

Pass a wrapped completion callback to `ReminderCenterPage` so completing a reminder updates `_homeReminderCount`.

- [ ] **Step 3: Refresh when returning from reminder page**

After `ReminderCenterPage` pops, reload the count so the Home badge matches the latest reminders.

- [ ] **Step 4: Verify**

Run:

```bash
flutter analyze
flutter test
```

Expected: analyzer reports no issues and all tests pass.

### Task 3: Install On Simulator

**Files:**
- No code changes expected.

- [ ] **Step 1: Build and install**

Run: `flutter run -d emulator-5554 --debug --no-resident`

Expected: debug APK builds and installs successfully on the running Android emulator.
