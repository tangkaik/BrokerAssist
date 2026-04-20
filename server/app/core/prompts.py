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

def customer_summary(records_text: str) -> str:
    """生成客户摘要的 prompt（模板）。"""
    tmpl = get_prompts()["customer_summary"]
    return tmpl.format(records_text=records_text)


def customer_summary_system() -> str:
    """客户摘要的 system prompt。"""
    return get_prompts()["customer_summary_system"]


# ---- 客户对话 ----

def customer_chat(
    customer_summary_text: str,
    recent_records_text: str,
    question: str,
) -> str:
    """客户对话的 prompt（模板）。"""
    tmpl = get_prompts()["customer_chat"]
    return tmpl.format(
        customer_summary_text=customer_summary_text,
        recent_records_text=recent_records_text,
        question=question,
    )


def customer_chat_system() -> str:
    """客户对话的 system prompt。"""
    return get_prompts()["customer_chat_system"]


# ---- 拜访建议 ----

def advice(
    customer_summary_text: str,
    recent_records_text: str,
) -> str:
    """拜访建议的 prompt（模板）。"""
    tmpl = get_prompts()["advice"]
    return tmpl.format(
        customer_summary_text=customer_summary_text,
        recent_records_text=recent_records_text,
    )


def advice_system() -> str:
    """拜访建议的 system prompt。"""
    return get_prompts()["advice_system"]


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


# ---- 全局 AI 问答 ----

def global_qa(
    customer_context_text: str,
    question: str,
    today_date: str,
    stale_date: str,
    customer_count: int,
) -> str:
    """全局 AI 问答的 prompt（模板）。"""
    tmpl = get_prompts()["global_qa"]
    return tmpl.format(
        customer_context_text=customer_context_text,
        question=question,
        today_date=today_date,
        stale_date=stale_date,
        _customer_count=customer_count,
    )


def global_qa_system() -> str:
    """全局 AI 问答的 system prompt。"""
    return get_prompts()["global_qa_system"]


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
