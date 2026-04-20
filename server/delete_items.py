#!/usr/bin/env python3.11
"""
删除指定客户和记录
"""

import asyncio
import sys

sys.path.insert(0, '/Users/kaitang/Desktop/【保险助手】/BrokerAssist/server')

from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from sqlalchemy import select, delete, and_

async def delete_items():
    async with async_session_factory() as session:
        # 1. 删除客户 "啊啊啊"
        result = await session.execute(
            select(Customer).where(Customer.name == "啊啊啊")
        )
        customer = result.scalar_one_or_none()
        
        if customer:
            # 先删除该客户的所有记录
            await session.execute(
                delete(Record).where(Record.customer_id == customer.id)
            )
            # 删除客户
            await session.delete(customer)
            print(f"✅ 删除客户: 啊啊啊 (ID: {customer.id[:8]}...)")
            print(f"   同时删除了该客户的所有记录")
        else:
            print("⚠️ 未找到客户: 啊啊啊")
        
        # 2. 删除内容为 "测试11223344" 的记录
        result = await session.execute(
            select(Record).where(Record.content == "测试11223344")
        )
        record = result.scalar_one_or_none()
        
        if record:
            await session.delete(record)
            print(f"✅ 删除记录: 测试11223344 (ID: {record.id[:8]}...)")
        else:
            print("⚠️ 未找到记录: 测试11223344")
        
        await session.commit()
        
        # 统计
        result = await session.execute(select(Customer))
        customers = result.scalars().all()
        
        result = await session.execute(select(Record))
        records = result.scalars().all()
        
        print(f"\n📊 当前总数:")
        print(f"   客户: {len(customers)}")
        print(f"   记录: {len(records)}")

if __name__ == "__main__":
    print("═══════════════════════════════")
    print("  删除指定客户和记录")
    print("═══════════════════════════════\n")
    asyncio.run(delete_items())
