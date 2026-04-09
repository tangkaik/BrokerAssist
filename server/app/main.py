"""
BrokerAssist API - FastAPI 应用入口

AI 保险经纪人助手后端服务
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import register_routers
from app.core.config import settings
from app.core.logging_config import setup_logging
from app.db.init_db import init_db
from app.db.session import close_db_connections

# 初始化统一日志
setup_logging(settings.log_level)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    应用生命周期管理
    
    启动时：
    - 校验配置
    - 初始化数据库连接
    - 加载必要资源
    
    关闭时：
    - 关闭数据库连接
    - 清理资源
    """
    # ===== 启动 =====
    logger.info(f"Starting {settings.app_name} v{settings.app_version}")
    logger.info(f"Debug mode: {settings.debug}")
    
    # 校验配置（缺少必填项会立即报错）
    try:
        settings.validate()
        logger.info("配置校验通过")
    except ValueError as e:
        logger.error(f"配置校验失败: {e}")
        raise
    
    # 初始化数据库
    await init_db()
    
    yield
    
    # ===== 关闭 =====
    logger.info("Shutting down...")
    await close_db_connections()


def create_application() -> FastAPI:
    """
    创建并配置 FastAPI 应用
    
    Returns:
        配置好的 FastAPI 应用实例
    """
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="AI 保险经纪人助手 API",
        docs_url="/docs" if settings.debug else None,
        redoc_url="/redoc" if settings.debug else None,
        openapi_url="/openapi.json" if settings.debug else None,
        lifespan=lifespan,
    )
    
    # 配置 CORS
    # MVP 阶段允许所有来源，生产环境应限制具体域名
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # TODO: 生产环境配置具体域名
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    
    # 注册所有路由
    register_routers(app)
    
    # 全局异常处理器
    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        """统一业务错误响应格式"""
        return JSONResponse(
            status_code=exc.status_code,
            content={"success": False, "error": {"code": exc.status_code, "message": exc.detail}}
        )
    
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        """兜底异常处理"""
        logger.exception("未处理的异常")
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": {"code": 500, "message": "服务器内部错误"}}
        )
    
    return app


# 创建应用实例
app = create_application()


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level="debug" if settings.debug else "info",
    )
