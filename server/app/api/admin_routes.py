"""管理后台 API。"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, require_administrator
from app.schemas.admin import (
    AdminCustomerItem,
    AdminStats,
    AdminUserItem,
    IndustryCloneRequest,
    IndustryEnabledRequest,
    IndustryItem,
    IndustryUpsertRequest,
    PasswordResetRequest,
)
from app.services.admin_service import AdminService
from app.utils.response import error_response, success_response


router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_administrator)],
)


def get_admin_service(session: AsyncSession = Depends(get_db)) -> AdminService:
    return AdminService(session)


@router.get("/stats", summary="管理后台概况")
async def stats(service: AdminService = Depends(get_admin_service)):
    return success_response(data=AdminStats(**await service.stats()))


@router.get("/users", summary="用户列表")
async def users(
    keyword: str = Query("", max_length=120),
    service: AdminService = Depends(get_admin_service),
):
    items = [AdminUserItem(**item) for item in await service.users(keyword.strip())]
    return success_response(data={"items": items})


@router.get("/users/{user_id}/customers", summary="用户客户列表")
async def user_customers(
    user_id: str,
    service: AdminService = Depends(get_admin_service),
):
    items = [AdminCustomerItem.model_validate(item) for item in await service.user_customers(user_id)]
    return success_response(data={"items": items})


@router.put("/users/{user_id}/password", summary="重置用户密码")
async def reset_password(
    user_id: str,
    data: PasswordResetRequest,
    service: AdminService = Depends(get_admin_service),
):
    try:
        await service.reset_password(user_id, data.password)
    except ValueError as exc:
        return error_response("USER_NOT_FOUND", str(exc), status_code=404)
    return success_response(data={"ok": True})


@router.get("/industries", summary="行业列表")
async def industries(service: AdminService = Depends(get_admin_service)):
    items = [IndustryItem.model_validate(item) for item in await service.industries()]
    return success_response(data={"items": items})


@router.post("/industries", summary="新增行业")
async def create_industry(
    data: IndustryUpsertRequest,
    service: AdminService = Depends(get_admin_service),
):
    try:
        industry = await service.create_industry(data)
    except ValueError as exc:
        return error_response("INDUSTRY_EXISTS", str(exc), status_code=409)
    return success_response(data=IndustryItem.model_validate(industry), status_code=201)


@router.put("/industries/{key}", summary="编辑行业")
async def update_industry(
    key: str,
    data: IndustryUpsertRequest,
    service: AdminService = Depends(get_admin_service),
):
    try:
        industry = await service.update_industry(key.strip().lower(), data)
    except ValueError as exc:
        return error_response("INDUSTRY_NOT_FOUND", str(exc), status_code=404)
    return success_response(data=IndustryItem.model_validate(industry))


@router.post("/industries/{key}/clone", summary="复制为新行业")
async def clone_industry(
    key: str,
    data: IndustryCloneRequest,
    service: AdminService = Depends(get_admin_service),
):
    try:
        industry = await service.clone_industry(key.strip().lower(), data)
    except ValueError as exc:
        message = str(exc)
        status_code = 409 if "已存在" in message else 404
        return error_response("INDUSTRY_CLONE_FAILED", message, status_code=status_code)
    return success_response(data=IndustryItem.model_validate(industry), status_code=201)


@router.put("/industries/{key}/enabled", summary="启用或停用行业")
async def set_industry_enabled(
    key: str,
    data: IndustryEnabledRequest,
    service: AdminService = Depends(get_admin_service),
):
    try:
        industry = await service.set_industry_enabled(key.strip().lower(), data.enabled)
    except ValueError as exc:
        return error_response("INDUSTRY_ENABLE_FAILED", str(exc), status_code=400)
    return success_response(data=IndustryItem.model_validate(industry))
