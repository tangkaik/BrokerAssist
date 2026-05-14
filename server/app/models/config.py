"""
配置模型
"""
from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Config(Base):
    """系统配置键值对"""

    __tablename__ = "configs"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, comment="主键 UUID",
    )
    key: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False, comment="配置键",
    )
    value: Mapped[str] = mapped_column(
        Text(), nullable=False, comment="配置值",
    )
    label: Mapped[str | None] = mapped_column(
        String(200), nullable=True, comment="配置标签",
    )
    description: Mapped[str | None] = mapped_column(
        Text(), nullable=True, comment="配置说明",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, comment="创建时间",
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False, comment="更新时间",
    )
