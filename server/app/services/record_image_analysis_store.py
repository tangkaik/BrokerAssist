"""
记录图片识别结果存储

使用 JSON 文件维护 record_id + image_url -> 分析结果 的映射。
"""
from __future__ import annotations

import json
from pathlib import Path
from threading import Lock
from typing import Optional


_STORE_LOCK = Lock()


class RecordImageAnalysisStore:
    def __init__(self, store_path: Optional[Path] = None):
        server_root = Path(__file__).resolve().parents[2]
        self.store_path = store_path or server_root / "data" / "record_image_analysis.json"

    def _ensure_file(self) -> None:
        self.store_path.parent.mkdir(parents=True, exist_ok=True)
        if not self.store_path.exists():
            self.store_path.write_text("{}", encoding="utf-8")

    def _read(self) -> dict:
        self._ensure_file()
        try:
            content = self.store_path.read_text(encoding="utf-8").strip()
            if not content:
                return {}
            data = json.loads(content)
            return data if isinstance(data, dict) else {}
        except (OSError, json.JSONDecodeError):
            return {}

    def _write(self, data: dict) -> None:
        self._ensure_file()
        self.store_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def get_record_analysis_map(self, record_id: str) -> dict[str, dict]:
        with _STORE_LOCK:
            data = self._read()
            record_data = data.get(record_id, {})
            return record_data if isinstance(record_data, dict) else {}

    def get_image_analysis(self, record_id: str, image_url: str) -> dict | None:
        return self.get_record_analysis_map(record_id).get(image_url)

    def save_image_analysis(self, record_id: str, image_url: str, payload: dict) -> None:
        with _STORE_LOCK:
            data = self._read()
            record_data = data.get(record_id)
            if not isinstance(record_data, dict):
                record_data = {}
            record_data[image_url] = payload
            data[record_id] = record_data
            self._write(data)

    def delete_record(self, record_id: str) -> None:
        with _STORE_LOCK:
            data = self._read()
            if record_id in data:
                data.pop(record_id, None)
                self._write(data)
