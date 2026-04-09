"""
音频转写任务管理路由

提供音频上传和转写相关的 REST API 接口：
- POST /api/v1/transcriptions/upload - 上传音频并转写
- POST /api/v1/transcriptions/{id}/confirm - 确认转写结果
- GET /api/v1/customers/{customer_id}/transcriptions - 客户转写列表

注意：所有业务逻辑委托给 TranscriptionService，路由层只负责：
1. 接收参数
2. 调用 service
3. 返回统一响应
"""
from typing import Optional

from fastapi import APIRouter, Depends, UploadFile, File, Form, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.transcription import (
    TranscriptionConfirm,
    TranscriptionUploadResponse,
    TranscriptionConfirmResponse,
    TranscriptionListResponse,
)
from app.services.transcription_service import TranscriptionService
from app.utils.response import success_response, error_response, not_found_error

router = APIRouter(tags=["transcriptions"])


# ==========================================
# 依赖注入
# ==========================================

def get_transcription_service(
    session: AsyncSession = Depends(get_db),
) -> TranscriptionService:
    """获取转写任务服务实例"""
    return TranscriptionService(session)


# ==========================================
# 路由定义
# ==========================================

@router.post(
    "/transcriptions/upload",
    summary="上传音频并转写",
    description="上传音频文件到 Supabase Storage，并调用讯飞进行语音转写",
    response_description="转写任务ID和转写结果",
)
async def upload_and_transcribe(
    customer_id: str = Form(..., description="客户ID"),
    file: UploadFile = File(..., description="音频文件"),
    user_id: str = Depends(get_current_user_id),
    service: TranscriptionService = Depends(get_transcription_service),
):
    """
    上传音频并转写
    
    支持的音频格式：wav, mp3, m4a 等
    文件大小限制：建议不超过 500MB
    
    流程：
    1. 验证客户权限
    2. 上传文件到 Supabase Storage
    3. 调用讯飞语音转写
    4. 返回转写结果
    """
    # 读取文件内容
    file_content = await file.read()
    file_size = len(file_content)
    
    # 检查文件大小（限制 500MB）
    max_size = 500 * 1024 * 1024  # 500MB
    if file_size > max_size:
        return error_response(
            code="FILE_TOO_LARGE",
            message="文件大小超过限制（最大500MB）",
            status_code=413,
        )
    
    # 调用服务
    result = await service.upload_and_transcribe(
        user_id=user_id,
        customer_id=customer_id,
        file_content=file_content,
        file_name=file.filename or "audio.wav",
        file_size=file_size,
    )
    
    # 根据状态返回
    if result.status == "failed":
        return error_response(
            code="TRANSCRIPTION_FAILED",
            message=result.error_message or "转写失败",
            status_code=500,
        )
    
    return success_response(data=result)


@router.post(
    "/transcriptions/{transcription_id}/confirm",
    summary="确认转写结果",
    description="将用户编辑后的转写文本保存为正式沟通记录",
    response_description="保存成功",
)
async def confirm_transcription(
    transcription_id: str,
    data: TranscriptionConfirm,
    user_id: str = Depends(get_current_user_id),
    service: TranscriptionService = Depends(get_transcription_service),
):
    """
    确认转写结果
    
    用户可以对转写文本进行编辑，确认后保存为正式的沟通记录（record）。
    只有 status=transcribed 的任务才能被确认。
    保存后会自动更新客户的 summary_status 为 "stale"。
    """
    result = await service.confirm_transcription(
        user_id=user_id,
        transcription_id=transcription_id,
        content=data.content,
    )
    
    return success_response(data=result)


@router.get(
    "/customers/{customer_id}/transcriptions",
    summary="客户转写列表",
    description="获取指定客户的所有音频转写任务列表",
    response_description="转写任务列表",
)
async def get_customer_transcriptions(
    customer_id: str,
    limit: int = Query(50, ge=1, le=100, description="返回数量限制"),
    user_id: str = Depends(get_current_user_id),
    service: TranscriptionService = Depends(get_transcription_service),
):
    """
    获取客户转写列表
    
    返回指定客户的所有音频转写任务，按创建时间倒序排列。
    包含上传中、转写中、已完成等各种状态的任务。
    """
    result = await service.get_customer_transcriptions(
        user_id=user_id,
        customer_id=customer_id,
        limit=limit,
    )
    
    return success_response(data=result)
