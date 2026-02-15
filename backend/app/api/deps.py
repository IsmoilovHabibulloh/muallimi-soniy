"""API dependency functions."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database import get_db
from app.models.admin import AdminUser
from app.models.book import Book, UnitType
from app.utils import decode_access_token

security = HTTPBearer()

# Shared constant — used in image analysis, bulk unit updates, and rollback
UNIT_TYPE_MAP = {
    "letter": UnitType.LETTER,
    "word": UnitType.WORD,
    "sentence": UnitType.SENTENCE,
    "drill_group": UnitType.DRILL_GROUP,
    "divider": UnitType.DIVIDER,
}


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    """Dependency: extract and validate admin from JWT token."""
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token yaroqsiz yoki muddati o'tgan",
            headers={"WWW-Authenticate": "Bearer"},
        )

    username = payload.get("sub")
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token yaroqsiz",
        )

    result = await db.execute(
        select(AdminUser).where(AdminUser.username == username)
    )
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin topilmadi",
        )

    return admin


async def get_published_book(db: AsyncSession = Depends(get_db)) -> Book:
    """Dependency: get the single published book or raise 404."""
    result = await db.execute(
        select(Book).where(Book.is_published == True).limit(1)
    )
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=404, detail="Kitob topilmadi")
    return book


async def get_any_book(db: AsyncSession = Depends(get_db)) -> Book:
    """Dependency: get the single book (admin context, any status) or raise 404."""
    result = await db.execute(select(Book).limit(1))
    book = result.scalar_one_or_none()
    if not book:
        raise HTTPException(status_code=404, detail="Kitob topilmadi")
    return book
