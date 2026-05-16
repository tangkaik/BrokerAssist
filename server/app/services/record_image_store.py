"""
记录图片存储（已迁移到数据库）

图片文件仍保存在磁盘，但元数据改为 record_images 表管理。
"""
from __future__ import annotations

import asyncio
import re
import uuid
from pathlib import Path
from typing import Optional

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import async_session_factory
from app.models.record_image import RecordImage


_STORE_LOCK = asyncio.Lock()


class RecordImageStore:
    """记录图片存储（数据库版）"""

    def __init__(self, root_dir: Optional[Path] = None, index_path: Optional[Path] = None):
        server_root = Path(__file__).resolve().parents[2]
        self.root_dir = root_dir or server_root / "data" / "record_images"
        # index_path 保留参数兼容，不再使用

    def _ensure_dirs(self) -> None:
        self.root_dir.mkdir(parents=True, exist_ok=True)

    def _safe_name(self, name: str) -> str:
        cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._")
        return cleaned or "image"

    def _add_image_rows(self, session: AsyncSession, record_id: str, items: list[dict]) -> None:
        for item in items:
            img = RecordImage(
                id=str(uuid.uuid4()),
                record_id=record_id,
                image_name=item["name"],
                image_path=item["path"],
                url=item["url"],
                content_type=item["content_type"],
            )
            session.add(img)

    async def save_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        record_id: str,
        files: list[tuple[str, bytes, Optional[str]]],
        session: AsyncSession | None = None,
    ) -> list[dict]:
        if not files:
            return []

        self._ensure_dirs()
        target_dir = self.root_dir / user_id / customer_id / record_id
        target_dir.mkdir(parents=True, exist_ok=True)

        def _save() -> list[dict]:
            saved_items = []
            for original_name, file_bytes, content_type in files:
                suffix = Path(original_name).suffix.lower() or ".jpg"
                safe_base = self._safe_name(Path(original_name).stem)
                file_name = f"{uuid.uuid4().hex[:10]}_{safe_base}{suffix}"
                file_path = target_dir / file_name
                file_path.write_bytes(file_bytes)

                relative_path = file_path.relative_to(self.root_dir.parent).as_posix()
                saved_items.append({
                    "name": original_name,
                    "path": relative_path,
                    "url": f"/media/{relative_path}",
                    "content_type": content_type or "image/jpeg",
                })
            return saved_items

        saved_items = await asyncio.to_thread(_save)

        async with _STORE_LOCK:
            if session is not None:
                self._add_image_rows(session, record_id, saved_items)
                await session.flush()
            else:
                async with async_session_factory() as owned_session:
                    self._add_image_rows(owned_session, record_id, saved_items)
                    await owned_session.commit()

        return saved_items

    async def get_record_images(self, record_id: str) -> list[dict]:
        async with async_session_factory() as session:
            result = await session.execute(
                select(RecordImage).where(RecordImage.record_id == record_id)
            )
            images = result.scalars().all()
            return [
                {
                    "name": img.image_name,
                    "path": img.image_path,
                    "url": img.url,
                    "content_type": img.content_type,
                }
                for img in images
            ]

    async def replace_record_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        record_id: str,
        keep_urls: list[str],
        new_files: list[tuple[str, bytes, Optional[str]]],
        session: AsyncSession | None = None,
    ) -> list[dict]:
        async def _replace(active_session: AsyncSession) -> list[dict]:
            # 获取现有图片
            result = await active_session.execute(
                select(RecordImage).where(RecordImage.record_id == record_id)
            )
            existing = result.scalars().all()

            kept_items = []
            for img in existing:
                if img.url in keep_urls:
                    kept_items.append({
                        "name": img.image_name,
                        "path": img.image_path,
                        "url": img.url,
                        "content_type": img.content_type,
                    })
                else:
                    # 删除磁盘文件
                    file_path = self.root_dir.parent / img.image_path
                    if file_path.exists():
                        file_path.unlink()
                    await active_session.delete(img)

            # 保存新文件
            if new_files:
                target_dir = self.root_dir / user_id / customer_id / record_id
                target_dir.mkdir(parents=True, exist_ok=True)

                def _save_new() -> list[dict]:
                    new_items = []
                    for original_name, file_bytes, content_type in new_files:
                        suffix = Path(original_name).suffix.lower() or ".jpg"
                        safe_base = self._safe_name(Path(original_name).stem)
                        file_name = f"{uuid.uuid4().hex[:10]}_{safe_base}{suffix}"
                        file_path = target_dir / file_name
                        file_path.write_bytes(file_bytes)
                        relative_path = file_path.relative_to(self.root_dir.parent).as_posix()
                        new_items.append({
                            "name": original_name,
                            "path": relative_path,
                            "url": f"/media/{relative_path}",
                            "content_type": content_type or "image/jpeg",
                        })
                    return new_items

                new_items = await asyncio.to_thread(_save_new)
                self._add_image_rows(active_session, record_id, new_items)
                kept_items.extend(new_items)

            await active_session.flush()
            return kept_items

        async with _STORE_LOCK:
            if session is not None:
                return await _replace(session)

            async with async_session_factory() as owned_session:
                kept_items = await _replace(owned_session)
                await owned_session.commit()
                return kept_items

    async def delete_record_images(self, record_id: str) -> None:
        async with _STORE_LOCK:
            async with async_session_factory() as session:
                result = await session.execute(
                    select(RecordImage).where(RecordImage.record_id == record_id)
                )
                images = result.scalars().all()

                def _delete_files():
                    for img in images:
                        file_path = self.root_dir.parent / img.image_path
                        if file_path.exists():
                            file_path.unlink()

                await asyncio.to_thread(_delete_files)

                await session.execute(
                    delete(RecordImage).where(RecordImage.record_id == record_id)
                )
                await session.commit()
