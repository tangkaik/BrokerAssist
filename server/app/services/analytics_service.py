"""
埋点分析服务层

提供埋点数据的存储、查询、统计和导出功能
"""
import csv
import io
import logging
import uuid
from datetime import datetime, date, timedelta
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path

from sqlalchemy import select, func, and_, desc, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.analytics import AnalyticsEvent, AnalyticsBatch
from app.schemas.analytics import (
    AnalyticsEventCreate,
    AnalyticsBatchCreate,
    ConversionMetric,
    EventTypeMetric,
    DailyMetric,
)

logger = logging.getLogger(__name__)


class AnalyticsService:
    """埋点分析服务"""
    
    def __init__(self, session: AsyncSession):
        self.session = session
    
    # ============== 事件上报 ==============
    
    async def create_event(
        self,
        user_id: str,
        event_data: AnalyticsEventCreate,
        device_id: Optional[str] = None,
        platform: Optional[str] = None,
        app_version: Optional[str] = None
    ) -> AnalyticsEvent:
        """创建单个事件"""
        event = AnalyticsEvent(
            id=str(uuid.uuid4()),
            event_name=event_data.event_name,
            event_time=event_data.event_time or datetime.utcnow(),
            user_id=user_id,
            session_id=event_data.session_id,
            device_id=device_id,
            platform=platform,
            app_version=app_version,
            properties=event_data.properties,
            created_at=datetime.utcnow()
        )
        
        self.session.add(event)
        await self.session.commit()
        
        logger.debug(f"Analytics event created: {event.event_name} for user {user_id}")
        return event
    
    async def create_batch(
        self,
        user_id: str,
        batch_data: AnalyticsBatchCreate
    ) -> Tuple[str, int, int]:
        """批量创建事件"""
        batch_id = str(uuid.uuid4())
        success_count = 0
        failed_count = 0
        
        # 创建批次记录
        batch = AnalyticsBatch(
            id=batch_id,
            user_id=user_id,
            event_count=len(batch_data.events),
            device_id=batch_data.device_id,
            platform=batch_data.platform,
            app_version=batch_data.app_version,
            status="processing",
            received_at=datetime.utcnow()
        )
        self.session.add(batch)
        
        # 批量创建事件
        for event_data in batch_data.events:
            try:
                event = AnalyticsEvent(
                    id=str(uuid.uuid4()),
                    event_name=event_data.event_name,
                    event_time=event_data.event_time or datetime.utcnow(),
                    user_id=user_id,
                    session_id=event_data.session_id,
                    device_id=batch_data.device_id,
                    platform=batch_data.platform,
                    app_version=batch_data.app_version,
                    properties=event_data.properties,
                    created_at=datetime.utcnow()
                )
                self.session.add(event)
                success_count += 1
            except Exception as e:
                logger.error(f"Failed to create analytics event: {e}")
                failed_count += 1
        
        # 更新批次状态
        batch.status = "completed" if failed_count == 0 else "partial"
        batch.processed_at = datetime.utcnow()
        
        await self.session.commit()
        
        logger.info(f"Analytics batch {batch_id}: {success_count} success, {failed_count} failed")
        return batch_id, success_count, failed_count
    
    # ============== 数据查询 ==============
    
    async def query_events(
        self,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        event_name: Optional[str] = None,
        user_id: Optional[str] = None,
        limit: int = 1000,
        offset: int = 0
    ) -> Tuple[List[AnalyticsEvent], int]:
        """查询事件列表"""
        conditions = []
        
        if start_date:
            conditions.append(AnalyticsEvent.event_time >= datetime.combine(start_date, datetime.min.time()))
        if end_date:
            conditions.append(AnalyticsEvent.event_time < datetime.combine(end_date + timedelta(days=1), datetime.min.time()))
        if event_name:
            conditions.append(AnalyticsEvent.event_name == event_name)
        if user_id:
            conditions.append(AnalyticsEvent.user_id == user_id)
        
        # 查询总数
        count_query = select(func.count(AnalyticsEvent.id))
        if conditions:
            count_query = count_query.where(and_(*conditions))
        total_result = await self.session.execute(count_query)
        total = total_result.scalar()
        
        # 查询数据
        query = select(AnalyticsEvent).order_by(desc(AnalyticsEvent.event_time))
        if conditions:
            query = query.where(and_(*conditions))
        query = query.offset(offset).limit(limit)
        
        result = await self.session.execute(query)
        events = result.scalars().all()
        
        return list(events), total
    
    async def get_dashboard_data(
        self,
        start_date: date,
        end_date: date,
        user_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """获取 Dashboard 统计数据"""
        start_dt = datetime.combine(start_date, datetime.min.time())
        end_dt = datetime.combine(end_date + timedelta(days=1), datetime.min.time())
        date_conditions = [
            AnalyticsEvent.event_time >= start_dt,
            AnalyticsEvent.event_time < end_dt
        ]
        
        if user_id:
            date_conditions.append(AnalyticsEvent.user_id == user_id)
        
        # 汇总指标
        summary_query = select(
            func.count(AnalyticsEvent.id).label('total_events'),
            func.count(func.distinct(AnalyticsEvent.user_id)).label('unique_users'),
            func.count(func.distinct(AnalyticsEvent.session_id)).label('unique_sessions')
        ).where(and_(*date_conditions))
        
        summary_result = await self.session.execute(summary_query)
        summary_row = summary_result.fetchone()
        
        summary = {
            'total_events': summary_row.total_events or 0,
            'unique_users': summary_row.unique_users or 0,
            'unique_sessions': summary_row.unique_sessions or 0
        }
        
        # 每日趋势
        daily_query = select(
            func.date(AnalyticsEvent.event_time).label('date'),
            func.count(AnalyticsEvent.id).label('event_count'),
            func.count(func.distinct(AnalyticsEvent.user_id)).label('unique_users')
        ).where(and_(*date_conditions)).group_by(
            func.date(AnalyticsEvent.event_time)
        ).order_by(func.date(AnalyticsEvent.event_time))
        
        daily_result = await self.session.execute(daily_query)
        daily_trend = [
            DailyMetric(
                date=str(row.date),
                event_count=row.event_count,
                unique_users=row.unique_users
            )
            for row in daily_result.fetchall()
        ]
        
        # 事件类型分布
        type_query = select(
            AnalyticsEvent.event_name.label('event_name'),
            func.count(AnalyticsEvent.id).label('count'),
            func.count(func.distinct(AnalyticsEvent.user_id)).label('unique_users')
        ).where(and_(*date_conditions)).group_by(
            AnalyticsEvent.event_name
        ).order_by(desc(func.count(AnalyticsEvent.id)))
        
        type_result = await self.session.execute(type_query)
        event_types = [
            EventTypeMetric(
                event_name=row.event_name,
                count=row.count,
                unique_users=row.unique_users
            )
            for row in type_result.fetchall()
        ]
        
        # 转化指标（针对 result_record_created）
        conversions = await self._get_conversion_metrics(date_conditions)
        
        return {
            'date_range': {
                'start': start_date.isoformat(),
                'end': end_date.isoformat()
            },
            'summary': summary,
            'daily_trend': [m.model_dump() for m in daily_trend],
            'event_types': [m.model_dump() for m in event_types],
            'conversions': [m.model_dump() for m in conversions]
        }
    
    async def _get_conversion_metrics(
        self,
        date_conditions: list
    ) -> List[ConversionMetric]:
        """获取转化指标"""
        # 查询 result_record_created 事件
        query = select(
            AnalyticsEvent.properties
        ).where(
            and_(
                *date_conditions,
                AnalyticsEvent.event_name == 'result_record_created'
            )
        )
        
        result = await self.session.execute(query)
        rows = result.fetchall()
        
        # 按 source + action 分组统计
        stats = {}
        for row in rows:
            props = row.properties or {}
            source = props.get('source', 'unknown')
            action = props.get('customer_action', 'unknown')
            success = props.get('success', False)
            duration = props.get('duration_ms', 0)
            
            key = (source, action)
            if key not in stats:
                stats[key] = {'attempts': 0, 'success': 0, 'durations': []}
            
            stats[key]['attempts'] += 1
            if success:
                stats[key]['success'] += 1
            if duration:
                stats[key]['durations'].append(duration)
        
        # 构建返回结果
        conversions = []
        for (source, action), data in stats.items():
            avg_duration = sum(data['durations']) / len(data['durations']) if data['durations'] else None
            conversions.append(ConversionMetric(
                source=source,
                action=action,
                attempts=data['attempts'],
                success=data['success'],
                success_rate=round(data['success'] / data['attempts'], 4) if data['attempts'] > 0 else 0,
                avg_duration_ms=round(avg_duration, 2) if avg_duration else None
            ))
        
        return conversions
    
    # ============== CSV 导出 ==============
    
    async def export_to_csv(
        self,
        start_date: date,
        end_date: date,
        event_names: Optional[List[str]] = None,
        user_id: Optional[str] = None
    ) -> Tuple[str, int]:
        """
        导出事件数据为 CSV
        
        Returns:
            (CSV内容字符串, 记录数)
        """
        # 查询所有匹配的事件
        conditions = []
        start_dt = datetime.combine(start_date, datetime.min.time())
        end_dt = datetime.combine(end_date + timedelta(days=1), datetime.min.time())
        
        conditions.extend([
            AnalyticsEvent.event_time >= start_dt,
            AnalyticsEvent.event_time < end_dt
        ])
        
        if event_names:
            conditions.append(AnalyticsEvent.event_name.in_(event_names))
        if user_id:
            conditions.append(AnalyticsEvent.user_id == user_id)
        
        query = select(AnalyticsEvent).where(and_(*conditions)).order_by(
            AnalyticsEvent.event_time
        )
        
        result = await self.session.execute(query)
        events = result.scalars().all()
        
        # 生成 CSV
        output = io.StringIO()
        
        # 收集所有可能的属性字段
        all_props = set()
        for event in events:
            if event.properties:
                all_props.update(event.properties.keys())
        
        # 定义基础字段
        base_fields = ['event_id', 'event_name', 'event_time', 'user_id', 'session_id', 
                       'device_id', 'platform', 'app_version']
        prop_fields = sorted([f'prop_{p}' for p in all_props])
        fieldnames = base_fields + prop_fields
        
        # 写入 CSV
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        
        for event in events:
            row = {
                'event_id': event.id,
                'event_name': event.event_name,
                'event_time': event.event_time.isoformat() if event.event_time else '',
                'user_id': event.user_id,
                'session_id': event.session_id or '',
                'device_id': event.device_id or '',
                'platform': event.platform or '',
                'app_version': event.app_version or '',
            }
            
            # 展开属性
            if event.properties:
                for key, value in event.properties.items():
                    if isinstance(value, (dict, list)):
                        import json
                        row[f'prop_{key}'] = json.dumps(value, ensure_ascii=False)
                    else:
                        row[f'prop_{key}'] = str(value) if value is not None else ''
            
            writer.writerow(row)
        
        return output.getvalue(), len(events)
