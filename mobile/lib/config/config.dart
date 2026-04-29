/// App 配置文件
/// 
/// P1 阶段：基础配置，仅包含后端 API 地址
class AppConfig {
  /// 后端 API 基础地址
  /// 
  /// 默认指向当前测试服务器。
  /// 如需覆盖，可在构建时通过 --dart-define=API_BASE_URL=... 传入。
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://39.106.169.40/api/v1',
  );
  
  /// 默认用户 Token（开发调试使用）
  static const String defaultToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZGVmYXVsdC11c2VyIn0.FRHB6-A51jwFCjJ3Y5FAyKXe8iQhZqA3-KjeymG6dZw';
  
  /// 连接超时时间（秒）
  static const int connectTimeout = 10;
  
  /// 接收超时时间（秒）
  static const int receiveTimeout = 30;
}
