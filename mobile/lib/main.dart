import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/home_page.dart';
import 'pages/customer_list_page.dart';
import 'pages/ai_chat_page.dart';
import 'pages/login_page.dart';
import 'pages/account_page.dart';
import 'pages/customer_detail_page.dart';
import 'pages/reminder_center_page.dart';
import 'services/api_config.dart';
import 'services/api.dart';
import 'services/auth_session.dart';
import 'services/api_error_handler.dart';
import 'services/industry_settings.dart';
import 'services/local_notification_service.dart';
import 'services/reminder_data_service.dart';
import 'theme/brand_colors.dart';
import 'models/models.dart';

/// BrokerAssist App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await AuthSession.load();
  await IndustrySettings.load();
  await LocalNotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isAuthenticated = AuthSession.isLoggedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.authVersion.addListener(_syncAuthState);
    LocalNotificationService.instance.notificationTapPayload.addListener(
      _handleNotificationTap,
    );
    _refreshCurrentUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthSession.authVersion.removeListener(_syncAuthState);
    LocalNotificationService.instance.notificationTapPayload.removeListener(
      _handleNotificationTap,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthSession.isLoggedIn) {
      ReminderDataService.refreshLocalNotificationSchedule();
    }
  }

  Future<void> _handleNotificationTap() async {
    final payload =
        LocalNotificationService.instance.notificationTapPayload.value;
    if (payload == null || !payload.startsWith('reminders')) return;
    LocalNotificationService.instance.notificationTapPayload.value = null;
    if (!AuthSession.isLoggedIn) return;

    final reminderStatuses =
        await ReminderDataService.loadTodayReminderStatuses(updateCount: true);
    final navigator = ApiErrorHandler.navigatorKey.currentState;
    if (navigator == null || reminderStatuses.isEmpty) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReminderCenterPage(
          initialReminders: reminderStatuses
              .map((item) => item.reminder)
              .toList(),
          initialCompletedReminderIds: reminderStatuses
              .where((item) => item.isCompleted)
              .map((item) => item.reminder.id)
              .toSet(),
          onOpenCustomer: (customerId) async {
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailPage(),
                settings: RouteSettings(arguments: customerId),
              ),
            );
          },
          onRefreshCompletedReminderIds: () async {
            final statuses = await ReminderDataService.loadTodayReminderStatuses(
              updateCount: true,
            );
            return statuses
                .where((item) => item.isCompleted)
                .map((item) => item.reminder.id)
                .toSet();
          },
          onCompleteReminder: ReminderDataService.markCompleted,
          onReopenReminder: ReminderDataService.reopenReminder,
        ),
      ),
    );
  }

  void _syncAuthState() {
    if (!mounted) return;
    setState(() => _isAuthenticated = AuthSession.isLoggedIn);
  }

  Future<void> _refreshCurrentUser() async {
    if (!AuthSession.isLoggedIn) return;
    final response = await apiService.me();
    if (!mounted) return;
    if (response.success && response.data != null) {
      await AuthSession.updateUser(response.data!);
      await IndustrySettings.load();
      await ReminderDataService.refreshLocalNotificationSchedule();
    } else if (response.error?.code == 'UNAUTHORIZED' ||
        response.error?.code == 'HTTP_401') {
      await AuthSession.clear();
      IndustrySettings.resetInMemory();
    }
    _syncAuthState();
  }

  Future<void> _handleAuthenticated(AuthSessionData session) async {
    await AuthSession.save(token: session.token, user: session.user);
    await IndustrySettings.load();
    _syncAuthState();
    await ReminderDataService.refreshLocalNotificationSchedule();
  }

  Future<void> _handleLogout() async {
    await AuthSession.clear();
    IndustrySettings.resetInMemory();
    _syncAuthState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '客记',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: BrandColors.primary),
        scaffoldBackgroundColor: BrandColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: BrandColors.background,
          foregroundColor: BrandColors.ink,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      navigatorKey: ApiErrorHandler.navigatorKey,
      home: _isAuthenticated
          ? KeyedSubtree(
              key: const ValueKey('authenticated-home'),
              child: MainNavigationScreen(onLogout: _handleLogout),
            )
          : KeyedSubtree(
              key: const ValueKey('login-home'),
              child: LoginPage(onAuthenticated: _handleAuthenticated),
            ),
    );
  }
}

/// 主导航屏 — 底部栏始终悬浮，每个 Tab 有独立 Navigator
class MainNavigationScreen extends StatefulWidget {
  final Future<void> Function() onLogout;

  const MainNavigationScreen({super.key, required this.onLogout});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _homeReminderCount = ReminderDataService.todayReminderCount.value;
  final List<int> _tabHistory = [];
  final List<int> _tabDepths = [1, 1, 1, 1];
  late final List<_TabStackObserver> _tabObservers;

  final _keys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  List<Widget> get _tabPages => [
    const HomePage(),
    const CustomerListPage(),
    const AIChatPage(),
    AccountPage(onLogout: widget.onLogout),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderDataService.todayReminderCount.addListener(_syncHomeReminderCount);
    ReminderDataService.refreshTodayReminderCount();
    _tabObservers = List.generate(
      4,
      (index) => _TabStackObserver(
        onDepthChanged: (depth) {
          if (!mounted || _tabDepths[index] == depth) return;
          setState(() => _tabDepths[index] = depth);
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReminderDataService.todayReminderCount.removeListener(
      _syncHomeReminderCount,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthSession.isLoggedIn) {
      ReminderDataService.refreshTodayReminderCount();
    }
  }

  void _syncHomeReminderCount() {
    if (!mounted) return;
    setState(() {
      _homeReminderCount = ReminderDataService.todayReminderCount.value;
    });
  }

  Widget _buildTab(int index) {
    return Navigator(
      key: _keys[index],
      observers: [_tabObservers[index]],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => _tabPages[index],
          settings: settings,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = <({IconData icon, IconData selectedIcon, String label})>[
      (icon: Icons.home_outlined, selectedIcon: Icons.home, label: '首页'),
      (icon: Icons.people_outline, selectedIcon: Icons.people, label: '客户'),
      (
        icon: Icons.smart_toy_outlined,
        selectedIcon: Icons.smart_toy,
        label: 'AI 助手',
      ),
      (icon: Icons.person_outline, selectedIcon: Icons.person, label: '我的'),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final currentNavigator = _keys[_currentIndex].currentState;
        if (currentNavigator != null && await currentNavigator.maybePop()) {
          return;
        }

        if (_tabHistory.isNotEmpty) {
          setState(() => _currentIndex = _tabHistory.removeLast());
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(4, _buildTab),
        ),
        bottomNavigationBar: _tabDepths[_currentIndex] > 1
            ? null
            : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  // 如果点击当前 Tab，pop 到根页面
                  if (index == _currentIndex) {
                    _keys[index].currentState?.popUntil(
                      (route) => route.isFirst,
                    );
                    return;
                  }

                  setState(() {
                    _tabHistory.remove(index);
                    _tabHistory.add(_currentIndex);
                    _currentIndex = index;
                  });
                },
                destinations: List.generate(navItems.length, (index) {
                  final item = navItems[index];
                  final isHome = index == 0;
                  return NavigationDestination(
                    icon: isHome
                        ? HomeTabIconWithBadge(
                            icon: item.icon,
                            count: _homeReminderCount,
                            selected: false,
                          )
                        : Icon(item.icon),
                    selectedIcon: isHome
                        ? HomeTabIconWithBadge(
                            icon: item.selectedIcon,
                            count: _homeReminderCount,
                            selected: true,
                          )
                        : Icon(item.selectedIcon),
                    label: item.label,
                  );
                }),
              ),
      ),
    );
  }
}

class HomeTabIconWithBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool selected;

  const HomeTabIconWithBadge({
    super.key,
    required this.icon,
    required this.count,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final badgeText = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: selected ? 25 : 24),
          if (count > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabStackObserver extends NavigatorObserver {
  _TabStackObserver({required this.onDepthChanged});

  final ValueChanged<int> onDepthChanged;
  int _depth = 1;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute == null) return;
    _depth += 1;
    onDepthChanged(_depth);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute == null) return;
    _depth = (_depth - 1).clamp(1, 99);
    onDepthChanged(_depth);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _depth = (_depth - 1).clamp(1, 99);
    onDepthChanged(_depth);
  }
}
