"""行业配置。"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class AssistantSuggestionGroup:
    key: str
    title: str
    icon: str
    variants: tuple[tuple[str, ...], ...]


@dataclass(frozen=True)
class AppDisplayConfig:
    workspace_label: str
    icon_key: str
    quick_tip: str


@dataclass(frozen=True)
class ReminderRuleConfig:
    birthday_enabled: bool = True
    festival_enabled: bool = True
    festival_group_title: str = "节日关怀"
    festival_body_template: str = "{festival}还有 {days} 天，建议提前准备客户关怀。"
    key_date_enabled: bool = False
    key_date_keywords: tuple[str, ...] = ()
    key_date_title_template: str = "{customer}关键日期提醒"
    key_date_body_template: str = "{customer} 的关键日期还有 {days} 天，请及时跟进。"
    key_date_group_title: str = "关键日期"
    key_date_source_key: str = "key_date_detected"


@dataclass(frozen=True)
class IndustryProfile:
    key: str
    label: str
    role_name: str
    summary_focus: tuple[str, ...]
    missing_info: tuple[str, ...]
    advice_focus: str
    forbidden_guidance: tuple[str, ...]
    query_examples: tuple[str, ...]
    assistant_suggestions: tuple[AssistantSuggestionGroup, ...]
    app_display: AppDisplayConfig
    reminder_rules: ReminderRuleConfig

    @property
    def summary_focus_text(self) -> str:
        return "\n".join(f"     - {item}" for item in self.summary_focus)

    @property
    def missing_info_text(self) -> str:
        return "、".join(self.missing_info)

    @property
    def forbidden_guidance_text(self) -> str:
        return "\n".join(f"  - {item}" for item in self.forbidden_guidance)

    @property
    def query_examples_text(self) -> str:
        return "、".join(self.query_examples)


def _suggestion_group(
    key: str,
    title: str,
    icon: str,
    variants: tuple[tuple[str, ...], ...],
) -> AssistantSuggestionGroup:
    return AssistantSuggestionGroup(key=key, title=title, icon=icon, variants=variants)


_COMMON_HELP_SUGGESTIONS = _suggestion_group(
    key="help",
    title="问产品用法",
    icon="help",
    variants=(
        ("客户画像怎么生成？", "下一步建议在哪里看？", "怎样添加一次客户沟通记录？"),
        ("怎么给客户添加标签？", "语音记录怎么确认到客户？", "AI助手能查哪些客户条件？"),
        ("行业选择后还能修改吗？", "客户列表怎么搜索拼音？", "图片记录可以识别什么？"),
    ),
)


_HARDCODED_PROFILES = {
    "generic": IndustryProfile(
        key="generic",
        label="通用",
        role_name="客户关系管理助手",
        summary_focus=(
            "客户基本情况：年龄、职业、所在城市等",
            "明确表达的需求、意向或目标",
            "顾虑点/异议：担忧、犹豫、明确拒绝的点",
            "待跟进的具体事项",
            "重要联系方式：微信名称、QQ号、电话等",
            "常见见面地点：便于后续约见参考",
            "沟通偏好：面谈/电话/微信、方便联系时间",
        ),
        missing_info=("客户基本情况", "核心需求", "预算或可接受范围", "决策人", "下一步动作"),
        advice_focus="围绕下一步沟通、信息补充、关系推进和明确客户决策条件给出建议。",
        forbidden_guidance=("不要编造客户没有表达过的需求或预算", "不要替客户做最终决定"),
        query_examples=("高意向", "预算充足", "企业主", "待跟进", "两个月未联系"),
        assistant_suggestions=(
            _suggestion_group(
                key="query",
                title="查客户数据",
                icon="manage_search",
                variants=(
                    ("哪些客户两个月没联系了？", "列出预算敏感的客户", "有哪些客户适合本周优先跟进？"),
                    ("列出最近沟通频繁的客户", "哪些客户还没有明确需求？", "住在海淀区的客户有哪些？"),
                    ("列出女性客户", "哪些客户提到价格顾虑？", "有多少客户超过两个月没联系？"),
                ),
            ),
            _suggestion_group(
                key="assist",
                title="客户跟进助手",
                icon="edit_note",
                variants=(
                    ("给{first}写一段跟进微信", "总结{second}上次沟通，并给出这次建议", "明天见{third}，帮我准备会谈简报"),
                    ("给{first}写一段久未回复后的跟进微信", "整理{second}的需求和顾虑", "见{third}前要确认哪些问题？"),
                    ("给{first}写一段温和确认时间的微信", "{second}现在情况怎样，下一步怎么跟？", "{third}犹豫时怎么推进？"),
                ),
            ),
            _COMMON_HELP_SUGGESTIONS,
        ),
        app_display=AppDisplayConfig(
            workspace_label="通用顾问",
            icon_key="work",
            quick_tip="把每次客户沟通记下来，AI 自动回顾并帮你判断下次跟进时机",
        ),
        reminder_rules=ReminderRuleConfig(),
    ),
    "insurance": IndustryProfile(
        key="insurance",
        label="保险经纪",
        role_name="保险经纪人助手",
        summary_focus=(
            "客户基本情况：年龄、职业、家庭结构、所在城市",
            "已购保单情况：险种、保额、保费、保险公司",
            "保障缺口分析：现有保障和客户需求之间的差距",
            "明确的保险需求：寿险、健康险、意外险、年金等",
            "预算范围和对保费的接受度",
            "顾虑点/异议：对保险的担忧、犹豫、拒绝理由",
            "待跟进的具体事项：方案设计、产品对比、体检安排等",
        ),
        missing_info=("客户基本情况", "已购保单", "保障需求", "预算范围", "决策人", "下一步动作"),
        advice_focus="围绕保障需求分析、产品匹配、方案设计和异议处理给出建议。",
        forbidden_guidance=(
            "不要编造客户没有的健康状况",
            "不要承诺具体理赔结果",
            "不要推荐不在合规范围内的产品",
            "不要替客户做投保决定",
        ),
        query_examples=("高意向", "健康险需求", "有孩子", "企业主", "待跟进", "两个月未联系"),
        assistant_suggestions=(
            _suggestion_group(
                key="query",
                title="查客户数据",
                icon="manage_search",
                variants=(
                    ("哪些客户两个月没联系了？", "列出关注重疾险的客户", "有健康告知顾虑的客户有哪些？"),
                    ("列出预算敏感的客户", "哪些客户提到孩子保障？", "最近适合跟进保单配置的客户有哪些？"),
                    ("列出关注养老规划的客户", "哪些客户还没有明确预算？", "有哪些客户适合本周优先跟进？"),
                ),
            ),
            _suggestion_group(
                key="assist",
                title="客户跟进助手",
                icon="edit_note",
                variants=(
                    ("给{first}写一段聊保障缺口的微信", "总结{second}上次拜访，并给出这次建议", "明天见{third}，帮我准备会谈简报"),
                    ("给{first}写一段解释重疾险必要性的微信", "整理{second}的家庭责任和保障缺口", "见{third}前要确认哪些健康告知问题？"),
                    ("给{first}写一段保费压力异议处理话术", "{second}现在情况怎样，下一步怎么跟？", "{third}一直拖延决策怎么推进？"),
                ),
            ),
            _COMMON_HELP_SUGGESTIONS,
        ),
        app_display=AppDisplayConfig(
            workspace_label="保险顾问",
            icon_key="health",
            quick_tip="每次见完客户，打开录音说 60 秒，AI 自动帮你整理要点和下一步建议",
        ),
        reminder_rules=ReminderRuleConfig(
            festival_group_title="节日礼品",
            key_date_enabled=True,
            key_date_keywords=("保单", "保费", "缴费", "续费", "到期", "扣款"),
            key_date_title_template="{customer}保单缴费提醒",
            key_date_body_template="{customer} 的保单缴费日还有 {days} 天，请及时跟进。",
            key_date_group_title="保单缴费",
            key_date_source_key="payment_date_detected",
        ),
    ),
    "real_estate": IndustryProfile(
        key="real_estate",
        label="房产顾问",
        role_name="房产顾问助手",
        summary_focus=(
            "客户基本情况：年龄、职业、家庭结构、所在城市",
            "购房需求：刚需/改善/投资、户型偏好、面积需求",
            "预算范围：首付能力、月供承受力",
            "区域偏好：意向区域、对交通/学区/配套的要求",
            "看房进度：已看房源、意向程度",
            "顾虑点/异议：对市场、价格、区域的担忧",
            "待跟进事项：带看安排、贷款咨询、政策了解等",
        ),
        missing_info=("客户基本情况", "购房需求", "预算范围", "区域偏好", "决策人", "下一步动作"),
        advice_focus="围绕房源匹配、市场分析、带看安排和谈判策略给出建议。",
        forbidden_guidance=(
            "不要编造房源信息",
            "不要承诺房价涨跌",
            "不要替客户做购房决定",
            "不要提供超出经纪人范围的法律/税务建议",
        ),
        query_examples=("高意向", "改善型", "学区房", "首次置业", "待跟进", "两个月未联系"),
        assistant_suggestions=(
            _suggestion_group(
                key="query",
                title="查客户数据",
                icon="manage_search",
                variants=(
                    ("哪些客户两个月没联系了？", "列出预算敏感的客户", "住在海淀区、预算充足的客户有哪些？"),
                    ("最近提到学区的客户有哪些？", "列出看房意向强的客户", "预算在500万以内的客户有哪些？"),
                    ("哪些客户关注通勤和地铁？", "列出近期沟通过首付压力的客户", "有哪些客户适合本周优先跟进？"),
                ),
            ),
            _suggestion_group(
                key="assist",
                title="客户跟进助手",
                icon="edit_note",
                variants=(
                    ("给{first}写一段约看房微信", "总结{second}上次拜访，并给出这次建议", "明天见{third}，帮我准备会谈简报"),
                    ("给{first}写一段跟进首付顾虑的微信", "整理{second}的预算和区域偏好", "见{third}前要确认哪些问题？"),
                    ("给{first}写一段看房后的温和跟进微信", "{second}现在情况怎样，下一步怎么跟？", "{third}犹豫不决时怎么推进？"),
                ),
            ),
            _COMMON_HELP_SUGGESTIONS,
        ),
        app_display=AppDisplayConfig(
            workspace_label="房产顾问",
            icon_key="apartment",
            quick_tip="记录客户偏好和预算范围，AI 自动整理并提醒匹配的房源方向",
        ),
        reminder_rules=ReminderRuleConfig(),
    ),
}


def _parse_summary_focus(value: str) -> tuple[str, ...]:
    lines = [line.strip(" -1234567890.") for line in value.strip().splitlines()]
    return tuple(line for line in lines if line)


def _parse_tuple_field(value: str) -> tuple[str, ...]:
    items = [item.strip() for item in value.replace("\n", "、").split("、")]
    return tuple(item for item in items if item)


PROMPT_CONFIG_DEFAULTS = {
    "summary_focus": [],
    "missing_info": [],
    "advice_focus": "",
    "forbidden_guidance": [],
    "query_examples": [],
    "assistant_suggestions": [],
    "app_display": {},
    "reminder_rules": {},
}


def profile_to_prompt_config(profile: IndustryProfile) -> dict[str, list[str] | str]:
    return {
        "summary_focus": list(profile.summary_focus),
        "missing_info": list(profile.missing_info),
        "advice_focus": profile.advice_focus,
        "forbidden_guidance": list(profile.forbidden_guidance),
        "query_examples": list(profile.query_examples),
        "assistant_suggestions": [
            {
                "key": group.key,
                "title": group.title,
                "icon": group.icon,
                "variants": [list(row) for row in group.variants],
            }
            for group in profile.assistant_suggestions
        ],
        "app_display": {
            "workspace_label": profile.app_display.workspace_label,
            "icon_key": profile.app_display.icon_key,
            "quick_tip": profile.app_display.quick_tip,
        },
        "reminder_rules": {
            "birthday_enabled": profile.reminder_rules.birthday_enabled,
            "festival_enabled": profile.reminder_rules.festival_enabled,
            "festival_group_title": profile.reminder_rules.festival_group_title,
            "festival_body_template": profile.reminder_rules.festival_body_template,
            "key_date_enabled": profile.reminder_rules.key_date_enabled,
            "key_date_keywords": list(profile.reminder_rules.key_date_keywords),
            "key_date_title_template": profile.reminder_rules.key_date_title_template,
            "key_date_body_template": profile.reminder_rules.key_date_body_template,
            "key_date_group_title": profile.reminder_rules.key_date_group_title,
            "key_date_source_key": profile.reminder_rules.key_date_source_key,
        },
    }


def _suggestion_groups_from_config(value: object) -> tuple[AssistantSuggestionGroup, ...]:
    groups = []
    if not isinstance(value, list):
        return ()
    for item in value:
        if not isinstance(item, dict):
            continue
        variants = []
        for row in item.get("variants") or []:
            if not isinstance(row, list):
                continue
            cleaned = tuple(str(text).strip() for text in row if str(text).strip())
            if cleaned:
                variants.append(cleaned)
        if not variants:
            continue
        key = str(item.get("key") or "").strip()
        title = str(item.get("title") or "").strip()
        if not key or not title:
            continue
        groups.append(
            AssistantSuggestionGroup(
                key=key,
                title=title,
                icon=str(item.get("icon") or "help").strip(),
                variants=tuple(variants),
            )
        )
    return tuple(groups)


def _app_display_from_config(value: object) -> AppDisplayConfig:
    if not isinstance(value, dict):
        value = {}
    return AppDisplayConfig(
        workspace_label=str(value.get("workspace_label") or "").strip(),
        icon_key=str(value.get("icon_key") or "work").strip(),
        quick_tip=str(value.get("quick_tip") or "").strip(),
    )


def _reminder_rules_from_config(value: object) -> ReminderRuleConfig:
    if not isinstance(value, dict):
        value = {}
    keywords = value.get("key_date_keywords") or []
    return ReminderRuleConfig(
        birthday_enabled=bool(value.get("birthday_enabled", True)),
        festival_enabled=bool(value.get("festival_enabled", True)),
        festival_group_title=str(value.get("festival_group_title") or "节日关怀").strip(),
        festival_body_template=str(
            value.get("festival_body_template")
            or "{festival}还有 {days} 天，建议提前准备客户关怀。"
        ).strip(),
        key_date_enabled=bool(value.get("key_date_enabled", False)),
        key_date_keywords=tuple(str(item).strip() for item in keywords if str(item).strip()),
        key_date_title_template=str(
            value.get("key_date_title_template") or "{customer}关键日期提醒"
        ).strip(),
        key_date_body_template=str(
            value.get("key_date_body_template")
            or "{customer} 的关键日期还有 {days} 天，请及时跟进。"
        ).strip(),
        key_date_group_title=str(value.get("key_date_group_title") or "关键日期").strip(),
        key_date_source_key=str(value.get("key_date_source_key") or "key_date_detected").strip(),
    )


def profile_from_mapping(industry: object) -> IndustryProfile:
    prompt_config = getattr(industry, "prompt_config", None)
    if prompt_config is None and isinstance(industry, dict):
        prompt_config = industry.get("prompt_config")
    get_value = industry.get if isinstance(industry, dict) else lambda key: getattr(industry, key)
    key = get_value("key")
    default_profile = _HARDCODED_PROFILES.get(key, _HARDCODED_PROFILES["generic"])
    default_config = profile_to_prompt_config(default_profile)
    config = {**PROMPT_CONFIG_DEFAULTS, **default_config, **(prompt_config or {})}
    return IndustryProfile(
        key=key,
        label=get_value("label"),
        role_name=get_value("role_name"),
        summary_focus=tuple(config.get("summary_focus") or ()),
        missing_info=tuple(config.get("missing_info") or ()),
        advice_focus=str(config.get("advice_focus") or ""),
        forbidden_guidance=tuple(config.get("forbidden_guidance") or ()),
        query_examples=tuple(config.get("query_examples") or ()),
        assistant_suggestions=_suggestion_groups_from_config(config.get("assistant_suggestions")),
        app_display=_app_display_from_config(config.get("app_display")),
        reminder_rules=_reminder_rules_from_config(config.get("reminder_rules")),
    )


def default_industry_profiles() -> list[IndustryProfile]:
    return list(_HARDCODED_PROFILES.values())


def normalize_industry_key(value: str) -> str:
    """Normalize an industry key, defaulting to 'generic'."""
    key = (value or "").strip().lower()
    return key or "generic"


def get_industry_profile_sync(industry_key: str) -> IndustryProfile:
    """同步获取单个行业配置（兼容旧代码）。"""
    default = _HARDCODED_PROFILES.get("generic")
    return _HARDCODED_PROFILES.get(industry_key, default) or default
