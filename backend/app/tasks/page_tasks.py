"""Async page image analysis tasks."""

import logging
import os

from app.tasks.celery_app import celery_app
from app.config import get_settings

logger = logging.getLogger("muallimi")
settings = get_settings()


@celery_app.task(bind=True, max_retries=2, default_retry_delay=30)
def analyze_page_image_task(self, page_id: int, image_path: str):
    """Analyze a page image: run OCR and create text units.

    This runs in a Celery worker (sync context).
    Uses synchronous DB session.
    """
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from app.models.book import Book, Page, TextUnit, UnitType, PageStatus
    from app.services.image_analyzer import analyze_image

    engine = create_engine(settings.sync_database_url)

    try:
        with Session(engine) as db:
            page = db.query(Page).filter(Page.id == page_id).first()
            if not page:
                logger.error(f"Page {page_id} not found")
                return {"status": "error", "message": "Page not found"}

            # Update status to analyzing
            page.analysis_status = PageStatus.ANALYZING
            db.commit()

            # Run image analysis
            full_image_path = os.path.join(settings.MEDIA_DIR, image_path)
            units = analyze_image(full_image_path)

            if not units:
                page.analysis_status = PageStatus.ERROR
                page.analysis_error = "OCR dan hech qanday text topilmadi"
                db.commit()
                return {"status": "error", "message": "No text found"}

            # Delete existing draft units (if re-analyzing)
            db.query(TextUnit).filter(
                TextUnit.page_id == page_id,
                TextUnit.is_manual == False
            ).delete(synchronize_session='fetch')

            # Create text unit records
            from app.api.deps import UNIT_TYPE_MAP
            for unit_data in units:
                unit = TextUnit(
                    page_id=page_id,
                    unit_type=UNIT_TYPE_MAP.get(unit_data.unit_type, UnitType.WORD),
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
            page.has_text_data = True
            page.analysis_error = None
            db.commit()

            logger.info(f"Page {page_id} analysis complete: {len(units)} units")
            return {
                "status": "success",
                "page_id": page_id,
                "units_count": len(units),
            }

    except Exception as e:
        logger.error(f"Page analysis failed for page {page_id}: {e}")
        try:
            with Session(engine) as db:
                page = db.query(Page).filter(Page.id == page_id).first()
                if page:
                    page.analysis_status = PageStatus.ERROR
                    page.analysis_error = str(e)
                    db.commit()
        except Exception:
            pass
        self.retry(exc=e)
