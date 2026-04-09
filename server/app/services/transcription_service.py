"""
音频转写任务管理服务

封装转写任务相关的所有业务逻辑：
- 上传音频到 Supabase Storage
- 创建转写任务
- 调用讯飞转写
- 保存转写结果
- 确认转写结果并生成 record

状态流转：
    pending -> transcribing -> transcribed -> confirmed
                     |           
                     +-> failed
"""
import logging
import os
import re
import uuid
from typing import Optional, Tuple

from sqlalchemy import select, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

from app.models.transcription import Transcription
from app.models.customer import Customer
from app.models.record import Record
from app.schemas.transcription import (
    TranscriptionUploadResponse,
    TranscriptionConfirmResponse,
    TranscriptionItem,
    TranscriptionListResponse,
)
from app.services.xunfei_service import XunfeiService
from app.services.record_service import RecordService
from app.storage.supabase_storage import SupabaseStorage
from app.schemas.record import RecordCreate


class TranscriptionService:
    """
    音频转写任务服务类
    
    核心设计：
    1. 先创建 DB 记录（status=pending），再执行后续操作
    2. 任何失败都更新 DB 状态并记录错误
    3. 返回统一结构，transcription_id 始终有值
    4. 分离原始文件名（展示）和安全文件名（存储）
    """
    
    # 支持的音频格式白名单
    ALLOWED_AUDIO_FORMATS = {'.wav', '.mp3', '.m4a', '.aac', '.ogg', '.amr', '.flac'}
    # 最大文件大小：500MB
    MAX_FILE_SIZE = 500 * 1024 * 1024
    
    def __init__(
        self,
        session: AsyncSession,
        storage: Optional[SupabaseStorage] = None,
        xunfei: Optional[XunfeiService] = None,
    ):
        self.session = session
        self.storage = storage or SupabaseStorage()
        self.xunfei = xunfei or XunfeiService()
    
    def _sanitize_filename(self, file_name: str) -> str:
        """
        生成安全文件名（用于 Storage）
        
        规则：
        1. 只允许 ASCII 字母、数字、下划线
        2. 中文、空格、特殊字符全部转为下划线
        3. 压缩连续下划线，去除首尾下划线
        4. 空值兜底为 'audio'
        5. 保留原始扩展名（转小写）
        6. 添加随机前缀避免重名
        """
        # 1. 去除路径，保留文件名
        base_name = os.path.basename(file_name)
        
        # 2. 分离扩展名
        if '.' in base_name:
            name_part, ext = base_name.rsplit('.', 1)
            ext = '.' + ext.lower()
        else:
            name_part = base_name
            ext = '.wav'
        
        # 3. 随机前缀（确保唯一性）
        random_prefix = uuid.uuid4().hex[:8]
        
        # 4. 处理名称部分：只保留 ASCII 字母数字，其他全部转为下划线
        # [^A-Za-z0-9]+ 匹配一个或多个非字母数字字符
        safe_name = re.sub(r'[^A-Za-z0-9]+', '_', name_part)
        
        # 5. 去除首尾下划线
        safe_name = safe_name.strip('_')
        
        # 6. 如果结果为空，使用默认值
        if not safe_name:
            safe_name = 'audio'
        
        # 7. 截断（保留前 20 字符）
        safe_name = safe_name[:20]
        
        # 8. 组合并确保总长度不超过 50
        result = f"{random_prefix}_{safe_name}{ext}"
        if len(result) > 50:
            result = f"{random_prefix}_audio{ext}"
        
        return result
    
    def _validate_audio_file(self, file_name: str, file_size: int) -> Tuple[bool, str]:
        """校验音频文件格式和大小"""
        if file_size > self.MAX_FILE_SIZE:
            return False, f"文件大小超过限制（最大 {self.MAX_FILE_SIZE // 1024 // 1024}MB）"
        
        if file_size == 0:
            return False, "文件不能为空"
        
        file_ext = file_name.lower()
        if not any(file_ext.endswith(fmt) for fmt in self.ALLOWED_AUDIO_FORMATS):
            allowed = ', '.join(sorted(self.ALLOWED_AUDIO_FORMATS))
            return False, f"不支持的音频格式，请上传: {allowed}"
        
        return True, ""
    
    async def _verify_customer_access(
        self, user_id: str, customer_id: str
    ) -> Optional[Customer]:
        """验证客户是否属于当前用户"""
        query = select(Customer).where(
            and_(
                Customer.id == customer_id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        )
        result = await self.session.execute(query)
        return result.scalar_one_or_none()
    
    async def upload_and_transcribe(
        self,
        user_id: str,
        customer_id: str,
        file_content: bytes,
        file_name: str,
        file_size: int,
    ) -> TranscriptionUploadResponse:
        """
        上传音频并执行转写
        
        执行顺序（关键：先 DB 后操作）：
        1. 校验客户权限
        2. 校验文件
        3. 生成安全文件名
        4. 【创建 DB 记录】status=pending
        5. 上传 Storage
        6. 更新 DB status=transcribing
        7. 调用讯飞转写
        8. 更新 DB 最终结果
        
        任何步骤失败：更新 DB status=failed，记录 error_message
        """
        transcription: Optional[Transcription] = None
        transcription_id = str(uuid.uuid4())
        
        try:
            # ========== 步骤 1: 校验客户权限 ==========
            customer = await self._verify_customer_access(user_id, customer_id)
            if not customer:
                # 早期失败：无 DB 记录，直接返回
                return TranscriptionUploadResponse(
                    transcription_id="",
                    status="failed",
                    original_name=file_name,
                    transcript_text=None,
                    error_message="[客户校验]客户不存在或无权访问",
                )
            
            # ========== 步骤 2: 校验文件 ==========
            is_valid, error_msg = self._validate_audio_file(file_name, file_size)
            if not is_valid:
                return TranscriptionUploadResponse(
                    transcription_id="",
                    status="failed",
                    original_name=file_name,
                    transcript_text=None,
                    error_message=f"[文件校验]{error_msg}",
                )
            
            # ========== 步骤 3: 准备文件名 ==========
            original_name = file_name  # 保留原始文件名
            safe_file_name = self._sanitize_filename(file_name)
            logger.info(f"Filename: original='{original_name}', safe='{safe_file_name}'")
            
            # ========== 步骤 4: 创建 DB 记录（关键：先持久化）==========
            transcription = Transcription(
                id=transcription_id,
                customer_id=customer_id,
                original_name=original_name,
                file_name=safe_file_name,
                file_path="",  # 临时，上传后更新
                file_size=file_size,
                status="pending",  # 初始状态
                transcript_text=None,
                error_message=None,
                record_id=None,
            )
            self.session.add(transcription)
            await self.session.flush()
            logger.info(f"[DB] Created transcription {transcription_id} with status=pending")
            
            # ========== 步骤 5: 上传 Storage ==========
            try:
                file_url = await self.storage.upload_file(
                    file_data=file_content,
                    file_name=safe_file_name,
                    user_id=user_id,
                    folder="transcriptions",
                    content_type="audio/wav",
                )
                # 更新路径
                transcription.file_path = file_url
                await self.session.flush()
                logger.info(f"[Storage] Uploaded to {file_url}")
            except Exception as e:
                error_detail = f"[存储上传]{str(e)}"
                logger.error(error_detail)
                transcription.status = "failed"
                transcription.error_message = error_detail
                await self.session.flush()
                return TranscriptionUploadResponse(
                    transcription_id=transcription_id,
                    status="failed",
                    original_name=original_name,
                    transcript_text=None,
                    error_message=error_detail,
                )
            
            # ========== 步骤 6: 更新状态为转写中 ==========
            transcription.status = "transcribing"
            await self.session.flush()
            logger.info(f"[DB] Updated status to transcribing")
            
            # ========== 步骤 7: 调用讯飞创建任务 ==========
            order_id, error = await self.xunfei.upload_and_create_task(
                audio_data=file_content,
                file_name=safe_file_name,
            )
            
            if error:
                error_detail = f"[讯飞创建]{error}"
                logger.error(error_detail)
                transcription.status = "failed"
                transcription.error_message = error_detail
                await self.session.flush()
                return TranscriptionUploadResponse(
                    transcription_id=transcription_id,
                    status="failed",
                    original_name=original_name,
                    transcript_text=None,
                    error_message=error_detail,
                )
            
            # ========== 步骤 8: 轮询获取结果 ==========
            logger.info(f"[Xunfei] Waiting for result, order_id={order_id}")
            transcript_text, error = await self.xunfei.get_transcribe_result(
                order_id=order_id,
                max_retry=60,
                retry_interval=5,
            )
            
            if error:
                error_detail = f"[讯飞轮询]{error}"
                logger.error(error_detail)
                transcription.status = "failed"
                transcription.error_message = error_detail
                await self.session.flush()
                return TranscriptionUploadResponse(
                    transcription_id=transcription_id,
                    status="failed",
                    original_name=original_name,
                    transcript_text=None,
                    error_message=error_detail,
                )
            
            # 检查结果是否为空
            if not transcript_text or not transcript_text.strip():
                error_detail = "[结果解析]转写结果为空"
                logger.error(error_detail)
                transcription.status = "failed"
                transcription.error_message = error_detail
                await self.session.flush()
                return TranscriptionUploadResponse(
                    transcription_id=transcription_id,
                    status="failed",
                    original_name=original_name,
                    transcript_text=None,
                    error_message=error_detail,
                )
            
            # ========== 步骤 9: 成功，更新状态 ==========
            transcription.status = "transcribed"
            transcription.transcript_text = transcript_text
            await self.session.flush()
            logger.info(f"[DB] Updated status to transcribed, text length={len(transcript_text)}")
            
            return TranscriptionUploadResponse(
                transcription_id=transcription_id,
                status="transcribed",
                original_name=original_name,
                transcript_text=transcript_text,
                error_message=None,
            )
            
        except Exception as e:
            # 兜底：捕获所有未处理异常
            error_detail = f"[系统异常]{str(e)}"
            logger.exception(error_detail)
            
            if transcription:
                transcription.status = "failed"
                transcription.error_message = error_detail
                await self.session.flush()
                return TranscriptionUploadResponse(
                    transcription_id=transcription_id,
                    status="failed",
                    original_name=original_name if 'original_name' in locals() else file_name,
                    transcript_text=None,
                    error_message=error_detail,
                )
            else:
                # DB 记录都没创建成功
                return TranscriptionUploadResponse(
                    transcription_id="",
                    status="failed",
                    original_name=file_name,
                    transcript_text=None,
                    error_message=error_detail,
                )
    
    async def confirm_transcription(
        self,
        user_id: str,
        transcription_id: str,
        content: str,
    ) -> TranscriptionConfirmResponse:
        """
        确认转写结果并保存为 record
        
        严格状态校验：
        - 只允许 status = transcribed 时确认
        - confirmed: 拒绝，提示"已确认"
        - pending/transcribing: 拒绝，提示"处理中，请等待"
        - failed: 拒绝，提示"转写失败，当前不可确认"
        """
        from fastapi import HTTPException
        
        # 1. 查询转写任务
        query = select(Transcription).where(
            Transcription.id == transcription_id
        )
        result = await self.session.execute(query)
        transcription = result.scalar_one_or_none()
        
        if not transcription:
            raise HTTPException(status_code=404, detail="转写任务不存在")
        
        # 2. 验证权限
        customer = await self._verify_customer_access(user_id, transcription.customer_id)
        if not customer:
            raise HTTPException(status_code=403, detail="无权访问此转写任务")
        
        # 3. 严格状态校验
        if transcription.status == "confirmed":
            raise HTTPException(status_code=400, detail="该转写任务已确认")
        elif transcription.status == "pending":
            raise HTTPException(status_code=400, detail="处理中，请等待")
        elif transcription.status == "transcribing":
            raise HTTPException(status_code=400, detail="处理中，请等待")
        elif transcription.status == "failed":
            raise HTTPException(status_code=400, detail="转写失败，当前不可确认")
        elif transcription.status != "transcribed":
            raise HTTPException(status_code=400, detail=f"当前状态不支持确认: {transcription.status}")
        
        # 4. 复用 RecordService 创建 record
        record_service = RecordService(self.session)
        record_id, error = await record_service.create_record(
            user_id=user_id,
            data=RecordCreate(
                customer_id=transcription.customer_id,
                content=content.strip(),
            )
        )
        
        if error:
            raise HTTPException(status_code=500, detail=f"创建记录失败: {error}")
        
        # 5. 更新转写任务
        transcription.status = "confirmed"
        transcription.transcript_text = content.strip()
        transcription.record_id = record_id
        await self.session.flush()
        
        logger.info(f"[Confirm] Transcription {transcription_id} confirmed, record {record_id} created")
        
        return TranscriptionConfirmResponse(
            transcription_id=transcription_id,
            record_id=record_id,
            status="confirmed",
            confirmed_text=content.strip(),
        )
    
    async def get_customer_transcriptions(
        self, user_id: str, customer_id: str, limit: int = 50
    ) -> TranscriptionListResponse:
        """获取客户的转写任务列表"""
        customer = await self._verify_customer_access(user_id, customer_id)
        if not customer:
            return TranscriptionListResponse(items=[], total=0)
        
        query = select(Transcription).where(
            Transcription.customer_id == customer_id
        ).order_by(
            desc(Transcription.created_at)
        ).limit(limit)
        
        result = await self.session.execute(query)
        transcriptions = result.scalars().all()
        
        items = [
            TranscriptionItem(
                id=t.id,
                customer_id=t.customer_id,
                original_name=t.original_name,
                file_size=t.file_size,
                status=t.status,
                transcript_text=t.transcript_text,
                created_at=t.created_at,
            )
            for t in transcriptions
        ]
        
        return TranscriptionListResponse(items=items, total=len(items))
    
    async def get_transcription_detail(
        self, user_id: str, transcription_id: str
    ) -> Tuple[Optional[Transcription], Optional[str]]:
        """获取转写任务详情"""
        query = select(Transcription, Customer).join(
            Customer,
            and_(
                Transcription.customer_id == Customer.id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        ).where(Transcription.id == transcription_id)
        
        result = await self.session.execute(query)
        row = result.one_or_none()
        
        if not row:
            return None, "转写任务不存在或无权访问"
        
        transcription, _ = row
        return transcription, None
