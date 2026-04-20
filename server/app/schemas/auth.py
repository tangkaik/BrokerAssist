"""
认证模块 Schema
"""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class RegisterRequest(BaseModel):
    account: str = Field(..., min_length=3, max_length=120, description="登录账号")
    password: str = Field(..., min_length=6, max_length=128, description="密码")
    name: Optional[str] = Field(None, max_length=100, description="昵称")

    @field_validator("account")
    @classmethod
    def normalize_account(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class LoginRequest(BaseModel):
    account: str = Field(..., min_length=3, max_length=120, description="登录账号")
    password: str = Field(..., min_length=6, max_length=128, description="密码")

    @field_validator("account")
    @classmethod
    def normalize_account(cls, value: str) -> str:
        return value.strip().lower()


class UserProfile(BaseModel):
    id: str
    account: str
    name: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AuthResponse(BaseModel):
    token: str
    user: UserProfile
