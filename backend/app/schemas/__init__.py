"""Pydantic schemas for book-related data."""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel


class TextUnitOut(BaseModel):
    id: int
    unit_type: str
    text_content: str
    bbox_x: float
    bbox_y: float
    bbox_w: float
    bbox_h: float
    sort_order: int
    is_manual: bool
    audio_segment_url: Optional[str] = None

    class Config:
        from_attributes = True


class TextUnitCreate(BaseModel):
    unit_type: str = "letter"
    text_content: str
    bbox_x: float
    bbox_y: float
    bbox_w: float
    bbox_h: float
    sort_order: int = 0
    is_manual: bool = True


class TextUnitUpdate(BaseModel):
    unit_type: Optional[str] = None
    text_content: Optional[str] = None
    bbox_x: Optional[float] = None
    bbox_y: Optional[float] = None
    bbox_w: Optional[float] = None
    bbox_h: Optional[float] = None
    sort_order: Optional[int] = None


class PageOut(BaseModel):
    id: int
    page_number: int
    image_url: Optional[str] = None
    image_2x_url: Optional[str] = None
    image_width: Optional[int] = None
    image_height: Optional[int] = None
    has_text_data: bool
    is_annotated: bool
    text_units: List[TextUnitOut] = []

    class Config:
        from_attributes = True


class PageSummary(BaseModel):
    id: int
    page_number: int
    image_url: Optional[str] = None
    has_text_data: bool
    is_annotated: bool
    unit_count: int = 0

    class Config:
        from_attributes = True


class ChapterOut(BaseModel):
    id: int
    title: str
    title_ar: Optional[str] = None
    sort_order: int
    start_page: Optional[int] = None
    end_page: Optional[int] = None

    class Config:
        from_attributes = True


class ChapterCreate(BaseModel):
    title: str
    title_ar: Optional[str] = None
    sort_order: int = 0
    start_page: Optional[int] = None
    end_page: Optional[int] = None


class BookOut(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    author: Optional[str] = None
    total_pages: int
    manifest_version: int
    is_published: bool
    chapters: List[ChapterOut] = []
    created_at: datetime

    class Config:
        from_attributes = True


class BookSummary(BaseModel):
    id: int
    title: str
    total_pages: int
    manifest_version: int
    is_published: bool

    class Config:
        from_attributes = True


# ─── Section schemas ────────────────────────────

class SectionOut(BaseModel):
    id: int
    section_type: str
    target_letter: Optional[str] = None
    title_ar: Optional[str] = None
    title_uz: Optional[str] = None
    sort_order: int
    unit_ids: List[int] = []
    bbox_y_start: Optional[float] = None
    bbox_y_end: Optional[float] = None
    is_manual: bool = False

    class Config:
        from_attributes = True


class SectionUpdate(BaseModel):
    section_type: Optional[str] = None
    target_letter: Optional[str] = None
    title_ar: Optional[str] = None
    title_uz: Optional[str] = None
    sort_order: Optional[int] = None


class SectionMerge(BaseModel):
    section_ids: List[int]  # IDs of sections to merge (must be adjacent)
