"""行业配置模型。"""
from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Industry(Base):
    """App 支持的行业及其提示词配置。"""

    __tablename__ = "industries"

    key: Mapped[str] = mapped_column(String(40), primary_key=True, comment="行业标识")
    label: Mapped[str] = mapped_column(String(100), nullable=False, comment="行业名称")
    role_name: Mapped[str] = mapped_column(String(100), nullable=False, comment="AI 角色名")
    enabled: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
        server_default="true",
        comment="是否启用",
    )
    prompt_config: Mapped[dict] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default="{}",
        comment="行业提示词配置",
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
