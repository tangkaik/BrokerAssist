import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/home_page.dart';
import 'pages/customer_list_page.dart';
import 'pages/ai_chat_page.dart';
import 'pages/login_page.dart';
import 'pages/account_page.dart';
import 'services/api_config.dart';
import 'services/api.dart';
import 'services/auth_session.dart';
import 'services/api_error_handler.dart';
import 'services/industry_settings.dart';
import 'models/models.dart';

/// BrokerAssist App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  await AuthSession.load();
  await IndustrySettings.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAuthenticated = AuthSession.isLoggedIn;

  @override
  void initState() {
    super.initState();
    AuthSession.authVersion.addListener(_syncAuthState);
    _refreshCurrentUser();
  }

  @override
  void dispose() {
    AuthSession.authVersion.removeListener(_syncAuthState);
    super.dispose();
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
  }

  Future<void> _handleLogout() async {
    await AuthSession.clear();
    IndustrySettings.resetInMemory();
    _syncAuthState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '保险助手',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
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
    final navItems = [
      (Icons.home_outlined, Icons.home, '首页'),
      (Icons.people_outline, Icons.people, '客户'),
      (Icons.smart_toy_outlined, Icons.smart_toy, 'AI 助手'),
      (Icons.person_outline, Icons.person, '我的'),
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
                destinations: navItems
                    .map(
                      (item) => NavigationDestination(
                        icon: Icon(item.$1),
                        selectedIcon: Icon(item.$2),
                        label: item.$3,
                      ),
                    )
                    .toList(),
              ),
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
