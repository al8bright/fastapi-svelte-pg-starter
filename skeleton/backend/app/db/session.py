"""요청 단위 DB 세션 (architecture.md §7).

엔진/세션 팩토리는 .env 의 DATABASE_URL 로부터 모듈 로드 시 1회 생성한다.
"""
from sqlalchemy.orm import Session, sessionmaker

from app.config import get_settings
from app.db.engine import create_engine_from_settings

engine = create_engine_from_settings(get_settings())
SessionLocal: sessionmaker[Session] = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)
