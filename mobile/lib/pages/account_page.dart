import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api.dart';
import '../services/auth_session.dart';
import '../services/industry_settings.dart';
import '../theme/brand_colors.dart';
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

    final shouldPickFile = await _showImportRequirementsSheet();
    if (shouldPickFile != true || !mounted) return;

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

  Future<bool?> _showImportRequirementsSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导入客户 Excel',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                const _ImportRequirementItem(text: '只支持 .xlsx 文件。'),
                const _ImportRequirementItem(text: '第一行必须是表头。'),
                const _ImportRequirementItem(text: '必须有“客户姓名”列，也可写“姓名”。'),
                const _ImportRequirementItem(text: '可选列：电话、性别、年龄、生日、地址、标签。'),
                const _ImportRequirementItem(
                  text: '生日用 YYYY-MM-DD，标签可用“、”或“,”分隔；重复客户会跳过。',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('选择 Excel 文件'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
      backgroundColor: BrandColors.background,
      appBar: AppBar(title: const Text('我的账号')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
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
                leading: const Icon(
                  Icons.work_outline_rounded,
                  color: BrandColors.primaryDark,
                ),
                title: const Text('行业设置'),
                subtitle: Text('已锁定：${industry.workspaceLabel}'),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.settings_outlined,
              color: BrandColors.primaryDark,
            ),
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
                : const Icon(
                    Icons.table_view_outlined,
                    color: BrandColors.primaryDark,
                  ),
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
                : const Icon(
                    Icons.upload_file_outlined,
                    color: BrandColors.primaryDark,
                  ),
            title: const Text('导入客户 Excel'),
            subtitle: const Text('从 .xlsx 文件批量创建客户'),
            onTap: _isImporting ? null : _importCustomersExcel,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportRequirementItem extends StatelessWidget {
  final String text;

  const _ImportRequirementItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 8, right: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
