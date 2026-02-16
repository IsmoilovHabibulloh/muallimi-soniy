"""Application configuration via environment variables."""

from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # App
    APP_NAME: str = "Muallimi Soniy"
    APP_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "production"
    DEBUG: bool = False

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://muallimi:password@postgres:5432/muallimi_soniy"
    DATABASE_URL_SYNC: str = ""

    # Redis
    REDIS_URL: str = "redis://redis:6379/0"

    # Celery
    CELERY_BROKER_URL: str = "redis://redis:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://redis:6379/2"

    # Auth
    ADMIN_USERNAME: str = "admin"
    ADMIN_PASSWORD: str = ""
    JWT_SECRET_KEY: str = ""
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 480

    # Telegram
    TELEGRAM_BOT_TOKEN: str = ""
    TELEGRAM_CHAT_IDS: str = ""

    # CORS
    ALLOWED_ORIGINS: str = "http://localhost:8888"

    # Media
    MEDIA_BASE_URL: str = "http://localhost:8888/media"
    MEDIA_DIR: str = "/app/media"
    MAX_UPLOAD_SIZE_MB: int = 100

    @property
    def allowed_origins_list(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    @property
    def telegram_chat_ids_list(self) -> List[str]:
        return [c.strip() for c in self.TELEGRAM_CHAT_IDS.split(",") if c.strip()]

    @property
    def sync_database_url(self) -> str:
        if self.DATABASE_URL_SYNC:
            return self.DATABASE_URL_SYNC
        return self.DATABASE_URL.replace("+asyncpg", "")

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()
