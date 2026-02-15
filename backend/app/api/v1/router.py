"""Main API v1 router aggregating all sub-routers."""

from fastapi import APIRouter

from app.api.v1.book import router as book_router
from app.api.v1.manifest import router as manifest_router
from app.api.v1.feedback import router as feedback_router
from app.api.v1.admin.auth import router as admin_auth_router
from app.api.v1.admin.book import router as admin_book_router
from app.api.v1.admin.audio import router as admin_audio_router
from app.api.v1.admin.settings import router as admin_settings_router

router = APIRouter(prefix="/api/v1")

# Public endpoints
router.include_router(book_router)
router.include_router(manifest_router)
router.include_router(feedback_router)

# Admin endpoints
admin_router = APIRouter(prefix="/admin")
admin_router.include_router(admin_auth_router)
admin_router.include_router(admin_book_router)
admin_router.include_router(admin_audio_router)
admin_router.include_router(admin_settings_router)

router.include_router(admin_router)
