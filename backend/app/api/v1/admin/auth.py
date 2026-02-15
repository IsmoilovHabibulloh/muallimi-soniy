"""Admin authentication endpoints."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.admin import AdminUser
from app.schemas.admin import AdminLogin, AdminTokenOut
from app.utils import verify_password, create_access_token
from app.config import get_settings

router = APIRouter(prefix="/auth", tags=["Admin Auth"])
settings = get_settings()


@router.post("/login", response_model=AdminTokenOut)
async def admin_login(data: AdminLogin, db: AsyncSession = Depends(get_db)):
    """Authenticate admin and return JWT token."""
    result = await db.execute(
        select(AdminUser).where(AdminUser.username == data.username)
    )
    admin = result.scalar_one_or_none()

    if not admin or not verify_password(data.password, admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Noto'g'ri foydalanuvchi nomi yoki parol",
        )

    # Update last login
    admin.last_login = datetime.now(timezone.utc)
    await db.flush()

    token = create_access_token(data={"sub": admin.username})

    return AdminTokenOut(
        access_token=token,
        expires_in=settings.JWT_EXPIRE_MINUTES * 60,
    )
