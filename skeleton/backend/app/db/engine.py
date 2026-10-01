"""SQLAlchemy 엔진 팩토리 (ARCHITECTURE.md §7).

PostgreSQL 세션 타임존을 Asia/Seoul 로 고정한다 (§10 KST 단일 기준).
SQLite(테스트) / PostgreSQL(운영) 양쪽을 지원한다.
"""
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.pool import StaticPool

from app.config import Settings


def postgres_connect_args() -> dict[str, str]:
    return {"options": "-c timezone=Asia/Seoul"}


def create_engine_from_settings(settings: Settings) -> Engine:
    url = settings.database_url or "sqlite:///:memory:"
    kwargs: dict = {}
    if url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
        if ":memory:" in url:
            kwargs["poolclass"] = StaticPool
    elif "postgresql" in url:
        kwargs["connect_args"] = postgres_connect_args()
    return create_engine(url, pool_pre_ping=True, **kwargs)
