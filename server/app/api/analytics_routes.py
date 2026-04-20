"""
埋点分析 API 路由

提供事件上报、查询、统计和 CSV 导出功能
"""
import io
import logging
from datetime import date, timedelta
from typing import Optional, List

from fastapi import APIRouter, Depends, Query, HTTPException, status
from fastapi.responses import StreamingResponse, PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db, get_current_user_id
from app.schemas.analytics import (
    AnalyticsEventCreate,
    AnalyticsBatchCreate,
    AnalyticsBatchResponse,
    AnalyticsEventResponse,
    AnalyticsListResponse,
    AnalyticsEventItem,
)
from app.services.analytics_service import AnalyticsService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/analytics", tags=["analytics"])

@router.post("/events", response_model=AnalyticsBatchResponse)
async def upload_events(
    request: AnalyticsBatchCreate,
    user_id: str = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_db)
):
    """批量上报埋点事件"""
    try:
        service = AnalyticsService(session)
        batch_id, success_count, failed_count = await service.create_batch(
            user_id=user_id,
            batch_data=request
        )
        
        return AnalyticsBatchResponse(
            success=True,
            batch_id=batch_id,
            processed_count=success_count,
            failed_count=failed_count,
            message=f"Successfully processed {success_count} events"
        )
    except Exception as e:
        logger.error(f"Failed to upload analytics events: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process events: {str(e)}"
        )


@router.post("/events/single", response_model=AnalyticsEventResponse)
async def upload_single_event(
    request: AnalyticsEventCreate,
    device_id: Optional[str] = Query(default=None),
    platform: Optional[str] = Query(default=None),
    app_version: Optional[str] = Query(default=None),
    user_id: str = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_db)
):
    """上报单个埋点事件"""
    try:
        service = AnalyticsService(session)
        event = await service.create_event(
            user_id=user_id,
            event_data=request,
            device_id=device_id,
            platform=platform,
            app_version=app_version
        )
        
        return AnalyticsEventResponse(
            success=True,
            event_id=event.id,
            message="Event created successfully"
        )
    except Exception as e:
        logger.error(f"Failed to create analytics event: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create event: {str(e)}"
        )


@router.get("/events", response_model=AnalyticsListResponse)
async def query_events(
    start_date: Optional[str] = Query(default=None, description="开始日期 YYYY-MM-DD"),
    end_date: Optional[str] = Query(default=None, description="结束日期 YYYY-MM-DD"),
    event_name: Optional[str] = Query(default=None),
    user_id: str = Depends(get_current_user_id),
    limit: int = Query(default=1000, ge=1, le=10000),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_db)
):
    """查询事件列表"""
    try:
        start = date.fromisoformat(start_date) if start_date else None
        end = date.fromisoformat(end_date) if end_date else None
        
        service = AnalyticsService(session)
        events, total = await service.query_events(
            start_date=start,
            end_date=end,
            event_name=event_name,
            user_id=user_id,
            limit=limit,
            offset=offset
        )
        
        return AnalyticsListResponse(
            total=total,
            items=[AnalyticsEventItem.model_validate(e) for e in events],
            limit=limit,
            offset=offset
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid date format: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Failed to query events: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to query events: {str(e)}"
        )


@router.get("/dashboard", response_model=dict)
async def get_dashboard(
    start_date: Optional[str] = Query(default=None, description="开始日期 YYYY-MM-DD"),
    end_date: Optional[str] = Query(default=None, description="结束日期 YYYY-MM-DD"),
    user_id: str = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_db)
):
    """获取 Dashboard 统计数据"""
    try:
        if end_date:
            end = date.fromisoformat(end_date)
        else:
            end = date.today()
        
        if start_date:
            start = date.fromisoformat(start_date)
        else:
            start = end - timedelta(days=6)
        
        service = AnalyticsService(session)
        data = await service.get_dashboard_data(
            start_date=start,
            end_date=end,
            user_id=user_id
        )
        
        return data
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid date format: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Failed to get dashboard: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get dashboard: {str(e)}"
        )


@router.get("/export/csv")
async def export_csv(
    start_date: str = Query(..., description="开始日期 YYYY-MM-DD"),
    end_date: str = Query(..., description="结束日期 YYYY-MM-DD"),
    event_names: Optional[List[str]] = Query(default=None, description="事件名称过滤"),
    user_id: str = Depends(get_current_user_id),
    download: bool = Query(default=True, description="是否作为附件下载"),
    session: AsyncSession = Depends(get_db)
):
    """导出埋点数据为 CSV 文件"""
    try:
        start = date.fromisoformat(start_date)
        end = date.fromisoformat(end_date)
        
        # 限制导出范围（最多90天）
        if (end - start).days > 90:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Date range too large. Maximum 90 days allowed."
            )
        
        service = AnalyticsService(session)
        csv_content, record_count = await service.export_to_csv(
            start_date=start,
            end_date=end,
            event_names=event_names,
            user_id=user_id
        )
        
        # 生成文件名
        filename = f"analytics_{start_date}_{end_date}_{record_count}records.csv"
        
        if download:
            # 作为文件下载
            return StreamingResponse(
                io.BytesIO(csv_content.encode('utf-8-sig')),
                media_type="text/csv; charset=utf-8",
                headers={
                    "Content-Disposition": f"attachment; filename={filename}"
                }
            )
        else:
            # 直接返回文本
            return PlainTextResponse(
                content=csv_content,
                media_type="text/csv; charset=utf-8"
            )
            
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid date format: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Failed to export CSV: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to export CSV: {str(e)}"
        )
