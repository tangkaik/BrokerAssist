"""管理后台服务。"""
from __future__ import annotations

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.industry_profiles import default_industry_profiles, profile_to_prompt_config
from app.core.security import hash_password
from app.models.customer import Customer
from app.models.industry import Industry
from app.models.user import User
from app.schemas.admin import IndustryCloneRequest, IndustryUpsertRequest


class AdminService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def stats(self) -> dict[str, int]:
        total_users = await self.session.scalar(select(func.count()).select_from(User)) or 0
        total_customers = (
            await self.session.scalar(
                select(func.count()).select_from(Customer).where(Customer.deleted_at.is_(None))
            )
            or 0
        )
        return {"total_users": total_users, "total_customers": total_customers}

    async def users(self, keyword: str = "") -> list[dict]:
        customer_count = func.count(Customer.id).label("customer_count")
        stmt = (
            select(User, customer_count)
            .outerjoin(Customer, (Customer.user_id == User.id) & (Customer.deleted_at.is_(None)))
            .group_by(User.id)
            .order_by(User.created_at.desc())
        )
        if keyword:
            pattern = f"%{keyword}%"
            stmt = stmt.where(or_(User.account.ilike(pattern), User.name.ilike(pattern)))

        rows = (await self.session.execute(stmt)).all()
        return [
            {
                "id": user.id,
                "account": user.account,
                "name": user.name,
                "industry_key": user.industry_key,
                "customer_count": count,
                "created_at": user.created_at,
            }
            for user, count in rows
        ]

    async def user_customers(self, user_id: str) -> list[Customer]:
        return list(
            (
                await self.session.scalars(
                    select(Customer)
                    .where(Customer.user_id == user_id, Customer.deleted_at.is_(None))
                    .order_by(Customer.updated_at.desc())
                )
            ).all()
        )

    async def reset_password(self, user_id: str, password: str) -> None:
        user = await self.session.get(User, user_id)
        if user is None:
            raise ValueError("用户不存在")
        user.password_hash = hash_password(password)
        await self.session.flush()

    async def industries(self) -> list[Industry]:
        await self.ensure_default_industries()
        return list((await self.session.scalars(select(Industry).order_by(Industry.key))).all())

    async def ensure_default_industries(self) -> None:
        changed = False
        for profile in default_industry_profiles():
            existing = await self.session.get(Industry, profile.key)
            if existing:
                default_config = profile_to_prompt_config(profile)
                merged_config = {**default_config, **(existing.prompt_config or {})}
                if merged_config != existing.prompt_config:
                    existing.prompt_config = merged_config
                    changed = True
                continue
            self.session.add(
                Industry(
                    key=profile.key,
                    label=profile.label,
                    role_name=profile.role_name,
                    enabled=True,
                    prompt_config=profile_to_prompt_config(profile),
                )
            )
            changed = True
        if changed:
            await self.session.flush()

    async def create_industry(self, data: IndustryUpsertRequest) -> Industry:
        if await self.session.get(Industry, data.key):
            raise ValueError("行业标识已存在")
        industry = Industry(
            key=data.key,
            label=data.label,
            role_name=data.role_name,
            enabled=data.enabled,
            prompt_config=data.prompt_config.model_dump(),
        )
        self.session.add(industry)
        await self.session.flush()
        await self.session.refresh(industry)
        return industry

    async def update_industry(self, key: str, data: IndustryUpsertRequest) -> Industry:
        industry = await self.session.get(Industry, key)
        if industry is None:
            raise ValueError("行业不存在")
        industry.label = data.label
        industry.role_name = data.role_name
        industry.enabled = True if key == "generic" else data.enabled
        industry.prompt_config = data.prompt_config.model_dump()
        await self.session.flush()
        await self.session.refresh(industry)
        return industry

    async def clone_industry(self, source_key: str, data: IndustryCloneRequest) -> Industry:
        source = await self.session.get(Industry, source_key)
        if source is None:
            raise ValueError("源行业不存在")
        if await self.session.get(Industry, data.key):
            raise ValueError("行业标识已存在")
        industry = Industry(
            key=data.key,
            label=data.label,
            role_name=source.role_name,
            enabled=True,
            prompt_config=dict(source.prompt_config or {}),
        )
        self.session.add(industry)
        await self.session.flush()
        await self.session.refresh(industry)
        return industry

    async def set_industry_enabled(self, key: str, enabled: bool) -> Industry:
        industry = await self.session.get(Industry, key)
        if industry is None:
            raise ValueError("行业不存在")
        if key == "generic" and not enabled:
            raise ValueError("通用行业不能停用")
        industry.enabled = enabled
        await self.session.flush()
        await self.session.refresh(industry)
        return industry
