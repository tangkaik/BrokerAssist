"""
认证路由
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user, get_db
from app.schemas.auth import LoginRequest, RegisterRequest, UserProfile
from app.services.auth_service import AuthService
from app.utils.response import error_response, success_response

router = APIRouter(prefix="/auth", tags=["auth"])


def get_auth_service(session: AsyncSession = Depends(get_db)) -> AuthService:
    return AuthService(session)


@router.post("/register", summary="注册")
async def register(
    data: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
):
    try:
        result = await service.register(data)
    except ValueError as exc:
        return error_response("ACCOUNT_ALREADY_EXISTS", str(exc), status_code=409)
    return success_response(data=result, status_code=201)


@router.post("/login", summary="登录")
async def login(
    data: LoginRequest,
    service: AuthService = Depends(get_auth_service),
):
    try:
        result = await service.login(data)
    except ValueError as exc:
        return error_response("INVALID_CREDENTIALS", str(exc), status_code=401)
    return success_response(data=result)


@router.get("/me", summary="当前用户")
async def me(user=Depends(get_current_user)):
    return success_response(data=UserProfile.model_validate(user))
