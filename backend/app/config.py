import secrets

from pydantic_settings import BaseSettings
from pydantic import field_validator
from functools import lru_cache
from typing import List, Optional


class Settings(BaseSettings):
    """Application configuration settings."""

    # App settings
    APP_NAME: str = "YouTube Music Player API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # API settings
    API_V1_PREFIX: str = "/api/v1"

    # Security
    SECRET_KEY: str = ""
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS — comma-separated allowed origins
    CORS_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/musicplayer"

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    CACHE_TTL_SECONDS: int = 3600  # 1 hour

    # YouTube settings
    YOUTUBE_AUDIO_FORMAT: str = "bestaudio/best"
    YOUTUBE_VIDEO_FORMAT: str = "bestvideo+bestaudio/best"

    @field_validator("SECRET_KEY", mode="before")
    @classmethod
    def _ensure_secret_key(cls, v: str) -> str:
        if not v or v in (
            "your-super-secret-key-change-in-production",
            "change-me-to-a-random-secret-key",
        ):
            # Auto-generate a strong key (logged as warning at startup)
            import logging
            key = secrets.token_urlsafe(64)
            logging.getLogger(__name__).warning(
                "SECRET_KEY not set or using default — generated a random key. "
                "Set SECRET_KEY in .env for stable tokens across restarts."
            )
            return key
        return v

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
