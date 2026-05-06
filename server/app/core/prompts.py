"""
AI Prompts 管理器

从 prompts.yaml 加载所有 AI 提示词，提供类型安全的访问接口。
"""
from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

from app.core.industry_profiles import get_industry_profile


def _load_prompts() -> dict[str, Any]:
    """从 prompts.yaml 加载原始字典。"""
    path = Path(__file__).parent.parent / "prompts.yaml"
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


@lru_cache()
def get_prompts() -> dict[str, Any]:
    """获取所有 prompts（缓存，只读一次）。"""
    return _load_prompts()


# ---- 客户摘要 ----

def _industry_format_args(industry_key: str | None) -> dict[str, str]:
    profile = get_industry_profile(industry_key)
    return {
        "industry_label": profile.label,
        "industry_role": profile.role_name,
        "summary_focus_text": profile.summary_focus_text,
        "missing_info_text": profile.missing_info_text,
        "advice_focus_text": profile.advice_focus,
        "forbidden_guidance_text": profile.forbidden_guidance_text,
        "query_examples_text": profile.query_examples_text,
    }


def customer_summary(records_text: str, industry_key: str | None = None) -> str:
    """生成客户摘要的 prompt（模板）。"""
    tmpl = get_prompts()["customer_summary"]
    return tmpl.format(records_text=records_text, **_industry_format_args(industry_key))


def customer_summary_system(industry_key: str | None = None) -> str:
    """客户摘要的 system prompt。"""
    return get_prompts()["customer_summary_system"].format(
        **_industry_format_args(industry_key)
    )


# ---- 客户对话 ----

def customer_chat(
    customer_summary_text: str,
    recent_records_text: str,
    question: str,
    industry_key: str | None = None,
) -> str:
    """客户对话的 prompt（模板）。"""
    tmpl = get_prompts()["customer_chat"]
    return tmpl.format(
        customer_summary_text=customer_summary_text,
        recent_records_text=recent_records_text,
        question=question,
        **_industry_format_args(industry_key),
    )


def customer_chat_system(industry_key: str | None = None) -> str:
    """客户对话的 system prompt。"""
    return get_prompts()["customer_chat_system"].format(
        **_industry_format_args(industry_key)
    )


# ---- 拜访建议 ----

def advice(
    customer_summary_text: str,
    recent_records_text: str,
    industry_key: str | None = None,
) -> str:
    """拜访建议的 prompt（模板）。"""
    tmpl = get_prompts()["advice"]
    return tmpl.format(
        customer_summary_text=customer_summary_text,
        recent_records_text=recent_records_text,
        **_industry_format_args(industry_key),
    )


def advice_system(industry_key: str | None = None) -> str:
    """拜访建议的 system prompt。"""
    return get_prompts()["advice_system"].format(
        **_industry_format_args(industry_key)
    )


# ---- 地点分类 ----

def area_classify(target_area: str) -> str:
    """地点目标分类的 prompt（模板）。"""
    tmpl = get_prompts()["area_classify"]
    return tmpl.format(target_area=target_area)


def area_classify_system() -> str:
    """地点分类的 system prompt。"""
    return get_prompts()["area_classify_system"]


# ---- 地点短语提取 ----

def location_extract(source_text: str) -> str:
    """从客户材料中提取地点短语的 prompt（模板）。"""
    tmpl = get_prompts()["location_extract"]
    return tmpl.format(source_text=source_text)


def location_extract_system() -> str:
    """地点提取的 system prompt。"""
    return get_prompts()["location_extract_system"]


# ---- 地点归属判断 ----

def location_classify(phrase_list: str) -> str:
    """地点归属判断的 prompt（模板）。"""
    tmpl = get_prompts()["location_classify"]
    return tmpl.format(phrase_list=phrase_list)


def location_classify_system() -> str:
    """地点归属判断的 system prompt。"""
    return get_prompts()["location_classify_system"]


def customer_query_plan(question: str, industry_key: str | None = None) -> str:
    """客户查询规划 prompt（模板）。"""
    tmpl = get_prompts()["customer_query_plan"]
    return tmpl.format(question=question, **_industry_format_args(industry_key))


def customer_query_plan_system(industry_key: str | None = None) -> str:
    """客户查询规划 system prompt。"""
    return get_prompts()["customer_query_plan_system"].format(
        **_industry_format_args(industry_key)
    )


def assistant_intent_plan(
    question: str,
    conversation_context: str = "无",
    industry_key: str | None = None,
) -> str:
    """AI 助手意图规划 prompt（模板）。"""
    tmpl = get_prompts()["assistant_intent_plan"]
    return tmpl.format(
        question=question,
        conversation_context=conversation_context,
        **_industry_format_args(industry_key),
    )


def assistant_intent_plan_system(industry_key: str | None = None) -> str:
    """AI 助手意图规划 system prompt。"""
    return get_prompts()["assistant_intent_plan_system"].format(
        **_industry_format_args(industry_key)
    )


def app_help_qa(
    question: str,
    conversation_context: str = "无",
    industry_key: str | None = None,
) -> str:
    """产品用法问答 prompt（模板）。"""
    tmpl = get_prompts()["app_help_qa"]
    return tmpl.format(
        question=question,
        conversation_context=conversation_context,
        **_industry_format_args(industry_key),
    )


def app_help_qa_system(industry_key: str | None = None) -> str:
    """产品用法问答 system prompt。"""
    return get_prompts()["app_help_qa_system"].format(
        **_industry_format_args(industry_key)
    )


def business_assist_plan(
    question: str,
    conversation_context: str = "无",
    industry_key: str | None = None,
) -> str:
    """单客户业务助手任务规划 prompt（模板）。"""
    tmpl = get_prompts()["business_assist_plan"]
    return tmpl.format(
        question=question,
        conversation_context=conversation_context,
        **_industry_format_args(industry_key),
    )


def business_assist_plan_system(industry_key: str | None = None) -> str:
    """单客户业务助手任务规划 system prompt。"""
    return get_prompts()["business_assist_plan_system"].format(
        **_industry_format_args(industry_key)
    )


def business_assist(
    question: str,
    customer_context_text: str = "无",
    conversation_context: str = "无",
    task_type: str = "general",
    task_instructions: str = "",
    industry_key: str | None = None,
) -> str:
    """单客户业务辅助 prompt（模板）。"""
    tmpl = get_prompts()["business_assist"]
    return tmpl.format(
        question=question,
        customer_context_text=customer_context_text,
        conversation_context=conversation_context,
        task_type=task_type,
        task_instructions=task_instructions,
        **_industry_format_args(industry_key),
    )


def business_assist_system(industry_key: str | None = None) -> str:
    """通用业务辅助 system prompt。"""
    return get_prompts()["business_assist_system"].format(
        **_industry_format_args(industry_key)
    )


# ---- 图片分析 ----

def image_analysis(
    mode_instructions: str,
) -> str:
    """图片分析的 prompt（模板）。"""
    tmpl = get_prompts()["image_analysis"]
    return tmpl.format(mode_instructions=mode_instructions)


def image_analysis_fallback() -> str:
    """图片分析默认模式指令。"""
    return get_prompts()["image_analysis_fallback"]


def image_analysis_mode_table() -> str:
    return get_prompts()["image_analysis_mode_table"]


def image_analysis_mode_key_points() -> str:
    return get_prompts()["image_analysis_mode_key_points"]


def image_analysis_mode_summary() -> str:
    return get_prompts()["image_analysis_mode_summary"]


def image_analysis_mode_customer_info() -> str:
    return get_prompts()["image_analysis_mode_customer_info"]
