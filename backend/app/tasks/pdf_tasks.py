"""Async PDF processing tasks."""

import logging
import os

from app.tasks.celery_app import celery_app
from app.config import get_settings

logger = logging.getLogger("muallimus")
settings = get_settings()


@celery_app.task(bind=True, max_retries=2, default_retry_delay=30)
def process_pdf_task(self, pdf_path: str):
    """Process uploaded PDF: render pages + extract text."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session
    from app.database import Base
    from app.models.book import Book, Page, TextUnit, UnitType
    from app.services.pdf_import import render_pdf_pages, extract_text_units

    engine = create_engine(settings.sync_database_url)

    try:
        # Render pages
        output_dir = os.path.join(settings.MEDIA_DIR, "pages")
        pages_info = render_pdf_pages(pdf_path, output_dir)

        with Session(engine) as db:
            # Create or get book
            book = db.query(Book).first()
            if not book:
                book = Book(
                    title="Muallimus Soniy",
                    description="Ahmad Xodiy Maqsudiy — Muallimus Soniy (Ikkinchi Muallim)",
                    author="Ahmad Xodiy Maqsudiy",
                    total_pages=len(pages_info),
                )
                db.add(book)
                db.flush()
            else:
                book.total_pages = len(pages_info)

            # Create page records
            for pinfo in pages_info:
                existing = db.query(Page).filter(
                    Page.book_id == book.id,
                    Page.page_number == pinfo["page_number"]
                ).first()

                if existing:
                    existing.image_path = pinfo["image_path"]
                    existing.image_2x_path = pinfo["image_2x_path"]
                    existing.image_width = pinfo["width"]
                    existing.image_height = pinfo["height"]
                    page = existing
                else:
                    page = Page(
                        book_id=book.id,
                        page_number=pinfo["page_number"],
                        image_path=pinfo["image_path"],
                        image_2x_path=pinfo["image_2x_path"],
                        image_width=pinfo["width"],
                        image_height=pinfo["height"],
                    )
                    db.add(page)
                    db.flush()

                # Try extracting text units
                units = extract_text_units(pdf_path, pinfo["page_number"])
                if units:
                    page.has_text_data = True
                    for uinfo in units:
                        text_unit = TextUnit(
                            page_id=page.id,
                            unit_type=UnitType(uinfo["unit_type"]),
                            text_content=uinfo["text_content"],
                            bbox_x=uinfo["bbox_x"],
                            bbox_y=uinfo["bbox_y"],
                            bbox_w=uinfo["bbox_w"],
                            bbox_h=uinfo["bbox_h"],
                            sort_order=uinfo["sort_order"],
                            is_manual=False,
                        )
                        db.add(text_unit)

            db.commit()
            logger.info(f"PDF processing complete: {len(pages_info)} pages")

        return {"status": "success", "pages": len(pages_info)}

    except Exception as e:
        logger.error(f"PDF processing failed: {e}")
        self.retry(exc=e)
