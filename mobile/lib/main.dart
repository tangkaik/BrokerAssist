import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/customer_list_page.dart';
import 'pages/ai_chat_page.dart';
import 'pages/login_page.dart';
import 'pages/account_page.dart';
import 'services/api_config.dart';
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

  Widget _buildTab(int index) {
    return Navigator(
      key: _keys[index],
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

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, _buildTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          // 如果点击当前 Tab，pop 到根页面
          if (index == _currentIndex) {
            _keys[index].currentState?.popUntil((route) => route.isFirst);
          }
          setState(() => _currentIndex = index);
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
    );
  }
}
