import 'package:pinyin/pinyin.dart';

import '../models/models.dart';

bool isPinyinLikeKeyword(String keyword) {
  final normalized = keyword.trim();
  if (normalized.isEmpty) return false;
  return RegExp(r'^[a-zA-Z]+$').hasMatch(normalized);
}

bool customerMatchesKeyword(Customer customer, String keyword) {
  final normalized = keyword.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  final name = customer.name.toLowerCase();
  final phone = customer.phone?.toLowerCase() ?? '';
  final summary = customer.summary?.toLowerCase() ?? '';
  final tags = customer.tags.map((tag) => tag.toLowerCase()).join(' ');

  if (name.contains(normalized) ||
      phone.contains(normalized) ||
      summary.contains(normalized) ||
      tags.contains(normalized)) {
    return true;
  }

  final pinyinWords = PinyinHelper.getPinyinE(customer.name)
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  final fullPinyin = pinyinWords.join('');
  final initials = pinyinWords.map((word) => word[0]).join();

  return fullPinyin.contains(normalized) ||
      initials.contains(normalized) ||
      pinyinWords.any((word) => word.startsWith(normalized));
}
