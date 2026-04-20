"""
埋点分析数据模型 (Analytics Model)

定义用户行为埋点数据的 ORM 映射
支持 CSV 导出和数据分析
"""
from datetime import datetime
from typing import Optional, Dict, Any

from sqlalchemy import String, DateTime, Text, Boolean, Integer, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AnalyticsEvent(Base):
    """
    埋点事件表
    
    存储用户行为事件，包括：
    - 页面浏览 (page_view)
    - 用户操作 (action)
    - 结果事件 (result)
    """
    __tablename__ = "analytics_events"
    
    # 主键 - UUID
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="事件ID (UUID)"
    )
    
    # 事件基础信息
    event_name: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="事件名称，如: page_view, action_start_recording, result_record_created"
    )
    
    event_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
        comment="事件发生时间"
    )
    
    # 用户标识
    user_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        index=True,
        comment="用户ID (当前MVP固定为default-user)"
    )
    
    session_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        comment="会话ID"
    )
    
    # 设备/环境信息
    device_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="设备标识"
    )
    
    platform: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="平台: android, ios, web"
    )
    
    app_version: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="App版本号"
    )
    
    # 扩展属性 (JSON格式)
    properties: Mapped[Dict[str, Any]] = mapped_column(
        JSONB,
        nullable=False,
        default=dict,
        server_default="{}",
        comment="事件属性(JSON格式)"
    )
    
    # 创建时间（入库时间）
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="记录创建时间"
    )
    
    # 索引优化
    __table_args__ = (
        # 复合索引：按用户+时间查询
        Index('idx_analytics_user_time', 'user_id', 'event_time'),
        # 复合索引：按事件名+时间查询
        Index('idx_analytics_name_time', 'event_name', 'event_time'),
    )
    
    def __repr__(self) -> str:
        return f"<AnalyticsEvent(id={self.id}, name={self.event_name}, time={self.event_time})>"
    
    def to_csv_row(self) -> dict:
        """
        转换为CSV行格式
        
        Returns:
            平铺的字典，适合CSV导出
        """
        row = {
            'event_id': self.id,
            'event_name': self.event_name,
            'event_time': self.event_time.isoformat() if self.event_time else '',
            'user_id': self.user_id,
            'session_id': self.session_id or '',
            'device_id': self.device_id or '',
            'platform': self.platform or '',
            'app_version': self.app_version or '',
        }
        
        # 展开 properties 中的字段
        if self.properties:
            for key, value in self.properties.items():
                # 处理嵌套对象，转换为JSON字符串
                if isinstance(value, (dict, list)):
                    import json
                    row[f'prop_{key}'] = json.dumps(value, ensure_ascii=False)
                else:
                    row[f'prop_{key}'] = value
        
        return row


class AnalyticsBatch(Base):
    """
    批量上报批次表
    
    记录客户端批量上报的状态
    """
    __tablename__ = "analytics_batches"
    
    # 主键 - UUID
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="批次ID (UUID)"
    )
    
    # 用户标识
    user_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        index=True,
        comment="用户ID"
    )
    
    # 批次信息
    event_count: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="批次中包含的事件数量"
    )
    
    # 设备信息
    device_id: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
        comment="设备标识"
    )
    
    platform: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="平台"
    )
    
    app_version: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="App版本"
    )
    
    # 状态
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="received",
        comment="状态: received, processing, completed, failed"
    )
    
    # 错误信息
    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="错误信息"
    )
    
    # 时间戳
    received_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="接收时间"
    )
    
    processed_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="处理完成时间"
    )
    
    def __repr__(self) -> str:
        return f"<AnalyticsBatch(id={self.id}, events={self.event_count}, status={self.status})>"
