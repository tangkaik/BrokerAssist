"""公开行业配置 API。"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_db
from app.services.industry_profile_service import get_enabled_industry_profiles
from app.utils.response import success_response


router = APIRouter(prefix="/industries", tags=["industries"])


@router.get("", summary="可选行业列表")
async def industries(session: AsyncSession = Depends(get_db)):
    profiles = await get_enabled_industry_profiles(session)
    return success_response(
        data={
            "items": [
                {
                    "key": profile.key,
                    "label": profile.label,
                    "role_name": profile.role_name,
                    "assistant_suggestions": [
                        {
                            "key": group.key,
                            "title": group.title,
                            "icon": group.icon,
                            "variants": [list(row) for row in group.variants],
                        }
                        for group in profile.assistant_suggestions
                    ],
                    "app_display": {
                        "workspace_label": profile.app_display.workspace_label,
                        "icon_key": profile.app_display.icon_key,
                        "quick_tip": profile.app_display.quick_tip,
                    },
                    "reminder_rules": {
                        "birthday_enabled": profile.reminder_rules.birthday_enabled,
                        "festival_enabled": profile.reminder_rules.festival_enabled,
                        "festival_group_title": profile.reminder_rules.festival_group_title,
                        "festival_body_template": profile.reminder_rules.festival_body_template,
                        "key_date_enabled": profile.reminder_rules.key_date_enabled,
                        "key_date_keywords": list(profile.reminder_rules.key_date_keywords),
                        "key_date_title_template": profile.reminder_rules.key_date_title_template,
                        "key_date_body_template": profile.reminder_rules.key_date_body_template,
                        "key_date_group_title": profile.reminder_rules.key_date_group_title,
                        "key_date_source_key": profile.reminder_rules.key_date_source_key,
                    },
                }
                for profile in profiles
            ]
        }
    )
