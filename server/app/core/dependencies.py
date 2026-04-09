"""
依赖注入定义

FastAPI 依赖注入系统的集中定义，包括：
- 数据库会话
- 当前用户
- 常用服务实例
"""
from typing import AsyncGenerator, Optional

from fastapi import Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.db.session import async_session_factory


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    获取数据库会话依赖
    
    使用 async generator 确保会话正确关闭
    用法: Depends(get_db)
    """
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def get_current_user_id(
    x_user_id: Optional[str] = Header(None),
) -> str:
    """
    获取当前用户 ID
    
    MVP 阶段逻辑：
    - 如果请求头带了 x-user-id，使用请求头的值
    - 否则使用配置的默认用户 ID
    
    后续演进：
    - 从 JWT token 解析用户身份
    - 验证用户权限
    
    Args:
        x_user_id: 请求头中的用户 ID
        
    Returns:
        用户 ID 字符串
    """
    # MVP 阶段：优先使用请求头，否则使用默认用户
    # 注意：生产环境应该从认证 token 中解析
    return x_user_id or settings.default_user_id


# 类型别名，用于路由函数的类型提示
DbSession = Depends(get_db)
CurrentUserId = Depends(get_current_user_id)
