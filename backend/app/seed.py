"""Database seed: ensure admin user exists on startup."""

import asyncio
import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import AsyncSessionLocal
from app.models.admin import AdminUser
from app.utils import hash_password
from app.config import get_settings

logger = logging.getLogger("muallimi")
settings = get_settings()


async def ensure_admin_user():
    """Create default admin user if not exists."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(AdminUser).where(AdminUser.username == settings.ADMIN_USERNAME)
        )
        admin = result.scalar_one_or_none()

        if not admin:
            if not settings.ADMIN_PASSWORD:
                logger.warning("ADMIN_PASSWORD not set, skipping admin seed")
                return

            admin = AdminUser(
                username=settings.ADMIN_USERNAME,
                password_hash=hash_password(settings.ADMIN_PASSWORD),
            )
            db.add(admin)
            await db.commit()
            logger.info(f"Admin user '{settings.ADMIN_USERNAME}' created")
        else:
            logger.info(f"Admin user '{settings.ADMIN_USERNAME}' already exists")
