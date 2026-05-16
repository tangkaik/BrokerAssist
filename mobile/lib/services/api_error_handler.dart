import 'package:flutter/material.dart';
import 'auth_session.dart';

/// API 错误处理器
/// - 显示 toast 提示
/// - 401 自动跳转登录页
class ApiErrorHandler {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void handleError(String message, {String? code}) {
    if (code == 'HTTP_401') {
      _navigateToLogin();
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final displayMessage = _friendlyMessage(code, message);
    _showSnackBar(context, displayMessage);
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void _navigateToLogin() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    AuthSession.clear();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('登录已过期，请重新登录'),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static String _friendlyMessage(String? code, String message) {
    if (code == 'NETWORK_ERROR') return '网络连接失败，请检查网络';
    if (code == 'HTTP_500') return '服务器错误，请稍后重试';
    if (code == 'HTTP_502' || code == 'HTTP_503') return '服务暂不可用，请稍后重试';
    if (code == 'TIMEOUT') return '请求超时，请重试';
    return message;
  }
}
