"""
行业模型
"""
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Industry(Base):
    """行业定义"""

    __tablename__ = "industries"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, comment="主键 UUID",
    )
    key: Mapped[str] = mapped_column(
        String(40), unique=True, nullable=False, comment="行业标识",
    )
    label: Mapped[str] = mapped_column(
        String(100), nullable=False, comment="中文标签",
    )
    role_name: Mapped[str] = mapped_column(
        String(100), nullable=False, comment="角色名称",
    )
    enabled: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true", comment="是否启用",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, comment="创建时间",
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False, comment="更新时间",
    )


class IndustryPrompt(Base):
    """行业提示词"""

    __tablename__ = "industry_prompts"
    __table_args__ = (
        UniqueConstraint("industry_key", "prompt_field", name="uq_industry_prompts_key_field"),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, comment="主键 UUID",
    )
    industry_key: Mapped[str] = mapped_column(
        String(40), ForeignKey("industries.key", ondelete="CASCADE"), nullable=False, comment="行业标识",
    )
    prompt_field: Mapped[str] = mapped_column(
        String(100), nullable=False, comment="提示词字段名",
    )
    value: Mapped[str] = mapped_column(
        Text(), nullable=False, comment="提示词内容",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False, comment="创建时间",
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False, comment="更新时间",
    )
