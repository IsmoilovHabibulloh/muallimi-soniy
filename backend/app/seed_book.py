"""Seed the book with pages from Muallimi Soniy for native rendering."""

import asyncio
import logging
from sqlalchemy import select, delete, text
from app.database import AsyncSessionLocal
from app.models.book import Book, Chapter, Page, TextUnit, UnitType
from app.seed_book_data import PAGES

logger = logging.getLogger("muallimi")

# Advisory lock ID to prevent multiple workers from seeding simultaneously
SEED_LOCK_ID = 123456789


def get_page_content(page_num: int) -> list[dict]:
    """Return list of text_unit dicts for a given page number.
    
    Pages 1-2: Each tuple is already one unit (no splitting needed).
    Pages 3+: Splits letter/word entries by whitespace so each character
    or word becomes its own TextUnit. Sentences stay as-is.
    """
    raw = PAGES.get(page_num, [])
    units = []
    order = 0

    # Pages 1 and 2: each tuple = one unit, no splitting
    if page_num <= 2:
        for text_content, section, unit_type in raw:
            units.append({
                "text": text_content,
                "section": section,
                "type": unit_type,
                "order": order,
            })
            order += 1
        return units

    # Pages 3+: split letters/words by whitespace
    for raw_order, (text_content, section, unit_type) in enumerate(raw):
        if unit_type == "sentence":
            # Sentences stay whole
            units.append({
                "text": text_content,
                "section": section,
                "type": unit_type,
                "order": order,
            })
            order += 1
        else:
            # Split letters/words by whitespace
            parts = text_content.split()
            for col, part in enumerate(parts):
                units.append({
                    "text": part,
                    "section": section,
                    "type": unit_type,
                    "order": order,
                    "grid": {"row": raw_order, "col": col},
                })
                order += 1
    return units


async def seed_book():
    """Create or update the book with pages from PAGES dict.
    
    Uses PostgreSQL advisory lock to prevent race conditions
    when multiple gunicorn workers start simultaneously.
    """
    page_numbers = sorted(PAGES.keys())  # [1, 2, ..., 18]
    total_pages = len(page_numbers)

    async with AsyncSessionLocal() as db:
        # Try to acquire advisory lock (non-blocking)
        result = await db.execute(
            text(f"SELECT pg_try_advisory_lock({SEED_LOCK_ID})")
        )
        got_lock = result.scalar()
        if not got_lock:
            logger.info("Another worker is seeding, skipping...")
            return

        try:
            # Check if book exists
            result = await db.execute(select(Book).limit(1))
            book = result.scalar_one_or_none()

            if not book:
                book = Book(
                    title="المُعَلِّمُ الثَّانِي",
                    description="Ikkinchi Muallim — Arab alifbosi va o'qish darsligi",
                    author="Muallimi Soniy",
                    total_pages=total_pages,
                    manifest_version=1,
                    is_published=True,
                )
                db.add(book)
                await db.flush()
                logger.info(f"Book created: {book.title}")
            else:
                logger.info(f"Book exists: {book.title} (id={book.id})")

            # Create chapter if not exists
            result = await db.execute(select(Chapter).where(Chapter.book_id == book.id))
            chapters = result.scalars().all()
            if not chapters:
                ch = Chapter(
                    book_id=book.id,
                    title="الدَّرْسُ الْأَوَّلُ",
                    sort_order=0,
                    start_page=page_numbers[0],
                    end_page=page_numbers[-1],
                )
                db.add(ch)
                await db.flush()
                logger.info("Chapter created")

            # Check if pages already exist — if so, SKIP seeding to preserve data
            result = await db.execute(
                select(Page).where(Page.book_id == book.id).limit(1)
            )
            existing_page = result.scalar_one_or_none()
            if existing_page:
                logger.info("Pages already exist, skipping seed to preserve data.")
                await db.commit()
                return

            # Only create pages if NONE exist (first-time setup)
            for pn in page_numbers:
                page = Page(
                    book_id=book.id,
                    page_number=pn,
                    layout_type="native",
                    has_text_data=True,
                    is_annotated=True,
                )
                db.add(page)
                await db.flush()

                content = get_page_content(pn)
                for item in content:
                    unit_type = {
                        "letter": UnitType.LETTER,
                        "word": UnitType.WORD,
                        "sentence": UnitType.SENTENCE,
                    }[item["type"]]
                    meta = {"section": item["section"]}
                    if "grid" in item:
                        meta["grid"] = item["grid"]
                    unit = TextUnit(
                        page_id=page.id,
                        unit_type=unit_type,
                        text_content=item["text"],
                        bbox_x=0, bbox_y=0, bbox_w=0, bbox_h=0,
                        sort_order=item["order"],
                        is_manual=False,
                        metadata_=meta,
                    )
                    db.add(unit)

                logger.info(f"  Page {pn}: {len(content)} units created")

            await db.commit()
            logger.info(f"Book seeding complete! {total_pages} pages created.")

        finally:
            # Release advisory lock
            await db.execute(
                text(f"SELECT pg_advisory_unlock({SEED_LOCK_ID})")
            )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(seed_book())
