import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'auth_session.dart';

class IndustryOption {
  final String key;
  final String label;
  final String workspaceLabel;
  final IconData icon;
  final String quickTip;

  const IndustryOption({
    required this.key,
    required this.label,
    required this.workspaceLabel,
    required this.icon,
    required this.quickTip,
  });

  static const generic = IndustryOption(
    key: 'generic',
    label: '通用',
    workspaceLabel: '通用顾问',
    icon: Icons.work_outline_rounded,
    quickTip: '把每次客户沟通记下来，AI 自动回顾并帮你判断下次跟进时机',
  );

  static const options = [
    generic,
    IndustryOption(
      key: 'insurance',
      label: '保险经纪',
      workspaceLabel: '保险顾问',
      icon: Icons.health_and_safety_outlined,
      quickTip: '每次见完客户，打开录音说 60 秒，AI 自动帮你整理要点和下一步建议',
    ),
    IndustryOption(
      key: 'real_estate',
      label: '房产顾问',
      workspaceLabel: '房产顾问',
      icon: Icons.apartment_rounded,
      quickTip: '记录客户偏好和预算范围，AI 自动整理并提醒匹配的房源方向',
    ),
  ];

  static IndustryOption byKey(String key) {
    return options.firstWhere(
      (option) => option.key == key,
      orElse: () => generic,
    );
  }
}

class IndustrySettings {
  static const String _legacyIndustryStorageKey = 'home:selected-industry';
  static const String _industryStoragePrefix = 'industry:selected';

  static final ValueNotifier<IndustryOption> selected =
      ValueNotifier<IndustryOption>(IndustryOption.generic);

  static bool _hasSelectedIndustry = false;

  static bool get hasSelectedIndustry => _hasSelectedIndustry;
  static IndustryOption get current => selected.value;

  static String get _industryStorageKey {
    final user = AuthSession.currentUser;
    if (user == null) return _legacyIndustryStorageKey;
    return '$_industryStoragePrefix:${user.id}';
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_industryStorageKey);
    final userIndustryKey = AuthSession.currentUser?.industryKey;
    final userIndustrySelected =
        AuthSession.currentUser?.industrySelected ?? false;
    final effectiveKey = userIndustryKey?.isNotEmpty == true
        ? userIndustryKey
        : savedKey;
    _hasSelectedIndustry = userIndustrySelected || savedKey != null;
    selected.value = IndustryOption.byKey(
      effectiveKey ?? IndustryOption.generic.key,
    );
  }

  static void resetInMemory() {
    _hasSelectedIndustry = false;
    selected.value = IndustryOption.generic;
  }

  static Future<void> save(IndustryOption industry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_industryStorageKey, industry.key);
    _hasSelectedIndustry = true;
    selected.value = industry;

    if (AuthSession.isLoggedIn) {
      final response = await apiService.updatePreferences(
        industryKey: industry.key,
      );
      if (response.success && response.data != null) {
        await AuthSession.updateUser(response.data!);
      }
    }
  }
}
