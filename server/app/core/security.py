"""
认证与安全工具

提供：
- 密码哈希与校验
- Bearer token 生成与校验
"""
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from app.core.config import settings


# 在小规格云主机上保留足够强度，同时避免首启或注册时长时间卡死。
ARGON2_TIME_COST = 2
ARGON2_MEMORY_COST = 19456
ARGON2_PARALLELISM = 1


def hash_password(password: str, *, time_cost: int = ARGON2_TIME_COST) -> str:
    """生成 Argon2 密码哈希。"""
    import argon2
    ph = argon2.PasswordHasher(
        time_cost=time_cost,
        memory_cost=ARGON2_MEMORY_COST,
        parallelism=ARGON2_PARALLELISM,
    )
    return ph.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """校验密码是否匹配。"""
    import argon2
    ph = argon2.PasswordHasher(
        time_cost=ARGON2_TIME_COST,
        memory_cost=ARGON2_MEMORY_COST,
        parallelism=ARGON2_PARALLELISM,
    )
    try:
        ph.verify(password_hash, password)
        return True
    except argon2.exceptions.VerifyMismatchError:
        return False
    except Exception:
        return False


def create_access_token(user_id: str, account: str) -> str:
    """创建 Bearer token。"""
    now = datetime.now(timezone.utc)
    payload = {
        "user_id": user_id,
        "account": account,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.auth_token_expire_days)).timestamp()),
    }
    return jwt.encode(payload, settings.auth_secret_key, algorithm="HS256")


def decode_access_token(token: str) -> dict[str, Any]:
    """校验并解析 token。"""
    try:
        payload = jwt.decode(
            token,
            settings.auth_secret_key,
            algorithms=["HS256"],
            options={"require": ["exp", "user_id", "account"]},
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise ValueError("Token 已过期")
    except jwt.InvalidTokenError as exc:
        raise ValueError(f"Token 无效: {exc}")
