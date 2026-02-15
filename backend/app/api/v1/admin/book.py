"""Admin book management endpoints."""

import os
import shutil
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Body
from sqlalchemy import select, delete, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.api.deps import get_current_admin, get_any_book, UNIT_TYPE_MAP
from app.models.admin import AdminUser
from app.models.book import Book, Chapter, Page, TextUnit, UnitType, PageStatus, PageVersion
from app.models.system import AuditLog
from app.schemas import (
    BookOut, ChapterCreate, ChapterOut,
    PageOut, TextUnitCreate, TextUnitUpdate, TextUnitOut,
)
from app.config import get_settings

router = APIRouter(prefix="/book", tags=["Admin Book"])
settings = get_settings()


@router.get("", response_model=BookOut)
async def admin_get_book(
    book: Book = Depends(get_any_book),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get full book details for admin."""
    # Reload with chapters eagerly loaded
    result = await db.execute(
        select(Book).options(selectinload(Book.chapters)).where(Book.id == book.id)
    )
    return result.scalar_one()


@router.put("/publish")
async def publish_book(
    book: Book = Depends(get_any_book),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Publish current state: increment manifest version."""
    from app.models.system import ManifestVersion

    book.manifest_version += 1
    book.is_published = True

    # Record manifest version
    mv = ManifestVersion(
        version=book.manifest_version,
        published_by=admin.id,
        changelog=f"Published v{book.manifest_version}",
    )
    db.add(mv)

    # Audit log
    log = AuditLog(
        admin_id=admin.id,
        action="publish",
        entity_type="book",
        entity_id=book.id,
        details={"version": book.manifest_version},
    )
    db.add(log)
    await db.flush()

    return {"version": book.manifest_version, "message": "Kitob nashr qilindi"}


# === Chapters ===

@router.post("/chapters", response_model=ChapterOut, status_code=201)
async def create_chapter(
    data: ChapterCreate,
    book: Book = Depends(get_any_book),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):

    chapter = Chapter(book_id=book.id, **data.model_dump())
    db.add(chapter)
    await db.flush()

    db.add(AuditLog(admin_id=admin.id, action="create", entity_type="chapter", entity_id=chapter.id))
    return chapter


@router.delete("/chapters/{chapter_id}")
async def delete_chapter(
    chapter_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Chapter).where(Chapter.id == chapter_id))
    chapter = result.scalar_one_or_none()
    if not chapter:
        raise HTTPException(status_code=404, detail="Bob topilmadi")
    await db.delete(chapter)
    db.add(AuditLog(admin_id=admin.id, action="delete", entity_type="chapter", entity_id=chapter_id))
    return {"message": "Bob o'chirildi"}


# === Pages ===

@router.get("/pages", response_model=List[dict])
async def admin_get_pages(
    book: Book = Depends(get_any_book),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get all pages with analysis status and unit counts."""

    result = await db.execute(
        select(Page).where(Page.book_id == book.id).order_by(Page.page_number)
    )
    pages = result.scalars().all()

    # Get unit counts per page
    counts_result = await db.execute(
        select(TextUnit.page_id, func.count(TextUnit.id))
        .group_by(TextUnit.page_id)
    )
    unit_counts = dict(counts_result.all())

    return [
        {
            "id": p.id,
            "page_number": p.page_number,
            "layout_type": p.layout_type,
            "image_url": f"{settings.MEDIA_BASE_URL}/{p.image_path}" if p.image_path else None,
            "source_image_url": f"{settings.MEDIA_BASE_URL}/{p.source_image_path}" if p.source_image_path else None,
            "has_text_data": p.has_text_data,
            "is_annotated": p.is_annotated,
            "analysis_status": p.analysis_status.value if p.analysis_status else "empty",
            "analysis_error": p.analysis_error,
            "unit_count": unit_counts.get(p.id, 0),
            "qa_report": p.qa_report,
        }
        for p in pages
    ]


@router.get("/pages/{page_id}/units", response_model=List[TextUnitOut])
async def admin_get_page_units(
    page_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TextUnit).where(TextUnit.page_id == page_id).order_by(TextUnit.sort_order)
    )
    units = result.scalars().all()
    return units


# === Image Upload & Analysis ===

@router.post("/pages/upload-image")
async def upload_page_image(
    page_number: int = Form(...),
    file: UploadFile = File(...),
    book: Book = Depends(get_any_book),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Upload a page image and trigger OCR analysis.

    Creates or updates a page, saves the image, and starts background analysis.
    """
    # Validate file type
    if not file.filename:
        raise HTTPException(status_code=400, detail="Fayl nomi yo'q")

    ext = file.filename.lower().rsplit(".", 1)[-1] if "." in file.filename else ""
    if ext not in ("png", "jpg", "jpeg", "webp"):
        raise HTTPException(status_code=400, detail="Faqat PNG, JPG, WEBP formatlar qabul qilinadi")

    # book is injected via get_any_book dependency

    # Save uploaded image
    upload_dir = os.path.join(settings.MEDIA_DIR, "pages", "source")
    os.makedirs(upload_dir, exist_ok=True)
    filename = f"page_{page_number:03d}_source.{ext}"
    file_path = os.path.join(upload_dir, filename)
    relative_path = f"pages/source/{filename}"

    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Get image dimensions
    try:
        from PIL import Image
        img = Image.open(file_path)
        img_width, img_height = img.size
        img.close()
    except Exception:
        img_width, img_height = None, None

    # Create or update page
    result = await db.execute(
        select(Page).where(Page.book_id == book.id, Page.page_number == page_number)
    )
    page = result.scalar_one_or_none()

    if page:
        page.source_image_path = relative_path
        page.image_path = relative_path  # Also set as display image
        page.image_width = img_width
        page.image_height = img_height
        page.analysis_status = PageStatus.PENDING
        page.analysis_error = None
    else:
        page = Page(
            book_id=book.id,
            page_number=page_number,
            layout_type="native",
            source_image_path=relative_path,
            image_path=relative_path,
            image_width=img_width,
            image_height=img_height,
            analysis_status=PageStatus.PENDING,
        )
        db.add(page)
        # Update book total_pages
        book.total_pages = max(book.total_pages, page_number)

    await db.flush()

    # Start background analysis
    try:
        from app.tasks.page_tasks import analyze_page_image_task
        task = analyze_page_image_task.delay(page.id, relative_path)
        task_id = task.id
    except Exception as e:
        # If Celery is not available, run analysis inline
        task_id = None
        try:
            from app.services.image_analyzer import analyze_image
            units = analyze_image(file_path)

            # Delete existing non-manual units
            await db.execute(
                delete(TextUnit).where(
                    TextUnit.page_id == page.id,
                    TextUnit.is_manual == False
                )
            )

            for unit_data in units:
                unit_type_map = UNIT_TYPE_MAP
                unit = TextUnit(
                    page_id=page.id,
                    unit_type=unit_type_map.get(unit_data.unit_type, UnitType.WORD),
                    text_content=unit_data.text,
                    bbox_x=unit_data.bbox_x,
                    bbox_y=unit_data.bbox_y,
                    bbox_w=unit_data.bbox_w,
                    bbox_h=unit_data.bbox_h,
                    sort_order=unit_data.sort_order,
                    confidence=unit_data.confidence,
                    is_manual=False,
                    metadata_=unit_data.metadata or {},
                )
                db.add(unit)

            page.analysis_status = PageStatus.DRAFT
            page.has_text_data = len(units) > 0
            await db.flush()
        except Exception as analysis_error:
            page.analysis_status = PageStatus.ERROR
            page.analysis_error = str(analysis_error)

    db.add(AuditLog(
        admin_id=admin.id,
        action="upload_image",
        entity_type="page",
        entity_id=page.id,
        details={"filename": file.filename, "page_number": page_number, "task_id": task_id},
    ))

    return {
        "message": "Rasm yuklandi va tahlil boshlandi",
        "page_id": page.id,
        "page_number": page_number,
        "task_id": task_id,
        "analysis_status": page.analysis_status.value,
    }


@router.get("/pages/{page_id}/draft")
async def get_page_draft(
    page_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get page draft with all units for overlay editor."""
    result = await db.execute(
        select(Page).options(selectinload(Page.text_units)).where(Page.id == page_id)
    )
    page = result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    units = sorted(page.text_units, key=lambda u: u.sort_order)

    return {
        "id": page.id,
        "page_number": page.page_number,
        "analysis_status": page.analysis_status.value if page.analysis_status else "empty",
        "analysis_error": page.analysis_error,
        "source_image_url": f"{settings.MEDIA_BASE_URL}/{page.source_image_path}" if page.source_image_path else None,
        "image_url": f"{settings.MEDIA_BASE_URL}/{page.image_path}" if page.image_path else None,
        "image_width": page.image_width,
        "image_height": page.image_height,
        "qa_report": page.qa_report,
        "units": [
            {
                "id": u.id,
                "unit_type": u.unit_type.value if hasattr(u.unit_type, 'value') else u.unit_type,
                "text_content": u.text_content,
                "bbox_x": u.bbox_x,
                "bbox_y": u.bbox_y,
                "bbox_w": u.bbox_w,
                "bbox_h": u.bbox_h,
                "sort_order": u.sort_order,
                "confidence": u.confidence,
                "is_manual": u.is_manual,
                "metadata": u.metadata_ or {},
            }
            for u in units
        ],
    }


@router.put("/pages/{page_id}/units/bulk")
async def bulk_update_units(
    page_id: int,
    units: List[dict] = Body(...),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Bulk update/create/delete text units for a page.

    Expects a list of unit dicts. Each must have an "action":
    - "update": update existing unit (requires "id")
    - "create": create new unit
    - "delete": delete unit (requires "id")
    """
    result = await db.execute(select(Page).where(Page.id == page_id))
    page = result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    created = 0
    updated = 0
    deleted = 0

    for u in units:
        action = u.get("action", "update")

        if action == "delete":
            unit_id = u.get("id")
            if unit_id:
                await db.execute(delete(TextUnit).where(TextUnit.id == unit_id, TextUnit.page_id == page_id))
                deleted += 1

        elif action == "create":
            unit_type_map = UNIT_TYPE_MAP
            new_unit = TextUnit(
                page_id=page_id,
                unit_type=unit_type_map.get(u.get("unit_type", "word"), UnitType.WORD),
                text_content=u.get("text_content", ""),
                bbox_x=u.get("bbox_x", 0),
                bbox_y=u.get("bbox_y", 0),
                bbox_w=u.get("bbox_w", 0),
                bbox_h=u.get("bbox_h", 0),
                sort_order=u.get("sort_order", 0),
                is_manual=True,
                metadata_=u.get("metadata", {}),
            )
            db.add(new_unit)
            created += 1

        elif action == "update":
            unit_id = u.get("id")
            if not unit_id:
                continue
            result = await db.execute(
                select(TextUnit).where(TextUnit.id == unit_id, TextUnit.page_id == page_id)
            )
            unit = result.scalar_one_or_none()
            if not unit:
                continue

            for field in ["text_content", "bbox_x", "bbox_y", "bbox_w", "bbox_h", "sort_order"]:
                if field in u:
                    setattr(unit, field, u[field])
            if "unit_type" in u:
                try:
                    unit.unit_type = UnitType(u["unit_type"])
                except ValueError:
                    pass
            if "metadata" in u:
                unit.metadata_ = u["metadata"]
            unit.is_manual = True
            updated += 1

    page.is_annotated = True
    page.has_text_data = True
    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="bulk_edit",
        entity_type="page",
        entity_id=page_id,
        details={"created": created, "updated": updated, "deleted": deleted},
    ))

    return {
        "message": f"Yangilandi: {created} yaratildi, {updated} o'zgartirildi, {deleted} o'chirildi",
        "created": created,
        "updated": updated,
        "deleted": deleted,
    }


@router.post("/pages/{page_id}/publish")
async def publish_page(
    page_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Run QA checks and publish a page if it passes."""
    from app.services.qa_checker import run_qa_checks

    result = await db.execute(
        select(Page).options(selectinload(Page.text_units)).where(Page.id == page_id)
    )
    page = result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    # Build unit dicts for QA
    units_data = [
        {
            "text_content": u.text_content,
            "bbox_x": u.bbox_x,
            "bbox_y": u.bbox_y,
            "bbox_w": u.bbox_w,
            "bbox_h": u.bbox_h,
            "sort_order": u.sort_order,
            "audio_segment_url": None,  # TODO: add audio mapping check
        }
        for u in page.text_units
    ]

    qa_result = run_qa_checks(units_data)
    page.qa_report = qa_result.to_dict()

    if not qa_result.passed:
        await db.flush()
        raise HTTPException(
            status_code=422,
            detail={
                "message": "QA tekshiruvdan o'tmadi",
                "qa_report": qa_result.to_dict(),
            }
        )

    # QA passed — create version snapshot BEFORE publishing
    from app.models.book import PageVersion

    # Get next version number
    ver_result = await db.execute(
        select(func.coalesce(func.max(PageVersion.version), 0))
        .where(PageVersion.page_id == page_id)
    )
    next_version = ver_result.scalar() + 1

    # Serialize text units to snapshot
    snapshot = [
        {
            "unit_type": u.unit_type.value if hasattr(u.unit_type, 'value') else str(u.unit_type),
            "text_content": u.text_content,
            "bbox_x": u.bbox_x,
            "bbox_y": u.bbox_y,
            "bbox_w": u.bbox_w,
            "bbox_h": u.bbox_h,
            "sort_order": u.sort_order,
            "is_manual": u.is_manual,
            "confidence": u.confidence,
            "metadata": u.metadata_,
        }
        for u in page.text_units
    ]

    db.add(PageVersion(
        page_id=page_id,
        version=next_version,
        snapshot=snapshot,
        qa_report=qa_result.to_dict(),
        published_by=admin.id,
    ))

    # Publish
    page.analysis_status = PageStatus.PUBLISHED
    page.published_at = datetime.utcnow()
    page.is_annotated = True

    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="publish_page",
        entity_type="page",
        entity_id=page_id,
        details={"qa_score": qa_result.score, "version": next_version},
    ))

    return {
        "message": f"Sahifa nashr qilindi (v{next_version})",
        "page_id": page_id,
        "version": next_version,
        "qa_report": qa_result.to_dict(),
    }


@router.get("/pages/{page_id}/versions")
async def list_page_versions(
    page_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """List all published versions of a page."""
    result = await db.execute(
        select(PageVersion)
        .where(PageVersion.page_id == page_id)
        .order_by(PageVersion.version.desc())
    )
    versions = result.scalars().all()

    return [
        {
            "id": v.id,
            "version": v.version,
            "unit_count": len(v.snapshot) if v.snapshot else 0,
            "qa_score": v.qa_report.get("score") if v.qa_report else None,
            "created_at": v.created_at.isoformat() if v.created_at else None,
        }
        for v in versions
    ]


@router.post("/pages/{page_id}/rollback/{version_id}")
async def rollback_page(
    page_id: int,
    version_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Rollback a page to a previous version's text units."""
    # Load version
    ver_result = await db.execute(
        select(PageVersion).where(
            PageVersion.id == version_id,
            PageVersion.page_id == page_id,
        )
    )
    version = ver_result.scalar_one_or_none()
    if not version:
        raise HTTPException(status_code=404, detail="Versiya topilmadi")

    # Load page
    page_result = await db.execute(
        select(Page).options(selectinload(Page.text_units)).where(Page.id == page_id)
    )
    page = page_result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    # Delete current text units
    await db.execute(
        delete(TextUnit).where(TextUnit.page_id == page_id)
    )

    # Restore from snapshot
    for u_data in version.snapshot:
        unit_type_val = u_data.get("unit_type", "letter")
        try:
            unit_type = UnitType(unit_type_val)
        except ValueError:
            unit_type = UnitType.LETTER

        db.add(TextUnit(
            page_id=page_id,
            unit_type=unit_type,
            text_content=u_data.get("text_content", ""),
            bbox_x=u_data.get("bbox_x", 0),
            bbox_y=u_data.get("bbox_y", 0),
            bbox_w=u_data.get("bbox_w", 0),
            bbox_h=u_data.get("bbox_h", 0),
            sort_order=u_data.get("sort_order", 0),
            is_manual=u_data.get("is_manual", False),
            confidence=u_data.get("confidence"),
            metadata_=u_data.get("metadata"),
        ))

    # Set page to DRAFT for re-review
    page.analysis_status = PageStatus.DRAFT
    page.qa_report = version.qa_report

    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="rollback_page",
        entity_type="page",
        entity_id=page_id,
        details={"restored_version": version.version},
    ))

    return {
        "message": f"Sahifa v{version.version} ga qaytarildi",
        "page_id": page_id,
        "restored_version": version.version,
        "unit_count": len(version.snapshot),
    }


# === Single Unit CRUD (kept for backward compat) ===

@router.post("/pages/{page_id}/units", response_model=TextUnitOut, status_code=201)
async def create_text_unit(
    page_id: int,
    data: TextUnitCreate,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Manually create a text unit (hotspot annotation)."""
    result = await db.execute(select(Page).where(Page.id == page_id))
    page = result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    unit = TextUnit(
        page_id=page_id,
        unit_type=UnitType(data.unit_type),
        text_content=data.text_content,
        bbox_x=data.bbox_x,
        bbox_y=data.bbox_y,
        bbox_w=data.bbox_w,
        bbox_h=data.bbox_h,
        sort_order=data.sort_order,
        is_manual=True,
    )
    db.add(unit)

    page.is_annotated = True
    page.has_text_data = True
    await db.flush()

    db.add(AuditLog(admin_id=admin.id, action="create", entity_type="text_unit", entity_id=unit.id))
    return unit


@router.put("/units/{unit_id}", response_model=TextUnitOut)
async def update_text_unit(
    unit_id: int,
    data: TextUnitUpdate,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(TextUnit).where(TextUnit.id == unit_id))
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(status_code=404, detail="Birlik topilmadi")

    for field, value in data.model_dump(exclude_unset=True).items():
        if field == "unit_type" and value is not None:
            value = UnitType(value)
        setattr(unit, field, value)

    await db.flush()
    db.add(AuditLog(admin_id=admin.id, action="update", entity_type="text_unit", entity_id=unit_id))
    return unit


@router.delete("/units/{unit_id}")
async def delete_text_unit(
    unit_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(TextUnit).where(TextUnit.id == unit_id))
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(status_code=404, detail="Birlik topilmadi")
    await db.delete(unit)
    db.add(AuditLog(admin_id=admin.id, action="delete", entity_type="text_unit", entity_id=unit_id))
    return {"message": "Birlik o'chirildi"}


# === PDF Import ===

@router.post("/import-pdf")
async def import_pdf(
    file: UploadFile = File(...),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Upload and process a PDF book."""
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Faqat PDF fayl qabul qilinadi")

    # Save uploaded file
    upload_dir = os.path.join(settings.MEDIA_DIR, "uploads")
    os.makedirs(upload_dir, exist_ok=True)
    file_path = os.path.join(upload_dir, "book.pdf")

    with open(file_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    # Trigger async processing
    from app.tasks.pdf_tasks import process_pdf_task
    task = process_pdf_task.delay(file_path)

    db.add(AuditLog(
        admin_id=admin.id,
        action="import_pdf",
        entity_type="book",
        details={"filename": file.filename, "task_id": task.id},
    ))

    return {"message": "PDF import boshlandi", "task_id": task.id}



# ═══════════════════════════════════════════════════
# Unit Splitting
# ═══════════════════════════════════════════════════

@router.post("/units/{unit_id}/split")
async def split_unit(
    unit_id: int,
    separator: Optional[str] = Body(None, embed=True),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Split a multi-token unit into individual units.

    AI auto-detects the best separator for Arabic educational text:
    - Arabic comma ، → comparison pairs (كَمَرْ – قَمَرْ، فَلَكْ – فَلَقْ)
    - Latin comma , → similar groupings
    - Semicolon ; → phrase groups
    - Whitespace → individual words/letters
    Admin can override with custom separator if AI guesses wrong.
    """
    # Get the unit
    result = await db.execute(select(TextUnit).where(TextUnit.id == unit_id))
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(status_code=404, detail="Unit topilmadi")

    text = unit.text_content.strip()
    detected_sep = None

    if separator and separator.strip():
        # Admin override
        detected_sep = separator
        parts = [p.strip() for p in text.split(separator) if p.strip()]
    else:
        # AI auto-detect: try separators in priority order
        separator_priority = [
            ('،', 'arab verguli'),   # Arabic comma — most common in Quran/Arabic textbooks
            (',', 'vergul'),         # Latin comma
            ('؛', 'arab nuqta-vergul'),  # Arabic semicolon
            (';', 'nuqta-vergul'),   # Latin semicolon
        ]

        parts = None
        for sep, _label in separator_priority:
            if sep in text:
                candidate = [p.strip() for p in text.split(sep) if p.strip()]
                if len(candidate) >= 2:
                    parts = candidate
                    detected_sep = sep
                    break

        if parts is None:
            # Fallback: split by whitespace
            parts = text.split()
            detected_sep = ' '

    if len(parts) <= 1:
        raise HTTPException(status_code=400, detail="Bo'lishga hojat yo'q — bitta qism")

    # Shift sort_order of subsequent units to make room
    await db.execute(
        update(TextUnit)
        .where(TextUnit.page_id == unit.page_id, TextUnit.sort_order > unit.sort_order)
        .values(sort_order=TextUnit.sort_order + len(parts) - 1)
    )

    # Get existing metadata
    existing_meta = dict(unit.metadata_ or {})
    section = existing_meta.get("section", "")

    # Create individual units
    new_units = []
    for i, part in enumerate(parts):
        meta = {"section": section, "grid": {"row": unit.sort_order, "col": i}}
        new_unit = TextUnit(
            page_id=unit.page_id,
            unit_type=unit.unit_type,
            text_content=part,
            bbox_x=0, bbox_y=0, bbox_w=0, bbox_h=0,
            sort_order=unit.sort_order + i,
            is_manual=True,
            metadata_=meta,
        )
        db.add(new_unit)
        new_units.append(new_unit)

    # Delete the original unit
    await db.execute(delete(TextUnit).where(TextUnit.id == unit_id))

    await db.flush()

    # Audit log
    db.add(AuditLog(
        admin_id=admin.id,
        action="split_unit",
        entity_type="text_unit",
        entity_id=unit_id,
        details={"parts": len(parts), "page_id": unit.page_id},
    ))

    return {
        "message": f"Unit {len(parts)} qismga bo'lindi",
        "parts": [{"id": u.id, "text": u.text_content} for u in new_units],
    }


# ═══════════════════════════════════════════════════
# Section Management (Lesson Sectioning Engine)
# ═══════════════════════════════════════════════════

from app.models.section import Section, SectionType as SectionTypeEnum
from app.schemas import SectionOut, SectionUpdate, SectionMerge
from app.services.sectioning import auto_section_page


@router.post("/pages/{page_id}/auto-section")
async def auto_section(
    page_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Run auto-sectioning algorithm on a page's text units."""
    # Load page with units
    result = await db.execute(
        select(Page).options(selectinload(Page.text_units)).where(Page.id == page_id)
    )
    page = result.scalar_one_or_none()
    if not page:
        raise HTTPException(status_code=404, detail="Sahifa topilmadi")

    if not page.text_units:
        raise HTTPException(status_code=400, detail="Bu sahifada matnlar yo'q")

    # Build unit dicts for algorithm
    units_data = [
        {
            "id": u.id,
            "unit_type": u.unit_type.value if hasattr(u.unit_type, 'value') else u.unit_type,
            "text_content": u.text_content,
            "bbox_x": u.bbox_x,
            "bbox_y": u.bbox_y,
            "bbox_w": u.bbox_w,
            "bbox_h": u.bbox_h,
            "sort_order": u.sort_order,
            "metadata": u.metadata_ or {},
        }
        for u in page.text_units
    ]

    # Run algorithm
    try:
        section_dicts = auto_section_page(page_id, units_data)
    except AssertionError as e:
        raise HTTPException(status_code=500, detail=f"Sectioning xatosi: {str(e)}")

    # Delete existing auto-generated sections (keep manual ones)
    await db.execute(
        delete(Section).where(
            Section.page_id == page_id,
            Section.is_manual == False,
        )
    )

    # Create new sections
    created_sections = []
    for s in section_dicts:
        try:
            section_type = SectionTypeEnum(s['section_type'])
        except ValueError:
            section_type = SectionTypeEnum.GENERIC

        section = Section(
            page_id=page_id,
            section_type=section_type,
            target_letter=s.get('target_letter'),
            title_ar=s.get('title_ar', ''),
            title_uz=s.get('title_uz', ''),
            sort_order=s.get('sort_order', 0),
            unit_ids=s.get('unit_ids', []),
            bbox_y_start=s.get('bbox_y_start'),
            bbox_y_end=s.get('bbox_y_end'),
            is_manual=False,
        )
        db.add(section)
        created_sections.append(section)

    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="auto_section",
        entity_type="page",
        entity_id=page_id,
        details={"sections_created": len(created_sections)},
    ))

    return {
        "message": f"{len(created_sections)} bo'lim yaratildi",
        "sections": [
            {
                "id": s.id,
                "section_type": s.section_type.value,
                "target_letter": s.target_letter,
                "title_ar": s.title_ar,
                "title_uz": s.title_uz,
                "sort_order": s.sort_order,
                "unit_ids": s.unit_ids,
                "bbox_y_start": s.bbox_y_start,
                "bbox_y_end": s.bbox_y_end,
            }
            for s in created_sections
        ],
    }


@router.get("/pages/{page_id}/sections")
async def get_page_sections(
    page_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get all sections for a page (admin view)."""
    result = await db.execute(
        select(Section)
        .where(Section.page_id == page_id)
        .order_by(Section.sort_order)
    )
    sections = result.scalars().all()

    return [
        {
            "id": s.id,
            "section_type": s.section_type.value if hasattr(s.section_type, 'value') else s.section_type,
            "target_letter": s.target_letter,
            "title_ar": s.title_ar,
            "title_uz": s.title_uz,
            "sort_order": s.sort_order,
            "unit_ids": s.unit_ids or [],
            "bbox_y_start": s.bbox_y_start,
            "bbox_y_end": s.bbox_y_end,
            "is_manual": s.is_manual,
        }
        for s in sections
    ]


@router.put("/sections/{section_id}")
async def update_section(
    section_id: int,
    data: SectionUpdate,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update a section (rename, change type, change target letter)."""
    result = await db.execute(select(Section).where(Section.id == section_id))
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(status_code=404, detail="Bo'lim topilmadi")

    for field, value in data.model_dump(exclude_unset=True).items():
        if field == "section_type" and value is not None:
            try:
                value = SectionTypeEnum(value)
            except ValueError:
                raise HTTPException(status_code=400, detail=f"Noma'lum bo'lim turi: {value}")
        setattr(section, field, value)

    section.is_manual = True
    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="update_section",
        entity_type="section",
        entity_id=section_id,
    ))

    return {"message": "Bo'lim yangilandi", "id": section.id}


@router.delete("/sections/{section_id}")
async def delete_section(
    section_id: int,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a single section."""
    result = await db.execute(select(Section).where(Section.id == section_id))
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(status_code=404, detail="Bo'lim topilmadi")

    await db.delete(section)
    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="delete_section",
        entity_type="section",
        entity_id=section_id,
    ))

    return {"message": "Bo'lim o'chirildi"}


@router.post("/sections/merge")
async def merge_sections(
    data: SectionMerge,
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Merge multiple adjacent sections into one."""
    if len(data.section_ids) < 2:
        raise HTTPException(status_code=400, detail="Kamida 2 bo'lim tanlang")

    # Load all sections
    result = await db.execute(
        select(Section)
        .where(Section.id.in_(data.section_ids))
        .order_by(Section.sort_order)
    )
    sections = result.scalars().all()

    if len(sections) != len(data.section_ids):
        raise HTTPException(status_code=404, detail="Ba'zi bo'limlar topilmadi")

    # Verify all belong to same page
    page_ids = {s.page_id for s in sections}
    if len(page_ids) > 1:
        raise HTTPException(status_code=400, detail="Bo'limlar bitta sahifadan bo'lishi kerak")

    # Merge: keep first, absorb others
    primary = sections[0]
    merged_unit_ids = list(primary.unit_ids or [])

    for s in sections[1:]:
        merged_unit_ids.extend(s.unit_ids or [])
        await db.delete(s)

    primary.unit_ids = merged_unit_ids
    primary.bbox_y_start = min(s.bbox_y_start or 0 for s in sections)
    primary.bbox_y_end = max(s.bbox_y_end or 100 for s in sections)
    primary.is_manual = True

    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="merge_sections",
        entity_type="section",
        entity_id=primary.id,
        details={"merged_ids": data.section_ids},
    ))

    return {
        "message": f"{len(data.section_ids)} bo'lim birlashtirildi",
        "section_id": primary.id,
    }


@router.post("/sections/{section_id}/split")
async def split_section(
    section_id: int,
    split_after_unit_id: int = Body(..., embed=True),
    admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Split a section into two at a given unit boundary."""
    result = await db.execute(select(Section).where(Section.id == section_id))
    section = result.scalar_one_or_none()
    if not section:
        raise HTTPException(status_code=404, detail="Bo'lim topilmadi")

    unit_ids = list(section.unit_ids or [])
    if split_after_unit_id not in unit_ids:
        raise HTTPException(status_code=400, detail="Unit bu bo'limda emas")

    split_idx = unit_ids.index(split_after_unit_id) + 1
    if split_idx >= len(unit_ids):
        raise HTTPException(status_code=400, detail="Oxirgi unitdan keyin bo'lish mumkin emas")

    first_half = unit_ids[:split_idx]
    second_half = unit_ids[split_idx:]

    # Update existing section
    section.unit_ids = first_half
    section.is_manual = True

    # Create new section for second half
    new_section = Section(
        page_id=section.page_id,
        section_type=section.section_type,
        target_letter=section.target_letter,
        title_ar=section.title_ar,
        title_uz=section.title_uz,
        sort_order=section.sort_order + 1,
        unit_ids=second_half,
        bbox_y_start=section.bbox_y_start,
        bbox_y_end=section.bbox_y_end,
        is_manual=True,
    )
    db.add(new_section)

    # Shift sort_order of subsequent sections
    await db.execute(
        update(Section)
        .where(
            Section.page_id == section.page_id,
            Section.sort_order > section.sort_order,
            Section.id != section.id,
        )
        .values(sort_order=Section.sort_order + 1)
    )

    await db.flush()

    db.add(AuditLog(
        admin_id=admin.id,
        action="split_section",
        entity_type="section",
        entity_id=section_id,
        details={"new_section_id": new_section.id},
    ))

    return {
        "message": "Bo'lim ikkiga bo'lindi",
        "original_id": section.id,
        "new_id": new_section.id,
    }

