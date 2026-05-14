"""行业配置 — 优先从数据库加载，数据库无数据时回退到硬编码默认值。"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)


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
    ),
}


def _parse_summary_focus(value: str) -> tuple[str, ...]:
    lines = [line.strip(" -1234567890.") for line in value.strip().splitlines()]
    return tuple(line for line in lines if line)


def _parse_tuple_field(value: str) -> tuple[str, ...]:
    items = [item.strip() for item in value.replace("\n", "、").split("、")]
    return tuple(item for item in items if item)


def normalize_industry_key(value: str) -> str:
    """Normalize an industry key to a known value, defaulting to 'generic'."""
    key = (value or "").strip().lower()
    known = set(_HARDCODED_PROFILES.keys())
    return key if key in known else "generic"


async def get_industry_profiles() -> dict[str, IndustryProfile]:
    """返回按 key 索引的行业配置。先尝试数据库，失败则回退到硬编码。"""
    try:
        from app.db.session import async_session_factory
        from sqlalchemy import select
        from app.models.industry import Industry, IndustryPrompt

        async with async_session_factory() as session:
            result = await session.execute(select(Industry).where(Industry.enabled == True))
            industries = result.scalars().all()

            if not industries:
                logger.info("No industries in DB, using hardcoded defaults")
                return dict(_HARDCODED_PROFILES)

            profiles: dict[str, IndustryProfile] = {}
            for ind in industries:
                prompts_result = await session.execute(
                    select(IndustryPrompt).where(IndustryPrompt.industry_key == ind.key)
                )
                prompts = {p.prompt_field: p.value for p in prompts_result.scalars().all()}

                hardcoded = _HARDCODED_PROFILES.get(ind.key)
                profiles[ind.key] = IndustryProfile(
                    key=ind.key,
                    label=ind.label,
                    role_name=ind.role_name,
                    summary_focus=_parse_summary_focus(
                        prompts.get("summary_focus", "\n".join(hardcoded.summary_focus) if hardcoded else "")
                    ),
                    missing_info=_parse_tuple_field(
                        prompts.get("missing_info", "、".join(hardcoded.missing_info) if hardcoded else "")
                    ),
                    advice_focus=prompts.get("advice_focus", hardcoded.advice_focus if hardcoded else ""),
                    forbidden_guidance=_parse_tuple_field(
                        prompts.get("forbidden_guidance", "\n".join(hardcoded.forbidden_guidance) if hardcoded else "")
                    ),
                    query_examples=_parse_tuple_field(
                        prompts.get("query_examples", "、".join(hardcoded.query_examples) if hardcoded else "")
                    ),
                )
            return profiles
    except Exception:
        logger.exception("Failed to load industry profiles from DB, using hardcoded defaults")
        return dict(_HARDCODED_PROFILES)


def get_industry_profile_sync(industry_key: str) -> IndustryProfile:
    """同步获取单个行业配置（兼容旧代码）。"""
    default = _HARDCODED_PROFILES.get("generic")
    return _HARDCODED_PROFILES.get(industry_key, default) or default
