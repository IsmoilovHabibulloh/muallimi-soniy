"""Page section models for lesson sectioning engine."""

import enum
from datetime import datetime

from sqlalchemy import (
    Column, Integer, String, Text, Float, Boolean,
    DateTime, ForeignKey, Enum, JSON
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class SectionType(str, enum.Enum):
    OPENING_SENTENCE = "opening_sentence"
    ALPHABET_GRID = "alphabet_grid"
    LETTER_INTRODUCTION = "letter_introduction"
    LETTER_DRILL = "letter_drill"
    WORD_DRILL = "word_drill"
    DIVIDER = "divider"
    GENERIC = "generic"


class Section(Base):
    __tablename__ = "sections"

    id = Column(Integer, primary_key=True, index=True)
    page_id = Column(Integer, ForeignKey("pages.id", ondelete="CASCADE"), nullable=False)
    section_type = Column(Enum(SectionType), nullable=False, default=SectionType.GENERIC)
    target_letter = Column(String(10), nullable=True)
    title_ar = Column(String(300), nullable=True)
    title_uz = Column(String(300), nullable=True)
    sort_order = Column(Integer, default=0)
    is_manual = Column(Boolean, default=False)
    unit_ids = Column(JSON, nullable=False, default=list)  # Ordered list of text_unit IDs
    bbox_y_start = Column(Float, nullable=True)  # Top boundary (% of page)
    bbox_y_end = Column(Float, nullable=True)    # Bottom boundary (% of page)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    page = relationship("Page", back_populates="sections")
