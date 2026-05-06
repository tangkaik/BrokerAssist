"""
客户管理服务

封装客户相关的所有业务逻辑：
- 创建客户
- 查询客户列表
- 查询客户详情
- 软删除客户
- 生成客户摘要
"""
import logging
import uuid
from datetime import datetime
from typing import Optional, List

from sqlalchemy import case, select, and_, or_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.record import Record
from app.models.user import User
from app.schemas.customer import CustomerCreate, CustomerListItem, CustomerDetail, CustomerListResponse, SummaryGenerateResponse, CustomerChatResponse, AdviceGenerateResponse, CustomerUpdate
from app.ai.kimi_client import KimiClient
from app.core.prompts import (
    customer_summary as _customer_summary_prompt,
    customer_summary_system as _customer_summary_system,
    customer_chat as _customer_chat_prompt,
    customer_chat_system as _customer_chat_system,
    advice as _advice_prompt,
    advice_system as _advice_system,
)
from app.services.customer_advice_store import CustomerAdviceStore

logger = logging.getLogger(__name__)


class CustomerService:
    """
    客户服务类
    
    所有客户相关业务逻辑封装在此类中
    """
    
    def __init__(self, session: AsyncSession):
        """
        初始化服务
        
        Args:
            session: 数据库会话
        """
        self.session = session
        self.advice_store = CustomerAdviceStore()

    async def _get_user_industry_key(self, user_id: str) -> str:
        user = await self.session.get(User, user_id)
        return getattr(user, "industry_key", None) or "generic"
    
    async def create_customer(
        self,
        user_id: str,
        data: CustomerCreate,
    ) -> str:
        """
        创建新客户
        
        Args:
            user_id: 当前用户ID
            data: 创建客户请求数据
            
        Returns:
            新创建客户的ID
        """
        # 生成 UUID
        customer_id = str(uuid.uuid4())

        # 识别地址结构化
        location_normalized = {"location_raw": None, "location_city": None, "location_district": None, "location_subarea": None}
        if data.location:
            from app.services.location_normalizer import LocationNormalizer
            location_normalized = await LocationNormalizer().normalize(data.location)

        # 创建客户实体
        customer = Customer(
            id=customer_id,
            user_id=user_id,
            name=data.name.strip(),
            phone=data.phone.strip() if data.phone else None,
            gender=data.gender.strip() if data.gender else None,
            age=data.age,
            location_raw=location_normalized.get("location_raw"),
            location_city=location_normalized.get("location_city"),
            location_district=location_normalized.get("location_district"),
            location_subarea=location_normalized.get("location_subarea"),
            tags=data.tags if data.tags else [],
            summary_status="stale",
            deleted_at=None,
        )
        
        self.session.add(customer)
        await self.session.flush()
        
        return customer_id
    
    async def get_customer_list(
        self,
        user_id: str,
        keyword: Optional[str] = None,
        sort_by: Optional[str] = "updated_at",
        sort_order: Optional[str] = "desc",
        page: int = 1,
        page_size: int = 20,
        summary_status: Optional[str] = None,
        stale_contact: bool = False,
    ) -> CustomerListResponse:
        """
        获取客户列表
        """
        from sqlalchemy import asc, desc as desc_order, or_
        from app.services.ai_service import STALE_CONTACT_MONTHS, subtract_months

        # 构建基础查询：未删除 + 属于当前用户
        query = select(Customer).where(
            and_(
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        )

        # 画像状态过滤
        if summary_status:
            statuses = [s.strip() for s in summary_status.split(",") if s.strip()]
            if statuses:
                query = query.where(Customer.summary_status.in_(statuses))

        # 超期未联系过滤
        if stale_contact:
            threshold = subtract_months(datetime.now().date(), STALE_CONTACT_MONTHS)
            threshold_dt = datetime(threshold.year, threshold.month, threshold.day)
            latest_sub = (
                select(Record.customer_id, func.max(Record.created_at).label("last_contact"))
                .group_by(Record.customer_id)
                .subquery()
            )
            query = query.outerjoin(
                latest_sub, latest_sub.c.customer_id == Customer.id
            ).where(
                or_(
                    latest_sub.c.last_contact.is_(None),
                    latest_sub.c.last_contact < threshold_dt,
                )
            )

        # 如果有搜索关键词，添加姓名或标签模糊匹配
        if keyword and keyword.strip():
            keyword_clean = keyword.strip()
            # 使用参数化查询避免 SQL 注入（通过 ilike 操作符）
            search_pattern = f"%{keyword_clean}%"
            query = query.where(
                or_(
                    Customer.name.ilike(search_pattern),
                    # JSON array contains 元素匹配（PostgreSQL jsonb）
                    Customer.tags.contains([keyword_clean])
                )
            )
        
        # 排序
        order_func = desc_order if sort_order == "desc" else asc
        if sort_by == "name":
            query = query.order_by(order_func(Customer.name))
        elif sort_by == "created_at":
            query = query.order_by(order_func(Customer.created_at))
        else:
            # 默认按更新时间
            query = query.order_by(order_func(Customer.updated_at))
        
        count_query = select(func.count()).select_from(query.subquery())
        count_result = await self.session.execute(count_query)
        total = count_result.scalar() or 0

        offset = max(page - 1, 0) * page_size
        paged_query = query.offset(offset).limit(page_size)

        result = await self.session.execute(paged_query)
        customers = result.scalars().all()
        
        # 转换为响应 Schema
        items = [
            CustomerListItem(
                id=c.id,
                name=c.name,
                phone=c.phone,
                gender=c.gender,
                age=c.age,
                location_raw=c.location_raw,
                location_city=c.location_city,
                location_district=c.location_district,
                location_subarea=c.location_subarea,
                tags=c.tags,
                updated_at=c.updated_at,
            )
            for c in customers
        ]
        
        return CustomerListResponse(
            items=items,
            total=total,
            page=page,
            page_size=page_size,
        )
    
    async def get_customer_detail(
        self,
        user_id: str,
        customer_id: str,
    ) -> Optional[CustomerDetail]:
        """
        获取客户详情
        
        Args:
            user_id: 当前用户ID
            customer_id: 客户ID
            
        Returns:
            客户详情，如果不存在或已删除则返回 None
        """
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
            return None
        
        return CustomerDetail(
            id=customer.id,
            name=customer.name,
            phone=customer.phone,
            gender=customer.gender,
            age=customer.age,
            location_raw=customer.location_raw,
            location_city=customer.location_city,
            location_district=customer.location_district,
            location_subarea=customer.location_subarea,
            tags=customer.tags,
            summary_text=customer.summary_text,
            summary_status=customer.summary_status,
            created_at=customer.created_at,
            updated_at=customer.updated_at,
        )
    
    async def delete_customer(
        self,
        user_id: str,
        customer_id: str,
    ) -> bool:
        """
        软删除客户
        
        Args:
            user_id: 当前用户ID
            customer_id: 要删除的客户ID
            
        Returns:
            是否删除成功（客户不存在或已删除返回 False）
        """
        # 先查询确认客户存在且未删除
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
        
        # 软删除：更新 deleted_at 字段
        customer.deleted_at = datetime.utcnow()
        await self.session.flush()
        
        return True

    async def update_customer(
        self,
        user_id: str,
        customer_id: str,
        data: CustomerUpdate,
    ) -> Optional[CustomerDetail]:
        """更新客户资料"""
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
            return None

        if data.name is not None:
            customer.name = data.name.strip()
        if data.phone is not None:
            customer.phone = data.phone.strip() or None
        if data.gender is not None:
            customer.gender = data.gender.strip() or None
        if data.age is not None:
            customer.age = data.age
        if data.tags is not None:
            customer.tags = data.tags
        if data.location is not None:
            from app.services.location_normalizer import LocationNormalizer
            normalized = await LocationNormalizer().normalize(data.location)
            customer.location_raw = normalized.get("location_raw")
            customer.location_city = normalized.get("location_city")
            customer.location_district = normalized.get("location_district")
            customer.location_subarea = normalized.get("location_subarea")

        customer.updated_at = datetime.utcnow()
        await self.session.flush()

        return CustomerDetail(
            id=customer.id,
            name=customer.name,
            phone=customer.phone,
            gender=customer.gender,
            age=customer.age,
            location_raw=customer.location_raw,
            location_city=customer.location_city,
            location_district=customer.location_district,
            location_subarea=customer.location_subarea,
            tags=customer.tags,
            summary_text=customer.summary_text,
            summary_status=customer.summary_status,
            created_at=customer.created_at,
            updated_at=customer.updated_at,
        )
    
    async def generate_summary(
        self,
        user_id: str,
        customer_id: str,
    ) -> SummaryGenerateResponse:
        """
        生成客户摘要
        
        基于客户的所有 records，调用 LLM 生成摘要。
        状态流转：stale → updating → ready/failed
        
        Args:
            user_id: 当前用户ID
            customer_id: 客户ID
            
        Returns:
            生成结果
            
        Raises:
            HTTPException: 各种校验失败时抛出
        """
        from fastapi import HTTPException
        
        # 1. 校验客户存在且属于当前用户
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
            raise HTTPException(status_code=404, detail="客户不存在或无权访问")
        
        # 2. 查询该客户的所有 records（按时间正序，从旧到新）
        records_query = select(Record).where(
            Record.customer_id == customer_id
        ).order_by(
            Record.created_at  # 正序排列
        )
        
        result = await self.session.execute(records_query)
        records = list(result.scalars().all())
        
        if not records:
            raise HTTPException(status_code=400, detail="该客户暂无沟通记录，无法生成摘要")
        
        # 3. 过滤低价值流程性记录（只在较短且命中噪音短语时过滤）
        NOISE_PHRASES = ['确认转写', '确认文本', '测试录音', '测试一下', '这是一条测试', '请点击链接']
        MIN_RECORD_LENGTH = 20  # 短记录阈值
        
        filtered_records = []
        for r in records:
            content = r.content or ""
            is_short = len(content) < MIN_RECORD_LENGTH
            has_noise = any(phrase in content for phrase in NOISE_PHRASES)
            # 只有较短且包含噪音短语的才过滤
            if is_short and has_noise:
                continue
            filtered_records.append(r)
        
        # 如果过滤后太少，保留原样
        if len(filtered_records) >= 2:
            records = filtered_records
            logger.info(f"[Summary] Filtered records: {len(records)} remain")
        
        # 4. 准备 records 文本（带序号，便于 LLM 理解演进）
        records_text = "\n---\n".join([
            f"【记录 {i+1} - {r.created_at.strftime('%Y-%m-%d')}】\n{r.content}"
            for i, r in enumerate(records)
        ])
        
        # 5. 更新状态为 updating
        customer.summary_status = "updating"
        await self.session.flush()
        logger.info(f"[Summary] Customer {customer_id} status -> updating, records: {len(records)}")
        
        # 6. 调用 LLM 生成摘要
        industry_key = await self._get_user_industry_key(user_id)
        prompt = _customer_summary_prompt(records_text, industry_key=industry_key)

        try:
            kimi = KimiClient()
            try:
                response = await kimi.chat_simple(
                    prompt=prompt,
                    system_prompt=_customer_summary_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()

            if not response or not response.strip():
                raise ValueError("LLM 返回空摘要")

            summary_text = response.strip()
            
        except Exception as e:
            # 失败处理：更新状态为 failed，保留旧摘要
            logger.error(f"[Summary] Generation failed for customer {customer_id}: {e}")
            customer.summary_status = "failed"
            await self.session.flush()
            
            raise HTTPException(
                status_code=500,
                detail=f"摘要生成失败: {str(e)}"
            )
        
        # 7. 成功：保存新摘要，更新状态为 ready
        now = datetime.now()
        customer.summary_text = summary_text
        customer.summary_status = "ready"
        customer.updated_at = now
        await self.session.flush()
        
        logger.info(f"[Summary] Customer {customer_id} status -> ready")
        
        return SummaryGenerateResponse(
            customer_id=customer_id,
            summary_text=summary_text,
            summary_status="ready",
            records_count=len(records),
            updated_at=now,
        )
    
    async def chat_with_customer(
        self,
        user_id: str,
        customer_id: str,
        question: str,
    ) -> CustomerChatResponse:
        """
        基于客户摘要和最近记录回答问题
        
        Args:
            user_id: 当前用户ID
            customer_id: 客户ID
            question: 用户问题
            
        Returns:
            对话响应
            
        Raises:
            HTTPException: 校验失败或摘要不可用时抛出
        """
        from fastapi import HTTPException
        
        # 1. 校验客户存在且属于当前用户
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
            raise HTTPException(status_code=404, detail="客户不存在或无权访问")
        
        # 2. 查询最近 3 条 records（按时间倒序）
        records_query = select(Record).where(
            Record.customer_id == customer_id
        ).order_by(
            desc(Record.created_at)
        ).limit(3)
        
        result = await self.session.execute(records_query)
        records = result.scalars().all()
        
        # 4. 组装 records 文本（按时间正序，从旧到新）
        records_text = "\n\n".join([
            f"[{r.created_at.strftime('%Y-%m-%d')}] {r.content}"
            for r in reversed(records)
        ])

        summary_ready = bool(customer.summary_text and customer.summary_status == "ready")
        if not summary_ready and not records_text:
            return CustomerChatResponse(
                customer_id=customer_id,
                question=question,
                answer="当前记录中没有足够信息回答此问题。请先添加拜访记录，或生成客户画像后再问。",
            )

        summary_text = customer.summary_text if summary_ready else (
            "客户画像尚未生成。以下回答只能基于最近沟通记录，不代表完整客户画像。"
        )
        
        # 5. 组装 Prompt
        industry_key = await self._get_user_industry_key(user_id)
        prompt = _customer_chat_prompt(
            customer_summary_text=summary_text,
            recent_records_text=records_text,
            question=question,
            industry_key=industry_key,
        )

        # 6. 调用 Kimi 生成回答
        try:
            kimi = KimiClient()
            try:
                answer = await kimi.chat_simple(
                    prompt=prompt,
                    system_prompt=_customer_chat_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
            
            # 校验返回内容
            if not answer or not answer.strip():
                raise HTTPException(status_code=500, detail="AI 返回空回答")
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"[Chat] Kimi API failed for customer {customer_id}: {e}")
            raise HTTPException(status_code=500, detail=f"对话生成失败: {str(e)}")
        
        logger.info(f"[Chat] Customer {customer_id} question answered, length: {len(answer)}")
        
        return CustomerChatResponse(
            customer_id=customer_id,
            question=question,
            answer=answer.strip(),
        )
    
    async def generate_advice(
        self,
        user_id: str,
        customer_id: str,
    ) -> AdviceGenerateResponse:
        """
        基于客户摘要和最近记录生成跟进建议
        
        Args:
            user_id: 当前用户ID
            customer_id: 客户ID
            
        Returns:
            跟进建议响应
            
        Raises:
            HTTPException: 校验失败或摘要不可用时抛出
        """
        from fastapi import HTTPException
        
        # 1. 校验客户存在且属于当前用户
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
            raise HTTPException(status_code=404, detail="客户不存在或无权访问")
        
        # 2. 校验摘要是否可用（必须已生成且状态为 ready）
        if not customer.summary_text or customer.summary_status != "ready":
            raise HTTPException(
                status_code=400, 
                detail="客户摘要尚未生成，请先生成摘要"
            )
        
        # 3. 查询最近 5 条 records（按时间倒序）
        records_query = select(Record).where(
            Record.customer_id == customer_id
        ).order_by(
            desc(Record.created_at)
        ).limit(5)
        
        result = await self.session.execute(records_query)
        records = result.scalars().all()
        
        # 4. 组装 records 文本（按时间正序，从旧到新）
        records_text = "\n\n".join([
            f"[{r.created_at.strftime('%Y-%m-%d')}] {r.content}"
            for r in reversed(records)
        ])
        
        # 5. 组装 Prompt
        industry_key = await self._get_user_industry_key(user_id)
        prompt = _advice_prompt(
            customer_summary_text=customer.summary_text,
            recent_records_text=records_text,
            industry_key=industry_key,
        )

        # 6. 调用 Kimi 生成建议
        try:
            kimi = KimiClient()
            try:
                advice = await kimi.chat_simple(
                    prompt=prompt,
                    system_prompt=_advice_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
            
            # 校验返回内容
            if not advice or not advice.strip():
                raise HTTPException(status_code=500, detail="AI 返回空建议")
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"[Advice] Kimi API failed for customer {customer_id}: {e}")
            raise HTTPException(status_code=500, detail=f"建议生成失败: {str(e)}")
        
        logger.info(f"[Advice] Customer {customer_id} advice generated, length: {len(advice)}")
        
        saved = await self.advice_store.save_advice(
            user_id=user_id,
            customer_id=customer_id,
            advice_text=advice.strip(),
        )

        return AdviceGenerateResponse(
            customer_id=customer_id,
            advice_text=advice.strip(),
            updated_at=datetime.fromisoformat(saved["updated_at"]),
        )

    async def get_saved_advice(
        self,
        user_id: str,
        customer_id: str,
    ) -> Optional[AdviceGenerateResponse]:
        """读取已保存的拜访建议"""
        from fastapi import HTTPException

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
            raise HTTPException(status_code=404, detail="客户不存在或无权访问")

        saved = await self.advice_store.get_advice(user_id=user_id, customer_id=customer_id)
        if not saved:
            return None

        updated_at = None
        if saved.get("updated_at"):
            updated_at = datetime.fromisoformat(saved["updated_at"])

        return AdviceGenerateResponse(
            customer_id=customer_id,
            advice_text=saved.get("advice_text", ""),
            updated_at=updated_at,
        )

    async def get_summary_stats(self, user_id: str) -> dict:
        """首页摘要统计：待更新画像数 + 超期未联系数 + 客户总数。"""
        from datetime import date as date_type
        from app.services.ai_service import STALE_CONTACT_MONTHS, subtract_months

        threshold = subtract_months(datetime.now().date(), STALE_CONTACT_MONTHS)
        threshold_dt = datetime(threshold.year, threshold.month, threshold.day)

        # 总数 + 按状态统计
        total_result = await self.session.execute(
            select(
                func.count(Customer.id),
                func.sum(
                    case(
                        (Customer.summary_status.in_(["stale", "failed"]), 1),
                        else_=0,
                    )
                ),
            ).where(
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None),
            )
        )
        total, stale_summary = total_result.one()
        total = total or 0
        stale_summary = stale_summary or 0

        # 超期未联系：最近一条 record 时间早于阈值 或 无任何记录
        latest_sub = (
            select(
                Record.customer_id,
                func.max(Record.created_at).label("last_contact"),
            )
            .group_by(Record.customer_id)
            .subquery()
        )

        stale_contact_result = await self.session.execute(
            select(func.count(Customer.id))
            .outerjoin(latest_sub, latest_sub.c.customer_id == Customer.id)
            .where(
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None),
                or_(
                    latest_sub.c.last_contact.is_(None),
                    latest_sub.c.last_contact < threshold_dt,
                ),
            )
        )
        stale_contact = stale_contact_result.scalar() or 0

        return {
            "customer_total": total,
            "stale_summary_count": stale_summary,
            "stale_contact_count": stale_contact,
        }
