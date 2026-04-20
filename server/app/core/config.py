"""
应用配置管理

使用 Pydantic Settings 从环境变量加载配置
"""
from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """应用配置类"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )
    
    # 应用基础配置
    app_name: str = "BrokerAssist API"
    app_version: str = "0.1.0"
    debug: bool = False
    host: str = "0.0.0.0"
    port: int = 8000
    
    # 数据库配置
    database_url: str = "postgresql+asyncpg://postgres:password@localhost:5432/brokerassist"
    
    # Supabase 配置
    supabase_url: Optional[str] = None
    supabase_key: Optional[str] = None
    supabase_storage_bucket: str = "recordings"
    
    # AI 服务配置 - Kimi
    kimi_api_key: Optional[str] = None
    kimi_base_url: str = "https://api.moonshot.cn"
    kimi_model: str = "moonshot-v1-8k"
    kimi_vision_model: Optional[str] = None

    # AI 服务配置 - 阿里云百炼（图片问答）
    dashscope_api_key: Optional[str] = None
    dashscope_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode"
    dashscope_vl_model: str = "qwen3-vl-flash"
    
    # AI 服务配置 - 讯飞
    xunfei_app_id: Optional[str] = None
    xunfei_api_key: Optional[str] = None
    xunfei_api_secret: Optional[str] = None
    xunfei_base_url: str = "https://api.xfyun.cn/v1"

    # 地图服务配置 - 高德
    gaode_api_key: Optional[str] = None
    gaode_geocode_base_url: str = "https://restapi.amap.com/v3/geocode/geo"
    
    # 安全/MVP 配置
    default_user_id: str = "default-user"
    default_test_account: str = "test@brokerassist.local"
    default_test_password: str = "Test123456"
    default_test_name: str = "测试账号"
    auth_secret_key: str = "brokerassist-dev-secret-change-me"
    auth_token_expire_days: int = 30
    
    # 日志配置
    log_level: str = "INFO"
    cors_allow_origins: str = "*"
    
    @property
    def is_production(self) -> bool:
        """是否为生产环境"""
        return not self.debug

    @property
    def cors_origins(self) -> list[str]:
        """解析逗号分隔的 CORS 来源配置。"""
        if self.cors_allow_origins.strip() == "*":
            return ["*"]
        return [
            origin.strip()
            for origin in self.cors_allow_origins.split(",")
            if origin.strip()
        ] or ["*"]
    
    def validate(self) -> None:
        """启动时检查必填配置"""
        errors = []
        
        if not self.database_url:
            errors.append("DATABASE_URL 必须配置（数据库连接字符串）")
        
        if not self.kimi_api_key:
            errors.append("KIMI_API_KEY 必须配置（Kimi AI API 密钥）")
        
        if errors:
            raise ValueError("配置错误:\n" + "\n".join(f"  - {e}" for e in errors))


@lru_cache()
def get_settings() -> Settings:
    """
    获取应用配置（单例模式）
    
    使用 lru_cache 确保配置只被加载一次
    """
    return Settings()


# 导出配置实例
settings = get_settings()
