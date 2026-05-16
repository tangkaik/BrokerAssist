part of '../customer_detail_page.dart';

extension _CustomerDetailFormatters on _CustomerDetailPageState {
  String get _locationDisplay {
    final c = _customer;
    if (c == null) return '';
    final parts = <String>[
      if (c.locationRaw != null && c.locationRaw!.isNotEmpty) c.locationRaw!,
      if (c.locationDistrict != null && c.locationDistrict!.isNotEmpty)
        c.locationDistrict!,
      if (c.locationSubarea != null && c.locationSubarea!.isNotEmpty)
        c.locationSubarea!,
    ];
    // 去重：避免 location_raw 已经包含下级信息时重复显示
    final seen = <String>{};
    final unique = <String>[];
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed)) {
        unique.add(trimmed);
      }
    }
    return unique.join(' · ');
  }

  String _displayGender(String raw) {
    switch (raw.trim()) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return raw;
    }
  }

  String _firstLine(String text, {int maxLength = 58}) {
    final cleaned = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join(' ');
    if (cleaned.length <= maxLength) return cleaned;
    return '${cleaned.substring(0, maxLength)}...';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_pad(date.month)}-${_pad(date.day)} '
        '${_pad(date.hour)}:${_pad(date.minute)}';
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}

class _PriorityItem {
  final IconData icon;
  final Color color;
  final String text;

  const _PriorityItem({
    required this.icon,
    required this.color,
    required this.text,
  });
}

const _profileTagStopWords = <String>{
  '当前已知情况',
  '最多3点',
  '客户',
  '因为',
  '产生',
  '预算',
  '有限',
  '需要',
  '建议',
  '沟通',
  '记录',
  '保险',
  '投保',
  '拜访',
  '下一次',
  '下一步',
  '目前',
  '暂无',
  '情况',
  '画像',
  '重点',
  '风险',
};
