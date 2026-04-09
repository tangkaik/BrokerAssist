"""
沟通记录管理服务

封装沟通记录相关的所有业务逻辑：
- 创建记录
- 查询客户记录列表
- 删除记录
- 关联更新客户 summary_status
"""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import select, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.record import Record
from app.models.customer import Customer
from app.schemas.record import RecordCreate, RecordItem, RecordListResponse


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
        
        # 创建记录实体
        record = Record(
            id=record_id,
            customer_id=data.customer_id,
            content=data.content.strip(),
            type="text",
        )
        
        self.session.add(record)
        
        # 更新客户 summary_status 为 stale
        customer.summary_status = "stale"
        
        await self.session.flush()
        
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
        items = [
            RecordItem(
                id=r.id,
                customer_id=r.customer_id,
                content=r.content,
                type=r.type,
                created_at=r.created_at,
            )
            for r in records
        ]
        
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
        
        # 删除记录
        await self.session.delete(record)
        
        # 更新客户 summary_status 为 stale（因为删除了记录，画像可能需要更新）
        customer.summary_status = "stale"
        
        await self.session.flush()
        
        return True, None
