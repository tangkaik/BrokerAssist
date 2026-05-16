"""数据库行业配置读取服务。"""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.industry_profiles import (
    IndustryProfile,
    default_industry_profiles,
    get_industry_profile_sync,
    profile_from_mapping,
)
from app.models.industry import Industry


async def get_enabled_industry_profiles(session: AsyncSession) -> list[IndustryProfile]:
    rows = (
        await session.scalars(
            select(Industry).where(Industry.enabled.is_(True)).order_by(Industry.key)
        )
    ).all()
    if not rows:
        return default_industry_profiles()
    return [profile_from_mapping(row) for row in rows]


async def get_industry_profile(session: AsyncSession, industry_key: str | None) -> IndustryProfile:
    key = (industry_key or "generic").strip().lower()
    row = await session.get(Industry, key)
    if row:
        return profile_from_mapping(row)
    return get_industry_profile_sync(key)
