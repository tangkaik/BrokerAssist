"""管理后台 Schema。"""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field, field_validator


def _clean_lines(values: list[str]) -> list[str]:
    return [str(value).strip() for value in values if str(value).strip()]


class AdminStats(BaseModel):
    total_users: int
    total_customers: int


class AdminUserItem(BaseModel):
    id: str
    account: str
    name: str | None = None
    industry_key: str
    customer_count: int
    created_at: datetime


class AdminCustomerItem(BaseModel):
    id: str
    name: str
    phone: str | None = None
    tags: list[str] = []
    updated_at: datetime

    model_config = {"from_attributes": True}


class PasswordResetRequest(BaseModel):
    password: str = Field(..., min_length=8, max_length=128)


class IndustryPromptConfig(BaseModel):
    summary_focus: list[str] = []
    missing_info: list[str] = []
    advice_focus: str = ""
    forbidden_guidance: list[str] = []
    query_examples: list[str] = []
    assistant_suggestions: list["IndustryAssistantSuggestionGroup"] = []
    app_display: "IndustryAppDisplayConfig" = Field(default_factory=lambda: IndustryAppDisplayConfig())
    reminder_rules: "ReminderRuleConfig" = Field(default_factory=lambda: ReminderRuleConfig())

    @field_validator("summary_focus", "missing_info", "forbidden_guidance", "query_examples")
    @classmethod
    def clean_list(cls, values: list[str]) -> list[str]:
        return _clean_lines(values)

    @field_validator("advice_focus")
    @classmethod
    def clean_text(cls, value: str) -> str:
        return value.strip()


class IndustryAssistantSuggestionGroup(BaseModel):
    key: str = Field(..., min_length=1, max_length=40)
    title: str = Field(..., min_length=1, max_length=80)
    icon: str = "help"
    variants: list[list[str]] = []

    @field_validator("key", "title", "icon")
    @classmethod
    def clean_text(cls, value: str) -> str:
        return value.strip()

    @field_validator("variants")
    @classmethod
    def clean_variants(cls, values: list[list[str]]) -> list[list[str]]:
        cleaned = [_clean_lines(row) for row in values]
        return [row for row in cleaned if row]


class IndustryAppDisplayConfig(BaseModel):
    workspace_label: str = ""
    icon_key: str = "work"
    quick_tip: str = ""

    @field_validator("workspace_label", "icon_key", "quick_tip")
    @classmethod
    def clean_text(cls, value: str) -> str:
        return value.strip()


class ReminderRuleConfig(BaseModel):
    birthday_enabled: bool = True
    festival_enabled: bool = True
    festival_group_title: str = "节日关怀"
    festival_body_template: str = "{festival}还有 {days} 天，建议提前准备客户关怀。"
    key_date_enabled: bool = False
    key_date_keywords: list[str] = []
    key_date_title_template: str = "{customer}关键日期提醒"
    key_date_body_template: str = "{customer} 的关键日期还有 {days} 天，请及时跟进。"
    key_date_group_title: str = "关键日期"
    key_date_source_key: str = "key_date_detected"

    @field_validator("key_date_keywords")
    @classmethod
    def clean_keyword_list(cls, values: list[str]) -> list[str]:
        return _clean_lines(values)

    @field_validator(
        "festival_group_title",
        "festival_body_template",
        "key_date_title_template",
        "key_date_body_template",
        "key_date_group_title",
        "key_date_source_key",
    )
    @classmethod
    def clean_text(cls, value: str) -> str:
        return value.strip()


class IndustryUpsertRequest(BaseModel):
    key: str = Field(..., min_length=2, max_length=40)
    label: str = Field(..., min_length=1, max_length=100)
    role_name: str = Field(..., min_length=1, max_length=100)
    enabled: bool = True
    prompt_config: IndustryPromptConfig

    @field_validator("key")
    @classmethod
    def normalize_key(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("label", "role_name")
    @classmethod
    def clean_required_text(cls, value: str) -> str:
        return value.strip()


class IndustryCloneRequest(BaseModel):
    key: str = Field(..., min_length=2, max_length=40)
    label: str = Field(..., min_length=1, max_length=100)

    @field_validator("key")
    @classmethod
    def normalize_key(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("label")
    @classmethod
    def clean_label(cls, value: str) -> str:
        return value.strip()


class IndustryEnabledRequest(BaseModel):
    enabled: bool


class IndustryItem(BaseModel):
    key: str
    label: str
    role_name: str
    enabled: bool
    prompt_config: IndustryPromptConfig
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
