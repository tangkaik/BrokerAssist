import 'package:flutter/material.dart';

import '../services/auth_session.dart';
import '../services/industry_settings.dart';
import 'api_settings_page.dart';

class AccountPage extends StatefulWidget {
  final Future<void> Function() onLogout;

  const AccountPage({super.key, required this.onLogout});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    final user = AuthSession.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('我的账号')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name?.isNotEmpty == true ? user!.name! : '未命名用户',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(user?.account ?? '未登录'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<IndustryOption>(
            valueListenable: IndustrySettings.selected,
            builder: (context, industry, _) {
              return ListTile(
                leading: const Icon(Icons.work_outline_rounded),
                title: const Text('行业设置'),
                subtitle: Text('已锁定：${industry.workspaceLabel}'),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('API 设置'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ApiSettingsPage()),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}
