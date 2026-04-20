"""
记录图片本地存储

在不修改数据库结构的前提下，将记录图片保存到本地文件系统，
并用 JSON 文件维护 record_id -> 图片列表 的映射。
"""
from __future__ import annotations

import json
import re
from pathlib import Path
from threading import Lock
from typing import Optional
from uuid import uuid4


_STORE_LOCK = Lock()


class RecordImageStore:
    """本地记录图片存储"""

    def __init__(self, root_dir: Optional[Path] = None, index_path: Optional[Path] = None):
        server_root = Path(__file__).resolve().parents[2]
        self.root_dir = root_dir or server_root / "data" / "record_images"
        self.index_path = index_path or server_root / "data" / "record_images_index.json"

    def _ensure_dirs(self) -> None:
        self.root_dir.mkdir(parents=True, exist_ok=True)
        self.index_path.parent.mkdir(parents=True, exist_ok=True)
        if not self.index_path.exists():
            self.index_path.write_text("{}", encoding="utf-8")

    def _read_index(self) -> dict:
        self._ensure_dirs()
        try:
            content = self.index_path.read_text(encoding="utf-8").strip()
            if not content:
                return {}
            data = json.loads(content)
            return data if isinstance(data, dict) else {}
        except (OSError, json.JSONDecodeError):
            return {}

    def _write_index(self, data: dict) -> None:
        self._ensure_dirs()
        self.index_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _safe_name(self, name: str) -> str:
        cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._")
        return cleaned or "image"

    def save_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        record_id: str,
        files: list[tuple[str, bytes, Optional[str]]],
    ) -> list[dict]:
        if not files:
            return []

        self._ensure_dirs()
        target_dir = self.root_dir / user_id / customer_id / record_id
        target_dir.mkdir(parents=True, exist_ok=True)

        saved_items = []
        for original_name, file_bytes, content_type in files:
            suffix = Path(original_name).suffix.lower() or ".jpg"
            safe_base = self._safe_name(Path(original_name).stem)
            file_name = f"{uuid4().hex[:10]}_{safe_base}{suffix}"
            file_path = target_dir / file_name
            file_path.write_bytes(file_bytes)

            relative_path = file_path.relative_to(self.root_dir.parent).as_posix()
            saved_items.append(
                {
                    "name": original_name,
                    "path": relative_path,
                    "url": f"/media/{relative_path}",
                    "content_type": content_type or "image/jpeg",
                }
            )

        with _STORE_LOCK:
            index = self._read_index()
            index[record_id] = saved_items
            self._write_index(index)

        return saved_items

    def get_record_images(self, record_id: str) -> list[dict]:
        with _STORE_LOCK:
            index = self._read_index()
            items = index.get(record_id, [])
            return items if isinstance(items, list) else []

    def replace_record_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        record_id: str,
        keep_urls: list[str],
        new_files: list[tuple[str, bytes, Optional[str]]],
    ) -> list[dict]:
        with _STORE_LOCK:
            index = self._read_index()
            existing = index.get(record_id, [])
            kept_items = [
                item for item in existing
                if isinstance(item, dict) and item.get("url") in keep_urls
            ]

            for item in existing:
                if not isinstance(item, dict):
                    continue
                if item.get("url") in keep_urls:
                    continue
                file_path = self.root_dir.parent / item.get("path", "")
                if file_path.exists():
                    file_path.unlink()

            if new_files:
                target_dir = self.root_dir / user_id / customer_id / record_id
                target_dir.mkdir(parents=True, exist_ok=True)
                for original_name, file_bytes, content_type in new_files:
                    suffix = Path(original_name).suffix.lower() or ".jpg"
                    safe_base = self._safe_name(Path(original_name).stem)
                    file_name = f"{uuid4().hex[:10]}_{safe_base}{suffix}"
                    file_path = target_dir / file_name
                    file_path.write_bytes(file_bytes)
                    relative_path = file_path.relative_to(self.root_dir.parent).as_posix()
                    kept_items.append(
                        {
                            "name": original_name,
                            "path": relative_path,
                            "url": f"/media/{relative_path}",
                            "content_type": content_type or "image/jpeg",
                        }
                    )

            index[record_id] = kept_items
            self._write_index(index)
            return kept_items

    def delete_record_images(self, record_id: str) -> None:
        with _STORE_LOCK:
            index = self._read_index()
            existing = index.pop(record_id, [])
            for item in existing:
                if not isinstance(item, dict):
                    continue
                file_path = self.root_dir.parent / item.get("path", "")
                if file_path.exists():
                    file_path.unlink()
            self._write_index(index)
