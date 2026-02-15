"""Pydantic schemas for audio-related data."""

from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel


class AudioSegmentOut(BaseModel):
    id: int
    segment_index: int
    file_url: Optional[str] = None
    start_ms: int
    end_ms: int
    duration_ms: int
    waveform_peaks: Optional[list] = None
    is_silence: bool
    label: Optional[str] = None
    version: int

    class Config:
        from_attributes = True


class AudioSegmentUpdate(BaseModel):
    start_ms: Optional[int] = None
    end_ms: Optional[int] = None
    label: Optional[str] = None
    is_silence: Optional[bool] = None


class AudioFileOut(BaseModel):
    id: int
    book_id: int
    original_filename: str
    duration_ms: Optional[int] = None
    file_size_bytes: Optional[int] = None
    status: str
    error_message: Optional[str] = None
    page_start: Optional[int] = None
    page_end: Optional[int] = None
    waveform_peaks: Optional[list] = None
    segment_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class SegmentMappingCreate(BaseModel):
    text_unit_id: int
    audio_segment_id: int


class SegmentMappingOut(BaseModel):
    id: int
    text_unit_id: int
    audio_segment_id: int
    version: int
    is_published: bool
    published_at: Optional[datetime] = None

    class Config:
        from_attributes = True
