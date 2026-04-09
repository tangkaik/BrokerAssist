"""
数据库会话管理

提供异步数据库引擎和会话工厂
"""
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings

# 异步数据库引擎实例
async_engine: AsyncEngine = create_async_engine(
    settings.database_url,
    echo=settings.debug,  # 调试模式输出 SQL
    future=True,
    pool_pre_ping=True,  # 连接池健康检查
    pool_size=10,
    max_overflow=20,
)

# 异步会话工厂
async_session_factory: async_sessionmaker[AsyncSession] = async_sessionmaker(
    async_engine,
    class_=AsyncSession,
    expire_on_commit=False,  # 提交后不过期对象
    autoflush=False,
    autocommit=False,
)


async def close_db_connections() -> None:
    """
    关闭所有数据库连接
    
    应用关闭时调用
    """
    await async_engine.dispose()
