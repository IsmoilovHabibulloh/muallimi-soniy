"""Feedback submission model."""

import enum

from sqlalchemy import Column, Integer, String, Text, DateTime, Enum, Boolean
from sqlalchemy.sql import func

from app.database import Base


class FeedbackType(str, enum.Enum):
    TAKLIF = "taklif"
    XATOLIK = "xatolik"


class FeedbackSubmission(Base):
    __tablename__ = "feedback_submissions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)
    phone = Column(String(20), nullable=False)
    feedback_type = Column(Enum(FeedbackType), nullable=False)
    details = Column(Text, nullable=False)
    telegram_sent = Column(Boolean, default=False)
    telegram_error = Column(Text, nullable=True)
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
