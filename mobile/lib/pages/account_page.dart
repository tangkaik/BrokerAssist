import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api.dart';
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
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _exportCustomersExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final response = await apiService.exportCustomersExcel();
      if (!mounted) return;
      if (!response.success || response.data == null) {
        _showMessage(response.error?.message ?? '导出失败');
        return;
      }

      final file = response.data!;
      final dir = await getTemporaryDirectory();
      final safeName = file.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${dir.path}/$safeName';
      await File(path).writeAsBytes(file.bytes, flush: true);
      await Share.shareXFiles([
        XFile(path, mimeType: file.contentType, name: safeName),
      ], text: '客户导出 Excel');
    } catch (e) {
      if (mounted) _showMessage('导出失败: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importCustomersExcel() async {
    if (_isImporting) return;

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        allowMultiple: false,
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null || path.isEmpty) return;

      setState(() => _isImporting = true);
      final response = await apiService.importCustomersExcel(path);
      if (!mounted) return;
      if (!response.success || response.data == null) {
        _showMessage(response.error?.message ?? '导入失败');
        return;
      }

      final data = response.data!;
      final created = data['created'] as int? ?? 0;
      final skipped = data['skipped'] as int? ?? 0;
      final failed = data['failed'] as int? ?? 0;
      _showMessage('导入完成：新增 $created 位，跳过 $skipped 位，失败 $failed 行');
    } catch (e) {
      if (mounted) _showMessage('导入失败: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
          ListTile(
            leading: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined),
            title: const Text('导出客户 Excel'),
            subtitle: const Text('导出当前账号下的全部客户资料'),
            onTap: _isExporting ? null : _exportCustomersExcel,
          ),
          ListTile(
            leading: _isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_outlined),
            title: const Text('导入客户 Excel'),
            subtitle: const Text('从 .xlsx 文件批量创建客户'),
            onTap: _isImporting ? null : _importCustomersExcel,
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
