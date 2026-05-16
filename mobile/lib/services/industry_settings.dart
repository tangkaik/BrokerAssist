import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'auth_session.dart';

class IndustryAssistantSuggestionGroup {
  final String key;
  final String title;
  final String icon;
  final List<List<String>> variants;

  const IndustryAssistantSuggestionGroup({
    required this.key,
    required this.title,
    required this.icon,
    required this.variants,
  });

  factory IndustryAssistantSuggestionGroup.fromJson(Map<String, dynamic> json) {
    return IndustryAssistantSuggestionGroup(
      key: (json['key'] as String?)?.trim() ?? '',
      title: (json['title'] as String?)?.trim() ?? '',
      icon: (json['icon'] as String?)?.trim() ?? 'help',
      variants: _parseVariantRows(json['variants']),
    );
  }

  static List<List<String>> _parseVariantRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<List>()
        .map(
          (row) => row
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
        )
        .where((row) => row.isNotEmpty)
        .toList(growable: false);
  }
}

class IndustryReminderRules {
  final bool birthdayEnabled;
  final bool festivalEnabled;
  final String festivalGroupTitle;
  final String festivalBodyTemplate;
  final bool keyDateEnabled;
  final List<String> keyDateKeywords;
  final String keyDateTitleTemplate;
  final String keyDateBodyTemplate;
  final String keyDateGroupTitle;
  final String keyDateSourceKey;

  const IndustryReminderRules({
    this.birthdayEnabled = true,
    this.festivalEnabled = true,
    this.festivalGroupTitle = '节日关怀',
    this.festivalBodyTemplate = '{festival}还有 {days} 天，建议提前准备客户关怀。',
    this.keyDateEnabled = false,
    this.keyDateKeywords = const [],
    this.keyDateTitleTemplate = '{customer}关键日期提醒',
    this.keyDateBodyTemplate = '{customer} 的关键日期还有 {days} 天，请及时跟进。',
    this.keyDateGroupTitle = '关键日期',
    this.keyDateSourceKey = 'key_date_detected',
  });

  static const generic = IndustryReminderRules();

  static const insurance = IndustryReminderRules(
    festivalGroupTitle: '节日礼品',
    keyDateEnabled: true,
    keyDateKeywords: ['保单', '保费', '缴费', '续费', '到期', '扣款'],
    keyDateTitleTemplate: '{customer}保单缴费提醒',
    keyDateBodyTemplate: '{customer} 的保单缴费日还有 {days} 天，请及时跟进。',
    keyDateGroupTitle: '保单缴费',
    keyDateSourceKey: 'payment_date_detected',
  );

  factory IndustryReminderRules.fromJson(Map<String, dynamic>? json) {
    if (json == null) return generic;
    return IndustryReminderRules(
      birthdayEnabled: json['birthday_enabled'] as bool? ?? true,
      festivalEnabled: json['festival_enabled'] as bool? ?? true,
      festivalGroupTitle:
          (json['festival_group_title'] as String?)?.trim() ?? '节日关怀',
      festivalBodyTemplate:
          (json['festival_body_template'] as String?)?.trim() ??
          '{festival}还有 {days} 天，建议提前准备客户关怀。',
      keyDateEnabled: json['key_date_enabled'] as bool? ?? false,
      keyDateKeywords:
          (json['key_date_keywords'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false),
      keyDateTitleTemplate:
          (json['key_date_title_template'] as String?)?.trim() ??
          '{customer}关键日期提醒',
      keyDateBodyTemplate:
          (json['key_date_body_template'] as String?)?.trim() ??
          '{customer} 的关键日期还有 {days} 天，请及时跟进。',
      keyDateGroupTitle:
          (json['key_date_group_title'] as String?)?.trim() ?? '关键日期',
      keyDateSourceKey:
          (json['key_date_source_key'] as String?)?.trim() ??
          'key_date_detected',
    );
  }
}

const _commonHelpSuggestions = IndustryAssistantSuggestionGroup(
  key: 'help',
  title: '问产品用法',
  icon: 'help',
  variants: [
    ['客户画像怎么生成？', '下一步建议在哪里看？', '怎样添加一次客户沟通记录？'],
    ['怎么给客户添加标签？', '语音记录怎么确认到客户？', 'AI助手能查哪些客户条件？'],
    ['行业选择后还能修改吗？', '客户列表怎么搜索拼音？', '图片记录可以识别什么？'],
  ],
);

const _genericSuggestions = [
  IndustryAssistantSuggestionGroup(
    key: 'query',
    title: '查客户数据',
    icon: 'manage_search',
    variants: [
      ['哪些客户两个月没联系了？', '列出预算敏感的客户', '有哪些客户适合本周优先跟进？'],
      ['列出最近沟通频繁的客户', '哪些客户还没有明确需求？', '住在海淀区的客户有哪些？'],
      ['列出女性客户', '哪些客户提到价格顾虑？', '有多少客户超过两个月没联系？'],
    ],
  ),
  IndustryAssistantSuggestionGroup(
    key: 'assist',
    title: '客户跟进助手',
    icon: 'edit_note',
    variants: [
      ['给{first}写一段跟进微信', '总结{second}上次沟通，并给出这次建议', '明天见{third}，帮我准备会谈简报'],
      ['给{first}写一段久未回复后的跟进微信', '整理{second}的需求和顾虑', '见{third}前要确认哪些问题？'],
      ['给{first}写一段温和确认时间的微信', '{second}现在情况怎样，下一步怎么跟？', '{third}犹豫时怎么推进？'],
    ],
  ),
  _commonHelpSuggestions,
];

const _insuranceSuggestions = [
  IndustryAssistantSuggestionGroup(
    key: 'query',
    title: '查客户数据',
    icon: 'manage_search',
    variants: [
      ['哪些客户两个月没联系了？', '列出关注重疾险的客户', '有健康告知顾虑的客户有哪些？'],
      ['列出预算敏感的客户', '哪些客户提到孩子保障？', '最近适合跟进保单配置的客户有哪些？'],
      ['列出关注养老规划的客户', '哪些客户还没有明确预算？', '有哪些客户适合本周优先跟进？'],
    ],
  ),
  IndustryAssistantSuggestionGroup(
    key: 'assist',
    title: '客户跟进助手',
    icon: 'edit_note',
    variants: [
      ['给{first}写一段聊保障缺口的微信', '总结{second}上次拜访，并给出这次建议', '明天见{third}，帮我准备会谈简报'],
      ['给{first}写一段解释重疾险必要性的微信', '整理{second}的家庭责任和保障缺口', '见{third}前要确认哪些健康告知问题？'],
      ['给{first}写一段保费压力异议处理话术', '{second}现在情况怎样，下一步怎么跟？', '{third}一直拖延决策怎么推进？'],
    ],
  ),
  _commonHelpSuggestions,
];

const _realEstateSuggestions = [
  IndustryAssistantSuggestionGroup(
    key: 'query',
    title: '查客户数据',
    icon: 'manage_search',
    variants: [
      ['哪些客户两个月没联系了？', '列出预算敏感的客户', '住在海淀区、预算充足的客户有哪些？'],
      ['最近提到学区的客户有哪些？', '列出看房意向强的客户', '预算在500万以内的客户有哪些？'],
      ['哪些客户关注通勤和地铁？', '列出近期沟通过首付压力的客户', '有哪些客户适合本周优先跟进？'],
    ],
  ),
  IndustryAssistantSuggestionGroup(
    key: 'assist',
    title: '客户跟进助手',
    icon: 'edit_note',
    variants: [
      ['给{first}写一段约看房微信', '总结{second}上次拜访，并给出这次建议', '明天见{third}，帮我准备会谈简报'],
      ['给{first}写一段跟进首付顾虑的微信', '整理{second}的预算和区域偏好', '见{third}前要确认哪些问题？'],
      ['给{first}写一段看房后的温和跟进微信', '{second}现在情况怎样，下一步怎么跟？', '{third}犹豫不决时怎么推进？'],
    ],
  ),
  _commonHelpSuggestions,
];

class IndustryOption {
  final String key;
  final String label;
  final String workspaceLabel;
  final IconData icon;
  final String quickTip;
  final String iconKey;
  final List<IndustryAssistantSuggestionGroup> assistantSuggestions;
  final IndustryReminderRules reminderRules;

  const IndustryOption({
    required this.key,
    required this.label,
    required this.workspaceLabel,
    required this.icon,
    required this.quickTip,
    required this.iconKey,
    required this.assistantSuggestions,
    required this.reminderRules,
  });

  static const generic = IndustryOption(
    key: 'generic',
    label: '通用',
    workspaceLabel: '通用顾问',
    icon: Icons.work_outline_rounded,
    iconKey: 'work',
    quickTip: '把每次客户沟通记下来，AI 自动回顾并帮你判断下次跟进时机',
    assistantSuggestions: _genericSuggestions,
    reminderRules: IndustryReminderRules.generic,
  );

  static final List<IndustryOption> fallbackOptions = [
    generic,
    const IndustryOption(
      key: 'insurance',
      label: '保险经纪',
      workspaceLabel: '保险顾问',
      icon: Icons.health_and_safety_outlined,
      iconKey: 'health',
      quickTip: '每次见完客户，打开录音说 60 秒，AI 自动帮你整理要点和下一步建议',
      assistantSuggestions: _insuranceSuggestions,
      reminderRules: IndustryReminderRules.insurance,
    ),
    const IndustryOption(
      key: 'real_estate',
      label: '房产顾问',
      workspaceLabel: '房产顾问',
      icon: Icons.apartment_rounded,
      iconKey: 'apartment',
      quickTip: '记录客户偏好和预算范围，AI 自动整理并提醒匹配的房源方向',
      assistantSuggestions: _realEstateSuggestions,
      reminderRules: IndustryReminderRules.generic,
    ),
  ];

  static List<IndustryOption> options = List.of(fallbackOptions);

  static IconData iconForKey(String iconKey) {
    return switch (iconKey) {
      'apartment' => Icons.apartment_rounded,
      'health' => Icons.health_and_safety_outlined,
      'generic' => Icons.work_outline_rounded,
      'work' => Icons.work_outline_rounded,
      'home' => Icons.home_work_outlined,
      'car' => Icons.directions_car_outlined,
      'school' => Icons.school_outlined,
      _ => Icons.business_center_outlined,
    };
  }

  static IndustryOption fromApi(Map<String, dynamic> json) {
    final key = (json['key'] as String?)?.trim() ?? '';
    final label = (json['label'] as String?)?.trim() ?? key;
    final appDisplay = json['app_display'] is Map<String, dynamic>
        ? json['app_display'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final fallback = fallbackOptions.firstWhere(
      (option) => option.key == key,
      orElse: () => IndustryOption(
        key: key,
        label: label,
        workspaceLabel: label,
        icon: iconForKey((appDisplay['icon_key'] as String?) ?? ''),
        iconKey: (appDisplay['icon_key'] as String?)?.trim() ?? 'business',
        quickTip: '先记录客户沟通，AI 会按$label行业方向整理画像和跟进建议',
        assistantSuggestions: generic.assistantSuggestions,
        reminderRules: IndustryReminderRules.generic,
      ),
    );
    final iconKey = (appDisplay['icon_key'] as String?)?.trim();
    final suggestions =
        (json['assistant_suggestions'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(IndustryAssistantSuggestionGroup.fromJson)
            .where((group) => group.key.isNotEmpty && group.variants.isNotEmpty)
            .toList(growable: false);
    return IndustryOption(
      key: key,
      label: label,
      workspaceLabel:
          (appDisplay['workspace_label'] as String?)?.trim().isNotEmpty == true
          ? (appDisplay['workspace_label'] as String).trim()
          : fallback.workspaceLabel,
      icon: iconForKey(iconKey?.isNotEmpty == true ? iconKey! : fallback.iconKey),
      iconKey: iconKey?.isNotEmpty == true ? iconKey! : fallback.iconKey,
      quickTip: (appDisplay['quick_tip'] as String?)?.trim().isNotEmpty == true
          ? (appDisplay['quick_tip'] as String).trim()
          : fallback.quickTip,
      assistantSuggestions: suggestions.isNotEmpty
          ? suggestions
          : fallback.assistantSuggestions,
      reminderRules: IndustryReminderRules.fromJson(
        json['reminder_rules'] is Map<String, dynamic>
            ? json['reminder_rules'] as Map<String, dynamic>
            : null,
      ),
    );
  }

  static void updateOptions(List<IndustryOption> nextOptions) {
    if (nextOptions.isEmpty) {
      options = List.of(fallbackOptions);
      return;
    }
    final hasGeneric = nextOptions.any((option) => option.key == generic.key);
    options = hasGeneric ? nextOptions : [generic, ...nextOptions];
  }

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
    await refreshAvailableOptions();
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

  static Future<void> refreshAvailableOptions() async {
    if (!AuthSession.isLoggedIn) {
      IndustryOption.updateOptions(IndustryOption.fallbackOptions);
      return;
    }
    final response = await apiService.getIndustries();
    if (!response.success || response.data == null) {
      return;
    }
    IndustryOption.updateOptions(
      response.data!
          .map(IndustryOption.fromApi)
          .where((option) => option.key.isNotEmpty)
          .toList(growable: false),
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
