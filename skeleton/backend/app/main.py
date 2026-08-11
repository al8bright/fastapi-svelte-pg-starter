"""FastAPI 진입점 (architecture.md §4).

- /api/v1 버전 prefix
- CORS 미들웨어
- DB 스키마는 Alembic 으로만 관리한다 (§11). 여기서 create_all 을 호출하지 않는다.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import app.models  # noqa: F401  모델 메타데이터 등록
from app.api.v1.router import api_router
from app.config import get_settings


@asynccontextmanager
async def lifespan(_: FastAPI):
    # 시작 훅: 기본 관리자(admin/admin123) 시드. DB 스키마 생성은 Alembic(upgrade head)으로 수행한다.
    # 테이블이 아직 없거나 DB 미연결이면 조용히 건너뛴다(스캐폴드 직후 등).
    from app.db.session import SessionLocal
    from app.services import user_service

    try:
        with SessionLocal() as db:
            user_service.ensure_admin(db)
    except Exception:  # noqa: BLE001  시드 실패가 서버 기동을 막지 않게 한다.
        pass
    yield


settings = get_settings()
app = FastAPI(title="__PROJECT_NAME__ API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list or ["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")
