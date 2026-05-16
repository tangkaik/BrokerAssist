"""
记录图片识别结果存储（已迁移到数据库）

使用 record_image_analyses 表管理分析结果。
"""
from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import select, delete
from app.db.session import async_session_factory
from app.models.record_image_analysis import RecordImageAnalysis


_STORE_LOCK = asyncio.Lock()


class RecordImageAnalysisStore:
    """记录图片分析存储（数据库版）"""

    def __init__(self, store_path: Optional[Path] = None):
        # store_path 保留参数兼容，不再使用
        pass

    async def get_record_analysis_map(self, record_id: str) -> dict[str, dict]:
        async with async_session_factory() as session:
            result = await session.execute(
                select(RecordImageAnalysis).where(
                    RecordImageAnalysis.record_id == record_id
                )
            )
            analyses = result.scalars().all()
            return {
                a.image_url: {
                    "answer": a.answer,
                    "updated_at": a.updated_at.isoformat() if a.updated_at else None,
                }
                for a in analyses
            }

    async def get_image_analysis(self, record_id: str, image_url: str) -> dict | None:
        return (await self.get_record_analysis_map(record_id)).get(image_url)

    async def save_image_analysis(self, record_id: str, image_url: str, payload: dict) -> None:
        async with _STORE_LOCK:
            async with async_session_factory() as session:
                # 查找已有记录
                result = await session.execute(
                    select(RecordImageAnalysis).where(
                        RecordImageAnalysis.record_id == record_id,
                        RecordImageAnalysis.image_url == image_url,
                    )
                )
                existing = result.scalar_one_or_none()

                if existing:
                    existing.answer = payload.get("answer", "")
                    existing.updated_at = datetime.now(timezone.utc)
                else:
                    analysis = RecordImageAnalysis(
                        id=str(uuid.uuid4()),
                        record_id=record_id,
                        image_url=image_url,
                        answer=payload.get("answer", ""),
                    )
                    session.add(analysis)

                await session.commit()

    async def delete_record(self, record_id: str) -> None:
        async with _STORE_LOCK:
            async with async_session_factory() as session:
                await session.execute(
                    delete(RecordImageAnalysis).where(
                        RecordImageAnalysis.record_id == record_id
                    )
                )
                await session.commit()
