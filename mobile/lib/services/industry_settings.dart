import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

class IndustryOption {
  final String key;
  final String label;
  final String workspaceLabel;
  final IconData icon;

  const IndustryOption({
    required this.key,
    required this.label,
    required this.workspaceLabel,
    required this.icon,
  });

  static const generic = IndustryOption(
    key: 'generic',
    label: '通用',
    workspaceLabel: '通用顾问工作区',
    icon: Icons.work_outline_rounded,
  );

  static const options = [
    generic,
    IndustryOption(
      key: 'insurance',
      label: '保险经纪',
      workspaceLabel: '保险顾问工作区',
      icon: Icons.health_and_safety_outlined,
    ),
    IndustryOption(
      key: 'real_estate',
      label: '房产顾问',
      workspaceLabel: '房产顾问工作区',
      icon: Icons.apartment_rounded,
    ),
    IndustryOption(
      key: 'education',
      label: '教育咨询',
      workspaceLabel: '教育顾问工作区',
      icon: Icons.school_outlined,
    ),
    IndustryOption(
      key: 'medical_beauty',
      label: '医美咨询',
      workspaceLabel: '医美顾问工作区',
      icon: Icons.spa_outlined,
    ),
    IndustryOption(
      key: 'wealth',
      label: '财富顾问',
      workspaceLabel: '财富顾问工作区',
      icon: Icons.account_balance_wallet_outlined,
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
    _hasSelectedIndustry = savedKey != null;
    selected.value = IndustryOption.byKey(
      savedKey ?? IndustryOption.generic.key,
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
  }
}
