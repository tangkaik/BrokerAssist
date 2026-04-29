import 'package:flutter/material.dart';

/// 客户头像组件
/// - 有头像 URL 则显示真实头像
/// - 否则显示姓名首字，颜色根据姓名 hash 生成
class CustomerAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;

  const CustomerAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: Colors.grey[200],
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _colorFromName(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withAlpha(40),
      child: Text(
        initial,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }

  /// 根据姓名 hash 生成颜色
  static Color _colorFromName(String name) {
    final colors = [
      const Color(0xFF2196F3), // 蓝
      const Color(0xFF4CAF50), // 绿
      const Color(0xFFFF9800), // 橙
      const Color(0xFF9C27B0), // 紫
      const Color(0xFF00BCD4), // 青
      const Color(0xFFE91E63), // 粉
      const Color(0xFF795548), // 棕
      const Color(0xFF607D8B), // 蓝灰
    ];

    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % colors.length;
    return colors[index];
  }
}
