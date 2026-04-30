import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/draft_record_page.dart';
import 'pages/customer_list_page.dart';
import 'pages/create_customer_page.dart';
import 'pages/edit_customer_page.dart';
import 'pages/add_to_existing_page.dart';
import 'pages/customer_detail_page.dart';
import 'pages/ai_chat_page.dart';
import 'pages/api_settings_page.dart';
import 'pages/analytics_export_page.dart';
import 'pages/login_page.dart';
import 'pages/account_page.dart';
import 'services/api_config.dart';
import 'services/auth_session.dart';
import 'services/api_error_handler.dart';
import 'services/industry_settings.dart';
import 'models/models.dart';

/// BrokerAssist App
///
/// P2 阶段：完整底部导航 + 首页草稿工作台
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 API 配置（运行时切换用）
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
      // 路由配置
      routes: {
        '/login': (context) => LoginPage(onAuthenticated: _handleAuthenticated),
        '/draft-record': (context) => const DraftRecordPage(),
        '/create-customer': (context) => const CreateCustomerPage(),
        '/edit-customer': (context) => const EditCustomerPage(),
        '/add-to-existing': (context) => const AddToExistingPage(),
        '/customer-detail': (context) => const CustomerDetailPage(),
        '/ai-chat': (context) => const AIChatPage(),
        '/api-settings': (context) => const ApiSettingsPage(),
        '/analytics-export': (context) => const AnalyticsExportPage(),
      },
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

/// 主导航屏
///
/// P2 阶段：
/// - 首页：草稿工作台（录音、转写、编辑）
/// - 客户：客户列表
class MainNavigationScreen extends StatefulWidget {
  final Future<void> Function() onLogout;

  const MainNavigationScreen({super.key, required this.onLogout});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  /// 导航页面列表
  List<_NavItem> get _navItems => [
    const _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '首页',
      page: HomePage(),
    ),
    const _NavItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      label: '客户',
      page: CustomerListPage(),
    ),
    const _NavItem(
      icon: Icons.smart_toy_outlined,
      selectedIcon: Icons.smart_toy,
      label: 'AI 助手',
      page: AIChatPage(),
    ),
    _NavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '我的',
      page: AccountPage(onLogout: widget.onLogout),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// 导航项配置
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget page;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.page,
  });
}
