"""Public book API endpoints."""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.section import Section

from app.database import get_db
from app.models.book import Book, Chapter, Page, TextUnit
from app.models.audio import UnitSegmentMapping, AudioSegment
from app.config import get_settings
from app.schemas import BookOut, BookSummary, PageOut, TextUnitOut, ChapterOut
from app.api.deps import get_published_book

router = APIRouter(prefix="/book", tags=["Book"])
settings = get_settings()


@router.get("", response_model=BookSummary)
async def get_book(book: Book = Depends(get_published_book)):
    """Get the book summary (single book app)."""
    return book


@router.get("/chapters", response_model=List[ChapterOut])
async def get_chapters(
    book: Book = Depends(get_published_book),
    db: AsyncSession = Depends(get_db),
):
    """Get table of contents (chapters)."""
    result = await db.execute(
        select(Chapter)
        .where(Chapter.book_id == book.id)
        .order_by(Chapter.sort_order)
    )
    return result.scalars().all()


@router.get("/pages", response_model=List[dict])
async def get_pages_list(
    book: Book = Depends(get_published_book),
    db: AsyncSession = Depends(get_db),
    offset: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
):
    """Get paginated list of pages (summaries)."""
    result = await db.execute(
        select(Page)
        .where(Page.book_id == book.id)
        .order_by(Page.page_number)
        .offset(offset)
        .limit(limit)
    )
    pages = result.scalars().all()

    return [
        {
            "id": p.id,
            "page_number": p.page_number,
            "image_url": f"{settings.MEDIA_BASE_URL}/{p.image_path}" if p.image_path else None,
            "has_text_data": p.has_text_data,
            "is_annotated": p.is_annotated,
        }
        for p in pages
    ]


@router.get("/pages/{page_number}", response_model=dict)
async def get_page(
    page_number: int,
    book: Book = Depends(get_published_book),
    db: AsyncSession = Depends(get_db),
):
    """Get a single page with all text units and their audio mappings."""

    result = await db.execute(
        select(Page)
        .options(
            selectinload(Page.text_units),
            selectinload(Page.sections),
        )
        .where(Page.book_id == book.id, Page.page_number == page_number)
    )
    page = result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    # Build text units with audio URLs
    units = []
    for unit in sorted(page.text_units, key=lambda u: u.sort_order):
        # Get published audio mapping
        mapping_result = await db.execute(
            select(UnitSegmentMapping)
            .options(selectinload(UnitSegmentMapping.audio_segment))
            .where(
                UnitSegmentMapping.text_unit_id == unit.id,
                UnitSegmentMapping.is_published == True,
            )
            .limit(1)
        )
        mapping = mapping_result.scalar_one_or_none()
        audio_url = None
        if mapping and mapping.audio_segment and mapping.audio_segment.file_path:
            audio_url = f"{settings.MEDIA_BASE_URL}/{mapping.audio_segment.file_path}"

        units.append({
            "id": unit.id,
            "unit_type": unit.unit_type.value if hasattr(unit.unit_type, 'value') else unit.unit_type,
            "text_content": unit.text_content,
            "bbox_x": unit.bbox_x,
            "bbox_y": unit.bbox_y,
            "bbox_w": unit.bbox_w,
            "bbox_h": unit.bbox_h,
            "sort_order": unit.sort_order,
            "is_manual": unit.is_manual,
            "audio_segment_url": audio_url,
            "metadata": unit.metadata_ or {},
        })

    # Build sections
    sections = []
    for sec in sorted(page.sections, key=lambda s: s.sort_order):
        sections.append({
            "id": sec.id,
            "section_type": sec.section_type.value if hasattr(sec.section_type, 'value') else sec.section_type,
            "target_letter": sec.target_letter,
            "title_ar": sec.title_ar,
            "title_uz": sec.title_uz,
            "sort_order": sec.sort_order,
            "unit_ids": sec.unit_ids or [],
            "bbox_y_start": sec.bbox_y_start,
            "bbox_y_end": sec.bbox_y_end,
            "is_manual": sec.is_manual,
        })

    return {
        "id": page.id,
        "page_number": page.page_number,
        "layout_type": getattr(page, 'layout_type', 'pdf') or 'pdf',
        "image_url": f"{settings.MEDIA_BASE_URL}/{page.image_path}" if page.image_path else None,
        "image_2x_url": f"{settings.MEDIA_BASE_URL}/{page.image_2x_path}" if page.image_2x_path else None,
        "image_width": page.image_width,
        "image_height": page.image_height,
        "has_text_data": page.has_text_data,
        "is_annotated": page.is_annotated,
        "text_units": units,
        "sections": sections,
    }
