"""
记录图片模型 (RecordImage Model)

存储沟通记录中附加的图片元数据
"""
from datetime import datetime

from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class RecordImage(Base):
    """记录图片表"""
    __tablename__ = "record_images"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="图片ID (UUID)"
    )

    record_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("records.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="所属记录ID"
    )

    image_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="原始文件名"
    )

    image_path: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="存储路径"
    )

    url: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="访问URL"
    )

    content_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="image/jpeg",
        server_default="'image/jpeg'",
        comment="MIME 类型"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        comment="创建时间"
    )
