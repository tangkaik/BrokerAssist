"""
沟通记录模型 (Record Model)

定义客户沟通记录的 ORM 映射
"""
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import String, DateTime, Text, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.customer import Customer


class Record(Base):
    """
    沟通记录表
    
    存储保险经纪人与客户的沟通内容
    """
    __tablename__ = "records"
    
    # 主键 - UUID
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="记录ID (UUID)"
    )
    
    # 关联客户 - 外键
    customer_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("customers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="所属客户ID"
    )
    
    # 记录内容
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="沟通内容（原始文本）"
    )

    # 地点线索（用户原始输入 + 后台归一化结果）
    location_raw: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="原始地点线索"
    )

    location_city: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="归一化城市"
    )

    location_district: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="归一化城区"
    )

    location_subarea: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="归一化街道/片区"
    )
    
    # 记录类型
    type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="text",
        server_default="'text'",
        comment="记录类型: text/audio"
    )
    
    # 时间戳
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
    
    # 关联关系
    customer: Mapped["Customer"] = relationship("Customer", back_populates="records")
    
    def __repr__(self) -> str:
        return f"<Record(id={self.id}, customer_id={self.customer_id}, type={self.type})>"
