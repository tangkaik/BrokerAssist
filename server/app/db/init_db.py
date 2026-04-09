"""
数据库初始化

用于：
- 创建所有数据表
- 初始化基础数据
- 执行数据库迁移
"""
import logging

from sqlalchemy import text

from app.db.base import Base
from app.db.session import async_engine

logger = logging.getLogger(__name__)


async def init_db() -> None:
    """
    初始化数据库
    
    创建所有定义在 models 中的表
    注意：生产环境应使用 Alembic 管理迁移
    """
    async with async_engine.begin() as conn:
        # 仅在调试模式下自动建表
        # 生产环境请使用 Alembic
        # await conn.run_sync(Base.metadata.create_all)
        
        # 测试数据库连接
        result = await conn.execute(text("SELECT version()"))
        version = result.scalar()
        logger.info(f"Database connected: {version}")


async def check_db_health() -> dict:
    """
    检查数据库健康状态
    
    Returns:
        健康状态字典
    """
    try:
        async with async_engine.connect() as conn:
            result = await conn.execute(text("SELECT 1"))
            result.scalar()
            return {"status": "healthy", "error": None}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}
