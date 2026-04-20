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

from fastapi import APIRouter, Depends, Query, UploadFile, File, Form
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


@router.post(
    "/records/with-images",
    summary="创建带图片的沟通记录",
    description="为客户创建新的沟通记录，并可附带上传图片",
    response_description="创建成功返回记录ID",
)
async def create_record_with_images(
    customer_id: str = Form(...),
    content: str = Form(...),
    location_raw: Optional[str] = Form(None),
    images: list[UploadFile] = File(default_factory=list),
    user_id: str = Depends(get_current_user_id),
    service: RecordService = Depends(get_record_service),
):
    """创建带图片的沟通记录"""
    image_payloads: list[tuple[str, bytes, Optional[str]]] = []

    for image in images:
        if image.content_type and not image.content_type.startswith("image/"):
            return error_response(
                code="INVALID_IMAGE_TYPE",
                message=f"{image.filename or '文件'} 不是支持的图片格式",
                status_code=400,
            )
        image_payloads.append(
            (
                image.filename or "image.jpg",
                await image.read(),
                image.content_type,
            )
        )

    record_id, error = await service.create_record_with_images(
        user_id=user_id,
        customer_id=customer_id,
        content=content,
        location_raw=location_raw,
        images=image_payloads,
    )

    if error:
        return not_found_error("客户")

    return success_response(
        data=RecordIdResponse(record_id=record_id),
        status_code=201,
    )


@router.put(
    "/records/{record_id}/with-images",
    summary="更新沟通记录",
    description="更新记录内容，并支持新增图片和删除已有图片",
    response_description="更新后的记录",
)
async def update_record_with_images(
    record_id: str,
    content: str = Form(...),
    location_raw: Optional[str] = Form(None),
    keep_image_urls: list[str] = Form(default_factory=list),
    images: list[UploadFile] = File(default_factory=list),
    user_id: str = Depends(get_current_user_id),
    service: RecordService = Depends(get_record_service),
):
    """更新记录及其图片"""
    image_payloads: list[tuple[str, bytes, Optional[str]]] = []

    for image in images:
        if image.content_type and not image.content_type.startswith("image/"):
            return error_response(
                code="INVALID_IMAGE_TYPE",
                message=f"{image.filename or '文件'} 不是支持的图片格式",
                status_code=400,
            )
        image_payloads.append(
            (
                image.filename or "image.jpg",
                await image.read(),
                image.content_type,
            )
        )

    record, error = await service.update_record_with_images(
        user_id=user_id,
        record_id=record_id,
        content=content,
        location_raw=location_raw,
        keep_image_urls=keep_image_urls,
        new_images=image_payloads,
    )

    if error:
        return not_found_error("记录", record_id)

    return success_response(data=record)


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


@router.post(
    "/records/{record_id}/images/analyze",
    summary="识别记录图片",
    description="手动触发对某张记录图片的识别",
    response_description="图片识别结果",
)
async def analyze_record_image(
    record_id: str,
    image_url: str = Form(...),
    analyze_modes: list[str] = Form(default_factory=list),
    user_id: str = Depends(get_current_user_id),
    service: RecordService = Depends(get_record_service),
):
    payload, error = await service.analyze_record_image(
        user_id=user_id,
        record_id=record_id,
        image_url=image_url,
        analyze_modes=analyze_modes,
    )

    if error == "记录不存在或无权访问":
        return not_found_error("记录", record_id)
    if error:
        return error_response(
            code="IMAGE_ANALYZE_FAILED",
            message=error,
            status_code=400,
        )

    return success_response(data=payload)


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
