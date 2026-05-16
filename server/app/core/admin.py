"""管理后台权限常量。"""
from __future__ import annotations


ADMIN_ACCOUNT = "administrator"


def normalize_account(value: str | None) -> str:
    return (value or "").strip().lower()


def is_administrator_account(value: str | None) -> bool:
    return normalize_account(value) == ADMIN_ACCOUNT
