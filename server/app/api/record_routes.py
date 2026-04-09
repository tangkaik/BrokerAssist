"""
沟通记录管理路由

提供沟通记录相关的 REST API 接口：
- POST /api/v1/records - 创建记录
- GET /api/v1/customers/{customer_id}/records - 客户记录列表
- DELETE /api/v1/records/{record_id} - 删除记录

注意：所有业务逻辑委托给 RecordService，路由层只负责：
1. 接收参数
2. 调用 service
3. 返回统一响应
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.record import (
    RecordCreate,
    RecordIdResponse,
    RecordListResponse,
)
from app.services.record_service import RecordService
from app.utils.response import success_response, error_response, not_found_error

router = APIRouter(tags=["records"])


# ==========================================
# 依赖注入
# ==========================================

def get_record_service(
    session: AsyncSession = Depends(get_db),
) -> RecordService:
    """获取沟通记录服务实例"""
    return RecordService(session)


# ==========================================
# 路由定义
# ==========================================

@router.post(
    "/records",
    summary="创建沟通记录",
    description="为客户创建新的沟通记录，自动更新客户画像状态为 stale",
    response_description="创建成功返回记录ID",
)
async def create_record(
    data: RecordCreate,
    user_id: str = Depends(get_current_user_id),
    service: RecordService = Depends(get_record_service),
):
    """
    创建沟通记录
    
    创建一条文本类型的沟通记录，关联到指定客户。
    创建成功后，客户的 summary_status 会自动更新为 "stale"。
    """
    record_id, error = await service.create_record(
        user_id=user_id,
        data=data,
    )
    
    if error:
        return not_found_error("客户")
    
    return success_response(
        data=RecordIdResponse(record_id=record_id),
        status_code=201,
    )


@router.get(
    "/customers/{customer_id}/records",
    summary="客户记录列表",
    description="获取指定客户的沟通记录列表，按时间倒序排列",
    response_description="记录列表",
)
async def get_customer_records(
    customer_id: str,
    limit: int = Query(50, ge=1, le=100, description="返回记录数量限制"),
    user_id: str = Depends(get_current_user_id),
    service: RecordService = Depends(get_record_service),
):
    """
    获取客户沟通记录列表
    
    返回指定客户的所有沟通记录，按创建时间倒序排列。
    如果客户不存在或无权访问，返回空列表。
    """
    result = await service.get_customer_records(
        user_id=user_id,
        customer_id=customer_id,
        limit=limit,
    )
    
    return success_response(data=result)


@router.delete(
    "/records/{record_id}",
    summary="删除沟通记录",
    description="删除指定的沟通记录",
    response_description="删除成功",
)
async def delete_record(
    record_id: str,
    user_id: str = Depends(get_current_user_id),
    service: RecordService = Depends(get_record_service),
):
    """
    删除沟通记录
    
    删除指定的沟通记录，同时更新客户画像状态为 stale。
    记录不存在或无权访问时返回 404。
    """
    success, error = await service.delete_record(
        user_id=user_id,
        record_id=record_id,
    )
    
    if not success:
        return not_found_error("记录", record_id)
    
    return success_response(data={"message": "删除成功"})
