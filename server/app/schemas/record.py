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


# ==========================================
# 响应 Schema
# ==========================================

class RecordIdResponse(BaseModel):
    """
    记录ID响应
    
    用于创建记录成功后的返回
    """
    record_id: str = Field(..., description="记录ID")


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
    
    model_config = {"from_attributes": True}


class RecordListResponse(BaseModel):
    """
    记录列表响应
    
    包装记录列表数据
    """
    items: list[RecordItem] = Field(default_factory=list, description="记录列表")
    total: int = Field(0, description="总数")
