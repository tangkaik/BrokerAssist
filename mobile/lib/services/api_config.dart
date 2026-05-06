import 'package:shared_preferences/shared_preferences.dart';

/// API 配置管理（运行时切换）
///
/// 支持：
/// - 默认线上测试服务器
/// - 自定义地址（便于切换到其他环境）
class ApiConfig {
  static const String _keyBaseUrl = 'api_base_url';

  /// 默认地址
  ///
  /// Android 模拟器访问宿主机 localhost 需要使用 10.0.2.2。
  /// 如需切换线上测试服务器，可在设置页里手动修改 API 地址。
  static const String defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8001/api/v1',
  );

  /// 当前使用的地址
  static String _currentUrl = defaultUrl;

  /// 获取当前地址
  static String get baseUrl => _currentUrl;

  /// 加载保存的配置
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUrl = prefs.getString(_keyBaseUrl) ?? defaultUrl;
  }

  /// 设置新地址
  static Future<void> setBaseUrl(String url) async {
    _currentUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url);
  }

  /// 重置为默认
  static Future<void> reset() async {
    _currentUrl = defaultUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBaseUrl);
  }
}
