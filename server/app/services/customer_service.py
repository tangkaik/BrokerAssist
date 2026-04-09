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

from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.customer import Customer
from app.models.record import Record
from app.schemas.customer import CustomerCreate, CustomerListItem, CustomerDetail, CustomerListResponse, SummaryGenerateResponse, CustomerChatResponse, AdviceGenerateResponse
from app.ai.kimi_client import KimiClient

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
        
        # 创建客户实体
        customer = Customer(
            id=customer_id,
            user_id=user_id,
            name=data.name.strip(),
            phone=data.phone.strip() if data.phone else None,
            gender=data.gender.strip() if data.gender else None,
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
    ) -> CustomerListResponse:
        """
        获取客户列表
        
        Args:
            user_id: 当前用户ID
            keyword: 搜索关键词（按姓名模糊匹配）
            
        Returns:
            客户列表响应
        """
        # 构建基础查询：未删除 + 属于当前用户
        query = select(Customer).where(
            and_(
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
        )
        
        # 如果有搜索关键词，添加姓名模糊匹配
        if keyword and keyword.strip():
            keyword_clean = keyword.strip()
            query = query.where(
                Customer.name.ilike(f"%{keyword_clean}%")
            )
        
        # 按更新时间倒序
        query = query.order_by(Customer.updated_at.desc())
        
        # 执行查询
        result = await self.session.execute(query)
        customers = result.scalars().all()
        
        # 转换为响应 Schema
        items = [
            CustomerListItem(
                id=c.id,
                name=c.name,
                phone=c.phone,
                tags=c.tags,
                updated_at=c.updated_at,
            )
            for c in customers
        ]
        
        return CustomerListResponse(
            items=items,
            total=len(items),
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
            tags=customer.tags,
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
        try:
            kimi = KimiClient()
            
            prompt = f"""你是一位资深保险经纪人。请基于以下客户沟通记录，生成一份客户跟进摘要。

沟通记录（按时间顺序）：
{records_text}

【核心任务】
从沟通记录中提取**客户明确提到的**信息，生成摘要。

【输出格式】
只输出以下两类内容：

1. 有明确信息的维度（从以下列表中挑选有信息的输出，无信息的维度**完全不提**）：
   - 客户基本情况：年龄、职业、所在城市等
   - 家庭情况：婚姻、子女、家庭成员等
   - 明确表达的保险需求或意向
   - 顾虑点/异议：担忧、犹豫、明确拒绝的点
   - 已有保单/保障情况
   - 待跟进的具体事项

2. 必须包含的固定部分：
   【当前缺失信息】：为了更好服务客户，还需要了解哪些信息

【绝对约束 - 违反会导致错误】
1. **严禁编造**：如果记录中没有明确提到客户年龄、城市、家庭情况、保险需求等信息，**绝对不要编造**
2. **识别噪音**：如果记录只有"确认转写"、"测试"等系统操作文本，说明**没有实质性沟通内容**
3. **无实质内容时**：直接只输出【当前缺失信息】部分，说明需要收集哪些信息，其他部分**完全省略**
4. 不要把系统操作、转写确认、测试行为当作客户需求来总结

【示例】
场景A - 有实质沟通：
记录："客户说我今年35岁，想了解重疾险"
输出：客户基本情况：35岁\n明确表达的保险需求：想了解重疾险\n【当前缺失信息】：职业、家庭情况、预算等

场景B - 无实质沟通（只有系统操作）：
记录："确认转写文本"、"测试录音"
输出：\n【当前缺失信息】：客户基本情况、家庭情况、保险需求、已有保障等所有信息均需收集

请生成客户跟进摘要："""
            
            response = await kimi.chat_simple(
                prompt=prompt,
                system_prompt="你是一位资深保险经纪人，擅长从沟通记录中提炼客户洞察，识别真实业务信息而非流程操作。"
            )
            
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
        
        # 2. 校验摘要是否可用（必须已生成且状态为 ready）
        if not customer.summary_text or customer.summary_status != "ready":
            raise HTTPException(
                status_code=400, 
                detail="客户摘要尚未生成，请先生成摘要"
            )
        
        # 3. 查询最近 3 条 records（按时间倒序）
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
        
        # 5. 组装 Prompt
        prompt = f"""你是一位保险经纪人助手。请基于以下客户信息回答问题。

【客户摘要】
{customer.summary_text}

【最近沟通记录】
{records_text}

【用户问题】
{question}

约束：
1. 只能基于上述信息回答
2. 如果信息不足，明确说"当前记录中没有足够信息回答此问题"
3. 不要猜测、不要编造记录中没有的内容
4. 回答简洁，控制在200字以内

请回答："""
        
        # 6. 调用 Kimi 生成回答
        try:
            kimi = KimiClient()
            answer = await kimi.chat_simple(
                prompt=prompt,
                system_prompt="你是一个保险经纪人助手，擅长基于客户信息回答问题。"
            )
            
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
        
        # 5. 组装 Prompt（优化版，收紧边界）
        prompt = f"""你是一位资深保险经纪人。请基于以下客户信息，给出跟进建议。

【客户摘要】
{customer.summary_text}

【最近沟通记录】
{records_text}

【角色边界 - 严格遵守】
- 你是"跟进助手"，不是"产品推荐助手"
- 你的任务是告诉经纪人"怎么跟进客户"，不是告诉客户"买什么产品"
- 禁止输出具体产品名称、保额、保费数字、产品组合方案
- 禁止替客户决定买什么

【输出格式 - 三部分】

**当前已知情况**（最多3点，只保留对跟进决策关键的信息）：
- 不要复述所有基础信息
- 只提炼影响下一步跟进策略的关键洞察

**建议下一步动作**（最多3条，具体可执行）：
- 格式：【谁】+【做什么】+【目标】
- 时间描述：如果记录中无明确时间，使用"下次沟通时"或省略，不要编造具体时间
- 优先原则：如果信息不足以支持成交建议，优先给出"先补什么信息"的动作
- 示例：
  * 【经纪人】询问客户【体检报告的具体异常项目】，目标是【判断投保可行性】
  * 【经纪人】准备【家庭收支表】与客户梳理，目标是【明确可接受保费范围】

**当前仍缺失的信息**（最多2-3项，按优先级排序）：
- 只列对成交影响最大的关键信息
- 如果信息严重不足，优先说明需要补充什么信息，而非强行推进

【约束】
- 整体控制在250字以内
- 禁止说"建议购买XX产品""建议选择XX保额"
- 聚焦"如何推进下一步沟通"而非"成交方案"

请输出跟进建议："""
        
        # 6. 调用 Kimi 生成建议
        try:
            kimi = KimiClient()
            advice = await kimi.chat_simple(
                prompt=prompt,
                system_prompt="你是一位资深保险经纪人，擅长基于客户信息给出结构化跟进建议。"
            )
            
            # 校验返回内容
            if not advice or not advice.strip():
                raise HTTPException(status_code=500, detail="AI 返回空建议")
                
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"[Advice] Kimi API failed for customer {customer_id}: {e}")
            raise HTTPException(status_code=500, detail=f"建议生成失败: {str(e)}")
        
        logger.info(f"[Advice] Customer {customer_id} advice generated, length: {len(advice)}")
        
        return AdviceGenerateResponse(
            customer_id=customer_id,
            advice_text=advice.strip(),
        )
