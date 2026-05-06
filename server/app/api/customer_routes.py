"""
客户管理路由

提供客户相关的 REST API 接口：
- POST /api/v1/customers - 创建客户
- GET /api/v1/customers - 客户列表
- GET /api/v1/customers/{id} - 客户详情
- DELETE /api/v1/customers/{id} - 删除客户（软删除）

注意：所有业务逻辑委托给 CustomerService，路由层只负责：
1. 接收参数
2. 调用 service
3. 返回统一响应
"""
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.customer import (
    CustomerCreate,
    CustomerIdResponse,
    CustomerDetail,
    CustomerListResponse,
    CustomerUpdate,
    CustomerChatRequest,
    CustomerChatResponse,
    AdviceGenerateResponse,
)
from app.services.customer_service import CustomerService
from app.utils.response import success_response, not_found_error

router = APIRouter(prefix="/customers", tags=["customers"])


# ==========================================
# 依赖注入
# ==========================================

def get_customer_service(
    session: AsyncSession = Depends(get_db),
) -> CustomerService:
    """获取客户服务实例"""
    return CustomerService(session)


# ==========================================
# 路由定义
# ==========================================

@router.post(
    "",
    summary="创建客户",
    description="创建新的客户记录",
    response_description="创建成功返回客户ID",
)
async def create_customer(
    data: CustomerCreate,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """
    创建客户
    
    创建一个新的客户记录，自动关联到当前用户
    """
    customer_id = await service.create_customer(
        user_id=user_id,
        data=data,
    )
    
    return success_response(
        data=CustomerIdResponse(customer_id=customer_id),
        status_code=201,
    )


@router.get(
    "",
    summary="客户列表",
    description="获取当前用户的客户列表，支持按姓名搜索",
    response_description="客户列表",
)
async def get_customer_list(
    keyword: Optional[str] = Query(None, description="搜索关键词（按姓名模糊匹配）"),
    sort_by: Optional[str] = Query("updated_at", description="排序字段（name, updated_at, created_at）"),
    sort_order: Optional[str] = Query("desc", description="排序方向（asc, desc）"),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    summary_status: Optional[str] = Query(None, description="画像状态过滤，逗号分隔，如 stale,failed"),
    stale_contact: bool = Query(False, description="只返回超期未联系客户"),
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    result = await service.get_customer_list(
        user_id=user_id,
        keyword=keyword,
        sort_by=sort_by,
        sort_order=sort_order,
        page=page,
        page_size=page_size,
        summary_status=summary_status,
        stale_contact=stale_contact,
    )
    
    return success_response(data=result)


@router.get(
    "/summary-stats",
    summary="客户摘要统计",
    description="返回待更新画像数、超期未联系客户数、客户总数",
    response_description="摘要统计数据",
)
async def get_summary_stats(
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    result = await service.get_summary_stats(user_id)
    return success_response(data=result)


@router.get(
    "/{customer_id}",
    summary="客户详情",
    description="获取单个客户的详细信息",
    response_description="客户详情",
)
async def get_customer_detail(
    customer_id: str,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """
    获取客户详情
    
    根据客户ID获取详细信息，客户不存在或已删除时返回 404
    """
    customer = await service.get_customer_detail(
        user_id=user_id,
        customer_id=customer_id,
    )
    
    if not customer:
        return not_found_error("客户", customer_id)
    
    return success_response(data=customer)


@router.put(
    "/{customer_id}",
    summary="更新客户",
    description="更新客户的基础资料",
    response_description="更新后的客户详情",
)
async def update_customer(
    customer_id: str,
    data: CustomerUpdate,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """更新客户基础资料"""
    customer = await service.update_customer(
        user_id=user_id,
        customer_id=customer_id,
        data=data,
    )

    if not customer:
        return not_found_error("客户", customer_id)

    return success_response(data=customer)


@router.delete(
    "/{customer_id}",
    summary="删除客户",
    description="软删除客户（更新 deleted_at 字段）",
    response_description="删除成功",
)
async def delete_customer(
    customer_id: str,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """
    删除客户（软删除）
    
    将客户的 deleted_at 字段设置为当前时间，客户不存在或已删除时返回 404
    """
    success = await service.delete_customer(
        user_id=user_id,
        customer_id=customer_id,
    )
    
    if not success:
        return not_found_error("客户", customer_id)
    
    return success_response(data={"message": "删除成功"})


@router.post(
    "/{customer_id}/summary/generate",
    summary="生成客户摘要",
    description="基于客户的沟通记录，调用 LLM 生成客户摘要",
    response_description="摘要生成结果",
)
async def generate_summary(
    customer_id: str,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """
    生成客户摘要
    
    基于该客户的所有沟通记录（records），调用 Kimi LLM 生成一段客户摘要。
    摘要包含：客户基本情况、明确表达的需求/关注点、下一步跟进建议。
    
    状态流转：
    - stale → updating（开始生成）
    - updating → ready（生成成功）
    - updating → failed（生成失败）
    
    生成失败后，保留旧的 summary_text 不清空，可重试。
    """
    result = await service.generate_summary(
        user_id=user_id,
        customer_id=customer_id,
    )
    
    return success_response(data=result)


@router.post(
    "/{customer_id}/chat",
    summary="客户对话",
    description="基于客户摘要和最近沟通记录，回答关于该客户的问题",
    response_description="对话回答",
)
async def chat_with_customer(
    customer_id: str,
    request: CustomerChatRequest,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """
    客户对话
    
    基于客户摘要和最近 3 条沟通记录，回答用户关于该客户的问题。
    
    约束：
    - 只能基于摘要和记录中明确提供的信息回答
    - 如果信息不足，会明确告知"当前记录中没有足够信息"
    - 不会猜测或编造记录中没有的内容
    
    前置条件：客户摘要必须已生成（summary_status == ready）
    """
    result = await service.chat_with_customer(
        user_id=user_id,
        customer_id=customer_id,
        question=request.question,
    )
    
    return success_response(data=result)


@router.post(
    "/{customer_id}/advice/generate",
    summary="生成跟进建议",
    description="基于客户摘要和最近沟通记录，生成结构化的跟进建议",
    response_description="建议生成结果",
)
async def generate_advice(
    customer_id: str,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """
    生成跟进建议
    
    基于客户摘要和最近 5 条沟通记录，生成结构化的跟进建议。
    
    输出包含三部分：
    1. 当前已知情况
    2. 建议下一步动作
    3. 仍缺失的信息
    
    前置条件：客户摘要必须已生成（summary_status == ready）
    """
    result = await service.generate_advice(
        user_id=user_id,
        customer_id=customer_id,
    )
    
    return success_response(data=result)


@router.get(
    "/{customer_id}/advice",
    summary="获取已保存的跟进建议",
    description="读取该客户最近一次生成并保存的跟进建议",
    response_description="已保存的建议",
)
async def get_saved_advice(
    customer_id: str,
    user_id: str = Depends(get_current_user_id),
    service: CustomerService = Depends(get_customer_service),
):
    """获取已保存的跟进建议"""
    result = await service.get_saved_advice(
        user_id=user_id,
        customer_id=customer_id,
    )

    return success_response(data=result)
