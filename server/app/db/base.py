"""
SQLAlchemy ORM 基础定义

所有模型类的基类，包含：
- 基础元数据
- 通用字段和方法
- 类型注解支持
"""
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, String
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.sql import func


class Base(DeclarativeBase):
    """
    SQLAlchemy 声明式基类
    
    所有数据模型都继承此类
    """
    
    # 类型注解映射
    type_annotation_map = {
        str: String(255),
        datetime: DateTime(timezone=True),
    }
    
    def to_dict(self) -> dict[str, Any]:
        """
        将模型实例转换为字典
        
        Returns:
            包含模型字段的字典
        """
        result = {}
        for column in self.__table__.columns:
            value = getattr(self, column.name)
            # 处理 datetime 序列化
            if isinstance(value, datetime):
                value = value.isoformat()
            result[column.name] = value
        return result


class BaseModelMixin:
    """
    基础模型混入类
    
    提供通用字段：
    - id: 主键
    - created_at: 创建时间
    - updated_at: 更新时间
    """
    
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="主键 UUID"
    )
    
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        comment="创建时间"
    )
    
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        comment="更新时间"
    )
