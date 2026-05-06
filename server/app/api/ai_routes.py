"""
AI 全局问答路由

提供全局业务问答能力，不依赖特定客户。
路由层只负责接收参数、调用服务、返回统一响应。
"""
import logging

from fastapi import APIRouter, Depends, File, Form, UploadFile
from pydantic import BaseModel, Field

from app.core.dependencies import get_current_user_id
from app.services.ai_service import AIService
from app.services.upload_guard import UploadValidationError, read_validated_images
from app.utils.response import error_response, success_response

router = APIRouter(tags=["ai"])
logger = logging.getLogger(__name__)


def get_ai_service() -> AIService:
    """提供 AI 服务实例，便于后续扩展依赖注入。"""
    return AIService()


class AIChatMessage(BaseModel):
    """前端传入的最近对话消息，用于轻量多轮追问。"""

    role: str = Field(..., description="user 或 assistant")
    content: str = Field(..., min_length=1, max_length=2000, description="消息内容")


class AIChatRequest(BaseModel):
    """AI 问答请求"""

    question: str = Field(..., min_length=1, max_length=500, description="用户问题")
    recent_messages: list[AIChatMessage] = Field(
        default_factory=list,
        max_length=16,
        description="最近 8 轮对话上下文，由前端裁剪后传入",
    )


class AIChatResponse(BaseModel):
    """AI 问答响应"""

    answer: str = Field(..., description="AI 回答")


@router.post(
    "/ai/chat",
    summary="全局业务问答",
    description="基于用户所有客户信息进行业务问答",
    response_description="AI 回答",
)
async def ai_chat(
    request: AIChatRequest,
    user_id: str = Depends(get_current_user_id),
    ai_service: AIService = Depends(get_ai_service),
):
    """
    全局业务问答

    基于当前用户的客户列表和摘要信息回答问题。
    适用于：列出所有客户、找出多久未联系的客户等全局查询。
    """
    recent_messages = [
        {"role": message.role, "content": message.content}
        for message in request.recent_messages
    ]
    answer = await ai_service.ask_global_question(
        user_id,
        request.question,
        recent_messages=recent_messages,
    )
    return success_response(data={"answer": answer})


@router.post(
    "/ai/chat-with-image",
    summary="带图片的全局 AI 问答",
    description="基于用户上传的一张图片和这次问题做单轮问答",
    response_description="AI 回答",
)
async def ai_chat_with_image(
    question: str = Form(...),
    image: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    ai_service: AIService = Depends(get_ai_service),
):
    _ = user_id

    if not question.strip():
        return error_response(
            code="INVALID_QUESTION",
            message="请输入问题",
            status_code=400,
        )

    try:
        validated = await read_validated_images([image])
        result = await ai_service.ask_image_question(
            question,
            image,
            validated_file=validated[0],
        )
    except UploadValidationError as error:
        return error_response(
            code="INVALID_IMAGE",
            message=str(error),
            status_code=400,
        )
    except ValueError as error:
        return error_response(
            code="INVALID_IMAGE",
            message=str(error),
            status_code=400,
        )
    except Exception:
        logger.exception("AI image chat failed")
        return error_response(
            code="IMAGE_CHAT_UNAVAILABLE",
            message="图片问答暂时不可用，请稍后再试。",
            status_code=503,
        )

    return success_response(data=result)
