"""
沟通记录管理服务

封装沟通记录相关的所有业务逻辑：
- 创建记录
- 创建带图片的记录
- 查询客户记录列表
- 删除记录
- 关联更新客户 summary_status
"""
import uuid
from typing import Optional

from sqlalchemy import select, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.record import Record
from app.models.customer import Customer
from app.schemas.record import (
    RecordCreate,
    RecordListResponse,
    RecordItem,
    RecordUpdate,
)
from app.services.location_normalizer import LocationNormalizer
from app.services.record_media_service import RecordMediaService


class RecordService:
    """
    沟通记录服务类
    
    所有沟通记录相关业务逻辑封装在此类中
    """
    
    def __init__(self, session: AsyncSession):
        """
        初始化服务
        
        Args:
            session: 数据库会话
        """
        self.session = session
        self.media_service = RecordMediaService()
        self.location_normalizer = LocationNormalizer()
    
    async def _update_customer_summary_status(
        self,
        customer_id: str,
        user_id: str,
    ) -> bool:
        """
        更新客户 summary_status 为 stale
        
        在创建新记录后调用，标记客户画像需要更新
        
        Args:
            customer_id: 客户ID
            user_id: 用户ID（用于权限验证）
            
        Returns:
            是否更新成功
        """
        # 查询客户（确保属于当前用户且未删除）
        query = select(Customer).where(
            and_(
                Customer.id == customer_id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        )
        
        result = await self.session.execute(query)
        customer = result.scalar_one_or_none()
        
        if not customer:
            return False
        
        # 更新 summary_status
        customer.summary_status = "stale"
        await self.session.flush()
        
        return True
    
    async def create_record(
        self,
        user_id: str,
        data: RecordCreate,
    ) -> tuple[Optional[str], Optional[str]]:
        """
        创建新沟通记录
        
        创建记录后自动更新客户的 summary_status 为 stale
        
        Args:
            user_id: 当前用户ID
            data: 创建记录请求数据
            
        Returns:
            (记录ID, 错误信息) - 成功时错误信息为 None
        """
        # 验证客户是否存在且属于当前用户
        customer_query = select(Customer).where(
            and_(
                Customer.id == data.customer_id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        )
        
        result = await self.session.execute(customer_query)
        customer = result.scalar_one_or_none()
        
        if not customer:
            return None, "客户不存在或无权访问"
        
        # 生成 UUID
        record_id = str(uuid.uuid4())
        location = await self.location_normalizer.normalize(data.location_raw)
        
        # 创建记录实体
        record = Record(
            id=record_id,
            customer_id=data.customer_id,
            content=data.content.strip(),
            type="text",
            location_raw=location["location_raw"],
            location_city=location["location_city"],
            location_district=location["location_district"],
            location_subarea=location["location_subarea"],
        )
        
        self.session.add(record)
        
        # 更新客户 summary_status 为 stale
        customer.summary_status = "stale"
        
        await self.session.flush()
        
        return record_id, None

    async def create_record_with_images(
        self,
        *,
        user_id: str,
        customer_id: str,
        content: str,
        location_raw: str | None,
        images: list[tuple[str, bytes, Optional[str]]],
    ) -> tuple[Optional[str], Optional[str]]:
        """创建带图片的记录"""
        record_id, error = await self.create_record(
            user_id=user_id,
            data=RecordCreate(customer_id=customer_id, content=content, location_raw=location_raw),
        )

        if error or not record_id:
            return None, error

        if images:
            await self.media_service.save_images(
                user_id=user_id,
                customer_id=customer_id,
                record_id=record_id,
                files=images,
                session=self.session,
            )

        return record_id, None
    
    async def get_customer_records(
        self,
        user_id: str,
        customer_id: str,
        limit: int = 50,
    ) -> RecordListResponse:
        """
        获取客户的沟通记录列表
        
        Args:
            user_id: 当前用户ID
            customer_id: 客户ID
            limit: 返回记录数量限制，默认50
            
        Returns:
            记录列表响应
        """
        # 首先验证客户是否存在且属于当前用户
        customer_query = select(Customer).where(
            and_(
                Customer.id == customer_id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        )
        
        result = await self.session.execute(customer_query)
        customer = result.scalar_one_or_none()
        
        if not customer:
            # 客户不存在，返回空列表
            return RecordListResponse(items=[], total=0)
        
        # 查询该客户的记录，按时间倒序
        query = select(Record).where(
            Record.customer_id == customer_id
        ).order_by(
            desc(Record.created_at)
        ).limit(limit)
        
        result = await self.session.execute(query)
        records = result.scalars().all()
        
        # 转换为响应 Schema
        items = [await self.media_service.build_record_item(record) for record in records]
        
        return RecordListResponse(
            items=items,
            total=len(items),
        )
    
    async def delete_record(
        self,
        user_id: str,
        record_id: str,
    ) -> tuple[bool, Optional[str]]:
        """
        删除沟通记录
        
        删除记录前验证记录所属客户是否属于当前用户
        
        Args:
            user_id: 当前用户ID
            record_id: 要删除的记录ID
            
        Returns:
            (是否成功, 错误信息) - 成功时错误信息为 None
        """
        # 查询记录及其关联客户
        query = select(Record, Customer).join(
            Customer,
            and_(
                Record.customer_id == Customer.id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        ).where(
            Record.id == record_id
        )
        
        result = await self.session.execute(query)
        row = result.one_or_none()
        
        if not row:
            return False, "记录不存在或无权访问"
        
        record, customer = row

        await self.media_service.delete_record_assets(record_id)
        # 删除记录
        await self.session.delete(record)
        
        # 更新客户 summary_status 为 stale（因为删除了记录，画像可能需要更新）
        customer.summary_status = "stale"
        
        await self.session.flush()
        
        return True, None

    async def update_record_with_images(
        self,
        *,
        user_id: str,
        record_id: str,
        content: str,
        location_raw: str | None,
        keep_image_urls: list[str],
        new_images: list[tuple[str, bytes, Optional[str]]],
    ) -> tuple[Optional[RecordItem], Optional[str]]:
        """更新记录内容，并同步处理图片增删"""
        query = select(Record, Customer).join(
            Customer,
            and_(
                Record.customer_id == Customer.id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        ).where(
            Record.id == record_id
        )

        result = await self.session.execute(query)
        row = result.one_or_none()

        if not row:
            return None, "记录不存在或无权访问"

        record, customer = row
        location = await self.location_normalizer.normalize(location_raw)
        record.content = content.strip()
        record.location_raw = location["location_raw"]
        record.location_city = location["location_city"]
        record.location_district = location["location_district"]
        record.location_subarea = location["location_subarea"]
        customer.summary_status = "stale"

        images = await self.media_service.replace_images(
            user_id=user_id,
            customer_id=record.customer_id,
            record_id=record_id,
            keep_urls=keep_image_urls,
            new_files=new_images,
            session=self.session,
        )

        await self.session.flush()

        return await self.media_service.build_record_item(record, images=images), None

    async def update_record(
        self,
        *,
        user_id: str,
        record_id: str,
        data: RecordUpdate,
    ) -> tuple[Optional[RecordItem], Optional[str]]:
        """更新纯文本记录，不涉及图片变更。"""
        query = select(Record, Customer).join(
            Customer,
            and_(
                Record.customer_id == Customer.id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        ).where(
            Record.id == record_id
        )

        result = await self.session.execute(query)
        row = result.one_or_none()

        if not row:
            return None, "记录不存在或无权访问"

        record, customer = row
        record.content = data.content.strip()
        if data.location_raw is not None:
            location = await self.location_normalizer.normalize(data.location_raw)
            record.location_raw = location["location_raw"]
            record.location_city = location["location_city"]
            record.location_district = location["location_district"]
            record.location_subarea = location["location_subarea"]
        customer.summary_status = "stale"

        await self.session.flush()

        return await self.media_service.build_record_item(record), None

    async def analyze_record_image(
        self,
        *,
        user_id: str,
        record_id: str,
        image_url: str,
        analyze_modes: list[str] | None = None,
    ) -> tuple[dict | None, str | None]:
        query = select(Record, Customer).join(
            Customer,
            and_(
                Record.customer_id == Customer.id,
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        ).where(
            Record.id == record_id
        )

        result = await self.session.execute(query)
        row = result.one_or_none()
        if not row:
            return None, "记录不存在或无权访问"

        record, _customer = row
        return await self.media_service.analyze_record_image(
            record_id=record.id,
            image_url=image_url,
            analyze_modes=analyze_modes,
        )
