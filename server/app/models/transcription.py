"""
音频转写任务模型 (Transcription Model)

管理音频文件上传和转写流程：
- 调用讯飞语音转写
- 保存转写结果
- 用户确认后生成正式 record
"""
from datetime import datetime
from typing import Optional, TYPE_CHECKING

from sqlalchemy import String, DateTime, Text, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.customer import Customer


class Transcription(Base):
    """
    音频转写任务表
    
    存储音频上传和转写过程的完整生命周期
    """
    __tablename__ = "transcriptions"
    
    # 主键 - UUID
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        comment="转写任务ID (UUID)"
    )
    
    # 关联客户 - 外键 (可为空，首页草稿流程)
    customer_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        ForeignKey("customers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="所属客户ID (可为空)"
    )
    
    # 文件信息
    original_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="用户原始上传文件名（展示用）"
    )
    
    file_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="安全文件名（用于转写任务）"
    )
    
    file_path: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="原始音频路径（当前不保存，保留为空）"
    )
    
    file_size: Mapped[Optional[int]] = mapped_column(
        nullable=True,
        comment="文件大小（字节）"
    )
    
    # 转写状态
    # uploaded: 已上传，等待转写
    # transcribing: 转写中
    # transcribed: 转写完成，等待用户确认
    # confirmed: 已确认，已生成 record
    # failed: 转写失败
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="uploaded",
        server_default="'uploaded'",
        comment="状态: uploaded/transcribing/transcribed/confirmed/failed"
    )
    
    # 转写结果
    transcript_text: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="转写后的文本内容"
    )
    
    # 错误信息
    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="错误信息（失败时填写）"
    )
    
    # 关联的 record_id（确认后填写）
    record_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        comment="关联的 record ID（确认后生成）"
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
    customer: Mapped[Optional["Customer"]] = relationship("Customer", back_populates="transcriptions")
    
    def __repr__(self) -> str:
        return f"<Transcription(id={self.id}, customer_id={self.customer_id}, status={self.status})>"
