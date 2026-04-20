"""
客户模型 (Customer Model)

定义客户数据的 ORM 映射
"""
from datetime import datetime
from typing import Optional, List

from sqlalchemy import String, DateTime, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Customer(Base):
    """
    客户表
    
    存储保险经纪人的客户基本信息
    """
    __tablename__ = "customers"
    
    # 主键 - UUID
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="客户ID (UUID)"
    )
    
    # 用户ID - 每个客户属于特定用户
    user_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        index=True,
        comment="所属用户ID"
    )
    
    # 客户基本信息
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="客户姓名"
    )
    
    phone: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="客户电话"
    )
    
    gender: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="客户性别"
    )

    # 客户地址（结构化）
    location_raw: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
        comment="原始地址字符串"
    )
    location_city: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="城市"
    )
    location_district: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
        comment="区/县"
    )
    location_subarea: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="片区/街道"
    )

    # 标签 - 使用 JSONB 存储字符串数组
    tags: Mapped[List[str]] = mapped_column(
        JSONB,
        nullable=False,
        default=list,
        server_default="[]",
        comment="客户标签列表"
    )
    
    # AI 总结状态
    summary_status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="stale",
        server_default="'stale'",
        comment="总结状态: stale/updating/ready/failed"
    )
    
    # AI 生成的客户摘要
    summary_text: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="AI生成的客户摘要"
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
    
    # 软删除标记 - 不为 null 表示已删除
    deleted_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        default=None,
        comment="删除时间 (null表示未删除)"
    )
    
    def __repr__(self) -> str:
        return f"<Customer(id={self.id}, name={self.name}, user_id={self.user_id})>"
