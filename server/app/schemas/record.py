"""
沟通记录模块 Pydantic Schema

用于请求验证和响应序列化
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ==========================================
# 基础 Schema
# ==========================================

class RecordBase(BaseModel):
    """记录基础字段"""
    content: str = Field(..., min_length=1, description="沟通内容")


# ==========================================
# 请求 Schema
# ==========================================

class RecordCreate(BaseModel):
    """
    创建记录请求
    
    用于 POST /api/v1/records
    """
    customer_id: str = Field(..., min_length=36, max_length=36, description="客户ID")
    content: str = Field(..., min_length=1, description="沟通内容")
    location_raw: Optional[str] = Field(None, description="原始地点线索")


class RecordUpdate(BaseModel):
    """更新记录请求"""
    content: str = Field(..., min_length=1, description="沟通内容")
    location_raw: Optional[str] = Field(None, description="原始地点线索")


# ==========================================
# 响应 Schema
# ==========================================

class RecordIdResponse(BaseModel):
    """
    记录ID响应
    
    用于创建记录成功后的返回
    """
    record_id: str = Field(..., description="记录ID")


class RecordImageItem(BaseModel):
    """记录图片项"""
    class VisionResult(BaseModel):
        answer: str = Field(..., description="识别结果")
        updated_at: datetime = Field(..., description="识别时间")

    name: str = Field(..., description="原始文件名")
    url: str = Field(..., description="图片访问地址")
    content_type: Optional[str] = Field(None, description="图片 MIME 类型")
    vision: Optional[VisionResult] = Field(None, description="图片识别结果")


class RecordItem(BaseModel):
    """
    记录列表项
    
    用于 GET /api/v1/customers/{id}/records 列表返回
    """
    id: str = Field(..., description="记录ID")
    customer_id: str = Field(..., description="客户ID")
    content: str = Field(..., description="沟通内容")
    type: str = Field(..., description="记录类型")
    created_at: datetime = Field(..., description="创建时间")
    location_raw: Optional[str] = Field(None, description="原始地点线索")
    location_city: Optional[str] = Field(None, description="归一化城市")
    location_district: Optional[str] = Field(None, description="归一化城区")
    location_subarea: Optional[str] = Field(None, description="归一化街道/片区")
    images: list[RecordImageItem] = Field(default_factory=list, description="关联图片")
    
    model_config = {"from_attributes": True}


class RecordListResponse(BaseModel):
    """
    记录列表响应
    
    包装记录列表数据
    """
    items: list[RecordItem] = Field(default_factory=list, description="记录列表")
    total: int = Field(0, description="总数")
