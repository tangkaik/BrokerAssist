"""
Supabase Storage 客户端

封装与 Supabase Storage 的交互，提供：
- 文件上传
- 文件下载
- 文件删除
- 签名 URL 生成

文档: https://supabase.com/docs/reference/python/storage
"""
import logging
import mimetypes
from io import BytesIO
from typing import Optional, BinaryIO, Union
from uuid import uuid4

from supabase import create_client, Client

from app.core.config import settings

logger = logging.getLogger(__name__)


class SupabaseStorage:
    """
    Supabase Storage 客户端封装
    
    使用方法:
        storage = SupabaseStorage()
        url = await storage.upload_file(file_content, "audio.wav")
    """
    
    def __init__(
        self,
        supabase_url: Optional[str] = None,
        supabase_key: Optional[str] = None,
        bucket: Optional[str] = None,
    ):
        """
        初始化 Storage 客户端
        
        Args:
            supabase_url: Supabase 项目 URL
            supabase_key: Supabase 服务密钥
            bucket: 存储桶名称
        """
        self.supabase_url = supabase_url or settings.supabase_url
        self.supabase_key = supabase_key or settings.supabase_key
        self.bucket = bucket or settings.supabase_storage_bucket
        
        if not all([self.supabase_url, self.supabase_key]):
            logger.warning("Supabase credentials not configured")
            self.client: Optional[Client] = None
        else:
            self.client = create_client(self.supabase_url, self.supabase_key)
    
    def _get_storage(self):
        """获取 storage 对象"""
        if not self.client:
            raise RuntimeError("Supabase client not initialized")
        return self.client.storage
    
    def _generate_path(
        self,
        user_id: str,
        file_name: str,
        folder: Optional[str] = None,
    ) -> str:
        """
        生成文件存储路径
        
        格式: {folder}/{user_id}/{uuid}-{safe_filename}
        
        注意：传入的 file_name 应该已经是安全化的（transcription_service 已处理）
        这里只做路径组合，不再处理文件名内容
        """
        import re
        
        unique_id = str(uuid4())[:8]
        
        # 确保文件名中没有路径分隔符（防御性编程）
        safe_filename = file_name.replace("/", "_").replace("\\", "_")
        
        # 组合路径
        if folder:
            path = f"{folder}/{user_id}/{unique_id}-{safe_filename}"
        else:
            path = f"{user_id}/{unique_id}-{safe_filename}"
        
        return path
    
    async def upload_file(
        self,
        file_data: Union[bytes, BinaryIO],
        file_name: str,
        user_id: str,
        folder: Optional[str] = "recordings",
        content_type: Optional[str] = None,
    ) -> str:
        """
        上传文件到 Supabase Storage
        
        Args:
            file_data: 文件数据（bytes 或文件对象）
            file_name: 文件名
            user_id: 用户 ID（用于路径隔离）
            folder: 文件夹名称
            content_type: MIME 类型
            
        Returns:
            文件的公开访问 URL
        """
        storage = self._get_storage()
        
        # 生成存储路径
        path = self._generate_path(user_id, file_name, folder)
        
        # 自动检测 content_type
        if not content_type:
            content_type, _ = mimetypes.guess_type(file_name)
            if not content_type:
                content_type = "application/octet-stream"
        
        # 确保 file_data 是 bytes
        if isinstance(file_data, BytesIO):
            file_data = file_data.read()
        elif hasattr(file_data, 'read'):
            file_data = file_data.read()
        
        try:
            # 上传文件
            result = storage.from_(self.bucket).upload(
                path=path,
                file=file_data,
                file_options={
                    "content-type": content_type,
                    "cache-control": "3600",
                }
            )
            
            # 获取公开 URL
            public_url = storage.from_(self.bucket).get_public_url(path)
            
            logger.info(f"File uploaded: {path}")
            return public_url
            
        except Exception as e:
            logger.error(f"Upload failed: {e}")
            raise
    
    async def upload_from_url(
        self,
        url: str,
        file_name: str,
        user_id: str,
        folder: Optional[str] = "recordings",
    ) -> str:
        """
        从 URL 下载并上传文件
        
        Args:
            url: 源文件 URL
            file_name: 保存的文件名
            user_id: 用户 ID
            folder: 文件夹名称
            
        Returns:
            文件的公开访问 URL
        """
        import httpx
        
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=60.0)
            response.raise_for_status()
            file_data = response.content
        
        return await self.upload_file(
            file_data=file_data,
            file_name=file_name,
            user_id=user_id,
            folder=folder,
        )
    
    async def delete_file(
        self,
        path: str,
    ) -> bool:
        """
        删除文件
        
        Args:
            path: 文件路径
            
        Returns:
            是否删除成功
        """
        storage = self._get_storage()
        
        try:
            storage.from_(self.bucket).remove([path])
            logger.info(f"File deleted: {path}")
            return True
        except Exception as e:
            logger.error(f"Delete failed: {e}")
            return False
    
    async def get_signed_url(
        self,
        path: str,
        expires_in: int = 3600,
    ) -> str:
        """
        获取带签名的临时访问 URL
        
        Args:
            path: 文件路径
            expires_in: 过期时间（秒）
            
        Returns:
            签名 URL
        """
        storage = self._get_storage()
        
        try:
            result = storage.from_(self.bucket).create_signed_url(
                path=path,
                expires_in=expires_in,
            )
            return result.get("signedURL", "")
        except Exception as e:
            logger.error(f"Create signed URL failed: {e}")
            raise
    
    async def list_files(
        self,
        prefix: Optional[str] = None,
        limit: int = 100,
    ) -> list:
        """
        列出文件
        
        Args:
            prefix: 路径前缀
            limit: 返回数量限制
            
        Returns:
            文件列表
        """
        storage = self._get_storage()
        
        try:
            result = storage.from_(self.bucket).list(
                path=prefix or "",
                options={
                    "limit": limit,
                    "offset": 0,
                }
            )
            return result
        except Exception as e:
            logger.error(f"List files failed: {e}")
            raise


# 全局 Storage 实例（可选）
_storage: Optional[SupabaseStorage] = None


def get_storage() -> SupabaseStorage:
    """获取全局 Storage 实例"""
    global _storage
    if _storage is None:
        _storage = SupabaseStorage()
    return _storage
