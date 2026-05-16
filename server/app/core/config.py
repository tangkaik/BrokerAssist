"""
应用配置管理

使用 Pydantic Settings 从环境变量加载配置
"""
from functools import lru_cache
import secrets
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
    port: int = 8001
    
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
    default_test_account: str = "t1"
    default_test_password: str = "123"
    default_test_name: str = "测试账号"
    auth_secret_key: str = "brokerassist-dev-secret-change-me"
    auth_token_expire_days: int = 30

    # 上传限制
    max_upload_image_count: int = 6
    max_upload_image_bytes: int = 10 * 1024 * 1024
    allowed_image_content_types: str = "image/jpeg,image/png,image/webp,image/heic,image/heif"
    
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

    @property
    def cors_allow_credentials(self) -> bool:
        """当 CORS 为 * 时禁止 credentials，避免浏览器侧无效配置。"""
        return self.cors_origins != ["*"]

    @property
    def allowed_image_types(self) -> set[str]:
        return {
            item.strip().lower()
            for item in self.allowed_image_content_types.split(",")
            if item.strip()
        }

    @property
    def supported_image_types(self) -> set[str]:
        """内置支持的图片类型，避免单纯依赖环境变量导致误拦截。"""
        return {
            "image/jpeg",
            "image/png",
            "image/webp",
            "image/heic",
            "image/heif",
        }
    
    def validate(self) -> None:
        """启动时检查必填配置"""
        errors = []
        
        if not self.database_url:
            errors.append("DATABASE_URL 必须配置（数据库连接字符串）")
        
        if not self.kimi_api_key:
            errors.append("KIMI_API_KEY 必须配置（Kimi AI API 密钥）")

        if self.is_production and self.auth_secret_key == "brokerassist-dev-secret-change-me":
            errors.append("生产环境必须配置 AUTH_SECRET_KEY，不能使用默认开发密钥")

        if self.is_production and len(self.auth_secret_key) < 32:
            errors.append("生产环境的 AUTH_SECRET_KEY 至少需要 32 个字符")

        if self.is_production and self.cors_origins == ["*"]:
            errors.append("生产环境必须配置明确的 CORS_ALLOW_ORIGINS，不能使用 *")

        if self.max_upload_image_count < 1:
            errors.append("MAX_UPLOAD_IMAGE_COUNT 必须大于 0")

        if self.max_upload_image_bytes < 1024:
            errors.append("MAX_UPLOAD_IMAGE_BYTES 必须至少为 1024")
        
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


def generate_secret_key(length: int = 48) -> str:
    """生成可用于 AUTH_SECRET_KEY 的随机密钥。"""
    return secrets.token_urlsafe(length)
