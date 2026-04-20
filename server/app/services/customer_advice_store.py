"""
客户拜访建议 JSON 存储

用于在不修改数据库结构的前提下，持久化保存客户的拜访建议。
"""
import json
from datetime import datetime
from pathlib import Path
from threading import Lock
from typing import Optional


_STORE_LOCK = Lock()


class CustomerAdviceStore:
    """基于 JSON 文件的客户拜访建议存储"""

    def __init__(self, file_path: Optional[Path] = None):
        server_root = Path(__file__).resolve().parents[2]
        self.file_path = file_path or server_root / "data" / "customer_advices.json"

    def _ensure_store_file(self) -> None:
        self.file_path.parent.mkdir(parents=True, exist_ok=True)
        if not self.file_path.exists():
            self.file_path.write_text("{}", encoding="utf-8")

    def _read_all(self) -> dict:
        self._ensure_store_file()
        try:
            content = self.file_path.read_text(encoding="utf-8").strip()
            if not content:
                return {}
            data = json.loads(content)
            return data if isinstance(data, dict) else {}
        except (json.JSONDecodeError, OSError):
            return {}

    def _write_all(self, data: dict) -> None:
        self._ensure_store_file()
        self.file_path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def get_advice(self, user_id: str, customer_id: str) -> Optional[dict]:
        with _STORE_LOCK:
            data = self._read_all()
            return data.get(user_id, {}).get(customer_id)

    def save_advice(self, user_id: str, customer_id: str, advice_text: str) -> dict:
        payload = {
            "customer_id": customer_id,
            "advice_text": advice_text,
            "updated_at": datetime.utcnow().isoformat(),
        }

        with _STORE_LOCK:
            data = self._read_all()
            user_data = data.setdefault(user_id, {})
            user_data[customer_id] = payload
            self._write_all(data)

        return payload
