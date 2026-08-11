"""애플리케이션 설정 (architecture.md §5).

설정은 OS 무관하게 .env 로 주입한다. 접근은 항상 get_settings() 로 한다.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # DB
    database_url: str | None = None

    # JWT
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 30

    # CORS
    cors_origins: str = "http://localhost:5173"

    # URL
    frontend_url: str = "http://localhost:5173"
    backend_public_url: str = "http://localhost:8000"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
