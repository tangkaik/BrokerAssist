import 'package:flutter/material.dart';
import 'analytics_export_page.dart';
import '../services/api_config.dart';
import '../theme/brand_colors.dart';

/// API 地址设置页
/// 
/// 用于运行时切换后端 API 地址：
/// - 默认线上测试服务器
/// - 可手动切换到其他环境
class ApiSettingsPage extends StatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  State<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends State<ApiSettingsPage> {
  late TextEditingController _urlController;
  String _currentUrl = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = ApiConfig.baseUrl;
    _urlController = TextEditingController(text: _currentUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// 保存配置
  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 API 地址')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      await ApiConfig.setBaseUrl(url);
      setState(() => _currentUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功，重新启动 App 生效')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 重置为默认
  Future<void> _reset() async {
    setState(() => _isSaving = true);
    
    try {
      await ApiConfig.reset();
      setState(() {
        _currentUrl = ApiConfig.baseUrl;
        _urlController.text = _currentUrl;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已重置为默认值')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重置失败: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 地址设置'),
        backgroundColor: BrandColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前地址
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '当前 API 地址',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentUrl,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 输入框
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'API 地址',
                hintText: 'http://39.106.169.40/api/v1',
                helperText: '默认已指向当前测试服务器，也可以手动切换',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.http),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            
            // 快捷选择
            Text(
              '快捷选择：',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('线上测试服'),
                  onPressed: () {
                    _urlController.text = 'http://39.106.169.40/api/v1';
                  },
                ),
                ActionChip(
                  label: const Text('本机开发'),
                  onPressed: () {
                    _urlController.text = 'http://127.0.0.1:8001/api/v1';
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? '保存中...' : '保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BrandColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // 重置按钮
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _reset,
                icon: const Icon(Icons.restore),
                label: const Text('重置为默认'),
              ),
            ),
            
            const Spacer(),
            
            // 数据分析入口
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsExportPage()));
                },
                icon: const Icon(Icons.analytics, color: Colors.green),
                label: const Text(
                  '数据统计与导出',
                  style: TextStyle(color: Colors.green),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '修改后需要重新启动 App 才能生效',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
