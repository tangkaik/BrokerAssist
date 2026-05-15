"""管理后台服务"""
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.config import Config
from app.models.customer import Customer
from app.models.industry import Industry, IndustryPrompt
from app.models.user import User


class AdminService:
    def __init__(self, session: AsyncSession):
        self.session = session

    # --- Stats ---

    async def get_stats(self) -> dict:
        total_users = await self.session.scalar(
            select(func.count(User.id))
        )
        total_customers = await self.session.scalar(
            select(func.count(Customer.id))
        )

        now = datetime.now(timezone.utc)
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        monthly_calls = await self.session.scalar(
            select(func.count()).select_from(text("analytics_events"))
            .where(text("event_name LIKE 'ai_%'"))
            .where(text("created_at >= :start")).params(start=month_start)
        )

        week_ago = now - timedelta(days=7)
        active_users = await self.session.scalar(
            select(func.count(func.distinct(text("user_id"))))
            .select_from(text("analytics_events"))
            .where(text("created_at >= :start")).params(start=week_ago)
        )

        daily_stats = []
        for i in range(29, -1, -1):
            day = now - timedelta(days=i)
            day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
            day_end = day_start + timedelta(days=1)
            daily_calls = await self.session.scalar(
                select(func.count()).select_from(text("analytics_events"))
                .where(text("event_name LIKE 'ai_%'"))
                .where(text("created_at >= :start AND created_at < :end"))
                .params(start=day_start, end=day_end)
            )
            daily_stats.append({"date": day_start.strftime("%Y-%m-%d"), "calls": daily_calls or 0})

        industry_dist = await self.session.execute(
            select(User.industry_key, func.count(User.id))
            .group_by(User.industry_key)
        )
        industry_stats = [{"industry_key": row[0] or "generic", "user_count": row[1]} for row in industry_dist]

        return {
            "total_users": total_users or 0,
            "total_customers": total_customers or 0,
            "monthly_ai_calls": monthly_calls or 0,
            "active_users_7d": active_users or 0,
            "daily_calls": daily_stats,
            "industry_distribution": industry_stats,
        }

    # --- Users ---

    async def list_users(self, page: int = 1, page_size: int = 20, search: str = "") -> dict:
        q = select(User)
        if search:
            q = q.where(
                (User.account.ilike(f"%{search}%")) | (User.name.ilike(f"%{search}%"))
            )

        total = await self.session.scalar(
            select(func.count()).select_from(q.subquery())
        )

        q = q.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        result = await self.session.execute(q)
        users = result.scalars().all()

        user_list = []
        for u in users:
            customer_count = await self.session.scalar(
                select(func.count(Customer.id)).where(Customer.user_id == u.id)
            )
            user_list.append({
                "id": u.id,
                "account": u.account,
                "name": u.name,
                "industry_key": u.industry_key,
                "industry_selected": u.industry_selected,
                "is_admin": u.is_admin,
                "disabled": u.disabled,
                "customer_count": customer_count or 0,
                "created_at": u.created_at.isoformat() if u.created_at else None,
                "updated_at": u.updated_at.isoformat() if u.updated_at else None,
            })

        return {"items": user_list, "total": total or 0, "page": page, "page_size": page_size}

    async def reset_user_password(self, user_id: str, new_password: str) -> None:
        user = await self.session.get(User, user_id)
        if not user:
            raise ValueError("用户不存在")
        user.password_hash = hash_password(new_password)
        await self.session.flush()

    async def set_user_status(self, user_id: str, disabled: bool) -> dict:
        user = await self.session.get(User, user_id)
        if not user:
            raise ValueError("用户不存在")
        user.disabled = disabled
        await self.session.flush()
        await self.session.refresh(user)
        return {"id": user.id, "disabled": user.disabled}

    async def get_user_customers(self, user_id: str) -> list:
        result = await self.session.execute(
            select(Customer).where(Customer.user_id == user_id).order_by(Customer.created_at.desc())
        )
        customers = result.scalars().all()
        return [
            {
                "id": c.id,
                "name": c.name,
                "phone": c.phone,
                "created_at": c.created_at.isoformat() if c.created_at else None,
            }
            for c in customers
        ]

    # --- Configs ---

    async def get_configs(self) -> list[dict]:
        result = await self.session.execute(select(Config).order_by(Config.key))
        configs = result.scalars().all()
        return [
            {"id": c.id, "key": c.key, "value": c.value, "label": c.label, "description": c.description}
            for c in configs
        ]

    async def upsert_config(self, key: str, value: str) -> dict:
        config = await self.session.scalar(select(Config).where(Config.key == key))
        if config:
            config.value = value
        else:
            config = Config(id=str(uuid4()), key=key, value=value, label=key)
            self.session.add(config)
        await self.session.flush()
        await self.session.refresh(config)
        return {"key": config.key, "value": config.value}

    # --- Industries ---

    async def list_industries(self) -> list[dict]:
        result = await self.session.execute(
            select(Industry).order_by(Industry.created_at)
        )
        industries = result.scalars().all()
        return [
            {
                "id": i.id,
                "key": i.key,
                "label": i.label,
                "role_name": i.role_name,
                "enabled": i.enabled,
                "created_at": i.created_at.isoformat() if i.created_at else None,
            }
            for i in industries
        ]

    async def create_industry(self, key: str, label: str, role_name: str) -> dict:
        existing = await self.session.scalar(select(Industry).where(Industry.key == key))
        if existing:
            raise ValueError(f"行业标识 '{key}' 已存在")
        industry = Industry(id=str(uuid4()), key=key, label=label, role_name=role_name)
        self.session.add(industry)
        await self.session.flush()
        await self.session.refresh(industry)
        return {"id": industry.id, "key": industry.key, "label": industry.label, "role_name": industry.role_name, "enabled": industry.enabled}

    async def update_industry(self, key: str, label: str | None, role_name: str | None, enabled: bool | None) -> dict:
        industry = await self.session.scalar(select(Industry).where(Industry.key == key))
        if not industry:
            raise ValueError("行业不存在")
        if label is not None:
            industry.label = label
        if role_name is not None:
            industry.role_name = role_name
        if enabled is not None:
            industry.enabled = enabled
        await self.session.flush()
        await self.session.refresh(industry)
        return {"key": industry.key, "label": industry.label, "role_name": industry.role_name, "enabled": industry.enabled}

    async def delete_industry(self, key: str) -> None:
        if key == "generic":
            raise ValueError("不能删除默认行业")
        industry = await self.session.scalar(select(Industry).where(Industry.key == key))
        if not industry:
            raise ValueError("行业不存在")
        await self.session.delete(industry)
        await self.session.flush()

    # --- Prompts ---

    async def get_industry_prompts(self, industry_key: str) -> list[dict]:
        result = await self.session.execute(
            select(IndustryPrompt).where(IndustryPrompt.industry_key == industry_key).order_by(IndustryPrompt.prompt_field)
        )
        prompts = result.scalars().all()
        return [{"id": p.id, "prompt_field": p.prompt_field, "value": p.value} for p in prompts]

    async def upsert_industry_prompts(self, industry_key: str, prompts: dict[str, str]) -> list[dict]:
        results = []
        for field, value in prompts.items():
            existing = await self.session.scalar(
                select(IndustryPrompt).where(
                    IndustryPrompt.industry_key == industry_key,
                    IndustryPrompt.prompt_field == field,
                )
            )
            if existing:
                existing.value = value
                results.append({"prompt_field": field, "value": value})
            else:
                prompt = IndustryPrompt(
                    id=str(uuid4()),
                    industry_key=industry_key,
                    prompt_field=field,
                    value=value,
                )
                self.session.add(prompt)
                results.append({"prompt_field": field, "value": value})
        await self.session.flush()
        return results
