"""
记录图片分析模型 (RecordImageAnalysis Model)

存储 AI 对记录图片的分析结果
"""
from datetime import datetime

from sqlalchemy import String, DateTime, ForeignKey, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class RecordImageAnalysis(Base):
    """记录图片分析表"""
    __tablename__ = "record_image_analyses"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="分析ID (UUID)"
    )

    record_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("records.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="所属记录ID"
    )

    image_url: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="图片URL"
    )

    answer: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="AI 分析结果"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        comment="创建时间"
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
        comment="更新时间"
    )
