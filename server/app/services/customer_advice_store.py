"""
客户拜访建议存储（已迁移到数据库）

直接从 customers 表的 advice_text / advice_updated_at 字段读写。
保留此类作为兼容层，后续可逐步移除。
"""
from datetime import datetime
from typing import Optional

from sqlalchemy import select
from app.db.session import async_session_factory
from app.models.customer import Customer


class CustomerAdviceStore:
    """客户拜访建议存储（数据库版）"""

    async def get_advice(self, user_id: str, customer_id: str) -> Optional[dict]:
        async with async_session_factory() as session:
            result = await session.execute(
                select(Customer).where(
                    Customer.id == customer_id,
                    Customer.user_id == user_id,
                    Customer.deleted_at.is_(None),
                )
            )
            c = result.scalar_one_or_none()
            if not c or not c.advice_text:
                return None
            return {
                "customer_id": customer_id,
                "advice_text": c.advice_text,
                "updated_at": c.advice_updated_at.isoformat() if c.advice_updated_at else None,
            }

    async def save_advice(self, user_id: str, customer_id: str, advice_text: str) -> dict:
        now = datetime.utcnow()
        async with async_session_factory() as session:
            result = await session.execute(
                select(Customer).where(
                    Customer.id == customer_id,
                    Customer.user_id == user_id,
                    Customer.deleted_at.is_(None),
                )
            )
            c = result.scalar_one_or_none()
            if c:
                c.advice_text = advice_text
                c.advice_updated_at = now
                await session.commit()

        return {
            "customer_id": customer_id,
            "advice_text": advice_text,
            "updated_at": now.isoformat(),
        }
