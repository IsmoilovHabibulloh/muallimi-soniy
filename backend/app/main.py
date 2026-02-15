"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import get_settings
from app.api.v1.router import router as v1_router
from app.middleware import RequestLoggingMiddleware
from app.middleware.rate_limit import RateLimitMiddleware

logger = logging.getLogger("muallimus")
settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown events."""
    # Startup: run seed if needed
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION} ({settings.ENVIRONMENT})")

    # Create tables if they don't exist
    try:
        from app.database import engine, Base
        from app.models.book import Book, Chapter, Page, TextUnit
        from app.models.admin import AdminUser
        from app.models.feedback import FeedbackSubmission
        from app.models.audio import AudioFile, AudioSegment, UnitSegmentMapping
        from app.models.system import SystemSettings, AuditLog, ManifestVersion
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables ensured")
    except Exception as e:
        logger.warning(f"Table creation error (non-fatal): {e}")

    # Ensure admin user exists
    try:
        from app.seed import ensure_admin_user
        await ensure_admin_user()
    except Exception as e:
        logger.warning(f"Seed error (non-fatal): {e}")

    # Seed book content if needed
    try:
        from app.seed_book import seed_book
        await seed_book()
    except Exception as e:
        logger.warning(f"Book seed error (non-fatal): {e}")

    yield

    # Shutdown
    logger.info("Shutting down")


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Muallimus Soniy — Ikkinchi Muallim. API for the Arabic learning book app.",
    docs_url="/docs" if settings.DEBUG or settings.ENVIRONMENT != "production" else None,
    redoc_url="/redoc" if settings.DEBUG or settings.ENVIRONMENT != "production" else None,
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list + (["*"] if settings.DEBUG else []),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(RateLimitMiddleware)

# API routes
app.include_router(v1_router)


# Health check
@app.get("/health", tags=["System"])
async def health_check():
    return {"status": "ok", "version": settings.APP_VERSION, "environment": settings.ENVIRONMENT}


@app.get("/version", tags=["System"])
async def version():
    return {"version": settings.APP_VERSION, "name": settings.APP_NAME}


# Global exception handler
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Unhandled error: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Ichki server xatosi. Iltimos, keyinroq urinib ko'ring."},
    )
