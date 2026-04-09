"""
讯飞语音转写服务封装

基于用户提供的测试通过代码，封装讯飞语音转写 API：
- 任务创建（上传音频）
- 结果查询
- 签名生成（HMAC-SHA1）

文档参考: 用户提供的 XfyunAsrClient demo
"""
import base64
import hmac
import json
import logging
import random
import re
import string
import time
import urllib.parse
import wave
from datetime import datetime
from io import BytesIO
from typing import Optional, Tuple, Dict, Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# 讯飞 API 基础配置
LFASR_HOST = "https://office-api-ist-dx.iflyaisol.com"
API_UPLOAD = "/v2/upload"
API_GET_RESULT = "/v2/getResult"


class XunfeiService:
    """
    讯飞语音转写服务
    
    封装讯飞 API 的调用细节，适配用户提供的 demo 代码逻辑
    """
    
    def __init__(
        self,
        app_id: Optional[str] = None,
        access_key_id: Optional[str] = None,
        access_key_secret: Optional[str] = None,
    ):
        """
        初始化服务
        
        Args:
            app_id: 讯飞应用 ID (appId)
            access_key_id: 讯飞 API Key (accessKeyId)
            access_key_secret: 讯飞 API Secret (accessKeySecret)
        """
        self.app_id = app_id or settings.xunfei_app_id
        self.access_key_id = access_key_id or settings.xunfei_api_key
        self.access_key_secret = access_key_secret or settings.xunfei_api_secret
        
        if not all([self.app_id, self.access_key_id, self.access_key_secret]):
            logger.warning("Xunfei credentials not fully configured")
        
        # HTTP 客户端
        self.client = httpx.AsyncClient(timeout=60.0, verify=False)
    
    def _generate_random_str(self, length: int = 16) -> str:
        """生成随机字符串"""
        return ''.join(random.choices(string.ascii_letters + string.digits, k=length))
    
    def _get_local_time_with_tz(self) -> str:
        """
        生成带时区偏移的本地时间
        格式：yyyy-MM-dd'T'HH:mm:ss±HHmm
        """
        local_now = datetime.now()
        tz_offset = local_now.astimezone().strftime('%z')  # 输出格式：+0800
        return f"{local_now.strftime('%Y-%m-%dT%H:%M:%S')}{tz_offset}"
    
    def _get_wav_duration_ms(self, audio_data: bytes) -> int:
        """
        从 WAV 音频数据解析时长（毫秒，整数）
        
        使用 io.BytesIO + wave.open 从内存解析，不操作文件系统
        
        原理：时长(毫秒) = 总帧数 / 采样率 * 1000
        
        Args:
            audio_data: WAV 音频文件二进制数据
            
        Returns:
            音频时长（毫秒，整数）
            
        Raises:
            ValueError: 解析失败时抛出清晰错误
        """
        try:
            with wave.open(BytesIO(audio_data), 'rb') as wav_file:
                n_frames = wav_file.getnframes()
                sample_rate = wav_file.getframerate()
                
                if sample_rate == 0:
                    raise ValueError("WAV 文件采样率为 0")
                
                duration_ms = int(round(n_frames / sample_rate * 1000))
                return duration_ms
                
        except wave.Error as e:
            raise ValueError(f"WAV 文件格式错误: {str(e)}")
        except Exception as e:
            raise ValueError(f"解析 WAV 时长失败: {str(e)}")
    
    def _estimate_duration_ms(self, file_size: int, file_name: str) -> int:
        """
        估算非 WAV 音频时长（毫秒）
        
        对于非 WAV 格式，根据文件大小和常见比特率估算
        
        Args:
            file_size: 文件大小（字节）
            file_name: 文件名（用于判断格式）
            
        Returns:
            估算的音频时长（毫秒）
        """
        # 获取文件扩展名
        ext = file_name.lower().split('.')[-1] if '.' in file_name else ''
        
        # 不同格式的平均比特率估算（kbps）
        bitrate_map = {
            'flac': 800,    # 无损压缩
            'mp3': 128,     # 常见 MP3
            'm4a': 128,     # AAC
            'aac': 128,     # AAC
            'ogg': 128,     # Vorbis
            'wma': 128,     # WMA
            'amr': 12,      # 语音专用
        }
        
        bitrate = bitrate_map.get(ext, 128)  # 默认 128kbps
        
        # 计算时长：文件大小(位) / 比特率
        duration_sec = (file_size * 8) / (bitrate * 1000)
        duration_ms = int(duration_sec * 1000)
        
        # 限制范围：最少 1 秒，最多 5 小时
        if duration_ms < 1000:
            duration_ms = 1000
        elif duration_ms > 5 * 60 * 60 * 1000:
            duration_ms = 5 * 60 * 60 * 1000
        
        logger.info(f"Estimated duration for {file_name}: {duration_ms} ms (size: {file_size}, bitrate: {bitrate}kbps)")
        return duration_ms
    
    def _generate_signature(self, params: Dict[str, str]) -> str:
        """
        生成签名
        
        根据讯飞文档要求：
        1. 排除 signature 参数
        2. 按参数名自然排序
        3. 对 key 和 value 都进行 URL encode
        4. HMAC-SHA1 加密 + Base64 编码
        
        Args:
            params: 参数字典
            
        Returns:
            签名字符串
        """
        # 排除 signature 参数，按参数名自然排序
        sign_params = {k: v for k, v in params.items() if k != "signature"}
        sorted_params = sorted(sign_params.items(), key=lambda x: x[0])
        
        # 构建 baseString：对 key 和 value 都进行 URL 编码
        base_parts = []
        for k, v in sorted_params:
            if v is not None and str(v).strip() != "":
                encoded_key = urllib.parse.quote(k, safe='')
                encoded_value = urllib.parse.quote(str(v), safe='')
                base_parts.append(f"{encoded_key}={encoded_value}")
        
        base_string = "&".join(base_parts)
        logger.debug(f"Signature base string: {base_string}")
        
        # HMAC-SHA1 加密 + Base64 编码
        hmac_obj = hmac.new(
            self.access_key_secret.encode("utf-8"),
            base_string.encode("utf-8"),
            digestmod="sha1"
        )
        signature = base64.b64encode(hmac_obj.digest()).decode("utf-8")
        
        return signature
    
    async def upload_and_create_task(
        self,
        audio_data: bytes,
        file_name: str,
    ) -> Tuple[Optional[str], Optional[str]]:
        """
        上传音频并创建转写任务
        
        Args:
            audio_data: 音频文件二进制数据
            file_name: 文件名（必须是 .wav 格式）
            
        Returns:
            (订单ID, 错误信息) - 成功时错误信息为 None
        """
        if not all([self.app_id, self.access_key_id, self.access_key_secret]):
            return None, "讯飞配置未完整设置（请检查 XUNFEI_APP_ID, XUNFEI_API_KEY, XUNFEI_API_SECRET）"
        
        # 准备参数
        file_size = str(len(audio_data))
        date_time = self._get_local_time_with_tz()
        signature_random = self._generate_random_str()
        
        # 根据文件格式选择时长计算方式
        file_name_lower = file_name.lower()
        if file_name_lower.endswith('.wav'):
            # WAV 格式：精确解析，解析失败时抛出错误
            duration_ms = self._get_wav_duration_ms(audio_data)
            logger.info(f"WAV duration parsed: {duration_ms} ms")
        else:
            # 其他格式：估算时长
            duration_ms = self._estimate_duration_ms(len(audio_data), file_name)
            logger.info(f"Estimated duration for non-WAV: {duration_ms} ms")
        
        logger.info(f"Uploading audio: {file_name}, size: {file_size} bytes, duration: {duration_ms} ms")
        
        # 构建 URL 参数
        url_params = {
            "appId": self.app_id,
            "accessKeyId": self.access_key_id,
            "dateTime": date_time,
            "signatureRandom": signature_random,
            "fileSize": file_size,
            "fileName": file_name,
            "language": "autodialect",  # 自动方言识别
            "duration": str(duration_ms),
        }
        
        # 生成签名
        signature = self._generate_signature(url_params)
        
        # 构建请求头
        headers = {
            "Content-Type": "application/octet-stream",
            "signature": signature,
        }
        
        # 构建最终请求 URL
        encoded_params = []
        for k, v in url_params.items():
            encoded_key = urllib.parse.quote(k, safe='')
            encoded_v = urllib.parse.quote(str(v), safe='')
            encoded_params.append(f"{encoded_key}={encoded_v}")
        upload_url = f"{LFASR_HOST}{API_UPLOAD}?{'&'.join(encoded_params)}"
        
        logger.debug(f"Upload URL: {upload_url}")
        
        try:
            # 发送 POST 请求（直接发送音频二进制数据）
            response = await self.client.post(
                url=upload_url,
                headers=headers,
                content=audio_data,
                timeout=30,
            )
            response.raise_for_status()
            
        except httpx.HTTPError as e:
            logger.error(f"Upload request failed: {e}")
            return None, f"上传请求失败: {str(e)}"
        
        # 解析响应
        try:
            result = response.json()
            logger.info(f"Upload response: {result}")
        except json.JSONDecodeError:
            return None, f"API 返回非 JSON 数据: {response.text}"
        
        # 检查 API 业务错误（注意：成功时 code 是字符串 "000000"）
        if result.get("code") != "000000":
            error_msg = result.get("descInfo", "未知错误")
            return None, f"上传失败: {error_msg} (code: {result.get('code')})"
        
        # 获取订单 ID
        order_id = result.get("content", {}).get("orderId")
        if not order_id:
            return None, "未获取到订单 ID"
        
        logger.info(f"Upload success, order ID: {order_id}")
        return order_id, None
    
    async def get_transcribe_result(
        self,
        order_id: str,
        max_retry: int = 60,
        retry_interval: int = 5,
    ) -> Tuple[Optional[str], Optional[str]]:
        """
        查询转写结果（带轮询）
        
        Args:
            order_id: 订单 ID
            max_retry: 最大重试次数
            retry_interval: 每次重试间隔（秒）
            
        Returns:
            (转写文本, 错误信息) - 成功时错误信息为 None
        """
        if not all([self.app_id, self.access_key_id, self.access_key_secret]):
            return None, "讯飞配置未完整设置"
        
        signature_random = self._generate_random_str()
        
        for retry_count in range(max_retry):
            # 构建查询参数
            query_params = {
                "appId": self.app_id,
                "accessKeyId": self.access_key_id,
                "dateTime": self._get_local_time_with_tz(),
                "ts": str(int(time.time())),
                "orderId": order_id,
                "signatureRandom": signature_random,
            }
            
            # 生成查询签名
            query_signature = self._generate_signature(query_params)
            
            # 构建请求头
            query_headers = {
                "Content-Type": "application/json",
                "signature": query_signature,
            }
            
            # 构建查询 URL
            encoded_query_params = []
            for k, v in query_params.items():
                encoded_key = urllib.parse.quote(k, safe='')
                encoded_v = urllib.parse.quote(str(v), safe='')
                encoded_query_params.append(f"{encoded_key}={encoded_v}")
            query_url = f"{LFASR_HOST}{API_GET_RESULT}?{'&'.join(encoded_query_params)}"
            
            try:
                response = await self.client.post(
                    url=query_url,
                    headers=query_headers,
                    json={},  # 空 JSON 请求体
                    timeout=15,
                )
                response.raise_for_status()
                
            except httpx.HTTPError as e:
                logger.error(f"Query request failed: {e}")
                return None, f"查询请求失败: {str(e)}"
            
            # 解析响应
            try:
                result = response.json()
            except json.JSONDecodeError:
                return None, f"查询响应非 JSON 数据: {response.text}"
            
            # 检查 API 错误
            if result.get("code") != "000000":
                error_msg = result.get("descInfo", "未知错误")
                return None, f"查询失败: {error_msg}"
            
            # 检查转写状态
            # 3=处理中，4=完成
            order_info = result.get("content", {}).get("orderInfo", {})
            process_status = order_info.get("status")
            
            if process_status == 4:
                # 转写完成，提取文本
                logger.info(f"Transcription completed for order: {order_id}")
                transcript_text, extract_error = self._extract_text_from_result(result)
                
                if extract_error:
                    # 提取失败，返回错误
                    logger.error(f"Failed to extract text: {extract_error}")
                    return None, f"转写完成但提取文本失败: {extract_error}"
                
                if not transcript_text or not transcript_text.strip():
                    # 文本为空
                    return None, "转写完成但结果为空"
                
                return transcript_text, None
            
            elif process_status == -1:
                # 转写失败，获取详细错误信息
                fail_type = order_info.get("failType", 0)
                error_msg = result.get("descInfo", "未知错误")
                
                # failType 常见值：
                # 1: 文件下载失败
                # 2: 音频解码失败
                # 3: 音频时长超过限制（最长5小时）
                # 4: 服务内部错误
                # 5: 音频格式不支持
                fail_reasons = {
                    1: "文件下载失败（请检查 Storage URL 是否可访问）",
                    2: "音频解码失败（文件可能损坏或格式不支持）",
                    3: "音频时长超过限制（最长5小时）",
                    4: "讯飞服务内部错误",
                    5: "音频格式不支持",
                }
                fail_reason = fail_reasons.get(fail_type, f"未知错误类型({fail_type})")
                
                return None, f"讯飞转写失败: {fail_reason} - {error_msg}"
            
            elif process_status != 3:
                # 其他异常状态
                return None, f"转写异常，状态码: {process_status}"
            
            # 处理中，等待后重试
            logger.info(f"Transcription in progress ({retry_count + 1}/{max_retry}), waiting...")
            await self._sleep(retry_interval)
        
        # 超时
        return None, f"查询超时，已重试 {max_retry} 次"
    
    async def _sleep(self, seconds: int):
        """异步休眠"""
        import asyncio
        await asyncio.sleep(seconds)
    
    def _extract_text_from_result(self, result: Dict[str, Any]) -> Tuple[Optional[str], Optional[str]]:
        """
        从讯飞响应中提取完整转写文本
        
        讯飞返回的结果结构较为复杂，需要根据实际响应解析
        
        Args:
            result: API 响应数据
            
        Returns:
            (转写文本, 错误信息) - 成功时错误信息为 None，失败时返回错误
        """
        try:
            content = result.get("content", {})
            
            # 打印原始返回 JSON 的关键结构（用于调试）
            logger.info(f"Extracting text from result, content keys: {list(content.keys())}")
            logger.info(f"orderInfo: {content.get('orderInfo', {})}")
            
            # 方式1: 直接有 utterances 字段
            utterances = content.get("utterances", [])
            if utterances:
                logger.info(f"Found utterances, count: {len(utterances)}")
                texts = []
                for u in utterances:
                    text = u.get("text", "")
                    if text:
                        texts.append(text)
                full_text = "\n".join(texts)
                if full_text.strip():
                    return full_text, None
                else:
                    return None, "转写结果为空（utterances 中无有效文本）"
            
            # 方式2: 从 orderResult 解析（完整兼容用户 demo）
            order_result_str = content.get("orderResult", "")
            if order_result_str:
                logger.debug(f"Found orderResult, length: {len(order_result_str)}")
                text, error = self._parse_order_result(order_result_str)
                if error:
                    return None, error
                if text and text.strip():
                    return text, None
                else:
                    return None, "转写结果为空（orderResult 解析后无有效文本）"
            
            # 方式3: 直接返回文本
            text = content.get("text", "")
            if text and text.strip():
                return text, None
            
            # 所有方式都未获取到有效文本
            logger.error(f"No text found in result. Available keys: {list(content.keys())}")
            return None, "转写结果为空（未找到有效文本字段）"
            
        except Exception as e:
            logger.error(f"Extract text failed: {e}")
            return None, f"提取文本时发生错误: {str(e)}"
    
    def _parse_order_result(self, order_result_str: str) -> Tuple[Optional[str], Optional[str]]:
        """
        解析 orderResult 字符串，提取所有文本
        
        完全兼容用户提供的 demo 代码逻辑：
        1. 处理转义字符
        2. 解析 orderResult JSON
        3. 遍历 lattice 数组
        4. 提取所有 w 字段
        
        Args:
            order_result_str: orderResult 字符串
            
        Returns:
            (文本, 错误信息)
        """
        try:
            # 1. 处理转义字符问题（demo 代码中的关键步骤）
            # 将双反斜杠替换为单反斜杠（处理过度转义）
            cleaned_str = re.sub(r'\\\\', r'\\', order_result_str)
            
            # 2. 解析 orderResult 字符串为 JSON 对象
            order_result = json.loads(cleaned_str)
            
            logger.info(f"Parsed order_result type: {type(order_result)}, keys: {list(order_result.keys()) if isinstance(order_result, dict) else 'N/A'}")
            
            # 3. 提取所有 w 字段的值
            w_values = []
            
            # 遍历 lattice 数组
            if isinstance(order_result, dict) and 'lattice' in order_result:
                lattice_list = order_result['lattice']
                logger.info(f"Found lattice with {len(lattice_list)} items")
                
                for i, lattice_item in enumerate(lattice_list):
                    if isinstance(lattice_item, dict) and 'json_1best' in lattice_item:
                        json_1best_str = lattice_item['json_1best']
                        
                        try:
                            # 解析 json_1best 字段（也是 JSON 字符串）
                            json_1best = json.loads(json_1best_str)
                            
                            # 处理 st 对象
                            if isinstance(json_1best, dict) and 'st' in json_1best:
                                st_data = json_1best['st']
                                if isinstance(st_data, dict) and 'rt' in st_data:
                                    for rt_item in st_data['rt']:
                                        if isinstance(rt_item, dict) and 'ws' in rt_item:
                                            for ws_item in rt_item['ws']:
                                                if isinstance(ws_item, dict) and 'cw' in ws_item:
                                                    for cw_item in ws_item['cw']:
                                                        if isinstance(cw_item, dict) and 'w' in cw_item:
                                                            w_values.append(cw_item['w'])
                        except json.JSONDecodeError as e:
                            logger.warning(f"Failed to parse json_1best in lattice item {i}: {e}")
                            continue
            else:
                # 可能是直接的列表格式（兼容旧版本）
                if isinstance(order_result, list):
                    logger.info(f"orderResult is a list with {len(order_result)} items, trying legacy parsing")
                    return self._extract_text_from_lattice_legacy(order_result), None
                else:
                    return None, "orderResult 格式不符合预期（缺少 lattice 字段）"
            
            # 拼接所有 w 值
            result_text = ''.join(w_values)
            logger.debug(f"Extracted {len(w_values)} words, text length: {len(result_text)}")
            return result_text, None
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON parse error: {e}, order_result preview: {order_result_str[:200]}")
            return None, f"解析 orderResult JSON 失败: {str(e)}"
        except Exception as e:
            logger.error(f"Parse order result error: {e}")
            return None, f"解析 orderResult 时发生错误: {str(e)}"
    
    async def close(self) -> None:
        """关闭 HTTP 客户端"""
        await self.client.aclose()


# 全局服务实例
_xunfei_service: Optional[XunfeiService] = None


def get_xunfei_service() -> XunfeiService:
    """获取全局讯飞服务实例"""
    global _xunfei_service
    if _xunfei_service is None:
        _xunfei_service = XunfeiService()
    return _xunfei_service
