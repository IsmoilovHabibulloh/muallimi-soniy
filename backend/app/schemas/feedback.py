"""Pydantic schemas for feedback."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from app.utils.validators import validate_phone as _validate_phone


class FeedbackCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=200)
    phone: str = Field(..., min_length=7, max_length=20)
    feedback_type: str = Field(..., pattern="^(taklif|xatolik)$")
    details: str = Field(..., min_length=10, max_length=2000)

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        result = _validate_phone(v)
        if result is None:
            raise ValueError("Telefon raqami noto'g'ri formatda")
        return result


class FeedbackOut(BaseModel):
    id: int
    name: str
    phone: str
    feedback_type: str
    details: str
    telegram_sent: bool
    created_at: datetime

    class Config:
        from_attributes = True
