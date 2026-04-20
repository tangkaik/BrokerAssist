"""
认证服务
"""
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password, verify_password
from app.models.user import User
from app.schemas.auth import AuthResponse, LoginRequest, RegisterRequest, UserProfile


class AuthService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def register(self, data: RegisterRequest) -> AuthResponse:
        existing = await self.session.scalar(
            select(User).where(User.account == data.account)
        )
        if existing:
            raise ValueError("该账号已存在")

        user = User(
            id=str(uuid4()),
            account=data.account,
            password_hash=hash_password(data.password),
            name=data.name,
        )
        self.session.add(user)
        await self.session.flush()
        await self.session.refresh(user)
        return self._build_auth_response(user)

    async def login(self, data: LoginRequest) -> AuthResponse:
        user = await self.session.scalar(
            select(User).where(User.account == data.account)
        )
        if not user or not verify_password(data.password, user.password_hash):
            raise ValueError("账号或密码错误")
        return self._build_auth_response(user)

    async def get_user_by_id(self, user_id: str) -> User | None:
        return await self.session.get(User, user_id)

    def _build_auth_response(self, user: User) -> AuthResponse:
        token = create_access_token(user_id=user.id, account=user.account)
        return AuthResponse(
            token=token,
            user=UserProfile.model_validate(user),
        )
