"""
图片理解服务

统一封装单张图片的视觉理解能力，供：
- AI 助手单轮图片问答
- 记录图片手动识别
共用
"""
from __future__ import annotations

import base64

from app.ai.kimi_client import KimiClient
from app.core.config import settings


def build_image_data_url(content_type: str, raw_bytes: bytes) -> str:
    encoded = base64.b64encode(raw_bytes).decode("utf-8")
    return f"data:{content_type};base64,{encoded}"


async def analyze_image_with_qwen(
    *,
    question: str,
    raw_bytes: bytes,
    content_type: str,
) -> str:
    if not settings.dashscope_api_key:
        raise ValueError("图片问答尚未配置视觉模型密钥")

    data_url = build_image_data_url(content_type, raw_bytes)
    client = KimiClient(
        api_key=settings.dashscope_api_key,
        base_url=settings.dashscope_base_url,
        model=settings.dashscope_vl_model,
    )

    response = await client.chat(
        messages=[
            {
                "role": "system",
                "content": (
                    "你是保险经纪人助手。请基于用户上传的一张图片，"
                    "判断这是什么类型的材料，并提取最关键的信息。"
                    "回答要简洁、结构化、可直接用于客户沟通或内部整理。"
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": question.strip()},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            },
        ]
    )

    answer = response.get("choices", [{}])[0].get("message", {}).get("content", "") or ""
    return answer.strip()
