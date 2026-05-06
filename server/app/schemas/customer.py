"""
客户模块 Pydantic Schema

用于请求验证和响应序列化
"""
from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel, Field, field_validator


# ==========================================
# 基础 Schema
# ==========================================

class CustomerBase(BaseModel):
    """客户基础字段"""
    name: str = Field(..., min_length=1, max_length=100, description="客户姓名")
    phone: Optional[str] = Field(None, max_length=50, description="客户电话")
    gender: Optional[str] = Field(None, max_length=20, description="客户性别")
    age: Optional[int] = Field(None, ge=0, le=120, description="客户年龄")
    tags: List[str] = Field(default_factory=list, description="客户标签列表")


# ==========================================
# 请求 Schema
# ==========================================

class CustomerCreate(BaseModel):
    """
    创建客户请求
    
    用于 POST /api/v1/customers
    """
    name: str = Field(..., min_length=1, max_length=100, description="客户姓名")
    phone: Optional[str] = Field(None, max_length=50, description="客户电话")
    gender: Optional[str] = Field(None, max_length=20, description="客户性别")
    age: Optional[int] = Field(None, ge=0, le=120, description="客户年龄")
    location: Optional[str] = Field(None, max_length=255, description="客户主地址")
    tags: List[str] = Field(default_factory=list, description="客户标签列表")

    @field_validator("tags")
    @classmethod
    def validate_tags(cls, v: List[str]) -> List[str]:
        """确保 tags 是字符串列表"""
        if v is None:
            return []
        return [str(tag).strip() for tag in v if tag and str(tag).strip()]


# ==========================================
# 响应 Schema
# ==========================================

class CustomerIdResponse(BaseModel):
    """
    客户ID响应
    
    用于创建客户成功后的返回
    """
    customer_id: str = Field(..., description="客户ID")


class CustomerListItem(BaseModel):
    """
    客户列表项

    用于 GET /api/v1/customers 列表返回
    """
    id: str = Field(..., description="客户ID")
    name: str = Field(..., description="客户姓名")
    phone: Optional[str] = Field(None, description="客户电话")
    gender: Optional[str] = Field(None, description="客户性别")
    age: Optional[int] = Field(None, description="客户年龄")
    location_raw: Optional[str] = Field(None, description="原始地址")
    location_city: Optional[str] = Field(None, description="城市")
    location_district: Optional[str] = Field(None, description="区")
    location_subarea: Optional[str] = Field(None, description="片区")
    tags: List[str] = Field(default_factory=list, description="客户标签列表")
    summary_status: str = Field("stale", description="画像状态")
    updated_at: datetime = Field(..., description="更新时间")

    model_config = {"from_attributes": True}


class CustomerDetail(BaseModel):
    """
    客户详情
    
    用于 GET /api/v1/customers/{id} 详情返回
    """
    id: str = Field(..., description="客户ID")
    name: str = Field(..., description="客户姓名")
    phone: Optional[str] = Field(None, description="客户电话")
    gender: Optional[str] = Field(None, description="客户性别")
    age: Optional[int] = Field(None, description="客户年龄")
    location_raw: Optional[str] = Field(None, description="原始地址")
    location_city: Optional[str] = Field(None, description="城市")
    location_district: Optional[str] = Field(None, description="区")
    location_subarea: Optional[str] = Field(None, description="片区")
    tags: List[str] = Field(default_factory=list, description="客户标签列表")
    summary_text: Optional[str] = Field(None, description="客户画像摘要")
    summary_status: str = Field(..., description="总结状态")
    created_at: datetime = Field(..., description="创建时间")
    updated_at: datetime = Field(..., description="更新时间")
    
    model_config = {"from_attributes": True}


class CustomerListResponse(BaseModel):
    """
    客户列表响应
    
    包装客户列表数据
    """
    items: List[CustomerListItem] = Field(default_factory=list, description="客户列表")
    total: int = Field(0, description="总数")
    page: int = Field(1, description="当前页码")
    page_size: int = Field(20, description="每页数量")


# ==========================================
# 其他 Schema
# ==========================================

class CustomerUpdate(BaseModel):
    """
    更新客户请求
    """
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = Field(None, max_length=50)
    gender: Optional[str] = Field(None, max_length=20)
    age: Optional[int] = Field(None, ge=0, le=120)
    location: Optional[str] = Field(None, max_length=255)
    tags: Optional[List[str]] = Field(None)

    @field_validator("tags")
    @classmethod
    def validate_tags(cls, v: Optional[List[str]]) -> Optional[List[str]]:
        """确保 tags 是字符串列表"""
        if v is None:
            return None
        return [str(tag).strip() for tag in v if tag and str(tag).strip()]


class SummaryGenerateResponse(BaseModel):
    """
    生成客户摘要响应
    
    用于 POST /api/v1/customers/{id}/summary/generate
    """
    customer_id: str = Field(..., description="客户ID")
    summary_text: str = Field(..., description="客户摘要")
    summary_status: str = Field(..., description="总结状态: ready/updating/failed/stale")
    records_count: int = Field(..., description="参与生成的记录数")
    updated_at: datetime = Field(..., description="更新时间")
    
    model_config = {"from_attributes": True}


class CustomerChatRequest(BaseModel):
    """
    客户对话请求
    
    用于 POST /api/v1/customers/{id}/chat
    """
    question: str = Field(..., min_length=1, max_length=500, description="用户问题")


class CustomerChatResponse(BaseModel):
    """
    客户对话响应
    
    用于 POST /api/v1/customers/{id}/chat
    """
    customer_id: str = Field(..., description="客户ID")
    question: str = Field(..., description="用户问题")
    answer: str = Field(..., description="AI回答")


class AdviceGenerateResponse(BaseModel):
    """
    生成跟进建议响应
    
    用于 POST /api/v1/customers/{id}/advice/generate
    """
    customer_id: str = Field(..., description="客户ID")
    advice_text: str = Field(..., description="跟进建议")
    updated_at: Optional[datetime] = Field(None, description="建议保存时间")
