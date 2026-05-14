"""管理后台 API 路由"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, require_admin
from app.models.user import User
from app.services.admin_service import AdminService
from app.utils.response import error_response, success_response

router = APIRouter(prefix="/admin", tags=["admin"])


def get_admin_service(session: AsyncSession = Depends(get_db)) -> AdminService:
    return AdminService(session)


# --- Stats ---

@router.get("/stats")
async def get_stats(
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.get_stats()
    return success_response(data)


# --- Users ---

@router.get("/users")
async def list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str = Query(""),
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.list_users(page=page, page_size=page_size, search=search)
    return success_response(data)


@router.put("/users/{user_id}/password")
async def reset_user_password(
    user_id: str,
    body: dict,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    new_password = body.get("password")
    if not new_password or len(new_password) < 3:
        return error_response("VALIDATION_ERROR", "密码至少3位", status_code=422)
    try:
        await svc.reset_user_password(user_id, new_password)
        return success_response({"message": "密码已重置"})
    except ValueError as e:
        return error_response("USER_NOT_FOUND", str(e), status_code=404)


@router.put("/users/{user_id}/status")
async def set_user_status(
    user_id: str,
    body: dict,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    disabled = bool(body.get("disabled", False))
    try:
        data = await svc.set_user_status(user_id, disabled)
        return success_response(data)
    except ValueError as e:
        return error_response("USER_NOT_FOUND", str(e), status_code=404)


@router.get("/users/{user_id}/customers")
async def get_user_customers(
    user_id: str,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.get_user_customers(user_id)
    return success_response(data)


# --- Configs ---

@router.get("/configs")
async def get_configs(
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.get_configs()
    return success_response(data)


@router.put("/configs/{key}")
async def upsert_config(
    key: str,
    body: dict,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    value = body.get("value", "")
    data = await svc.upsert_config(key, value)
    return success_response(data)


# --- Industries ---

@router.get("/industries")
async def list_industries(
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.list_industries()
    return success_response(data)


@router.post("/industries")
async def create_industry(
    body: dict,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    key = body.get("key", "").strip()
    label = body.get("label", "").strip()
    role_name = body.get("role_name", "").strip()
    if not key or not label or not role_name:
        return error_response("VALIDATION_ERROR", "key、label、role_name 不能为空", status_code=422)
    try:
        data = await svc.create_industry(key, label, role_name)
        return success_response(data, status_code=201)
    except ValueError as e:
        return error_response("INDUSTRY_EXISTS", str(e), status_code=400)


@router.get("/industries/{key}")
async def get_industry(
    key: str,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    industries = await svc.list_industries()
    match = next((i for i in industries if i["key"] == key), None)
    if not match:
        return error_response("INDUSTRY_NOT_FOUND", "行业不存在", status_code=404)
    return success_response(match)


@router.put("/industries/{key}")
async def update_industry(
    key: str,
    body: dict,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    try:
        data = await svc.update_industry(
            key,
            label=body.get("label"),
            role_name=body.get("role_name"),
            enabled=body.get("enabled"),
        )
        return success_response(data)
    except ValueError as e:
        return error_response("INDUSTRY_NOT_FOUND", str(e), status_code=404)


@router.delete("/industries/{key}")
async def delete_industry(
    key: str,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    try:
        await svc.delete_industry(key)
        return success_response({"message": "已删除"})
    except ValueError as e:
        return error_response("DELETE_FAILED", str(e), status_code=400)


# --- Prompts ---

@router.get("/industries/{key}/prompts")
async def get_industry_prompts(
    key: str,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.get_industry_prompts(key)
    return success_response(data)


@router.put("/industries/{key}/prompts")
async def upsert_industry_prompts(
    key: str,
    body: dict,
    _admin: User = Depends(require_admin),
    svc: AdminService = Depends(get_admin_service),
):
    data = await svc.upsert_industry_prompts(key, body)
    return success_response(data)
