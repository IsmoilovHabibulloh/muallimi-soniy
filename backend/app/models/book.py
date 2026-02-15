"""Book-related database models."""

import enum
from datetime import datetime

from sqlalchemy import (
    Column, Integer, String, Text, Float, Boolean,
    DateTime, ForeignKey, Enum, JSON
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class UnitType(str, enum.Enum):
    LETTER = "letter"
    WORD = "word"
    SENTENCE = "sentence"
    DRILL_GROUP = "drill_group"
    DIVIDER = "divider"


class PageStatus(str, enum.Enum):
    EMPTY = "empty"          # Bo'sh sahifa
    PENDING = "pending"      # Rasm yuklandi, analiz kutilmoqda
    ANALYZING = "analyzing"  # OCR + CV ishlayapti
    DRAFT = "draft"          # Analiz tugadi, admin ko'rib chiqishi kerak
    PUBLISHED = "published"  # Publish qilingan
    ERROR = "error"          # Xatolik yuz berdi


class Book(Base):
    __tablename__ = "books"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(500), nullable=False)
    description = Column(Text, nullable=True)
    author = Column(String(300), nullable=True)
    total_pages = Column(Integer, default=0)
    manifest_version = Column(Integer, default=1)
    is_published = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    chapters = relationship("Chapter", back_populates="book", cascade="all, delete-orphan", order_by="Chapter.sort_order")
    pages = relationship("Page", back_populates="book", cascade="all, delete-orphan", order_by="Page.page_number")
    audio_files = relationship("AudioFile", back_populates="book", cascade="all, delete-orphan")


class Chapter(Base):
    __tablename__ = "chapters"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(Integer, ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(500), nullable=False)
    title_ar = Column(String(500), nullable=True)
    sort_order = Column(Integer, default=0)
    start_page = Column(Integer, nullable=True)
    end_page = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    book = relationship("Book", back_populates="chapters")


class Page(Base):
    __tablename__ = "pages"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(Integer, ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    chapter_id = Column(Integer, ForeignKey("chapters.id", ondelete="SET NULL"), nullable=True)
    page_number = Column(Integer, nullable=False, index=True)
    layout_type = Column(String(20), default="native", nullable=False)  # "pdf" | "native"

    # Images
    image_path = Column(String(500), nullable=True)       # Rendered/reference image
    image_2x_path = Column(String(500), nullable=True)
    source_image_path = Column(String(500), nullable=True) # Original uploaded image
    image_width = Column(Integer, nullable=True)
    image_height = Column(Integer, nullable=True)

    # Status
    has_text_data = Column(Boolean, default=False)
    is_annotated = Column(Boolean, default=False)
    analysis_status = Column(
        Enum(PageStatus), default=PageStatus.EMPTY, nullable=False
    )
    analysis_error = Column(Text, nullable=True)

    # QA
    qa_report = Column(JSON, nullable=True)   # Last QA check result
    published_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    book = relationship("Book", back_populates="pages")
    text_units = relationship("TextUnit", back_populates="page", cascade="all, delete-orphan", order_by="TextUnit.sort_order")
    sections = relationship("Section", back_populates="page", cascade="all, delete-orphan", order_by="Section.sort_order")
    versions = relationship("PageVersion", back_populates="page", cascade="all, delete-orphan", order_by="PageVersion.version.desc()")


class TextUnit(Base):
    __tablename__ = "text_units"

    id = Column(Integer, primary_key=True, index=True)
    page_id = Column(Integer, ForeignKey("pages.id", ondelete="CASCADE"), nullable=False)
    unit_type = Column(Enum(UnitType), nullable=False, default=UnitType.LETTER)
    text_content = Column(Text, nullable=False)

    # Bounding box (relative to page image, percentages 0-100)
    bbox_x = Column(Float, nullable=False, default=0)
    bbox_y = Column(Float, nullable=False, default=0)
    bbox_w = Column(Float, nullable=False, default=0)
    bbox_h = Column(Float, nullable=False, default=0)

    sort_order = Column(Integer, default=0)
    is_manual = Column(Boolean, default=False)  # True if manually annotated/edited by admin
    confidence = Column(Float, nullable=True)    # OCR confidence (0.0 - 1.0)
    metadata_ = Column("metadata", JSON, nullable=True)  # Extra data (section, font size, direction)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    page = relationship("Page", back_populates="text_units")
    segment_mappings = relationship("UnitSegmentMapping", back_populates="text_unit", cascade="all, delete-orphan")


class PageVersion(Base):
    """Snapshot of a page's text_units at publish time for rollback."""
    __tablename__ = "page_versions"

    id = Column(Integer, primary_key=True, index=True)
    page_id = Column(Integer, ForeignKey("pages.id", ondelete="CASCADE"), nullable=False)
    version = Column(Integer, nullable=False)  # 1, 2, 3...
    snapshot = Column(JSON, nullable=False)     # List of text_unit dicts
    qa_report = Column(JSON, nullable=True)     # QA result at publish time
    published_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    page = relationship("Page", back_populates="versions")
