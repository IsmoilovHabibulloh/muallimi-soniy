"""Manifest endpoint with ETag support."""

import hashlib
from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.book import Book, Page, TextUnit
from app.models.audio import UnitSegmentMapping
from app.models.system import ManifestVersion
from app.config import get_settings

router = APIRouter(tags=["Manifest"])
settings = get_settings()


@router.get("/manifest")
async def get_manifest(request: Request, db: AsyncSession = Depends(get_db)):
    """Get current content manifest with ETag caching."""
    # Get book
    result = await db.execute(select(Book).limit(1))
    book = result.scalar_one_or_none()

    if not book:
        return {"version": 0, "book_id": 0, "total_pages": 0, "total_units": 0, "total_segments": 0}

    # Count entities
    pages_count = await db.scalar(
        select(func.count(Page.id)).where(Page.book_id == book.id)
    )
    units_count = await db.scalar(
        select(func.count(TextUnit.id)).join(Page).where(Page.book_id == book.id)
    )
    segments_count = await db.scalar(
        select(func.count(UnitSegmentMapping.id)).where(
            UnitSegmentMapping.is_published == True
        )
    )

    # Latest manifest version
    mv_result = await db.execute(
        select(ManifestVersion).order_by(ManifestVersion.version.desc()).limit(1)
    )
    mv = mv_result.scalar_one_or_none()

    manifest = {
        "version": book.manifest_version,
        "book_id": book.id,
        "total_pages": pages_count or 0,
        "total_units": units_count or 0,
        "total_segments": segments_count or 0,
        "published_at": mv.published_at.isoformat() if mv else None,
        "media_base_url": settings.MEDIA_BASE_URL,
    }

    # Generate ETag
    etag_content = f"v{book.manifest_version}-p{pages_count}-u{units_count}-s{segments_count}"
    etag = hashlib.md5(etag_content.encode()).hexdigest()

    # Check If-None-Match
    if_none_match = request.headers.get("If-None-Match")
    if if_none_match and if_none_match.strip('"') == etag:
        return Response(status_code=304, headers={"ETag": f'"{etag}"'})

    return Response(
        content=__import__("json").dumps(manifest),
        media_type="application/json",
        headers={
            "ETag": f'"{etag}"',
            "Cache-Control": "no-cache",
        },
    )
