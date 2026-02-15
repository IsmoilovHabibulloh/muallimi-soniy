"""Audio-related database models."""

import enum

from sqlalchemy import (
    Column, Integer, String, Text, Float, Boolean,
    DateTime, ForeignKey, Enum, JSON
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


class AudioStatus(str, enum.Enum):
    UPLOADED = "uploaded"
    PROCESSING = "processing"
    SEGMENTED = "segmented"
    READY = "ready"
    ERROR = "error"


class AudioFile(Base):
    __tablename__ = "audio_files"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(Integer, ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    original_filename = Column(String(500), nullable=False)
    file_path = Column(String(500), nullable=False)
    normalized_path = Column(String(500), nullable=True)
    duration_ms = Column(Integer, nullable=True)
    file_size_bytes = Column(Integer, nullable=True)
    status = Column(Enum(AudioStatus), default=AudioStatus.UPLOADED, nullable=False)
    error_message = Column(Text, nullable=True)
    # Which pages this audio covers
    page_start = Column(Integer, nullable=True)
    page_end = Column(Integer, nullable=True)
    waveform_peaks = Column(JSON, nullable=True)  # Array of peak values for visualization
    processing_metadata = Column(JSON, nullable=True)  # FFmpeg output, silence detect results
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    book = relationship("Book", back_populates="audio_files")
    segments = relationship("AudioSegment", back_populates="audio_file", cascade="all, delete-orphan", order_by="AudioSegment.segment_index")


class AudioSegment(Base):
    __tablename__ = "audio_segments"

    id = Column(Integer, primary_key=True, index=True)
    audio_file_id = Column(Integer, ForeignKey("audio_files.id", ondelete="CASCADE"), nullable=False)
    segment_index = Column(Integer, nullable=False)
    file_path = Column(String(500), nullable=True)  # Path to cut segment file
    start_ms = Column(Integer, nullable=False)
    end_ms = Column(Integer, nullable=False)
    duration_ms = Column(Integer, nullable=False)
    waveform_peaks = Column(JSON, nullable=True)
    is_silence = Column(Boolean, default=False)
    label = Column(String(200), nullable=True)  # Optional label for admin reference
    version = Column(Integer, default=1)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    audio_file = relationship("AudioFile", back_populates="segments")
    unit_mappings = relationship("UnitSegmentMapping", back_populates="audio_segment", cascade="all, delete-orphan")


class UnitSegmentMapping(Base):
    __tablename__ = "unit_segment_mappings"

    id = Column(Integer, primary_key=True, index=True)
    text_unit_id = Column(Integer, ForeignKey("text_units.id", ondelete="CASCADE"), nullable=False)
    audio_segment_id = Column(Integer, ForeignKey("audio_segments.id", ondelete="CASCADE"), nullable=False)
    version = Column(Integer, default=1)
    is_published = Column(Boolean, default=False)
    published_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    text_unit = relationship("TextUnit", back_populates="segment_mappings")
    audio_segment = relationship("AudioSegment", back_populates="unit_mappings")
