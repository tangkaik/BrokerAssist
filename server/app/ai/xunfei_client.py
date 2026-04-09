"""
讯飞语音转写 API 客户端

封装与讯飞语音转写 API 的交互，提供：
- 音频文件转写
- 转写任务管理
- 结果获取

文档: https://www.xfyun.cn/doc/asr/lfasr/API.html
"""
import base64
import hashlib
import hmac
import json
import logging
import time
from datetime import datetime
from typing import Optional, Dict, Any
from urllib.parse import urlencode, urlparse

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class XunfeiClient:
    """
    讯飞语音转写 API 客户端
    
    使用方法:
        client = XunfeiClient()
        task_id = await client.create_task(audio_url)
        result = await client.get_result(task_id)
    """
    
    def __init__(
        self,
        app_id: Optional[str] = None,
        api_key: Optional[str] = None,
        api_secret: Optional[str] = None,
        base_url: Optional[str] = None,
    ):
        """
        初始化客户端
        
        Args:
            app_id: 应用 ID
            api_key: API 密钥
            api_secret: API 密钥
            base_url: API 基础 URL
        """
        self.app_id = app_id or settings.xunfei_app_id
        self.api_key = api_key or settings.xunfei_api_key
        self.api_secret = api_secret or settings.xunfei_api_secret
        self.base_url = base_url or settings.xunfei_base_url
        
        if not all([self.app_id, self.api_key, self.api_secret]):
            logger.warning("Xunfei credentials not fully configured")
        
        self.client = httpx.AsyncClient(timeout=30.0)
    
    def _generate_signature(self, url: str, date: str) -> str:
        """
        生成讯飞 API 签名
        
        Args:
            url: 请求 URL
            date: RFC1123 格式的日期
            
        Returns:
            签名字符串
        """
        parsed_url = urlparse(url)
        signature_origin = f"host: {parsed_url.netloc}\n"
        signature_origin += f"date: {date}\n"
        signature_origin += f"POST {parsed_url.path} HTTP/1.1"
        
        signature_sha = hmac.new(
            self.api_secret.encode('utf-8'),
            signature_origin.encode('utf-8'),
            digestmod=hashlib.sha256
        ).digest()
        
        signature_sha_base64 = base64.b64encode(signature_sha).decode('utf-8')
        
        authorization_origin = f'api_key="{self.api_key}", algorithm="hmac-sha256", '
        authorization_origin += f'headers="host date request-line", '
        authorization_origin += f'signature="{signature_sha_base64}"'
        
        authorization = base64.b64encode(authorization_origin.encode('utf-8')).decode('utf-8')
        
        return authorization
    
    def _get_headers(self, url: str) -> Dict[str, str]:
        """
        获取请求头（包含签名）
        
        Args:
            url: 请求 URL
            
        Returns:
            请求头字典
        """
        date = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')
        authorization = self._generate_signature(url, date)
        
        return {
            "Content-Type": "application/json",
            "Host": urlparse(url).netloc,
            "Date": date,
            "Authorization": authorization,
        }
    
    async def create_task(
        self,
        audio_url: str,
        file_name: Optional[str] = None,
        language: str = "cn",
    ) -> str:
        """
        创建语音转写任务
        
        Args:
            audio_url: 音频文件 URL
            file_name: 文件名
            language: 语言，默认中文
            
        Returns:
            任务 ID
        """
        if not all([self.app_id, self.api_key, self.api_secret]):
            raise RuntimeError("Xunfei credentials not configured")
        
        url = f"{self.base_url}/prepare"
        
        payload = {
            "app_id": self.app_id,
            "signa": "",  # 某些接口需要
            "ts": str(int(time.time())),
            "file_len": "0",  # 文件长度，某些情况需要
            "file_name": file_name or "audio.wav",
            "language": language,
            "url": audio_url,
        }
        
        headers = self._get_headers(url)
        
        try:
            response = await self.client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            if data.get("ok") != 0:
                raise RuntimeError(f"Create task failed: {data}")
            
            return data.get("data")
        except httpx.HTTPError as e:
            logger.error(f"Xunfei create task failed: {e}")
            raise
    
    async def get_result(self, task_id: str) -> Dict[str, Any]:
        """
        获取转写结果
        
        Args:
            task_id: 任务 ID
            
        Returns:
            转写结果
        """
        if not all([self.app_id, self.api_key, self.api_secret]):
            raise RuntimeError("Xunfei credentials not configured")
        
        url = f"{self.base_url}/getResult"
        
        payload = {
            "app_id": self.app_id,
            "signa": "",
            "ts": str(int(time.time())),
            "task_id": task_id,
        }
        
        headers = self._get_headers(url)
        
        try:
            response = await self.client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            return data
        except httpx.HTTPError as e:
            logger.error(f"Xunfei get result failed: {e}")
            raise
    
    async def close(self) -> None:
        """关闭客户端连接"""
        await self.client.aclose()


# 全局客户端实例（可选）
_xunfei_client: Optional[XunfeiClient] = None


def get_xunfei_client() -> XunfeiClient:
    """获取全局讯飞客户端实例"""
    global _xunfei_client
    if _xunfei_client is None:
        _xunfei_client = XunfeiClient()
    return _xunfei_client
