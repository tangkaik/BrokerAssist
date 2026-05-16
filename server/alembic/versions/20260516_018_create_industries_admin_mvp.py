"""create industries for admin mvp

Revision ID: 20260516_018
Revises: 20260515_017
Create Date: 2026-05-16 00:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "20260516_018"
down_revision: Union[str, None] = "20260515_017"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _prompt_config(
    summary_focus: list[str],
    missing_info: list[str],
    advice_focus: str,
    forbidden_guidance: list[str],
    query_examples: list[str],
) -> dict[str, list[str] | str]:
    return {
        "summary_focus": summary_focus,
        "missing_info": missing_info,
        "advice_focus": advice_focus,
        "forbidden_guidance": forbidden_guidance,
        "query_examples": query_examples,
    }


def upgrade() -> None:
    op.create_table(
        "industries",
        sa.Column("key", sa.String(40), primary_key=True, comment="行业标识"),
        sa.Column("label", sa.String(100), nullable=False, comment="行业名称"),
        sa.Column("role_name", sa.String(100), nullable=False, comment="AI 角色名"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default="true", comment="是否启用"),
        sa.Column(
            "prompt_config",
            postgresql.JSONB(astext_type=sa.Text()),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
            comment="行业提示词配置",
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    industries = sa.table(
        "industries",
        sa.column("key", sa.String),
        sa.column("label", sa.String),
        sa.column("role_name", sa.String),
        sa.column("enabled", sa.Boolean),
        sa.column("prompt_config", postgresql.JSONB),
    )
    op.bulk_insert(
        industries,
        [
            {
                "key": "generic",
                "label": "通用",
                "role_name": "客户关系管理助手",
                "enabled": True,
                "prompt_config": _prompt_config(
                    [
                        "客户基本情况：年龄、职业、所在城市等",
                        "明确表达的需求、意向或目标",
                        "顾虑点/异议：担忧、犹豫、明确拒绝的点",
                        "待跟进的具体事项",
                        "重要联系方式：微信名称、QQ号、电话等",
                        "常见见面地点：便于后续约见参考",
                        "沟通偏好：面谈/电话/微信、方便联系时间",
                    ],
                    ["客户基本情况", "核心需求", "预算或可接受范围", "决策人", "下一步动作"],
                    "围绕下一步沟通、信息补充、关系推进和明确客户决策条件给出建议。",
                    ["不要编造客户没有表达过的需求或预算", "不要替客户做最终决定"],
                    ["高意向", "预算充足", "企业主", "待跟进", "两个月未联系"],
                ),
            },
            {
                "key": "insurance",
                "label": "保险经纪",
                "role_name": "保险经纪人助手",
                "enabled": True,
                "prompt_config": _prompt_config(
                    [
                        "客户基本情况：年龄、职业、家庭结构、所在城市",
                        "已购保单情况：险种、保额、保费、保险公司",
                        "保障缺口分析：现有保障和客户需求之间的差距",
                        "明确的保险需求：寿险、健康险、意外险、年金等",
                        "预算范围和对保费的接受度",
                        "顾虑点/异议：对保险的担忧、犹豫、拒绝理由",
                        "待跟进的具体事项：方案设计、产品对比、体检安排等",
                    ],
                    ["客户基本情况", "已购保单", "保障需求", "预算范围", "决策人", "下一步动作"],
                    "围绕保障需求分析、产品匹配、方案设计和异议处理给出建议。",
                    [
                        "不要编造客户没有的健康状况",
                        "不要承诺具体理赔结果",
                        "不要推荐不在合规范围内的产品",
                        "不要替客户做投保决定",
                    ],
                    ["高意向", "健康险需求", "有孩子", "企业主", "待跟进", "两个月未联系"],
                ),
            },
            {
                "key": "real_estate",
                "label": "房产顾问",
                "role_name": "房产顾问助手",
                "enabled": True,
                "prompt_config": _prompt_config(
                    [
                        "客户基本情况：年龄、职业、家庭结构、所在城市",
                        "购房需求：刚需/改善/投资、户型偏好、面积需求",
                        "预算范围：首付能力、月供承受力",
                        "区域偏好：意向区域、对交通/学区/配套的要求",
                        "看房进度：已看房源、意向程度",
                        "顾虑点/异议：对市场、价格、区域的担忧",
                        "待跟进事项：带看安排、贷款咨询、政策了解等",
                    ],
                    ["客户基本情况", "购房需求", "预算范围", "区域偏好", "决策人", "下一步动作"],
                    "围绕房源匹配、市场分析、带看安排和谈判策略给出建议。",
                    [
                        "不要编造房源信息",
                        "不要承诺房价涨跌",
                        "不要替客户做购房决定",
                        "不要提供超出经纪人范围的法律/税务建议",
                    ],
                    ["高意向", "改善型", "学区房", "首次置业", "待跟进", "两个月未联系"],
                ),
            },
        ],
    )


def downgrade() -> None:
    op.drop_table("industries")
