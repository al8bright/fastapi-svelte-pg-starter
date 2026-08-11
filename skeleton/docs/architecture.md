# 프로젝트 공통 아키텍처 가이드

> 본 문서는 **이 템플릿으로 만드는 모든 웹 프로젝트**가 따르는 공통 표준이다.
> 표준 스택은 **FastAPI(백엔드) + SvelteKit/Vite(프론트엔드) + PostgreSQL**이며,
> 인증은 **자체 계정 또는 OIDC SSO**, 시각은 **KST 단일 기준**을 따른다.

---

## ★ 핵심 MUST 요약 (반드시 고정)

> 아래 항목은 **프로젝트마다 바뀌지 않는 고정 규칙**이다. 어기려면 `docs/architecture.md`에 사유를 남기되, ⛔ 표시 항목은 예외 없이 금지한다.
> 세부 내용은 각 섹션(§) 참조.

| # | 고정 규칙 (MUST) | § |
|---|------------------|---|
| 1 | **표준 스택 고정**: 백엔드 FastAPI 0.115 + SQLAlchemy 2.0 + Alembic, 프론트 SvelteKit(SPA) + Svelte 5 + Vite + TS, DB는 **PostgreSQL** | §2 |
| 2 | **DB는 항상 Alembic으로만 관리** — 모든 스키마 생성·변경은 마이그레이션. ⛔ dev/운영 런타임 `create_all`·자동 DDL·수동 `ALTER` 금지(테스트 in-memory만 예외) | §11 |
| 3 | **설정은 OS 무관하게 `.env`로 주입** — 동일 `.env`가 Windows/mac/Linux에서 동작. ⛔ 개발 중 `$env:`/`export`/`set` 셸 환경변수 의존 금지. ⛔ `.env` 커밋 금지(`.env.example`만) | §5, §17 |
| 4 | **시각은 KST 단일 기준** — `now()`는 naive `datetime.now()`, PostgreSQL `connect_args`에 `timezone=Asia/Seoul`, 런타임 `TZ=Asia/Seoul`. ⛔ UTC 변환/`ZoneInfo` 신규 도입 금지 | §10, §7 |
| 5 | **API 경로 `/api/v1` 고정** — 버전 prefix는 `main.py`에서, 라우터는 `api/v1/router.py`로 집계 | §4 |
| 6 | **설정 접근은 `get_settings()` + `@lru_cache`** — ⛔ 모듈 전역 `settings` 싱글톤 금지 | §5 |
| 7 | **공통 의존성은 `app/dependencies.py` 단일 파일** (`get_db`, `get_current_user` 등) | §6 |
| 8 | **계층 분리** — 라우터(`api/`)는 HTTP만 얇게, 도메인 로직은 `services/`, 검증/직렬화는 `schemas/` | §4, §8 |
| 9 | **프론트 표준 스택 고정**: axios + `@tanstack/svelte-query` + Svelte 5 runes. ⛔ 서버 상태를 `$state`+`$effect`로 직접 패칭 금지 | §2, §13 |
| 10 | **패키지 매니저는 pnpm** — ⛔ npm 사용 금지 | §2 |
| 11 | **인증은 Bearer JWT** — `Authorization: Bearer <token>`, 검증 실패 시 401 | §9 |
| 12 | **테스트는 pytest + SQLite in-memory** — `get_settings.cache_clear()` autouse, `dependency_overrides`로 격리 | §12 |
| 13 | **TDD + Tidy First** — Red→Green→Refactor, 구조 변경과 동작 변경을 한 커밋에 섞지 않음 | §18 |
| 14 | **커밋 메시지**: `[Structural]`/`[Behavioral]` + conventional type, 테스트·린트 통과 시에만 | §19 |
| 15 | **변경은 브랜치→PR→CI 통과→머지** — ⛔ `main` 직접 푸시 금지, 1 PR은 Structural·Behavioral 중 하나만 | §20 |

---

## 0. 적용 범위 & 우선순위

- **MUST**: 신규 프로젝트는 반드시 따른다.
- **SHOULD**: 특별한 사유가 없으면 따른다. 벗어나면 `docs/architecture.md`에 사유를 남긴다.
- **MAY**: 프로젝트 성격에 따라 선택한다.
- 본 가이드와 개별 프로젝트 문서가 충돌하면 **본 가이드 우선**. 예외는 프로젝트 `docs/architecture.md`에 명시한다.

---

## 1. 프로젝트 명명 규칙

| 대상 | 규칙 | 예시 |
|------|------|------|
| **저장소/루트 폴더** | `PascalCase` 또는 `snake_case` 일관 유지(프로젝트 내 통일) | `MyProject`, `my_project` |
| **FastAPI app title** | `"<프로젝트> API"` | `FastAPI(title="my_project API", version="0.1.0")` |
| **PostgreSQL DB명** | `snake_case`, 프로젝트명 기반 | `my_project`, `shop` |
| **DB 테이블명** | `snake_case` **복수형**. 외부 시스템 연동 테이블은 접미사로 출처 표기 | `admins`, `events`, `orders_ext` |
| **Python 모듈 파일** | `snake_case`, 모델은 **단수** | `order.py`, `auth_service.py` |
| **프론트 컴포넌트 파일** | `PascalCase.svelte`, 파일명 = 컴포넌트명 | `LoginForm.svelte`, `EventCalendar.svelte` |
| **프론트 라우트 파일** | SvelteKit 규약 고정(소문자) — `+page.svelte` / `+layout.svelte` / `+layout.ts` | `routes/login/+page.svelte` |
| **프론트 라우트 디렉토리** | `kebab-case` (URL 세그먼트가 그대로 됨). 라우트 그룹은 괄호 | `routes/my-page/`, `routes/(protected)/` |
| **환경변수 접두** | 백엔드는 `UPPER_SNAKE`, 프론트는 `VITE_` 필수 | `DATABASE_URL`, `VITE_API_BASE_URL` |
| **토큰 저장 키** | `<project>_token` / `<project>_access_token` 으로 충돌 방지 | `my_project_token`, `shop_access_token` |

> 프론트 환경변수는 SvelteKit 의 `$env/static/public` + `PUBLIC_` 이 아니라 **`VITE_` 접두 + `import.meta.env` 를 계속 쓴다.**
> 이유: 본 스택은 SSR 없는 순수 SPA 이고, 백엔드/원본 프로젝트와 **동일한 `.env` 파일 호환**을 유지하기 위해서다.

---

## 2. 기술 스택 표준

### 백엔드
- **언어/런타임**: Python 3.10+ (`X | None` 문법, `Mapped[]` 타입 힌트 사용)
- **프레임워크**: FastAPI 0.115.x + Uvicorn(`[standard]`)
- **ORM/마이그레이션**: SQLAlchemy 2.0 (`Mapped`/`mapped_column`) + Alembic
- **DB 드라이버**: PostgreSQL + `psycopg2-binary`
- **설정**: `pydantic-settings` (BaseSettings)
- **검증/직렬화**: Pydantic 2.x
- **인증**: JWT. **자체 계정 → `PyJWT`**, **OIDC/SSO 연동 → `python-jose[cryptography]`**
- **테스트**: `pytest` + SQLite in-memory
- **HTTP 클라이언트(서버↔서버)**: `httpx2` (httpx 의 유지보수 후속, Starlette 1.x TestClient 호환)
- **버전 고정**: `requirements.txt`에 **`==` 정확한 버전 핀** (재현성 우선)

### 프론트엔드
- **빌드/런타임**: SvelteKit 2.70 (**SPA 모드**) + Svelte 5.56 + Vite 8.2 (Rolldown) + TypeScript 6.0
  - SPA 고정: `@sveltejs/adapter-static({ fallback: 'index.html' })` + 루트 `+layout.ts`의 `export const ssr = false`.
    백엔드가 별도 FastAPI 서버이고 JWT를 `localStorage`에 두므로 **SSR을 쓰지 않는다.**
- **라우팅**: **SvelteKit 파일 기반 라우팅**(`src/routes/`). 라우트 그룹 `(protected)`로 인증 가드(§14)
- **HTTP**: `axios` (인스턴스 + interceptor)
- **서버 상태**: `@tanstack/svelte-query` 6.1 (캐싱/재요청/무효화)
- **클라이언트 상태**: **Svelte 5 runes(`$state`)** — 토큰·세션 등 경량 전역 상태는 `.svelte.ts` 모듈에 둔다. **별도 상태 라이브러리를 쓰지 않는다.**
- **스타일**: Tailwind CSS v4 (CSS-first `@theme`)
- **패키지 매니저**: **pnpm** (npm 금지)
- **타입 체크**: `svelte-check` (`tsc -b` 대체) — `pnpm check` = `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json`
- **린트**: ESLint + typescript-eslint + `eslint-plugin-svelte`

> 프론트 표준 스택은 **axios + @tanstack/svelte-query + Svelte 5 runes**로 통일한다.
> 매우 단순한 화면만 있는 소규모 도구는 `fetch + runes($state)`만으로 처리하는 것을 MAY로 허용하되,
> 그 사유를 `docs/architecture.md`에 남긴다.

---

## 3. 저장소 구조(목표)

```
<ProjectName>/
├── backend/
│   ├── app/
│   ├── alembic/
│   ├── alembic.ini
│   ├── requirements.txt
│   ├── pytest.ini
│   └── tests/
├── frontend/
│   ├── src/
│   ├── package.json
│   ├── svelte.config.js
│   └── vite.config.ts
├── docs/
│   ├── architecture.md          # 본 가이드에서 벗어난 결정/사유 기록
│   └── <연동>-가이드.md          # 선택 (SSO 등 외부 연동)
├── plan.md                      # TDD 작업 순서 (필수)
├── .env.example
└── README.md
```

- 루트에 `plan.md`를 두고 **TDD 작업 순서**(실패 테스트 단위)를 관리한다.
- 환경값은 `.env.example`로 키만 공유하고 실제 `.env`는 커밋하지 않는다.

---

## 4. 백엔드 구조(`backend/app/`)

```
backend/app/
├── __init__.py
├── main.py                 # FastAPI 진입점, lifespan, 미들웨어, 라우터 등록
├── config.py               # Settings(BaseSettings) + get_settings()
├── dependencies.py         # get_db, get_current_user 등 공통 의존성  ★단일 파일
├── api/
│   ├── v1/                 # ★ /api/v1 버전 디렉토리
│   │   ├── router.py       # 하위 라우터 집계
│   │   ├── auth.py         # SSO 시작 / 콜백 / 세션
│   │   ├── health.py
│   │   └── <domain>.py     # 도메인별 APIRouter (얇은 HTTP 계층)
│   └── ...
├── core/
│   └── security.py         # JWT 생성/검증, now() (KST naive)
├── db/
│   ├── base.py             # DeclarativeBase (Base)
│   ├── engine.py           # 엔진 팩토리 (SQLite/PG 분기, KST connect_args)
│   └── session.py          # get_db 세션 / SessionLocal
├── models/
│   ├── __init__.py         # 모든 모델 re-export (Alembic/메타데이터 등록용)
│   └── <domain>.py
├── schemas/
│   └── <domain>.py         # Pydantic BaseModel (요청/응답)
└── services/
    ├── <domain>_service.py # 비즈니스 로직
    └── exceptions.py       # ServiceError 등 도메인 예외
```

### 계층 규칙 (MUST)
- **라우터(`api/`)는 얇게**: HTTP 입출력·인증·상태코드만. 비즈니스 로직 금지.
- **도메인 로직은 `services/`**: DB 트랜잭션, 규칙 검증, 외부 연동.
- **`schemas/`**: Pydantic 검증·직렬화 전용. ORM 모델과 분리.
- **의존성 주입**: DB 세션·현재 사용자는 항상 `Depends()`로 주입.

### `main.py` 표준 형태
```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.config import get_settings

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    import app.models  # 모델 메타데이터 등록
    # 엔진/세션 팩토리 초기화는 app.state 또는 db 모듈에서
    yield

app = FastAPI(title="<Project> API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")   # ★ 버전 prefix는 여기서

@app.get("/api/v1/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

### 라우터 집계 (`api/v1/router.py`)
```python
from fastapi import APIRouter
from app.api.v1 import auth, health, orders   # 도메인 모듈

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(health.router)
api_router.include_router(orders.router)
```

---

## 5. 설정 (`config.py`)  — `get_settings()` + `@lru_cache`

```python
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore",
    )

    # DB
    database_url: str | None = None

    # JWT
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 30

    # CORS
    cors_origins: str = "http://localhost:5173"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

규칙:
- **접근은 항상 `get_settings()` 함수로** (모듈 전역 `settings` 싱글톤 금지).
  → 테스트에서 `get_settings.cache_clear()`로 환경을 재설정할 수 있어야 한다.
- 파생 값은 `@property`(예: `cors_origin_list`)로 노출한다.
- 환경변수명이 필드명과 다르면 `Field(validation_alias=...)`로 명시한다.

### 설정 주입은 항상 `.env` — OS 독립 (MUST)

> **개발 환경 설정은 OS에 관계없이 반드시 프로젝트 루트의 `.env` 파일로 주입한다.**
> Windows/macOS/Linux 어디서든 **동일한 `.env` 파일**로 동작해야 한다.

- 백엔드: `pydantic-settings`가 `.env`를 로드한다(`env_file=".env"`). 코드에 설정값 하드코딩 금지.
- 프론트엔드: Vite가 `.env`의 `VITE_*`를 로드한다(§17). `import.meta.env`로만 접근.
- **금지(MUST NOT)**: 개발 중 OS별 셸 환경변수 설정에 의존하는 방식.
  - PowerShell `$env:VAR=...`, bash `export VAR=...`, `set VAR=...` 등으로 **셸에 값을 심어두고 실행하는 것** — OS·셸마다 달라 재현되지 않는다.
  - `launch.json`/IDE 설정·OS 사용자 환경변수에 비밀값을 박아두는 것.
- **예외**: 컨테이너/CI/배포 런타임에서 **오케스트레이터가 주입하는 실제 환경변수는 허용**(이때도 `pydantic-settings`가 `.env`와 동일 인터페이스로 읽으므로 코드 변경 불필요). 즉, **로컬 개발은 `.env` 강제**, 운영은 동일 키를 환경변수로 주입.
- `.env`는 **커밋 금지(`.gitignore`)**, `.env.example`에 **키만** 채워 커밋한다(§17).
- 줄바꿈/인코딩은 `UTF-8`로 통일하고, `.env`는 OS별로 갈라지지 않게 저장소에 `.gitattributes`로 `* text=auto eol=lf`를 권장한다.

---

## 6. 의존성 주입 (`app/dependencies.py`)  ★단일 파일

```python
from collections.abc import Generator
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.core.security import decode_access_token

def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_current_user(token: str = Depends(...), db: Session = Depends(get_db)):
    cred_error = HTTPException(status.HTTP_401_UNAUTHORIZED, "인증이 필요합니다.")
    payload = decode_access_token(token)
    if payload is None or "sub" not in payload:
        raise cred_error
    user = ...  # services 통해 조회
    if user is None:
        raise cred_error
    return user
```

- 공통 의존성(`get_db`, `get_current_user`, 권한 체크 등)은 **`app/dependencies.py` 한 곳**에 모은다.

---

## 7. DB · 세션 · 엔진

`app/db/engine.py` (엔진 팩토리 — SQLite 테스트/PostgreSQL 운영 동시 지원):
```python
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.pool import StaticPool
from app.config import Settings

def postgres_connect_args() -> dict[str, str]:
    return {"options": "-c timezone=Asia/Seoul"}   # ★ KST 고정

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
```

`app/db/base.py`:
```python
from sqlalchemy.orm import DeclarativeBase
class Base(DeclarativeBase):
    pass
```

`app/db/session.py`: 요청 단위 세션을 제공한다(`SessionLocal` 또는 `get_db`).
**PostgreSQL 연결에는 반드시 `timezone=Asia/Seoul` connect_args를 적용한다.**

---

## 8. 모델 · 스키마 · 서비스 규칙

### 모델 (`models/`) — SQLAlchemy 2.0 `Mapped`
```python
from datetime import datetime
from sqlalchemy import DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column
from app.core.security import now
from app.db.base import Base

class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    status: Mapped[str] = mapped_column(String(20), default="draft")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=now, onupdate=now)
```
- 모든 모델은 `models/__init__.py`에서 import(re-export)하여 메타데이터에 등록한다.
- 생성·수정 시각은 `default=now`(KST naive). 열거형은 `str, enum.Enum`을 상속.

### 스키마 (`schemas/`)
- `XxxBase` → `XxxCreate`/`XxxUpdate`/`XxxRead` 상속 패턴.
- 제약은 `Field(ge=, gt=, max_length=)`, 복합 규칙은 `@field_validator`.

### 서비스 (`services/`)
- 함수형 서비스(`def create_order(db, user, data)`)를 기본으로 한다.
- 실패는 `ServiceError(code=...)` 같은 **도메인 예외**로 던지고, 라우터에서 HTTP로 변환.
- N+1 방지: 조회 시 `selectinload` 등 명시적 로딩 옵션.

---

## 9. 인증 (JWT · SSO)

- `core/security.py`에 토큰 생성/검증과 `now()`를 둔다.
- **자체 계정**: access/refresh 토큰 분리(`typ` 클레임), `PyJWT`.
- **OIDC SSO 연동**: 백엔드가 authorize→callback→userinfo 처리 후 앱 세션 JWT 발급, `python-jose`.
- 토큰은 `Authorization: Bearer <token>` 헤더. 검증 실패는 401 + `WWW-Authenticate: Bearer`.
- 최초 로그인 시 `provision_from_userinfo()`로 사용자 upsert(없으면 생성, 식별정보 갱신).

---

## 10. 날짜·시간 (KST)  — MUST

- **기준**: 저장·표시되는 업무 일자는 **KST**로 통일. 애플리케이션에 UTC↔KST 변환 레이어를 두지 않는다.
- **PostgreSQL**: 엔진 `connect_args`에 `options="-c timezone=Asia/Seoul"`.
- **FastAPI**: `app.core.security.now()`는 **naive `datetime.now()`만** 사용.
- **실행 환경**: API 프로세스에 **`TZ=Asia/Seoul`** 설정.
- **금지(신규 코드)**: `datetime.now(timezone.utc)`, `ZoneInfo` 기반 변환 추가.

---

## 11. 마이그레이션 (Alembic)  — MUST: DB는 항상 Alembic으로 관리

> **모든 DB 스키마는 예외 없이 Alembic 마이그레이션으로만 생성·변경한다.**
> 개발·스테이징·운영 어느 환경에서도 동일하다. 스키마의 단일 진실 공급원(SSOT)은 마이그레이션 히스토리다.

- `alembic/env.py`에서 `app.config.get_settings()`의 DB URL과 `Base.metadata`를 사용한다.
- `import app.models`로 모든 모델을 로드한 뒤 `target_metadata = Base.metadata`.
- `compare_type=True`, PostgreSQL은 `NullPool` 권장. offline/online 모두 지원.
- 모델 변경 시 워크플로:
  ```powershell
  alembic revision --autogenerate -m "<변경 요약>"   # 초안 생성
  # 생성된 versions/*.py 를 반드시 검토·수정 (autogenerate는 초안일 뿐)
  alembic upgrade head                               # 적용
  ```
- 모든 마이그레이션은 **`downgrade()`를 작성**하고, 가능하면 되돌릴 수 있게 한다.
- 마이그레이션 파일은 **반드시 커밋**한다. 머지 시 head가 갈라지면 `alembic merge`로 정리.

### 금지 (MUST NOT)
- **런타임 `Base.metadata.create_all()`로 운영/개발 스키마를 만드는 행위** — 단, **테스트(SQLite in-memory)에서만 예외 허용**(§12).
- `DATABASE_AUTO_DDL` 같은 **자동 DDL 플래그를 dev/prod에서 켜는 것**.
- DB 콘솔에서 직접 `ALTER TABLE` 등 **마이그레이션을 거치지 않은 수동 스키마 변경**.

---

## 12. 백엔드 테스트 (pytest)

- `pytest.ini`: `pythonpath = .`, `testpaths = tests`.
- DB는 **SQLite in-memory**, 테스트마다 `Base.metadata.create_all/drop_all`.
- `conftest.py`에 공통 픽스처:
  - `_clear_settings_cache` (autouse): `get_settings.cache_clear()`.
  - `db_session`, `client`(`app.dependency_overrides[get_db]` 오버라이드).
  - 인증 통과용 `auth_client`/`admin_client` (현재 사용자 의존성 오버라이드).

```python
@pytest.fixture(autouse=True)
def _clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
```

---

## 13. 프론트엔드 구조 (`frontend/src/`)

표준 스택: **axios + @tanstack/svelte-query + Svelte 5 runes**.

```
frontend/
├── .env.example
├── package.json
├── pnpm-workspace.yaml          # onlyBuiltDependencies (pnpm 10+ 빌드 스크립트 허용)
├── svelte.config.js             # adapter-static({ fallback: 'index.html' }) — SPA fallback
├── vite.config.ts               # @tailwindcss/vite + sveltekit(), /api dev proxy
├── tsconfig.json
├── eslint.config.js
├── .gitignore                   # .svelte-kit/, build/, node_modules/, .env 등
├── static/.gitkeep              # 정적 자산 (원본 public/ 대응)
└── src/
    ├── app.html                 # HTML 셸 — <title>, lang="ko", %sveltekit.head% / %sveltekit.body%
    ├── app.css                  # Tailwind v4 @import + @theme 토큰 + body 스타일
    ├── app.d.ts                 # SvelteKit App 네임스페이스 타입 선언
    ├── lib/
    │   ├── api/
    │   │   ├── client.ts        # ★ axios 인스턴스 + 요청/응답 interceptor (토큰 주입/401)
    │   │   ├── auth.ts          # login(), getMe() + User/UserRole/TokenResponse 타입
    │   │   └── health.ts        # getHealth(), getDbHealth() + DbHealth 타입
    │   ├── auth/
    │   │   └── token.ts         # getToken/setToken/clearToken — 토큰 localStorage 래퍼
    │   ├── queries/
    │   │   ├── auth.ts          # createLogin(), createMe()        — svelte-query
    │   │   └── health.ts        # createHealth(), createDbHealth() — svelte-query
    │   └── stores/
    │       └── auth.svelte.ts   # runes $state 전역 인증 스토어 (token, user)
    └── routes/
        ├── +layout.ts           # export const ssr = false; export const prerender = true;
        ├── +layout.svelte       # QueryClientProvider + app.css import (앱 부트스트랩)
        ├── login/
        │   └── +page.svelte     # /login
        └── (protected)/         # 라우트 그룹 — URL 에 영향 없음, 인증 가드 담당
            ├── +layout.ts       # 토큰 없으면 redirect(302, resolve('/login'))
            ├── +layout.svelte   # 보호 영역 공통 레이아웃 ({@render children()})
            ├── +page.svelte     # /          메인
            ├── landing/
            │   └── +page.svelte # /landing   백엔드·DB 상태
            └── my/
                └── +page.svelte # /my        내 정보·로그아웃
```

`lib/api/client.ts` (axios 표준):
```ts
import axios from "axios"
import { getToken, clearToken } from "$lib/auth/token"

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL
    ? `${import.meta.env.VITE_API_BASE_URL}/api/v1`
    : "/api/v1",
})

api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      clearToken()
      if (location.pathname !== "/login") location.href = "/login"
    }
    return Promise.reject(error)
  },
)
```

`lib/stores/auth.svelte.ts` (Svelte 5 runes — 전역 클라이언트 상태):
```ts
import type { User } from "$lib/api/auth"
import { clearToken, getToken, setToken } from "$lib/auth/token"

// 클라이언트 전역 상태 (architecture.md §13).
// runes 를 쓰는 TS 모듈이므로 파일 확장자는 반드시 `.svelte.ts`.
class AuthStore {
  token = $state<string | null>(getToken())
  user = $state<User | null>(null)

  setSession(token: string): void {
    setToken(token)
    this.token = token
  }

  setUser(user: User | null): void {
    this.user = user
  }

  logout(): void {
    clearToken()
    this.token = null
    this.user = null
  }

  // 함수가 아니라 getter 다 — 사용처에서 괄호 없이 `authStore.isAuthenticated`.
  get isAuthenticated(): boolean {
    return Boolean(this.token)
  }
}

export const authStore = new AuthStore()
```

`lib/queries/health.ts` (svelte-query):
```ts
import { createQuery } from "@tanstack/svelte-query"
import { getDbHealth, getHealth } from "$lib/api/health"

// svelte-query 쿼리 (architecture.md §13).
export function createHealth() {
  return createQuery(() => ({ queryKey: ["health"], queryFn: getHealth, retry: false }))
}

export function createDbHealth() {
  return createQuery(() => ({ queryKey: ["health", "db"], queryFn: getDbHealth, retry: false }))
}
```

`lib/queries/auth.ts` (뮤테이션):
```ts
import { createMutation } from "@tanstack/svelte-query"
import { getMe, login } from "$lib/api/auth"
import { authStore } from "$lib/stores/auth.svelte"

export function createLogin() {
  return createMutation(() => ({
    mutationFn: ({ username, password }: { username: string; password: string }) =>
      login(username, password),
    onSuccess: async (token) => {
      authStore.setSession(token.access_token)
      authStore.setUser(await getMe())
    },
  }))
}
```

`routes/+layout.svelte` (프로바이더는 최상위에 한 번만):
```svelte
<script lang="ts">
  import { QueryClient, QueryClientProvider } from "@tanstack/svelte-query"
  import type { Snippet } from "svelte"
  import "../app.css"

  const { children }: { children: Snippet } = $props()

  const queryClient = new QueryClient()
</script>

<QueryClientProvider client={queryClient}>
  {@render children()}
</QueryClientProvider>
```

**svelte-query v6 호출 규칙** (React 판과 다르다 — React 문서를 복붙하면 깨진다):
- 옵션은 객체가 아니라 **함수(accessor)** 로 넘긴다: `createQuery(() => ({ ... }))` / `createMutation(() => ({ ... }))`. 함수 본문이 runes 처럼 반응형으로 재평가된다.
- 반환값은 store 가 아니라 **rune 기반 반응형 객체**다 → `$query.data` 가 **아니라** `query.data` / `query.isPending` / `query.isSuccess` / `query.isError` 로 바로 접근한다.
- `createQuery`/`createMutation`/`useQueryClient` 는 **컴포넌트 초기화 시점(`<script>` 최상단)에서만** 호출한다. 이벤트 핸들러 안에서 호출하면 `No QueryClient was found in Svelte context` 로 터진다. (래퍼인 `lib/queries/*.ts` 는 자신이 룬을 쓰지 않으므로 평범한 `.ts` 여도 된다.)

규칙:
- **서버 상태는 svelte-query**(`createQuery`/`createMutation`), **직접 `$state`+`$effect`로 데이터 패칭 금지**.
- **클라이언트 상태(토큰·세션·UI)는 runes**(`$state`) — 전역은 `lib/stores/*.svelte.ts`, 지역은 컴포넌트 내 `$state`.
- API 함수는 `lib/api/<domain>.ts`에 모으고, 컴포넌트는 `lib/queries/`의 쿼리 팩토리를 통해 접근한다.

---

## 14. 프론트엔드 인증 흐름

- **SSO**: `routes/login/+page.svelte`에서 `window.location.href = ${VITE_BACKEND_URL}/api/v1/auth/login`.
- **콜백**: `routes/auth/callback/+page.svelte`가 토큰 수신 → `authStore.setSession(token)` → `/api/v1/auth/me`로 사용자 로드 → 홈 리다이렉트.
- **보호 라우트**: 라우트 그룹 `(protected)/`의 `+layout.ts` 가드가 담당한다(미인증 시 `redirect(302, resolve('/login'))`).
  그룹 이름은 괄호라서 **URL 에 나타나지 않는다** — 보호 대상 페이지를 이 디렉토리 아래로 옮기기만 하면 된다.
- 토큰은 `localStorage`(키: `<project>_token`). 401은 interceptor가 일괄 처리(§13).
- ⚠️ `lib/auth/token.ts` 의 `getToken`/`setToken`/`clearToken` 에는 **`$app/environment` 의 `browser` 가드가 필수**다.
  `ssr = false` 라도 빌드의 **prerender 단계는 Node 에서 돌아** `localStorage` 가 없다(가드가 없으면 빌드가 깨진다).
- ⚠️ 내부 이동 경로는 `$app/paths` 의 **`resolve()`** 로 감싼다(`href={resolve('/landing')}`, `goto(resolve('/'))`).
  `eslint-plugin-svelte@3` 의 `svelte/no-navigation-without-resolve` 가 recommended 기본 포함이라 안 감싸면 lint 에러다.

```
src/routes/
├── +layout.ts               # ssr = false / prerender = true (SPA 고정)
├── +layout.svelte           # QueryClientProvider + app.css
├── login/+page.svelte       # /login
├── auth/callback/+page.svelte   # /auth/callback (SSO 콜백 — SSO 도입 시 추가, 스캐폴드에는 없음)
└── (protected)/             # ★ 인증 가드 그룹 (URL 에 영향 없음)
    ├── +layout.ts           # 토큰 없으면 redirect(302, resolve('/login'))
    ├── +layout.svelte       # 공통 레이아웃 ({@render children()})
    ├── +page.svelte         # /
    ├── landing/+page.svelte # /landing
    └── my/+page.svelte      # /my
```

```ts
// src/routes/(protected)/+layout.ts
import { redirect } from "@sveltejs/kit"
import { browser } from "$app/environment"
import { resolve } from "$app/paths"
import { getToken } from "$lib/auth/token"

// prerender 단계(Node)에서는 browser 가 false 라 리다이렉트하지 않고 빈 셸만 만든다.
export const load = () => {
  if (browser && !getToken()) redirect(302, resolve("/login"))
}
```

---

## 15. 스타일 — Tailwind CSS v4

- **진입 CSS는 `src/app.css`** 한 곳. 루트 `src/routes/+layout.svelte`에서 한 번만 import 한다.
- **CSS-first**(`@import "tailwindcss"`) + `@theme`로 색상/폰트 토큰 정의. 별도 `tailwind.config.js` 지양.
- Vite 전용이면 `@tailwindcss/vite` 플러그인(설정 파일 불필요).
  PostCSS 파이프라인(autoprefixer 등)이 필요하면 `@tailwindcss/postcss` 허용.
- 공통 컴포넌트 클래스는 `@layer components`.
- 한글 UI 기본 폰트는 **Pretendard**(+ `Noto Sans KR` 폴백) 권장.

```css
@import "tailwindcss";
@theme {
  --font-sans: Pretendard, "Noto Sans KR", system-ui, sans-serif;
  --color-primary: #002045;
}
```

---

## 16. 네이밍 컨벤션 (요약)

| 대상 | 규칙 |
|------|------|
| Python 파일/함수/변수 | `snake_case` |
| Python 클래스 / Enum | `PascalCase` (Enum 멤버는 `UPPER_CASE`) |
| DB 테이블 | `snake_case` 복수형 |
| 서비스 파일 | `<domain>_service.py` |
| Svelte 컴포넌트 파일/이름 | `PascalCase.svelte`, 파일명 = 컴포넌트명 |
| 라우트 파일 | SvelteKit 규약 고정 — `+page.svelte` / `+layout.svelte` / `+layout.ts` (소문자) |
| 쿼리 함수 | `lib/queries/<domain>.ts` 의 `createXxx()` |
| runes 를 쓰는 TS 모듈 | 확장자 `.svelte.ts` 필수 (예: `lib/stores/auth.svelte.ts`) — 컴파일러가 `$state` 를 처리하려면 필요 |
| TS 타입/인터페이스 | `PascalCase`, 유니온은 리터럴(`'active' | 'closed'`) |
| 경로 별칭 | `$lib` → `src/lib` (SvelteKit 내장, 별도 설정 불필요) |
| API 경로 | `/api/v1/<resource>` (리소스 복수형) |

---

## 17. 환경변수 표준

> 모든 설정은 **`.env` 파일로 OS 독립적으로 주입**한다(강제 규칙은 §5 참조). 셸 환경변수에 의존하지 않는다.

### 백엔드 (`.env`)
| 키 | 용도 |
|----|------|
| `DATABASE_URL` | PostgreSQL 연결 (또는 `DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`) |
| `SECRET_KEY` / `JWT_*` | 토큰 서명, 만료 |
| `CORS_ORIGINS` | 콤마 구분 허용 출처 |
| `FRONTEND_URL`, `BACKEND_PUBLIC_URL` | 리다이렉트/콜백 |
| `OAUTH_*` | SSO(authorize/token/userinfo URL, client id/secret, redirect uri) |
| `TZ` | 실행 환경 `Asia/Seoul` |

### 프론트엔드 (`.env`, `VITE_` 필수)
| 키 | 용도 |
|----|------|
| `VITE_API_BASE_URL` | API 호스트 (없으면 dev proxy `/api/v1`) |
| `VITE_BACKEND_URL` | SSO 리다이렉트용 백엔드 호스트 |

- `.env`는 커밋 금지. `.env.example`에 **키만** 공유.

---

## 18. 개발 원칙 (TDD · Tidy First)

- **TDD 사이클**: Red → Green → Refactor. `plan.md` 순서대로 **한 번에 실패하는 테스트 하나**.
  결함도 API 레벨 실패 테스트부터 작성한다.
- **최소 구현**으로 Green을 만들고, **Refactor는 Green 상태에서만**.
- **Tidy First**: **구조 변경(Structural)과 동작 변경(Behavioral)을 분리**한다. 한 커밋에 섞지 않는다.
- **중복 제거**를 철저히, 메서드는 작게.
- **서비스 레이어**: 라우터는 얇게, 도메인 로직은 `services/`.
- **의존성 주입**: DB 세션·현재 주체는 `Depends()`로 주입.

---

## 19. 커밋 규칙

- **형식**: `[Category] <type>: <요약(한글, 50자 이내, 현재형)>`
- **Category**: `[Structural]`(구조 변경, 로직 불변) / `[Behavioral]`(기능·버그·로직 변경)
- **type**: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`
- 모든 테스트 통과 + 린트 경고 0일 때만 커밋한다.

예) `[Behavioral] feat: 주문 생성 API 추가`, `[Structural] refactor: 의존성 dependencies.py로 이동`

---

## 20. 브랜치 · PR 규칙 (GitHub)

> 변경은 **브랜치 → PR → CI 통과 → 머지** 흐름으로 반영한다. `main` 직접 푸시는 금지.
> 커밋의 Structural/Behavioral 분리 원칙(§18, §19)을 **PR 단위에서도 그대로** 지킨다.

### 브랜치 명명
- `feat/<요약>`, `fix/<요약>`, `refactor/<요약>`, `docs/<요약>` (kebab-case)
- 예: `feat/order-create`, `refactor/move-deps`

### PR 작성
- **제목**: 커밋과 동일 형식 `[Category] <type>: <요약>`.
- **하나의 PR은 Structural·Behavioral 중 하나만** 담는다(섞지 않는다).
- **작게 유지**: 리뷰 가능한 크기로 쪼갠다.
- **본문 템플릿** (`.github/pull_request_template.md`로 저장소에 둔다):
  ```markdown
  ## 요약
  <무엇을 왜 바꿨는지 1~3줄>

  ## 변경 유형
  - [ ] Structural (구조 변경, 동작 불변)
  - [ ] Behavioral (기능·버그·로직 변경)

  ## 테스트
  - 추가/수정한 테스트와 결과 (pytest, 프론트 등)

  ## 체크리스트
  - [ ] 모든 테스트 통과 + 린트 경고 0
  - [ ] Structural/Behavioral 를 섞지 않음
  - [ ] DB 변경 시 Alembic 마이그레이션 포함 (§11)
  - [ ] 설정 변경 시 `.env.example` 갱신 (§5, §17)
  ```

### 머지 규칙
- **CI(테스트·린트) 통과**를 머지 게이트로 한다. ⛔ 실패 상태 머지 금지.
- 셀프 머지는 허용하되, 머지 전 **본인 diff 셀프 리뷰**를 거친다(팀 협업 시 리뷰어 지정).
- 머지 후 브랜치는 삭제한다.

### gh CLI 예시 (PowerShell)
```powershell
git switch -c feat/order-create
# ... 작업 + 커밋 ...
git push -u origin feat/order-create
gh pr create --fill --base main
gh pr view --web        # 상태/CI 확인
gh pr merge --squash --delete-branch
```

---

## 21. 신규 프로젝트 부트스트랩 체크리스트

- [ ] 저장소 구조(§3) 생성, `plan.md` / `.env.example` / `docs/architecture.md` / `.gitignore`(`.env` 제외) 작성
- [ ] 백엔드 `app/` 골격(§4): `main.py`, `config.py`, `dependencies.py`, `db/`, `core/security.py`
- [ ] `Settings` + `get_settings()` (§5) — **모든 설정은 `.env`로 주입, OS 독립 (MUST §5)**, CORS, `TZ=Asia/Seoul`
- [ ] PostgreSQL `connect_args` KST 고정 (§7, §10)
- [ ] Alembic 초기화 + 초기 마이그레이션 (§11) — **DB는 항상 Alembic으로만 관리, `create_all`은 테스트 전용 (MUST §11)**
- [ ] `pytest` + SQLite in-memory + `conftest.py` 픽스처 (§12)
- [ ] 프론트 `src/` 골격(§13): axios `lib/api/client.ts`, `lib/stores/auth.svelte.ts`, `+layout.svelte`의 QueryClientProvider
- [ ] SPA 고정: `svelte.config.js` adapter-static + 루트 `+layout.ts`의 `ssr = false` (§2, §13)
- [ ] `(protected)/+layout.ts` 가드 + SSO 로그인/콜백 흐름 (§14)
- [ ] Tailwind v4 `@theme`, pnpm, ESLint (§15, §2)
- [ ] `.github/pull_request_template.md` 추가, `main` 보호 + CI 머지 게이트 (§20)
- [ ] 첫 실패 테스트 작성(TDD Red) → 구현(Green) (§18)
