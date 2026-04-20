"""
数据库初始化

用于：
- 创建所有数据表
- 初始化基础数据
- 执行数据库迁移
"""
import logging

from sqlalchemy import text, select

from app.core.config import settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import async_engine, async_session_factory

# 导入所有模型以确保它们被注册
from app.models import User, Customer, Record, Transcription, AnalyticsEvent, AnalyticsBatch

logger = logging.getLogger(__name__)


async def init_db() -> None:
    """
    初始化数据库
    
    创建所有定义在 models 中的表
    注意：生产环境应使用 Alembic 管理迁移
    """
    async with async_engine.begin() as conn:
        # 自动创建所有表（包含新添加的埋点表）
        await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables created/verified")
        
        # 测试数据库连接
        result = await conn.execute(text("SELECT version()"))
        version = result.scalar()
        logger.info(f"Database connected: {version}")

    await ensure_default_test_user()


async def ensure_default_test_user() -> None:
    """
    确保默认测试账号存在。

    该账号复用 default-user 这批历史测试数据，便于持续演示和验证。
    """
    async with async_session_factory() as session:
        existing_user = await session.scalar(
            select(User).where(
                (User.id == settings.default_user_id)
                | (User.account == settings.default_test_account)
            )
        )
        if existing_user:
            updated = False
            if existing_user.id != settings.default_user_id:
                existing_user.id = settings.default_user_id
                updated = True
            if existing_user.account != settings.default_test_account:
                existing_user.account = settings.default_test_account
                updated = True
            if existing_user.name != settings.default_test_name:
                existing_user.name = settings.default_test_name
                updated = True
            if updated:
                await session.commit()
                logger.info("Default test user updated")
            else:
                logger.info("Default test user already exists")
            return

        session.add(
            User(
                id=settings.default_user_id,
                account=settings.default_test_account,
                password_hash=hash_password(settings.default_test_password),
                name=settings.default_test_name,
            )
        )
        await session.commit()
        logger.info("Default test user created")


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
