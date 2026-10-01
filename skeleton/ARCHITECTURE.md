# 프로젝트 공통 아키텍처 가이드

> 본 문서는 **이 템플릿으로 만드는 모든 웹 프로젝트**가 따르는 공통 표준이다.
> 표준 스택은 **FastAPI(백엔드) + SvelteKit/Vite(프론트엔드) + PostgreSQL**이며,
> 인증은 **자체 계정 또는 OIDC SSO**, 시각은 **KST 단일 기준**을 따른다.

---

## ★ 핵심 MUST 요약 (반드시 고정)

> 아래 항목은 **프로젝트마다 바뀌지 않는 고정 규칙**이다. 어기려면 `ARCHITECTURE.md`에 사유를 남기되, ⛔ 표시 항목은 예외 없이 금지한다.
> 세부 내용은 각 섹션(§) 참조.

| # | 고정 규칙 (MUST) | § |
|---|------------------|---|
| 1 | **표준 스택 고정**: 백엔드 FastAPI + SQLAlchemy 2.1 + Alembic, 프론트 SvelteKit(SPA) + Svelte 5 + Vite + TS, DB는 **PostgreSQL** | §2 |
| 2 | **DB는 항상 Alembic으로만 관리** — 모든 스키마 생성·변경은 마이그레이션. ⛔ dev/운영 런타임 `create_all`·자동 DDL·수동 `ALTER` 금지(테스트 in-memory만 예외) | §11 |
| 3 | **설정은 OS 무관하게 `.env`로 주입** — 동일 `.env`가 Windows/mac/Linux에서 동작. ⛔ 개발 중 `$env:`/`export`/`set` 셸 환경변수 의존 금지. ⛔ `.env` 커밋 금지(`.env.example`만) | §5, §17 |
| 4 | **시각은 KST 단일 기준** — `now()`는 naive `datetime.now()`, PostgreSQL `connect_args`에 `timezone=Asia/Seoul`, 런타임 `TZ=Asia/Seoul`. ⛔ UTC 변환/`ZoneInfo` 신규 도입 금지 | §10, §7 |
| 5 | **API 경로 `/api/v1` 고정** — 버전 prefix는 `main.py`에서, 라우터는 `api/v1/router.py`로 집계 | §4 |
| 6 | **설정 접근은 `get_settings()` + `@lru_cache`** — ⛔ 모듈 전역 `settings` 싱글톤 금지 | §5 |
| 7 | **공통 의존성은 `app/dependencies.py` 단일 파일** (`get_db`, `get_current_user` 등) | §6 |
| 8 | **계층 분리** — 라우터(`api/`)는 HTTP만 얇게, 도메인 로직은 `services/`, 검증/직렬화는 `schemas/` | §4, §8 |
| 9 | **프론트 표준 스택 고정**: axios + `@tanstack/svelte-query` + Svelte 5 runes. ⛔ 서버 상태를 `$state`+`$effect`로 직접 패칭 금지 | §2, §13 |
| 10 | **패키지 매니저는 pnpm** — ⛔ npm 사용 금지 | §2 |
| 11 | **인증은 메모리 access JWT + httpOnly refresh 쿠키** — API 호출은 `Authorization: Bearer <access>`(검증 실패 시 401), access 토큰은 **메모리에만**(⛔ `localStorage`/`sessionStorage` 금지), refresh 토큰은 백엔드가 심는 **httpOnly 쿠키**(`REFRESH_TOKEN_TRANSPORT=cookie`). refresh 는 **DB 세션(auth_sessions) 기반 불투명 토큰**으로 회전(rotation)·재사용 감지·즉시 폐기를 지원한다 | §9, §14 |
| 12 | **테스트는 pytest + SQLite in-memory** — `get_settings.cache_clear()` autouse, `dependency_overrides`로 격리 | §12 |
| 13 | **TDD + Tidy First** — Red→Green→Refactor, 구조 변경과 동작 변경을 한 커밋에 섞지 않음 | §18 |
| 14 | **커밋 메시지**: `[Structural]`/`[Behavioral]` + conventional type, 테스트·린트 통과 시에만 | §19 |
| 15 | **push 전 로컬 테스트·린트 통과가 유일한 게이트** — `main` 직접 커밋이 기본(브랜치·PR은 선택), 1 커밋은 Structural·Behavioral 중 하나만 | §20 |

---

## 0. 적용 범위 & 우선순위

- **MUST**: 신규 프로젝트는 반드시 따른다.
- **SHOULD**: 특별한 사유가 없으면 따른다. 벗어나면 `ARCHITECTURE.md`에 사유를 남긴다.
- **MAY**: 프로젝트 성격에 따라 선택한다.
- 본 가이드와 개별 프로젝트 문서가 충돌하면 **본 가이드 우선**. 예외는 프로젝트 `ARCHITECTURE.md`에 명시한다.

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

> 프론트 환경변수는 SvelteKit 의 `$env/static/public` + `PUBLIC_` 이 아니라 **`VITE_` 접두 + `import.meta.env` 를 계속 쓴다.**
> 이유: 본 스택은 SSR 없는 순수 SPA 이고, 백엔드/원본 프로젝트와 **동일한 `.env` 파일 호환**을 유지하기 위해서다.

---

## 2. 기술 스택 표준

### 백엔드
- **언어/런타임**: Python 3.10+ (`X | None` 문법, `Mapped[]` 타입 힌트 사용)
- **프레임워크**: FastAPI + Uvicorn(`[standard]`) (정확한 버전은 `requirements.txt` / [stack-versions] 스킬)
- **ORM/마이그레이션**: SQLAlchemy 2.1 (`Mapped`/`mapped_column`) + Alembic
- **DB 드라이버**: PostgreSQL + `psycopg2-binary`
- **설정**: `pydantic-settings` (BaseSettings)
- **검증/직렬화**: Pydantic 2.x
- **인증**: JWT. **자체 계정 → `PyJWT`**, **OIDC/SSO 연동 → `python-jose[cryptography]`**
- **테스트**: `pytest` + SQLite in-memory
- **HTTP 클라이언트(서버↔서버)**: `httpx2` (httpx 의 유지보수 후속, Starlette 1.x TestClient 호환)
- **버전 고정**: `requirements.txt`에 **`==` 정확한 버전 핀** (재현성 우선)

### 프론트엔드
- **빌드/런타임**: SvelteKit 3.0 (**SPA 모드**) + Svelte 5.57 + Vite 8.3 (Rolldown) + TypeScript 6.0
  - SPA 고정: `vite.config.ts` 의 `sveltekit({ adapter: adapter({ fallback: 'index.html' }) })` + 루트 `+layout.ts`의 `export const ssr = false`.
    (SvelteKit 3 부터 `svelte.config.js` 는 없다 — Kit 설정은 `sveltekit(...)` 플러그인 옵션으로 넘긴다.)
    백엔드가 별도 FastAPI 서버이고 인증 상태(access 토큰)가 브라우저 메모리에만 있으므로 **SSR을 쓰지 않는다**(§14).
- **라우팅**: **SvelteKit 파일 기반 라우팅**(`src/routes/`). 라우트 그룹 `(protected)`로 인증 가드(§14)
- **HTTP**: `axios` (인스턴스 + interceptor)
- **서버 상태**: `@tanstack/svelte-query` 6.3 (캐싱/재요청/무효화)
- **클라이언트 상태**: **Svelte 5 runes(`$state`)** — 토큰·세션 등 경량 전역 상태는 `.svelte.ts` 모듈에 둔다. **별도 상태 라이브러리를 쓰지 않는다.**
- **스타일**: Tailwind CSS v4 (CSS-first `@theme`)
- **패키지 매니저**: **pnpm** (npm 금지)
- **타입 체크**: `svelte-check` (`tsc -b` 대체) — `pnpm check` = `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json`
- **린트**: ESLint + typescript-eslint + `eslint-plugin-svelte`

> 프론트 표준 스택은 **axios + @tanstack/svelte-query + Svelte 5 runes**로 통일한다.
> 매우 단순한 화면만 있는 소규모 도구는 `fetch + runes($state)`만으로 처리하는 것을 MAY로 허용하되,
> 그 사유를 `ARCHITECTURE.md`에 남긴다.

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
│   └── vite.config.ts           # sveltekit({ adapter, ... }) — SvelteKit 3 은 svelte.config.js 없음
├── docs/                        # 프로젝트 고유 문서 (PRD·유저 플로우·기획서·<연동>-가이드 등)
│   └── README.md
├── AGENTS.md                    # AI 에이전트 공통 지침 (CLAUDE.md 가 @import)
├── CLAUDE.md                    # Claude Code 진입점
├── ARCHITECTURE.md              # 본 가이드 — 벗어난 결정/사유도 여기 기록
├── DESIGN.md                    # 디자인 토큰(색상/타이포그래피) — 테마(@theme)의 원본
├── PLAN.md                      # TDD 작업 순서 (필수)
├── .env.example
└── README.md
```

- 루트에 `PLAN.md`를 두고 **TDD 작업 순서**(실패 테스트 단위)를 관리한다.
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
│   │   ├── auth.py         # 자체 계정 /auth/login·refresh·logout·me; SSO는 도입 시 확장
│   │   ├── health.py
│   │   └── <domain>.py     # 도메인별 APIRouter (얇은 HTTP 계층)
│   └── ...
├── core/
│   └── security.py         # access JWT·refresh 불투명 토큰, 비밀번호 정책, now() (KST naive)
├── db/
│   ├── base.py             # DeclarativeBase (Base)
│   ├── engine.py           # 엔진 팩토리 (SQLite/PG 분기, KST connect_args)
│   └── session.py          # get_db 세션 / SessionLocal
├── models/
│   ├── __init__.py         # 모든 모델 re-export (Alembic/메타데이터 등록용)
│   ├── auth_session.py     # AuthSession(refresh 세션) + LoginThrottle(로그인 시도 제한) (§9)
│   └── <domain>.py
├── schemas/
│   └── <domain>.py         # Pydantic BaseModel (요청/응답)
└── services/
    ├── <domain>_service.py # 비즈니스 로직
    ├── session_service.py  # refresh 세션 생성·회전·폐기 (§9)
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

    # JWT / 세션 — access 는 짧게(탈취 창 축소), 갱신은 DB 세션 기반 refresh 토큰이 담당한다 (§9)
    secret_key: str = DEFAULT_SECRET_KEY  # "change-me-in-production-use-32-bytes"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 14

    # 로그인 시도 제한 — 계정별 연속 실패가 max 이상이면 lockout 분 동안 429 (§9)
    login_max_failures: int = 5
    login_lockout_minutes: int = 15

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
    if payload is None or "sub" not in payload or "sid" not in payload:
        raise cred_error
    # sid 세션이 폐기·만료면 access 토큰이 만료 전이어도 401 — 로그아웃의 즉시 무효화 (§9)
    if not session_service.is_active_session(db, payload["sid"]):
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
    url = settings.database_url
    if not url:
        raise RuntimeError("DATABASE_URL 이 설정되지 않았습니다 (.env 확인).")
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

### 모델 (`models/`) — SQLAlchemy 2.1 `Mapped`
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

## 9. 인증 (JWT · 세션 · SSO)

- `core/security.py`에 토큰 생성/검증과 비밀번호 정책, `now()`를 둔다. 세션(refresh) 도메인 로직은 `services/session_service.py`, 로그인·스로틀은 `services/user_service.py`, HTTP 변환은 `api/v1/auth.py`가 담당한다(§4 계층 분리 그대로).

### 토큰 모델 (자체 계정 — skeleton 구현)

- **access 토큰**: `PyJWT` HS256 JWT. 클레임은 `sub`(user id 문자열)·`sid`(세션 id)·`iat`·`exp`·`typ:"access"`. 만료 `ACCESS_TOKEN_EXPIRE_MINUTES` **기본 15분** — 짧게 잡아 탈취 창을 줄이고, 갱신은 refresh 토큰이 담당한다.
- **refresh 토큰**: JWT 가 **아니라** 불투명(opaque) 토큰 `"<session_id>.<urlsafe 무작위>"` 다. DB(`auth_sessions`)에는 **SHA-256 해시만** 저장한다 — DB 가 유출돼도 평문 토큰을 복원할 수 없고, 검증은 해시 재계산 + 상수시간 비교(`hmac.compare_digest`)다. refresh 토큰 1개 = `auth_sessions` 행 1개.
- **즉시 무효화**: `get_current_user` 가 요청마다 `sid` 세션의 유효성(존재·미폐기·미만료)을 검사한다 — 로그아웃·강제 폐기가 access 토큰 만료를 기다리지 않고 **즉시 401** 로 반영된다.
- 토큰은 `Authorization: Bearer <token>` 헤더. 검증 실패는 401 + `WWW-Authenticate: Bearer`.

### 엔드포인트 계약

| 엔드포인트 | 요청 | 응답 |
|------|------|------|
| `POST /auth/login` | `{username, password}` | `TokenResponse` (성공 200 / 자격증명 오류 401 / 잠금 429) |
| `POST /auth/refresh` | body 모드 `{refresh_token}` / cookie 모드 본문 없음(쿠키) | `TokenResponse` — **회전된 새 쌍** (실패는 원인 무관 401) |
| `POST /auth/logout` | body 모드 `{refresh_token}` / cookie 모드 본문 없음(쿠키) | **204 멱등·인증 불요** — 토큰 "소지"가 폐기 권한이다(해시 검증 후 폐기) |
| `GET /auth/me` | Bearer access | `UserRead` |

- `TokenResponse` 는 로그인·리프레시가 **동일 형태**다: `{access_token, refresh_token, token_type, expires_in, refresh_expires_in}`. `expires_in`/`refresh_expires_in` 은 절대 시각이 아니라 **"지금부터 남은 초"** 다 — 클라이언트가 서버와 시계를 맞출 필요 없이 갱신 시점을 계산한다.

### refresh 토큰 전달 방식 (`REFRESH_TOKEN_TRANSPORT`)

같은 백엔드 코드가 BFF 와 브라우저 SPA 를 모두 섬기도록 refresh 토큰의 운반 경로만 설정으로 바꾼다. 세션·회전·재사용 감지 로직은 동일하다.

| 모드 | 대상 | 동작 |
|------|------|------|
| `cookie` (**코드 기본값 · 이 템플릿**) | 브라우저 SPA (React·Nuxt·SvelteKit) | login/refresh 가 refresh 토큰을 **httpOnly 쿠키**로 심고 본문의 `refresh_token` 은 `null` 이다 — JS 가 refresh 토큰을 읽을 수 없다. refresh/logout 은 쿠키에서 읽고 본문은 보지 않는다. refresh 실패는 401 **+ 쿠키 삭제**, logout 은 항상 204 + 쿠키 삭제 |
| `body` | BFF (Next.js 서버) | 요청·응답 JSON 본문으로 주고받고 쿠키를 쓰지 않는다. refresh/logout 본문은 필수(없으면 422). 받은 토큰은 BFF 서버가 자기 httpOnly 쿠키에 보관한다 |

- 이 템플릿의 프론트(SvelteKit SPA)가 cookie 모드를 쓰는 방식은 §14 에 있다 — access 토큰은 메모리, 새로고침 시 쿠키로 복원.
- 쿠키 속성(cookie 모드): 이름 `refresh_token`, `Path=/api/v1/auth`(refresh/logout 에만 전송), `HttpOnly`, `SameSite=Lax`, `Secure=COOKIE_SECURE`, `Max-Age` = 세션의 남은 절대 수명(`refresh_expires_in` 과 같은 값).
- ⛔ `APP_ENV=production` + `cookie` 모드에서 `COOKIE_SECURE=false` 면 **기동을 거부**한다. 교차 출처 SPA 의 쿠키 갱신을 위해 CORS 는 `allow_credentials=True` 이며, 따라서 `CORS_ORIGINS` 에 출처를 명시한다(`*` 불가).
- **회전(rotation)**: `/auth/refresh` 는 성공할 때마다 새 secret 으로 교체하고, 직전 해시를 `prev_token_hash` 에 보관한다. **재사용 감지** — 현재 해시도 직전 해시도 아니거나, 직전 해시이지만 회전(`rotated_at`) 후 `ROTATION_GRACE_SECONDS`(60초)가 지났으면 탈취 신호로 보고 **세션을 즉시 폐기**한다. 응답은 다른 실패와 동일한 401 이다 — 실패 사유(형식 오류/미존재/만료/폐기/재사용)를 응답으로 구분하지 않아 공격자가 토큰 상태를 탐침하지 못한다.
- **동시 요청 유예(60초)**: access 토큰이 만료된 채 멀티 탭·동시 요청이 **같은 refresh 토큰으로 동시에** 갱신을 치는 것은 정상 상황이다 — 유예 없이 전부 재사용으로 판정하면 첫 요청만 이기고 나머지가 세션을 폐기해 사용자가 주기적으로 강제 로그아웃당한다. 그래서 직전 토큰은 회전 후 60초 동안만 정상 회전으로 받아 준다(이때 `prev_token_hash`·`rotated_at` 은 갱신하지 않는다 — 창이 슬라이딩하면 탈취된 이전 토큰이 무한히 살아남는다). 유예 내 이전 토큰 허용의 추가 노출은 실질 0 이다 — 그 토큰을 가진 공격자는 회전 전에도 같은 토큰을 쓸 수 있었다.
- ⚠️ **회전해도 절대 수명은 연장되지 않는다** — `expires_at` 은 로그인 시점 + `REFRESH_TOKEN_EXPIRE_DAYS`(기본 14일)로 고정이다. 회전으로 세션이 무한히 살아남지 못한다.

### 로그인 보호 (계정 존재 비노출 · 시도 제한)

- **실패 메시지 통일**: 로그인 실패는 원인(자격증명 불일치/비활성 계정)과 무관하게 같은 문구·같은 401 이다. 미존재 계정에도 **더미 bcrypt 해시로 1회 검증**해 응답 시간(타이밍)으로도 존재 여부가 드러나지 않게 한다.
- **로그인 스로틀**: 계정(username)별 DB 카운터(`login_throttles`). 연속 실패가 `LOGIN_MAX_FAILURES`(기본 5) 이상이면 `LOGIN_LOCKOUT_MINUTES`(기본 15분) 동안 **429** 로 거부한다. **미존재 계정도 행을 만들어 같은 429 를 받는다** — 잠금 응답 유무로도 계정 존재가 구분되지 않는다. 성공 시 스로틀 행은 삭제된다.
- **감사 로그**: 보안 이벤트(로그인 성공/실패/잠금, refresh 회전/거부/재사용 감지, 로그아웃)는 전용 로거 **`app.audit`** 로 남긴다 — 일반 로그와 분리 수집할 수 있다. 원인 구분은 응답이 아니라 이 로그로만 한다.

### 비밀번호 정책

- **새로 저장하는 비밀번호**는 `validate_new_password()` 한 곳에서 통합 검증한다 — 최소 `PASSWORD_MIN_LENGTH`(8자) + `len(password.encode("utf-8")) <= 72` bytes(bcrypt 상한). 위반은 422 도메인 오류로 변환한다. 한글은 UTF-8에서 글자당 3 bytes이므로 문자 수 제한과 같지 않다.
- 하한(8자)은 "새 비밀번호를 만드는 규칙"이라 **로그인 검증에는 적용하지 않는다** — 기존 계정의 짧은 비밀번호로도 로그인은 된다. 상한(72 bytes)은 HTTP 입력(스키마)에서도 미리 걸러 절단 착시를 막고, `hash_password()`도 방어적으로 초과 시 `ValueError`를 발생시킨다.

### SSO (도입 시 선택적 확장)

- **OIDC SSO**: 백엔드가 authorize→callback→userinfo 처리 후 앱 세션 JWT 발급, `python-jose`. 최초 로그인 시 `provision_from_userinfo()`로 사용자 upsert(없으면 생성, 식별정보 갱신). ERP 등 외부 시스템 연동도 프로젝트 요구에 따라 별도 확장한다.

### 응답 보안 헤더 · 캐시 금지 · CORS

백엔드는 모든 응답에 `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Cross-Origin-Opener-Policy: same-origin` 을 붙인다(`app/main.py` 보안 헤더 미들웨어 — CORS 바깥에서 감싸 preflight·오류 응답에도 적용).
HSTS(`max-age=31536000`)는 `COOKIE_SECURE=true` 이거나 `APP_ENV=production` 일 때만 보낸다 — body 모드(BFF) 운영은 `COOKIE_SECURE` 를 켜지 않을 수 있어 production 도 조건에 넣었고, 브라우저는 평문 HTTP 로 받은 HSTS 를 무시하므로 TLS 종단이 앞단 프록시여도 무해하다.
CSP 는 `/docs`·`/redoc` 의 CDN·인라인 스크립트를 막으므로 백엔드에서 붙이지 않고 프론트엔드(정적 호스팅/BFF) 쪽 책임으로 둔다.

- `/api/v1/auth/*` 응답은 성공·오류(401/422/429)·쿠키 삭제 응답을 가리지 않고 `Cache-Control: no-store` 다.
- 로그인 잠금 429 는 `Retry-After`(남은 잠금 초, 올림·최소 1)를 싣는다. 미존재 계정도 같은 스로틀 행을 거쳐 같은 헤더를 받으므로 계정 존재가 드러나지 않는다.
- CORS 는 `CORS_ORIGINS` 의 출처만 허용하고 `allow_credentials=True`(cookie 모드 refresh 쿠키 전송)를 유지하되, 메서드는 `GET·POST·PUT·PATCH·DELETE·OPTIONS`, 요청 헤더는 `Authorization·Content-Type` 만 명시 허용하며 `Retry-After` 를 expose 한다. 새 커스텀 요청 헤더가 필요하면 `app/main.py` 의 `CORS_ALLOW_HEADERS` 에 추가한다.

---

## 10. 날짜·시간 (KST)  — MUST

- **기준**: 저장·표시되는 업무 일자는 **KST**로 통일. 애플리케이션에 UTC↔KST 변환 레이어를 두지 않는다.
- **PostgreSQL**: 엔진 `connect_args`에 `options="-c timezone=Asia/Seoul"`.
- **FastAPI**: `app.core.security.now()`는 **naive `datetime.now()`만** 사용.
- **Unix 실행 환경**: API 프로세스에 **`TZ=Asia/Seoul`**을 설정하고 애플리케이션이 `tzset()`으로 적용한다.
- **Windows 실행 환경**: Windows CRT는 IANA `TZ=Asia/Seoul`을 프로세스 시각대에 적용하지 못하므로 **OS 시각대를 `서울`(UTC+9)로 설정**해야 한다. OS 오프셋이 KST와 다르면 애플리케이션이 경고한다.
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
  - `db_session_factory`: 테스트 엔진에 바인딩된 세션 팩토리.
  - `db_session`: 테스트별 DB 세션.
  - `client`: `app.dependency_overrides[get_db]`를 적용한 기본 API 클라이언트.
  - `lifespan_client`: 기동·종료 훅과 기본 관리자 시드·경고를 검증하는 클라이언트.
- skeleton 의 인증 회귀는 `tests/test_auth.py`(로그인·`/auth/me`)와 **`tests/test_auth_sessions.py`**(refresh 회전·재사용 감지 시 세션 폐기·동시 갱신 60초 유예·절대 수명 비연장·로그아웃 멱등·즉시 무효화·로그인 스로틀·비밀번호 정책), **`tests/test_auth_cookie_transport.py`**(cookie 모드 — 쿠키 속성·본문 `refresh_token=null`·쿠키 전용 refresh/logout·실패 시 쿠키 삭제·잠금 429), `tests/test_config.py`(`APP_ENV=production` fail-fast)가 고정한다(§9).

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
├── pnpm-workspace.yaml          # allowBuilds (pnpm 11 빌드 스크립트 허용)
├── vite.config.ts               # @tailwindcss/vite + sveltekit({ adapter: adapter-static fallback }), /api dev proxy
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
    │   │   ├── client.ts        # ★ axios 인스턴스(withCredentials) + Bearer 주입 + 401 → single-flight refresh·1회 재시도
    │   │   ├── auth.ts          # login(), logout(), getMe() + User/UserRole/TokenResponse 타입
    │   │   └── health.ts        # getHealth(), getDbHealth() + DbHealth 타입
    │   ├── auth/
    │   │   └── session.ts       # restoreSession()(앱 시작 시 쿠키로 세션 복원), signOut()
    │   ├── queries/
    │   │   ├── auth.ts          # createLogin(), createMe()        — svelte-query
    │   │   └── health.ts        # createHealth(), createDbHealth() — svelte-query
    │   ├── stores/
    │   │   └── auth.svelte.ts   # runes $state 전역 인증 스토어 (token=메모리 access 토큰, user)
    │   └── query-client.ts      # 전역 QueryClient 단일 인스턴스 (세션 만료·로그아웃 시 clear)
    └── routes/
        ├── +layout.ts           # ssr = false; prerender = true; load → restoreSession()
        ├── +layout.svelte       # QueryClientProvider + app.css import (앱 부트스트랩)
        ├── login/
        │   └── +page.svelte     # /login
        └── (protected)/         # 라우트 그룹 — URL 에 영향 없음, 인증 가드 담당
            ├── +layout.ts       # restoreSession() 대기 → 미인증이면 redirect(302, resolve('login'))
            ├── +layout.svelte   # 보호 영역 공통 레이아웃 ({@render children()})
            ├── +page.svelte     # /          메인
            ├── landing/
            │   └── +page.svelte # /landing   백엔드·DB 상태
            └── my/
                └── +page.svelte # /my        내 정보·로그아웃
```

`lib/api/client.ts` (axios 표준 — 인증 흐름은 §14):
```ts
import axios, { type InternalAxiosRequestConfig } from "axios"
import { goto } from "$app/navigation"
import { resolve } from "$app/paths"
import type { TokenResponse } from "#lib/api/auth.js"
import { queryClient } from "#lib/query-client.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// axios 인스턴스 (ARCHITECTURE.md §13). baseURL 미설정 시 vite dev proxy(/api/v1) 사용.
//
// 인증 흐름 (ARCHITECTURE.md §14):
// - access 토큰은 스토어(메모리)에만 있고, 요청 인터셉터가 Bearer 로 주입한다.
// - refresh 토큰은 백엔드가 심는 httpOnly 쿠키(refresh_token, Path=/api/v1/auth)라 JS 는 보지 못한다.
//   withCredentials: true — 교차 오리진(VITE_API_BASE_URL)에서도 쿠키를 주고받는다
//   (백엔드 CORS 는 allow_credentials=True + 명시 오리진. 쿠키가 SameSite=lax 라 same-site 배치 전제).
// - 401 이면 refresh 를 single-flight 로 1번만 호출하고 원 요청을 1회 재시도한다.
//   refresh 실패 = 세션 만료 → 상태·쿼리 캐시를 비우고 로그인 화면으로 보낸다.
const baseURL = import.meta.env.VITE_API_BASE_URL
  ? `${import.meta.env.VITE_API_BASE_URL}/api/v1`
  : "/api/v1"

export const api = axios.create({ baseURL, withCredentials: true })

// refresh 전용 인스턴스 — 인터셉터가 없어 401 처리와 얽히지 않는다(무한 루프 방지).
const refreshClient = axios.create({ baseURL, withCredentials: true })

// 자기 자신이 401 이어도 refresh 를 타면 안 되는 인증 엔드포인트.
const AUTH_PATHS = ["/auth/login", "/auth/refresh", "/auth/logout"]

// single-flight: 동시에 여러 요청이 401 을 받아도 refresh 는 한 번만 나간다.
// (refresh 토큰은 회전되므로 병렬 호출은 이전 토큰 재사용으로 오인될 수 있다.)
let refreshPromise: Promise<string | null> | null = null

/** httpOnly refresh 쿠키로 access 토큰을 재발급받아 스토어에 넣는다. 실패하면 null (상태는 건드리지 않는다). */
export function refreshAccessToken(): Promise<string | null> {
  refreshPromise ??= refreshClient
    .post<TokenResponse>("/auth/refresh")
    .then(({ data }) => {
      authStore.setSession(data.access_token)
      return data.access_token
    })
    .catch(() => null)
    .finally(() => {
      refreshPromise = null
    })
  return refreshPromise
}

/** 세션 만료 처리 — 상태·쿼리 캐시를 비우고 로그인 화면으로 (이미 로그인 화면이면 이동하지 않는다). */
export function expireSession(): void {
  authStore.clear()
  queryClient.clear()
  const loginPath = resolve("login")
  if (location.pathname !== loginPath) void goto(loginPath, { replaceState: true })
}

api.interceptors.request.use((config) => {
  const token = authStore.token
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

type RetriableConfig = InternalAxiosRequestConfig & { _retried?: boolean }

api.interceptors.response.use(
  (res) => res,
  async (error: unknown) => {
    if (!axios.isAxiosError(error) || error.response?.status !== 401 || !error.config) {
      throw error
    }
    const config: RetriableConfig = error.config
    const url = config.url ?? ""
    // 인증 엔드포인트 자체의 401(로그인 실패 등)과 이미 한 번 재시도한 요청은 그대로 실패시킨다.
    if (config._retried || AUTH_PATHS.some((p) => url.startsWith(p))) throw error

    const token = await refreshAccessToken()
    if (token === null) {
      expireSession()
      throw error
    }
    // 재시도는 1회뿐 — 요청 인터셉터가 새 access 토큰을 다시 주입한다.
    config._retried = true
    return api(config)
  },
)
```

`lib/stores/auth.svelte.ts` (Svelte 5 runes — 전역 클라이언트 상태. runes 를 쓰는 TS 모듈이므로 확장자는 반드시 `.svelte.ts`, `isAuthenticated` 는 함수가 아니라 getter):
```ts
import type { User } from "#lib/api/auth.js"

// 클라이언트 전역 상태 (ARCHITECTURE.md §13, §14).
// zustand 같은 별도 라이브러리 없이 Svelte 5 runes($state)로 대체한다 — 그래서 파일명이 .svelte.ts 다.
//
// access 토큰은 메모리($state)에만 둔다 — localStorage/sessionStorage 금지 (XSS 탈취 방지, §14).
// 새로고침하면 사라지는데, 앱 시작 시 #lib/auth/session.ts 의 restoreSession() 이
// httpOnly refresh 쿠키(POST /auth/refresh)로 다시 받아 온다.
// 모듈 수준 상태라 prerender(Node) 단계에서도 import 되지만, 값은 null 로만 존재하고
// 쓰기는 전부 브라우저에서 일어난다(쓰는 쪽이 browser 가드를 가진다).
class AuthStore {
  token = $state<string | null>(null)
  user = $state<User | null>(null)

  setSession(token: string): void {
    this.token = token
  }

  setUser(user: User | null): void {
    this.user = user
  }

  // 상태만 비운다 — 서버 세션 폐기(POST /auth/logout)·쿼리 캐시 정리·이동은 session.ts 의 signOut 이 맡는다.
  clear(): void {
    this.token = null
    this.user = null
  }

  get isAuthenticated(): boolean {
    return Boolean(this.token)
  }
}

export const authStore = new AuthStore()
```

`lib/queries/health.ts` (svelte-query):
```ts
import { createQuery } from "@tanstack/svelte-query"
import { getDbHealth, getHealth } from "#lib/api/health.js"

// svelte-query 쿼리 (ARCHITECTURE.md §13).
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
import { getMe, login } from "#lib/api/auth.js"
import { authStore } from "#lib/stores/auth.svelte.js"

export function createLogin() {
  return createMutation(() => ({
    mutationFn: ({ username, password }: { username: string; password: string }) =>
      login(username, password),
    onSuccess: async (token) => {
      authStore.setSession(token.access_token) // 메모리에만 — refresh 는 백엔드가 httpOnly 쿠키로 심었다
      authStore.setUser(await getMe())
    },
  }))
}
```

`routes/+layout.svelte` (프로바이더는 최상위에 한 번만. QueryClient 는 `lib/query-client.ts` 의 모듈 단일 인스턴스 — 세션 만료·로그아웃 시 이전 사용자의 캐시를 비워야 하므로 컴포넌트 안에서 `new QueryClient()` 하지 않는다):
```svelte
<script lang="ts">
  import { QueryClientProvider } from "@tanstack/svelte-query"
  import type { Snippet } from "svelte"
  import { queryClient } from "#lib/query-client.js"
  import "../app.css"

  // 부트스트랩 (ARCHITECTURE.md §13): svelte-query Provider 를 최상위에 한 번만 둔다.
  // QueryClient 는 모듈 단일 인스턴스(#lib/query-client) — 세션 만료·로그아웃 시 캐시를 비우기 위해서다.
  const { children }: { children: Snippet } = $props()
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
- **클라이언트 상태(access 토큰·사용자·UI)는 runes**(`$state`) — 전역은 `lib/stores/*.svelte.ts`, 지역은 컴포넌트 내 `$state`. ⛔ 토큰을 `localStorage`/`sessionStorage` 에 두지 않는다(§14).
- API 함수는 `lib/api/<domain>.ts`에 모으고, 컴포넌트는 `lib/queries/`의 쿼리 팩토리를 통해 접근한다.

---

## 14. 프론트엔드 인증 흐름

백엔드 `REFRESH_TOKEN_TRANSPORT=cookie`(§9)를 전제로 한다 — **access 토큰은 메모리, refresh 토큰은 httpOnly 쿠키**.

| 토큰 | 보관 위치 | JS 접근 | 수명 |
|------|-----------|---------|------|
| access (JWT) | `authStore.token` (`lib/stores/auth.svelte.ts` 의 `$state`, 메모리) | 가능 — 요청마다 `Authorization: Bearer` 로 주입 | `ACCESS_TOKEN_EXPIRE_MINUTES`(15분). **새로고침하면 사라진다** |
| refresh (불투명) | 백엔드가 심는 httpOnly 쿠키 `refresh_token` (`Path=/api/v1/auth`, `SameSite=Lax`, `Secure=COOKIE_SECURE`) | **불가** — 로그인/refresh 응답 본문의 `refresh_token` 은 항상 `null` | 세션 절대 수명 `REFRESH_TOKEN_EXPIRE_DAYS`(14일), refresh 마다 회전 |

- ⛔ 토큰을 `localStorage`/`sessionStorage`/JS 가 읽을 수 있는 쿠키에 저장하지 않는다 — XSS 한 번에 장기 세션이 탈취된다.
- **앱 시작(세션 복원)**: `lib/auth/session.ts` 의 `restoreSession()` 이 페이지 로드당 1회 `POST /auth/refresh`(쿠키 자동 전송)로 access 토큰을 다시 받아 메모리에 넣는다.
  루트 `+layout.ts` 와 `(protected)/+layout.ts` 의 `load` 가 **같은 Promise 를 기다린 뒤** 인증 여부를 판단한다 —
  레이아웃 load 는 병렬로 돌므로 보호 가드가 직접 기다려야 새로고침 시 로그인 화면으로 깜빡 튕기지 않는다. 실패(쿠키 없음·만료·폐기)는 조용히 비로그인 상태로 시작한다.
- **요청**: `lib/api/client.ts` 의 axios 인스턴스는 `withCredentials: true` 이고, 요청 인터셉터가 메모리의 access 토큰을 Bearer 로 주입한다.
- **401 처리**: `/auth/login`·`/auth/refresh`·`/auth/logout` 을 제외한 요청이 401 이면 refresh 를 **single-flight**(동시 401 이 여럿이어도 1번)로 호출하고 원 요청을 **1회만** 재시도한다.
  refresh 는 인터셉터가 없는 별도 인스턴스로 보낸다(무한 루프 방지). refresh 실패 = 세션 만료 → `expireSession()` 이 스토어·**svelte-query 캐시**(`queryClient.clear()`)를 비우고 `goto(resolve('login'), { replaceState: true })`.
- **로그인**: `createLogin()` → `POST /auth/login` → access 토큰을 스토어에 저장하고 `/auth/me` 로 사용자 로드 → 메인(`/`)으로 이동. refresh 쿠키는 백엔드 응답의 `Set-Cookie` 로 심어진다.
  실패 문구는 상태 코드로 구분한다 — **401** 자격증명 오류, **429** 잠금(`LOGIN_MAX_FAILURES` 회 연속 실패 → `LOGIN_LOCKOUT_MINUTES` 분, §9).
- **로그아웃**: `signOut()` → `POST /auth/logout`(인증 불요·항상 204, 서버 세션 폐기 + 쿠키 삭제) → 스토어·쿼리 캐시 정리 → `/login`. 네트워크 오류여도 클라이언트 상태는 비운다.
- **오리진 배치**: 개발은 vite dev proxy(`/api` → `http://localhost:8000`)로 프론트와 **같은 오리진**이라 쿠키가 그대로 오간다(`VITE_API_BASE_URL` 비움).
  `VITE_API_BASE_URL` 로 API 를 다른 오리진에 두면 `withCredentials` 로 쿠키를 보내며, 백엔드 `CORS_ORIGINS` 에 프론트 오리진을 **명시**해야 한다(`allow_credentials=True` 라 `*` 불가).
  쿠키가 `SameSite=Lax` 이므로 프론트와 API 는 **같은 사이트**(예: `app.example.com` ↔ `api.example.com`)여야 한다 — 다른 사이트면 refresh 쿠키가 전송되지 않아 새로고침마다 로그아웃된다.
  운영(HTTPS)은 `COOKIE_SECURE=true` 필수(§9, `APP_ENV=production` 에서 false 면 기동 거부).
- **SSO**(도입 시): `routes/login/+page.svelte`에서 `window.location.href = ${VITE_BACKEND_URL}/api/v1/auth/login`.
  백엔드 콜백이 세션을 만들고 refresh 쿠키를 심은 뒤 프론트로 리다이렉트하면, 앱 시작의 `restoreSession()` 이 그대로 access 토큰을 받는다 — 토큰을 URL 로 넘기지 않는다.
- **보호 라우트**: 라우트 그룹 `(protected)/`의 `+layout.ts` 가드가 담당한다(미인증 시 `redirect(302, resolve('login'))`).
  그룹 이름은 괄호라서 **URL 에 나타나지 않는다** — 보호 대상 페이지를 이 디렉토리 아래로 옮기기만 하면 된다.
- ⚠️ `restoreSession()` 에는 **`$app/env` 의 `browser` 가드가 필수**다. `ssr = false` 라도 빌드의 **prerender 단계는 Node 에서 돌아** load 가 실행된다(쿠키·`location` 이 없다).
- ⚠️ 내부 이동 경로는 `$app/paths` 의 **`resolve()`** 로 감싼다(`href={resolve('landing')}`, `goto(resolve(''))`).
  SvelteKit 3 의 pathname 은 **앞의 `/` 없이** 쓰고(루트 = `''`), 경로는 `svelte-check` 가 타입으로 검사한다.
  (`eslint-plugin-svelte@3.23` 의 `svelte/no-navigation-without-resolve` 는 Kit 3 에서 비활성 — lint 가 아니라 규칙으로 지킨다.)

```
src/routes/
├── +layout.ts               # ssr = false / prerender = true (SPA 고정) + load → restoreSession()
├── +layout.svelte           # QueryClientProvider(#lib/query-client) + app.css
├── login/+page.svelte       # /login (401·429 문구 구분)
├── auth/callback/+page.svelte   # /auth/callback (SSO 콜백 — SSO 도입 시 추가, 스캐폴드에는 없음)
└── (protected)/             # ★ 인증 가드 그룹 (URL 에 영향 없음)
    ├── +layout.ts           # restoreSession() 대기 → 미인증이면 redirect(302, resolve('login'))
    ├── +layout.svelte       # 공통 레이아웃 ({@render children()})
    ├── +page.svelte         # /
    ├── landing/+page.svelte # /landing
    └── my/+page.svelte      # /my (signOut)
```

`lib/auth/session.ts`:
```ts
import { browser } from "$app/env"
import { goto } from "$app/navigation"
import { resolve } from "$app/paths"
import { logout } from "#lib/api/auth.js"
import { refreshAccessToken } from "#lib/api/client.js"
import { queryClient } from "#lib/query-client.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// 세션 수명주기 (ARCHITECTURE.md §14).

// 페이지 로드(새로고침)당 1회만 시도한다 — 루트/보호 레이아웃 load 가 같은 Promise 를 공유한다.
let restorePromise: Promise<void> | null = null

/**
 * 앱 시작 시 httpOnly refresh 쿠키로 세션을 복원한다 (POST /auth/refresh).
 * access 토큰은 메모리에만 있어 새로고침하면 사라지므로, 인증 여부를 판단하기 전에 반드시 기다린다
 * — 그래야 로그인 상태에서 새로고침해도 로그인 화면으로 깜빡 튕기지 않는다.
 * 실패(쿠키 없음/만료/폐기)는 조용히 비로그인 상태로 시작한다.
 * prerender(Node) 단계에는 쿠키도 브라우저도 없으므로 아무것도 하지 않는다.
 */
export function restoreSession(): Promise<void> {
  if (!browser) return Promise.resolve()
  restorePromise ??= refreshAccessToken().then(() => undefined)
  return restorePromise
}

/** 로그아웃 — 서버 세션 폐기(실패해도 진행) → 상태·쿼리 캐시 정리 → 로그인 화면. */
export async function signOut(): Promise<void> {
  try {
    await logout()
  } catch {
    // 네트워크 오류여도 클라이언트 상태는 비운다(서버 세션은 만료로 정리된다).
  }
  authStore.clear()
  queryClient.clear()
  await goto(resolve("login"), { replaceState: true })
}
```

```ts
// src/routes/(protected)/+layout.ts
import { redirect } from "@sveltejs/kit"
import { browser } from "$app/env"
import { resolve } from "$app/paths"
import { restoreSession } from "#lib/auth/session.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// 보호 라우트 가드 (ARCHITECTURE.md §14). 미인증 시 로그인 화면으로 보낸다.
// (protected) 는 라우트 그룹이라 URL 에는 나타나지 않는다 — /, /landing, /my 가 전부 이 가드를 탄다.
// 레이아웃 load 는 병렬로 돌기 때문에 루트의 복원을 기다린다는 보장이 없다 → 같은 restoreSession()
// Promise 를 직접 기다린 뒤 메모리 상태로 판단한다(새로고침 시 로그인 화면으로 깜빡 튕기지 않는다).
// prerender 단계에서는 browser 가 false 라 리다이렉트하지 않고 빈 셸만 만든다.
export const load = async () => {
  if (!browser) return
  await restoreSession()
  if (!authStore.isAuthenticated) redirect(302, resolve("login"))
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
| 경로 별칭 | `#lib/*` → `src/lib/*` (`package.json` `"imports"`, Node subpath imports). import 시 확장자 `.js` 필수 — `#lib/api/client.js` |
| API 경로 | `/api/v1/<resource>` (리소스 복수형) |

---

## 17. 환경변수 표준

> 모든 설정은 **`.env` 파일로 OS 독립적으로 주입**한다(강제 규칙은 §5 참조). 셸 환경변수에 의존하지 않는다.

### 백엔드 (`backend/.env`)
| 키 | 용도 |
|----|------|
| `DATABASE_URL` | PostgreSQL 연결 — 단일 지원(개별 `DB_*` 키 미지원), 미설정 시 기동에서 fail-fast |
| `SECRET_KEY`, `ACCESS_TOKEN_EXPIRE_MINUTES` | 토큰 서명키, access 토큰 만료(분, 기본 15) |
| `REFRESH_TOKEN_EXPIRE_DAYS` | refresh 세션 절대 수명(일, 기본 14) — 회전해도 연장되지 않는다(§9) |
| `LOGIN_MAX_FAILURES`, `LOGIN_LOCKOUT_MINUTES` | 로그인 시도 제한 — 계정별 연속 실패 임계치(기본 5)와 잠금 시간(분, 기본 15) (§9) |
| `REFRESH_TOKEN_TRANSPORT` | refresh 토큰 전달 방식 — `cookie`(브라우저 SPA: 백엔드가 httpOnly 쿠키 설정, 코드 기본값) / `body`(BFF: JSON 본문). 이 템플릿은 `cookie` (§9, §14) |
| `COOKIE_SECURE` | refresh 쿠키의 `Secure` 속성. cookie 방식 + `APP_ENV=production` 이면 `true` 필수(아니면 기동 거부) |
| `CORS_ORIGINS` | 콤마 구분 허용 출처 |
| `FRONTEND_URL`, `BACKEND_PUBLIC_URL` | 리다이렉트/콜백 |
| `APP_ENV` | `production` 이면 안전하지 않은 기본값(기본 `SECRET_KEY`, 관리자 시드)으로 기동을 거부한다 |
| `SEED_DEFAULT_ADMIN`, `DEFAULT_ADMIN_PASSWORD` | 기동 시 기본 관리자(admin) 시드 여부·초기 비밀번호. **코드 기본값은 꺼짐** — `.env` 에서만 켠다(§21) |
| `OAUTH_*` | SSO 도입 시(authorize/token/userinfo URL, client id/secret, redirect uri) |
| `TZ` | Unix 실행 환경 `Asia/Seoul`; Windows에서는 OS 시각대를 서울(UTC+9)로 설정 |

### 프론트엔드 (`.env`, `VITE_` 필수)
| 키 | 용도 |
|----|------|
| `VITE_API_BASE_URL` | API 호스트 (없으면 dev proxy `/api/v1` — 같은 오리진). 지정하면 쿠키를 `withCredentials` 로 보내므로 백엔드 `CORS_ORIGINS` 에 프론트 오리진을 넣고, 프론트·API 를 같은 사이트에 둔다(§14) |
| `VITE_BACKEND_URL` | SSO 리다이렉트용 백엔드 호스트 |

- `.env`는 커밋 금지. `.env.example`에 **키만** 공유.

---

## 18. 개발 원칙 (TDD · Tidy First)

- **TDD 사이클**: Red → Green → Refactor. `PLAN.md` 순서대로 **한 번에 실패하는 테스트 하나**.
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

## 20. 변경 반영 규칙 (GitHub)

> 기본 흐름은 **`main`에서 작업 → 로컬 검증 → 커밋 → push** 다. 브랜치와 PR은 **선택**이다.
> 커밋의 Structural/Behavioral 분리 원칙(§18, §19)은 그대로 지킨다.

### ⛔ push 전 로컬 검증이 유일한 게이트다

PR 리뷰 단계가 없으므로 **커밋·push 전 검증을 건너뛰면 깨진 코드가 곧바로 `main`에 남는다.** CI는 push 이후에 도는 **사후 안전망**이지 사전 게이트가 아니다.

push 전에 반드시 통과시킨다:

```powershell
cd backend;  .\.venv\Scripts\python -m pytest -q;  .\.venv\Scripts\python -m ruff check .
cd ..\frontend;  pnpm lint;  pnpm check;  pnpm build
```

- 실패했거나 확인하지 않았으면 push 하지 않는다.
- push 후 CI가 실패하면 **되돌리거나 즉시 고치는 커밋을 올린다.** 실패 상태를 방치하지 않는다.

### 커밋 단위
- **하나의 커밋은 Structural·Behavioral 중 하나만** 담는다(§18 Tidy First). 브랜치가 없어도 이 분리는 유지한다.
- **작게 유지**: 한 커밋은 한 가지 목적. 나중에 되돌릴 수 있는 크기로.
- 형식은 §19를 따른다.

### 브랜치·PR을 쓰는 경우 (선택)
다음이면 브랜치를 따고 PR을 만든다. 그 외에는 `main` 직접 커밋으로 충분하다.
- 되돌리기 어렵거나 광범위한 변경 — 마이그레이션이 얽힌 리팩터링, 의존성 대량 상향
- 여러 커밋에 걸쳐 진행 중이라 중간 상태를 `main`에 두고 싶지 않을 때
- 리뷰를 받고 싶을 때(협업자가 있거나 스스로 diff를 정리해 보고 싶을 때)

브랜치 명명은 `feat/<요약>`, `fix/<요약>`, `refactor/<요약>`, `docs/<요약>` (kebab-case).
PR 제목은 커밋과 동일 형식이고, **하나의 PR도 Structural·Behavioral 중 하나만** 담는다.
본문 템플릿은 `.github/pull_request_template.md`에 둔다:

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

### 예시 (PowerShell)
```powershell
# 기본 — main 직접 커밋
git pull --ff-only
# ... 작업 + 로컬 검증 ...
git add <파일>
git commit -m "[Behavioral] feat: 주문 생성 API 추가"
git push

# 선택 — 브랜치·PR (위 조건에 해당할 때만)
git switch -c feat/order-create
git push -u origin feat/order-create
gh pr create --fill --base main
gh pr merge --squash --delete-branch
```

> **협업자가 생기면** `main` 브랜치 보호와 필수 CI 검사를 켜고 PR 흐름을 기본으로 되돌리는 것을 권장한다. 위 규칙은 단독 개발을 전제로 한다.

---

## 21. 신규 프로젝트 부트스트랩 체크리스트

- [ ] 저장소 구조(§3) 생성, `PLAN.md` / `.env.example` / `ARCHITECTURE.md` / `.gitignore`(`.env` 제외) 작성
- [ ] 백엔드 `app/` 골격(§4): `main.py`, `config.py`, `dependencies.py`, `db/`, `core/security.py`
- [ ] `Settings` + `get_settings()` (§5) — **모든 설정은 `.env`로 주입, OS 독립 (MUST §5)**, CORS, `TZ=Asia/Seoul`
- [ ] PostgreSQL `connect_args` KST 고정 (§7, §10)
- [ ] Alembic 초기화 + 초기 마이그레이션 (§11) — **DB는 항상 Alembic으로만 관리, `create_all`은 테스트 전용 (MUST §11)**
- [ ] `pytest` + SQLite in-memory + `conftest.py` 픽스처 (§12)
- [ ] 프론트 `src/` 골격(§13): axios `lib/api/client.ts`, `lib/stores/auth.svelte.ts`, `+layout.svelte`의 QueryClientProvider
- [ ] SPA 고정: `vite.config.ts` 의 `sveltekit({ adapter: adapter-static })` + 루트 `+layout.ts`의 `ssr = false` (§2, §13)
- [ ] 인증 흐름(§14): 메모리 access 토큰 + httpOnly refresh 쿠키(`REFRESH_TOKEN_TRANSPORT=cookie`), 앱 시작 `restoreSession()`, 401 → single-flight refresh·1회 재시도, `(protected)/+layout.ts` 가드 — 자체 계정 기본, SSO는 도입 시 콜백 추가
- [ ] Tailwind v4 `@theme`, pnpm, ESLint (§15, §2)
- [ ] `.github/workflows/ci.yml` 동작 확인 — push 이후 도는 **사후 안전망**이다. push 전 로컬 검증이 유일한 게이트 (§20)
- [ ] (협업자가 생기면) `.github/pull_request_template.md` 활용, `main` 보호 + CI 필수 검사 설정 (§20)
- [ ] 첫 실패 테스트 작성(TDD Red) → 구현(Green) (§18)

### 배포 전 체크리스트 (스타터 기본값 제거 — MUST)

skeleton 은 개발 편의를 위해 기본 관리자 계정(`admin`, 비밀번호는 스캐폴드가 무작위 생성해 `backend/.env` 의 `DEFAULT_ADMIN_PASSWORD` 에 기록)을 자동 시드한다. **운영 배포 전 반드시 제거·변경한다.**

- [ ] `SECRET_KEY` 를 무작위 값으로 교체 — 기본값(`change-me-in-production-use-32-bytes`)이면 개발에서는 경고, `APP_ENV=production` 에서는 **기동 실패**다 (공개된 키라 토큰 위조가 가능하다)
- [ ] 배포 대상의 KST 설정 확인 — Unix는 `backend/.env` 또는 런타임 환경변수의 `TZ=Asia/Seoul`과 `tzset()` 적용, Windows는 OS 시각대 `서울`(UTC+9) 설정 및 애플리케이션 경고 부재 확인 (§10, §17)
- [ ] `APP_ENV=production` 설정 — 기본 `SECRET_KEY`, 관리자 시드, `Secure` 없는 refresh 쿠키(`COOKIE_SECURE=false`)면 기동이 실패한다 (§17)
- [ ] 기본 관리자 시드 정리 — 운영 `backend/.env`에서 `SEED_DEFAULT_ADMIN=false`, 시드된 `admin` 계정 비밀번호 변경 (§17)
- [ ] HTTPS 종단 뒤에 배치하고 `COOKIE_SECURE=true` — refresh 쿠키가 평문 HTTP 로 새지 않게 한다 (§9)
- [ ] 프론트·API 오리진 배치 확인 — 같은 오리진(리버스 프록시 `/api`) 또는 같은 사이트 + `CORS_ORIGINS` 명시 (§14)
