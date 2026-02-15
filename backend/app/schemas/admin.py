"""Pydantic schemas for admin auth and system."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AdminLogin(BaseModel):
    username: str = Field(..., min_length=3, max_length=100)
    password: str = Field(..., min_length=6, max_length=200)


class AdminTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class AuditLogOut(BaseModel):
    id: int
    admin_id: Optional[int] = None
    action: str
    entity_type: Optional[str] = None
    entity_id: Optional[int] = None
    details: Optional[dict] = None
    ip_address: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class SystemSettingOut(BaseModel):
    key: str
    value: Optional[str] = None
    updated_at: datetime

    class Config:
        from_attributes = True


class SystemSettingUpdate(BaseModel):
    value: str


class TelegramSettings(BaseModel):
    bot_token: str = Field(..., min_length=10)
    chat_ids: str = Field(..., min_length=1)


class ManifestOut(BaseModel):
    version: int
    book_id: int
    total_pages: int
    total_units: int
    total_segments: int
    published_at: Optional[datetime] = None
    media_base_url: str


class HealthOut(BaseModel):
    status: str = "ok"
    version: str
    environment: str
