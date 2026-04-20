"""
埋点分析数据 Schema

Pydantic 模型定义，用于 API 请求/响应验证
"""
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field


# ============== 事件上报 Schema ==============

class AnalyticsEventCreate(BaseModel):
    """单个事件上报请求"""
    event_name: str = Field(..., description="事件名称", max_length=50)
    event_time: Optional[datetime] = Field(default=None, description="事件发生时间")
    session_id: Optional[str] = Field(default=None, description="会话ID", max_length=36)
    properties: Dict[str, Any] = Field(default_factory=dict, description="事件属性")


class AnalyticsBatchCreate(BaseModel):
    """批量事件上报请求"""
    events: List[AnalyticsEventCreate] = Field(..., description="事件列表")
    device_id: Optional[str] = Field(default=None, description="设备ID")
    platform: Optional[str] = Field(default=None, description="平台: android/ios/web")
    app_version: Optional[str] = Field(default=None, description="App版本")


class AnalyticsEventResponse(BaseModel):
    """事件上报响应"""
    success: bool = Field(..., description="是否成功")
    event_id: Optional[str] = Field(default=None, description="事件ID")
    message: Optional[str] = Field(default=None, description="消息")


class AnalyticsBatchResponse(BaseModel):
    """批量上报响应"""
    success: bool = Field(..., description="是否成功")
    batch_id: Optional[str] = Field(default=None, description="批次ID")
    processed_count: int = Field(default=0, description="处理成功的事件数")
    failed_count: int = Field(default=0, description="处理失败的事件数")
    message: Optional[str] = Field(default=None, description="消息")


# ============== 查询 Schema ==============

class AnalyticsQueryParams(BaseModel):
    """事件查询参数"""
    start_date: Optional[str] = Field(default=None, description="开始日期 (YYYY-MM-DD)")
    end_date: Optional[str] = Field(default=None, description="结束日期 (YYYY-MM-DD)")
    event_name: Optional[str] = Field(default=None, description="事件名称过滤")
    user_id: Optional[str] = Field(default=None, description="用户ID过滤")
    limit: int = Field(default=1000, ge=1, le=10000, description="返回数量限制")
    offset: int = Field(default=0, ge=0, description="偏移量")


class AnalyticsEventItem(BaseModel):
    """事件列表项"""
    id: str = Field(..., description="事件ID")
    event_name: str = Field(..., description="事件名称")
    event_time: datetime = Field(..., description="事件发生时间")
    user_id: str = Field(..., description="用户ID")
    session_id: Optional[str] = Field(None, description="会话ID")
    device_id: Optional[str] = Field(None, description="设备ID")
    platform: Optional[str] = Field(None, description="平台")
    properties: Dict[str, Any] = Field(default_factory=dict, description="事件属性")
    
    class Config:
        from_attributes = True


class AnalyticsListResponse(BaseModel):
    """事件列表响应"""
    total: int = Field(..., description="总数")
    items: List[AnalyticsEventItem] = Field(..., description="事件列表")
    limit: int = Field(..., description="限制数")
    offset: int = Field(..., description="偏移量")


# ============== 统计 Dashboard Schema ==============

class DailyMetric(BaseModel):
    """每日指标"""
    date: str = Field(..., description="日期 (YYYY-MM-DD)")
    event_count: int = Field(..., description="事件总数")
    unique_users: int = Field(..., description="独立用户数")


class EventTypeMetric(BaseModel):
    """事件类型指标"""
    event_name: str = Field(..., description="事件名称")
    count: int = Field(..., description="发生次数")
    unique_users: int = Field(..., description="独立用户数")


class ConversionMetric(BaseModel):
    """转化指标（用于 result_record_created）"""
    source: str = Field(..., description="来源: recording/manual")
    action: str = Field(..., description="操作: create_new/add_existing")
    attempts: int = Field(..., description="尝试次数")
    success: int = Field(..., description="成功次数")
    success_rate: float = Field(..., description="成功率")
    avg_duration_ms: Optional[float] = Field(None, description="平均耗时(ms)")


class AnalyticsDashboardResponse(BaseModel):
    """Dashboard 数据响应"""
    date_range: Dict[str, str] = Field(..., description="日期范围")
    summary: Dict[str, Any] = Field(..., description="汇总指标")
    daily_trend: List[DailyMetric] = Field(..., description="每日趋势")
    event_types: List[EventTypeMetric] = Field(..., description="事件类型分布")
    conversions: List[ConversionMetric] = Field(..., description="转化指标")


# ============== CSV 导出 Schema ==============

class CSVExportRequest(BaseModel):
    """CSV导出请求"""
    start_date: str = Field(..., description="开始日期 (YYYY-MM-DD)")
    end_date: str = Field(..., description="结束日期 (YYYY-MM-DD)")
    event_names: Optional[List[str]] = Field(default=None, description="事件名称过滤，null表示全部")
    user_id: Optional[str] = Field(default=None, description="用户ID过滤")
    format: str = Field(default="csv", description="格式: csv")


class CSVExportResponse(BaseModel):
    """CSV导出响应（异步生成）"""
    export_id: str = Field(..., description="导出任务ID")
    status: str = Field(..., description="状态: pending/processing/completed/failed")
    download_url: Optional[str] = Field(None, description="下载链接")
    message: Optional[str] = Field(None, description="状态消息")
    total_records: Optional[int] = Field(None, description="总记录数")
