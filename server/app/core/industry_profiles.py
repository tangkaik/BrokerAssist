"""轻量行业配置，用于让 AI prompt 按用户行业调整语境。"""
from __future__ import annotations

from dataclasses import dataclass


SUPPORTED_INDUSTRIES = {"generic", "insurance", "real_estate"}


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


_PROFILES = {
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
            "客户基本情况：年龄、职业、所在城市等",
            "家庭结构：婚姻、子女、父母、赡养或居住情况",
            "明确表达的保障需求或保险意向",
            "已有保单/保障情况",
            "预算、保费接受度或缴费压力",
            "健康告知相关信息：体检异常、既往症、复查情况等",
            "顾虑点/异议：担心理赔、条款、保费、被推销等",
            "待跟进的具体事项",
            "重要联系方式、常见见面地点和沟通偏好",
        ),
        missing_info=("家庭结构", "预算", "已有保障", "健康告知", "保障优先级"),
        advice_focus="围绕保障缺口、预算、健康告知、已有保单梳理和下一次沟通推进给出建议。",
        forbidden_guidance=(
            "不要输出具体产品名称、保额、保费数字或产品组合方案",
            "不要替客户决定买什么保险",
            "不要把跟进建议写成销售承诺或收益承诺",
        ),
        query_examples=("重疾险", "医疗险", "年金险", "保费敏感", "健康告知", "已有寿险"),
    ),
    "real_estate": IndustryProfile(
        key="real_estate",
        label="房产顾问",
        role_name="房产顾问助手",
        summary_focus=(
            "客户基本情况：家庭成员、职业、所在城市等",
            "购房/租房动机：自住、改善、投资、学区、通勤等",
            "预算范围、首付能力、贷款或付款方式偏好",
            "意向区域、通勤范围、学区/配套偏好",
            "户型、面积、楼层、朝向、新房/二手房等偏好",
            "看房进度、已看房源、满意/不满意原因",
            "决策人和影响决策的家庭成员",
            "顾虑点/异议：价格、税费、贷款、时机、房源真实性等",
            "待跟进的具体事项、常见见面地点和沟通偏好",
        ),
        missing_info=("预算", "意向区域", "户型偏好", "付款能力", "购房动机", "决策人"),
        advice_focus="围绕房源匹配、预算确认、看房安排、决策人沟通和下一步成交推进给出建议。",
        forbidden_guidance=(
            "不要编造不存在的房源、价格、政策或学区承诺",
            "不要承诺房价涨跌或投资收益",
            "不要替客户决定买哪套房",
        ),
        query_examples=("预算充足", "海淀看房", "三居", "学区", "首付", "改善型", "二手房"),
    ),
}


def normalize_industry_key(value: str | None) -> str:
    key = (value or "generic").strip()
    return key if key in SUPPORTED_INDUSTRIES else "generic"


def get_industry_profile(value: str | None) -> IndustryProfile:
    return _PROFILES[normalize_industry_key(value)]
