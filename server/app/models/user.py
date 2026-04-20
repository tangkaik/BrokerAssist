"""
用户模型
"""
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class User(Base):
    """应用账号。"""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="用户ID (UUID)",
    )
    account: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        unique=True,
        index=True,
        comment="登录账号（手机号或邮箱）",
    )
    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="密码哈希",
    )
    name: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="昵称",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        comment="创建时间",
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间",
    )

    def __repr__(self) -> str:
        return f"<User(id={self.id}, account={self.account})>"
