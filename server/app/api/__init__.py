"""
API 路由注册中心

所有路由模块在此统一注册到 FastAPI 应用
"""
from fastapi import APIRouter, FastAPI

from app.api import auth_routes, health_routes, customer_routes, record_routes, transcription_routes, ai_routes, analytics_routes


def register_routers(app: FastAPI) -> None:
    """
    注册所有 API 路由
    
    Args:
        app: FastAPI 应用实例
    """
    # 创建 v1 版本路由前缀
    api_v1 = APIRouter(prefix="/api/v1")
    
    # ==========================================
    # 健康检查路由（必须最先注册）
    # ==========================================
    api_v1.include_router(health_routes.router)
    api_v1.include_router(auth_routes.router)
    
    # ==========================================
    # MVP 阶段路由（按模块分组）
    # ==========================================
    
    # 客户管理路由
    api_v1.include_router(customer_routes.router)
    
    # 沟通记录路由
    api_v1.include_router(record_routes.router)
    
    # 音频转写路由
    api_v1.include_router(transcription_routes.router)
    
    # AI 服务路由
    api_v1.include_router(ai_routes.router)
    
    # 埋点分析路由
    api_v1.include_router(analytics_routes.router)
    
    # 文件上传路由
    # from app.api import upload_routes
    # api_v1.include_router(upload_routes.router, prefix="/upload", tags=["upload"])
    
    # ==========================================
    # 将 v1 路由注册到主应用
    # ==========================================
    app.include_router(api_v1)
