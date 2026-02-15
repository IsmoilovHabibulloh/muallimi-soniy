"""Admin audio management endpoints."""

import os
import shutil
from typing import List

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.api.deps import get_current_admin
from app.models.admin import AdminUser
from app.models.audio import AudioFile, AudioSegment, UnitSegmentMapping, AudioStatus
from app.models.book import TextUnit
from app.models.system import AuditLog
from app.schemas.audio import AudioFileOut, AudioSegmentOut, AudioSegmentUpdate, SegmentMappingCreate, SegmentMappingOut
from app.config import get_settings
from app.utils.validators import validate_file_extension, sanitize_filename

router = APIRouter(prefix="/audio", tags=["Admin Audio"])
settings = get_settings()


@router.post("/upload", response_model=AudioFileOut, status_code=201)
async def upload_audio(
    file: UploadFile = File(...),
    book_id: int = Form(...),
    page_start: int = Form(None),
    page_end: int = Form(None),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Upload an MP3 audio file for processing."""
    if not file.filename or not validate_file_extension(file.filename, ["mp3"]):
        raise HTTPException(status_code=400, detail="Faqat MP3 fayl qabul qilinadi")

    # Check file size
    content = await file.read()
    max_bytes = settings.MAX_UPLOAD_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"Fayl hajmi {settings.MAX_UPLOAD_SIZE_MB}MB dan oshmasligi kerak"
        )

    # Save file
    safe_name = sanitize_filename(file.filename)
    upload_dir = os.path.join(settings.MEDIA_DIR, "uploads")
    os.makedirs(upload_dir, exist_ok=True)
    file_path = os.path.join("uploads", safe_name)
    full_path = os.path.join(settings.MEDIA_DIR, file_path)

    with open(full_path, "wb") as f:
        f.write(content)

    audio_file = AudioFile(
        book_id=book_id,
        original_filename=file.filename,
        file_path=file_path,
        file_size_bytes=len(content),
        status=AudioStatus.UPLOADED,
        page_start=page_start,
        page_end=page_end,
    )
    db.add(audio_file)
    await db.flush()

    # Trigger async processing
    from app.tasks.audio_tasks import process_audio_task
    task = process_audio_task.delay(audio_file.id)

    db.add(AuditLog(
        admin_id=admin.id,
        action="upload_audio",
        entity_type="audio_file",
        entity_id=audio_file.id,
        details={"filename": file.filename, "task_id": task.id},
    ))

    return AudioFileOut(
        id=audio_file.id,
        book_id=audio_file.book_id,
        original_filename=audio_file.original_filename,
        file_size_bytes=audio_file.file_size_bytes,
        status=audio_file.status.value,
        page_start=page_start,
        page_end=page_end,
        created_at=audio_file.created_at,
    )


@router.get("/files", response_model=List[AudioFileOut])
async def list_audio_files(
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AudioFile).order_by(AudioFile.created_at.desc())
    )
    files = result.scalars().all()
    out = []
    for af in files:
        seg_count = 0
        if af.segments:
            seg_count = len(af.segments)
        out.append(AudioFileOut(
            id=af.id,
            book_id=af.book_id,
            original_filename=af.original_filename,
            duration_ms=af.duration_ms,
            file_size_bytes=af.file_size_bytes,
            status=af.status.value if hasattr(af.status, 'value') else af.status,
            error_message=af.error_message,
            page_start=af.page_start,
            page_end=af.page_end,
            waveform_peaks=af.waveform_peaks,
            segment_count=seg_count,
            created_at=af.created_at,
        ))
    return out


@router.get("/files/{audio_file_id}/segments", response_model=List[AudioSegmentOut])
async def get_segments(
    audio_file_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AudioSegment)
        .where(AudioSegment.audio_file_id == audio_file_id)
        .order_by(AudioSegment.segment_index)
    )
    segments = result.scalars().all()
    return [
        AudioSegmentOut(
            id=s.id,
            segment_index=s.segment_index,
            file_url=f"{settings.MEDIA_BASE_URL}/{s.file_path}" if s.file_path else None,
            start_ms=s.start_ms,
            end_ms=s.end_ms,
            duration_ms=s.duration_ms,
            waveform_peaks=s.waveform_peaks,
            is_silence=s.is_silence,
            label=s.label,
            version=s.version,
        )
        for s in segments
    ]


@router.put("/segments/{segment_id}", response_model=AudioSegmentOut)
async def update_segment(
    segment_id: int,
    data: AudioSegmentUpdate,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update segment boundaries (from waveform editor)."""
    result = await db.execute(select(AudioSegment).where(AudioSegment.id == segment_id))
    seg = result.scalar_one_or_none()
    if not seg:
        raise HTTPException(status_code=404, detail="Segment topilmadi")

    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(seg, field, value)

    if data.start_ms is not None or data.end_ms is not None:
        seg.duration_ms = seg.end_ms - seg.start_ms

    await db.flush()
    db.add(AuditLog(admin_id=admin.id, action="update", entity_type="audio_segment", entity_id=segment_id))

    return AudioSegmentOut(
        id=seg.id,
        segment_index=seg.segment_index,
        file_url=f"{settings.MEDIA_BASE_URL}/{seg.file_path}" if seg.file_path else None,
        start_ms=seg.start_ms,
        end_ms=seg.end_ms,
        duration_ms=seg.duration_ms,
        waveform_peaks=seg.waveform_peaks,
        is_silence=seg.is_silence,
        label=seg.label,
        version=seg.version,
    )


# === Segment ↔ Unit Mapping ===

@router.post("/mappings", response_model=SegmentMappingOut, status_code=201)
async def create_mapping(
    data: SegmentMappingCreate,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Map an audio segment to a text unit."""
    # Verify both exist
    unit = await db.get(TextUnit, data.text_unit_id)
    segment = await db.get(AudioSegment, data.audio_segment_id)
    if not unit or not segment:
        raise HTTPException(status_code=404, detail="Birlik yoki segment topilmadi")

    mapping = UnitSegmentMapping(
        text_unit_id=data.text_unit_id,
        audio_segment_id=data.audio_segment_id,
    )
    db.add(mapping)
    await db.flush()

    db.add(AuditLog(admin_id=admin.id, action="create", entity_type="mapping", entity_id=mapping.id))
    return mapping


@router.delete("/mappings/{mapping_id}")
async def delete_mapping(
    mapping_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(UnitSegmentMapping).where(UnitSegmentMapping.id == mapping_id))
    mapping = result.scalar_one_or_none()
    if not mapping:
        raise HTTPException(status_code=404, detail="Mapping topilmadi")
    await db.delete(mapping)
    db.add(AuditLog(admin_id=admin.id, action="delete", entity_type="mapping", entity_id=mapping_id))
    return {"message": "Mapping o'chirildi"}


@router.post("/files/{audio_file_id}/cut-segments")
async def cut_segments(
    audio_file_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Trigger FFmpeg to cut individual segment audio files."""
    audio_file = await db.get(AudioFile, audio_file_id)
    if not audio_file:
        raise HTTPException(status_code=404, detail="Audio fayl topilmadi")

    from app.tasks.audio_tasks import cut_segments_task
    task = cut_segments_task.delay(audio_file_id)

    db.add(AuditLog(
        admin_id=admin.id,
        action="cut_segments",
        entity_type="audio_file",
        entity_id=audio_file_id,
        details={"task_id": task.id},
    ))

    return {"message": "Segmentlar kesish boshlandi", "task_id": task.id}
