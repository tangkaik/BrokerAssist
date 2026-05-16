"""
记录媒体服务

负责：
- 记录图片的增删改查
- 读取图片分析结果
- 组装带图片信息的 RecordItem 响应
"""
from __future__ import annotations

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.record import Record
from app.schemas.record import RecordImageItem, RecordItem
from app.services.record_image_analysis_service import RecordImageAnalysisService
from app.services.record_image_store import RecordImageStore


class RecordMediaService:
    """封装记录图片与图片识别结果相关操作。"""

    def __init__(
        self,
        image_store: RecordImageStore | None = None,
        image_analysis_service: RecordImageAnalysisService | None = None,
    ):
        self.image_store = image_store or RecordImageStore()
        self.image_analysis_service = image_analysis_service or RecordImageAnalysisService(
            image_store=self.image_store,
        )

    async def save_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        record_id: str,
        files: list[tuple[str, bytes, str | None]],
        session: AsyncSession | None = None,
    ) -> list[dict]:
        return await self.image_store.save_images(
            user_id=user_id,
            customer_id=customer_id,
            record_id=record_id,
            files=files,
            session=session,
        )

    async def replace_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        record_id: str,
        keep_urls: list[str],
        new_files: list[tuple[str, bytes, str | None]],
        session: AsyncSession | None = None,
    ) -> list[dict]:
        return await self.image_store.replace_record_images(
            user_id=user_id,
            customer_id=customer_id,
            record_id=record_id,
            keep_urls=keep_urls,
            new_files=new_files,
            session=session,
        )

    async def delete_record_assets(self, record_id: str) -> None:
        await self.image_store.delete_record_images(record_id)
        await self.image_analysis_service.delete_record(record_id)

    async def analyze_record_image(
        self,
        *,
        record_id: str,
        image_url: str,
        analyze_modes: list[str] | None = None,
    ) -> tuple[dict | None, str | None]:
        return await self.image_analysis_service.analyze_record_image(
            record_id=record_id,
            image_url=image_url,
            analyze_modes=analyze_modes,
        )

    async def build_record_item(self, record: Record, images: list[dict] | None = None) -> RecordItem:
        image_items = images if images is not None else await self.image_store.get_record_images(record.id)
        image_analysis_map = await self.image_analysis_service.get_record_analysis_map(record.id)
        return RecordItem(
            id=record.id,
            customer_id=record.customer_id,
            content=record.content,
            type=record.type,
            created_at=record.created_at,
            location_raw=record.location_raw,
            location_city=record.location_city,
            location_district=record.location_district,
            location_subarea=record.location_subarea,
            images=[
                RecordImageItem(
                    name=image["name"],
                    url=image["url"],
                    content_type=image.get("content_type"),
                    vision=(
                        RecordImageItem.VisionResult(
                            answer=image_analysis_map[image["url"]]["answer"],
                            updated_at=image_analysis_map[image["url"]]["updated_at"],
                        )
                        if image.get("url") in image_analysis_map
                        else None
                    ),
                )
                for image in image_items
            ],
        )
