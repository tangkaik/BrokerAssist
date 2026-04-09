"""
健康检查路由

提供系统健康状态检查接口
"""
from fastapi import APIRouter, status

from app.db.init_db import check_db_health
from app.utils.response import success_response

router = APIRouter(tags=["health"])


@router.get(
    "/health",
    summary="健康检查",
    description="检查 API 服务和依赖组件的健康状态",
    response_description="服务健康状态",
)
async def health_check():
    """
    健康检查接口
    
    返回：
    - 服务运行状态
    - 版本信息
    - 数据库连接状态
    """
    # 检查数据库健康
    db_health = await check_db_health()
    
    health_data = {
        "status": "healthy",
        "service": "broker-assist-api",
        "version": "0.1.0",
        "components": {
            "database": db_health,
        },
    }
    
    return success_response(data=health_data)


@router.get(
    "/health/ping",
    summary="Ping 检查",
    description="简单的存活检查，不依赖外部服务",
    response_description="Pong 响应",
)
async def ping():
    """
    简单存活检查
    
    用于负载均衡健康检查，不查询数据库
    """
    return success_response(data={"message": "pong"})
