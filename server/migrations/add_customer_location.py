#!/usr/bin/env python3
"""
迁移脚本：为 customers 表添加地址字段
用法: python -m migrations.add_customer_location
"""
import os
import sys

# 确保项目根目录在 path 里
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import asyncio
from sqlalchemy import text


async def migrate():
    DATABASE_URL = os.environ.get("DATABASE_URL")
    if not DATABASE_URL:
        print("ERROR: DATABASE_URL not set")
        return

    # 使用同步引擎做 DDL（CREATE/DROP 不支持 async）
    from sqlalchemy import create_engine
    engine = create_engine(DATABASE_URL, isolation_level="AUTOCOMMIT")

    columns_to_add = [
        ("location_raw", "VARCHAR(255)"),
        ("location_city", "VARCHAR(50)"),
        ("location_district", "VARCHAR(50)"),
        ("location_subarea", "VARCHAR(100)"),
    ]

    with engine.connect() as conn:
        # 检查列是否已存在
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'customers' AND column_name = 'location_raw'
        """))
        if result.fetchone():
            print("字段 location_raw 已存在，跳过迁移")
            return

        for col_name, col_type in columns_to_add:
            sql = f"ALTER TABLE customers ADD COLUMN {col_name} {col_type}"
            print(f"执行: {sql}")
            conn.execute(text(sql))

        print("迁移完成！")

    engine.dispose()


if __name__ == "__main__":
    asyncio.run(migrate())
