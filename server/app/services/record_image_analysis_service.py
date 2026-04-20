"""
记录图片识别服务

负责：
- 根据分析模式组装提示词
- 读取记录图片文件
- 调用视觉模型进行识别
- 持久化识别结果
"""
from __future__ import annotations

from datetime import datetime, timezone

from app.services.record_image_analysis_store import RecordImageAnalysisStore
from app.services.record_image_store import RecordImageStore
from app.services.vision_service import analyze_image_with_qwen
from app.core.prompts import (
    image_analysis_mode_table,
    image_analysis_mode_key_points,
    image_analysis_mode_summary,
    image_analysis_mode_customer_info,
    image_analysis_fallback,
)


class RecordImageAnalysisService:
    """封装记录图片识别与 OCR 相关逻辑。"""

    def __init__(
        self,
        image_store: RecordImageStore | None = None,
        analysis_store: RecordImageAnalysisStore | None = None,
    ):
        self.image_store = image_store or RecordImageStore()
        self.analysis_store = analysis_store or RecordImageAnalysisStore()

    def get_record_analysis_map(self, record_id: str) -> dict[str, dict]:
        return self.analysis_store.get_record_analysis_map(record_id)

    def delete_record(self, record_id: str) -> None:
        self.analysis_store.delete_record(record_id)

    def _build_analysis_prompt(self, analyze_modes: list[str] | None = None) -> str:
        selected_modes = {
            mode.strip()
            for mode in (analyze_modes or [])
            if mode and mode.strip()
        }
        prompt_parts = [
            "请识别这张记录图片，严格按要求输出。",
            "先判断这是什么类型的材料。",
        ]

        if "output_table" in selected_modes:
            prompt_parts.append(image_analysis_mode_table())
        if "extract_key_points" in selected_modes:
            prompt_parts.append(image_analysis_mode_key_points())
        if "summarize_description" in selected_modes:
            prompt_parts.append(image_analysis_mode_summary())
        if "extract_customer_info" in selected_modes:
            prompt_parts.append(image_analysis_mode_customer_info())

        if not selected_modes:
            prompt_parts.append(image_analysis_fallback())
        else:
            prompt_parts.append("最后补一句可执行建议。")

        return "\n".join(prompt_parts)

    async def analyze_record_image(
        self,
        *,
        record_id: str,
        image_url: str,
        analyze_modes: list[str] | None = None,
    ) -> tuple[dict | None, str | None]:
        images = self.image_store.get_record_images(record_id)
        image_item = next((item for item in images if item.get("url") == image_url), None)
        if not image_item:
            return None, "图片不存在"

        file_path = self.image_store.root_dir.parent / image_item.get("path", "")
        if not file_path.exists():
            return None, "图片文件不存在"

        answer = await analyze_image_with_qwen(
            question=self._build_analysis_prompt(analyze_modes),
            raw_bytes=file_path.read_bytes(),
            content_type=image_item.get("content_type") or "image/jpeg",
        )

        payload = {
            "answer": answer or "暂时未识别出有效内容",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        self.analysis_store.save_image_analysis(record_id, image_url, payload)
        return payload, None
