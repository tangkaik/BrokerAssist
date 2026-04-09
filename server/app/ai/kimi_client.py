"""
Kimi (Moonshot AI) API 客户端

封装与 Kimi API 的交互，提供：
- 文本对话
- 流式响应
- 错误处理

文档: https://platform.moonshot.cn/docs
"""
import logging
from typing import AsyncGenerator, Optional, List, Dict, Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class KimiMessage:
    """Kimi 消息格式"""
    
    def __init__(self, role: str, content: str):
        self.role = role
        self.content = content
    
    def to_dict(self) -> Dict[str, str]:
        return {"role": self.role, "content": self.content}


class KimiClient:
    """
    Kimi API 客户端
    
    使用方法:
        client = KimiClient()
        response = await client.chat("你好")
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
    ):
        """
        初始化客户端
        
        Args:
            api_key: API 密钥，默认从配置读取
            base_url: API 基础 URL，默认从配置读取
            model: 使用的模型，默认从配置读取
        """
        self.api_key = api_key or settings.kimi_api_key
        self.base_url = base_url or settings.kimi_base_url
        self.model = model or settings.kimi_model
        
        if not self.api_key:
            logger.warning("Kimi API key not configured")
        
        # 创建 HTTP 客户端
        self.client = httpx.AsyncClient(
            base_url=self.base_url,
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            timeout=60.0,
        )
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        stream: bool = False,
    ) -> Dict[str, Any]:
        """
        发送对话请求
        
        Args:
            messages: 消息列表，格式 [{"role": "user", "content": "..."}]
            temperature: 温度参数，控制随机性
            max_tokens: 最大生成 token 数
            stream: 是否流式返回
            
        Returns:
            API 响应数据
        """
        if not self.api_key:
            raise RuntimeError("Kimi API key not configured")
        
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": stream,
        }
        
        if max_tokens:
            payload["max_tokens"] = max_tokens
        
        try:
            response = await self.client.post(
                "/v1/chat/completions",
                json=payload,
            )
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            logger.error(f"Kimi API request failed: {e}")
            raise
    
    async def chat_simple(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
    ) -> str:
        """
        简单对话接口
        
        Args:
            prompt: 用户输入
            system_prompt: 系统提示词
            
        Returns:
            AI 回复文本
        """
        messages = []
        
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        
        messages.append({"role": "user", "content": prompt})
        
        response = await self.chat(messages)
        
        # 提取回复内容
        choices = response.get("choices", [])
        if choices:
            return choices[0].get("message", {}).get("content", "")
        
        return ""
    
    async def stream_chat(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
    ) -> AsyncGenerator[str, None]:
        """
        流式对话接口
        
        Args:
            messages: 消息列表
            temperature: 温度参数
            
        Yields:
            生成的文本片段
        """
        if not self.api_key:
            raise RuntimeError("Kimi API key not configured")
        
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "stream": True,
        }
        
        try:
            async with self.client.stream(
                "POST",
                "/v1/chat/completions",
                json=payload,
            ) as response:
                response.raise_for_status()
                
                async for line in response.aiter_lines():
                    line = line.strip()
                    if line.startswith("data: "):
                        data = line[6:]
                        if data == "[DONE]":
                            break
                        
                        # 解析 SSE 数据
                        import json
                        try:
                            chunk = json.loads(data)
                            delta = chunk.get("choices", [{}])[0].get("delta", {})
                            content = delta.get("content", "")
                            if content:
                                yield content
                        except json.JSONDecodeError:
                            continue
        except httpx.HTTPError as e:
            logger.error(f"Kimi streaming request failed: {e}")
            raise
    
    async def close(self) -> None:
        """关闭客户端连接"""
        await self.client.aclose()


# 全局客户端实例（可选）
_kimi_client: Optional[KimiClient] = None


def get_kimi_client() -> KimiClient:
    """获取全局 Kimi 客户端实例"""
    global _kimi_client
    if _kimi_client is None:
        _kimi_client = KimiClient()
    return _kimi_client
