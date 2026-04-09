"""
音频转写模块 Pydantic Schema

用于请求验证和响应序列化
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ==========================================
# 基础 Schema
# ==========================================

class TranscriptionBase(BaseModel):
    """转写任务基础字段"""
    customer_id: str = Field(..., description="客户ID")


# ==========================================
# 请求 Schema
# ==========================================

class TranscriptionConfirm(BaseModel):
    """
    确认转写结果请求
    
    用于 POST /api/v1/transcriptions/{id}/confirm
    """
    content: str = Field(..., min_length=1, description="用户确认后的文本内容")


# ==========================================
# 响应 Schema
# ==========================================

class TranscriptionIdResponse(BaseModel):
    """
    转写任务ID响应
    
    用于上传成功后的返回
    """
    transcription_id: str = Field(..., description="转写任务ID")


class TranscriptionUploadResponse(BaseModel):
    """
    上传并转写响应
    
    包含转写任务ID和转写结果
    """
    transcription_id: str = Field(..., description="转写任务ID")
    status: str = Field(..., description="任务状态: pending/transcribing/transcribed/failed")
    original_name: str = Field(..., description="原始文件名（展示用）")
    transcript_text: Optional[str] = Field(None, description="转写文本（如果已完成）")
    error_message: Optional[str] = Field(None, description="错误信息（如果失败）")


class TranscriptionItem(BaseModel):
    """
    转写任务列表项
    
    用于列表查询返回
    """
    id: str = Field(..., description="转写任务ID")
    customer_id: str = Field(..., description="客户ID")
    original_name: str = Field(..., description="原始文件名（展示用）")
    file_size: Optional[int] = Field(None, description="文件大小")
    status: str = Field(..., description="状态: pending/transcribing/transcribed/failed/confirmed")
    transcript_text: Optional[str] = Field(None, description="转写文本")
    created_at: datetime = Field(..., description="创建时间")
    
    model_config = {"from_attributes": True}


class TranscriptionDetail(BaseModel):
    """
    转写任务详情
    
    用于详情查询返回
    """
    id: str = Field(..., description="转写任务ID")
    customer_id: str = Field(..., description="客户ID")
    original_name: str = Field(..., description="原始文件名（展示用）")
    file_name: str = Field(..., description="安全文件名（Storage用）")
    file_path: str = Field(..., description="Storage 完整路径")
    file_size: Optional[int] = Field(None, description="文件大小")
    status: str = Field(..., description="状态: pending/transcribing/transcribed/failed/confirmed")
    transcript_text: Optional[str] = Field(None, description="转写文本")
    error_message: Optional[str] = Field(None, description="错误信息")
    record_id: Optional[str] = Field(None, description="关联的record ID")
    created_at: datetime = Field(..., description="创建时间")
    updated_at: datetime = Field(..., description="更新时间")
    
    model_config = {"from_attributes": True}


class TranscriptionListResponse(BaseModel):
    """
    转写任务列表响应
    
    包装转写任务列表数据
    """
    items: list[TranscriptionItem] = Field(default_factory=list, description="转写任务列表")
    total: int = Field(0, description="总数")


class TranscriptionConfirmResponse(BaseModel):
    """
    确认转写结果响应
    
    用于确认后的返回
    """
    transcription_id: str = Field(..., description="转写任务ID")
    record_id: str = Field(..., description="生成的记录ID")
    status: str = Field("confirmed", description="转写任务状态")
    confirmed_text: str = Field(..., description="确认后的文本内容")
