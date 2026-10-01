# __PROJECT_NAME__

공통 아키텍처(FastAPI · SvelteKit · PostgreSQL) 기반 프로젝트.
상세 기준은 [`ARCHITECTURE.md`](ARCHITECTURE.md), 작업 순서는 [`PLAN.md`](PLAN.md), 디자인 토큰은 [`DESIGN.md`](DESIGN.md), AI 에이전트 지침은 [`AGENTS.md`](AGENTS.md), 프로젝트 고유 문서(PRD 등)는 [`docs/`](docs/README.md).

## 기술 스택 (주요 버전, 2026-10-02 기준)

> 아래 표는 **2026-10-02 기준** 요약이며, **정확한 출처(SSOT)** 는 다음 파일이다 — 변경 시 이 표가 아니라 해당 파일을 기준으로 한다:
> 런타임 [`scripts/versions.env`](scripts/versions.env) · 백엔드 [`backend/requirements.txt`](backend/requirements.txt) · 프론트 [`frontend/package.json`](frontend/package.json)

### 런타임
| 항목 | 버전 |
|------|------|
| Python | ≥ 3.13 |
| Node.js | ≥ 24 |
| pnpm | ≥ 11 |
| PostgreSQL | 프로젝트 고정 없음 (psycopg2-binary 2.9.x 지원 범위, 14+ 권장) |

### 백엔드 (`==` 정확히 핀, 재현성 우선)
| 패키지 | 버전 |
|--------|------|
| FastAPI | 0.142.2 |
| Uvicorn | 0.54.0 |
| SQLAlchemy | 2.1.1 |
| Alembic | 1.20.0 |
| psycopg2-binary | 2.9.13 |
| Pydantic / pydantic-settings | 2.13.5 / 2.15.0 |
| PyJWT | 2.15.1 |
| bcrypt | 5.0.0 |
| httpx2 | 2.13.1 |
| pytest | 9.1.1 |
| ruff | 0.16.9 |
| nh3 (본문 HTML 정화) | 0.3.7 |
| pillow (업로드 이미지 재인코딩) | 12.3.0 |

### 프론트엔드 (`^` 범위 핀)
| 패키지 | 버전 |
|--------|------|
| Svelte | 5.57 |
| SvelteKit (`@sveltejs/kit`) | 3.0 |
| @sveltejs/adapter-static | 4.0 |
| @sveltejs/vite-plugin-svelte | 7.3 |
| Vite | 8.3 (Rolldown) |
| TypeScript | 6.0 |
| svelte-check | 4.7 |
| vitest / jsdom (단위·컴포넌트 연기 테스트) | 5.0 / 30.1 |
| Tailwind CSS | 4.3 |
| @tailwindcss/vite | 4.3 |
| @tanstack/svelte-query | 6.3 |
| axios | 1.20 |
| ESLint | 10.11 |
| typescript-eslint | 8.71 |
| eslint-plugin-svelte | 3.23 |

## 사전 요구사항 (최초 1회)

런타임 **최소 버전**은 [`scripts/versions.env`](scripts/versions.env)에 정의돼 있다(**Python ≥ 3.13 / Node ≥ 24 / pnpm ≥ 11**).
부트스트랩 스크립트는 **이미 설치된 버전이 최소치 이상이면 그대로 재사용**하고, 미만이거나 없을 때만 설치한다.

```powershell
# Windows
.\scripts\bootstrap.ps1                 # 런타임 검사/설치
.\scripts\bootstrap.ps1 -WithPostgres   # PostgreSQL 까지 (psql 있으면 유지)
```

```bash
# macOS / Linux
./scripts/bootstrap.sh                  # 런타임 검사/설치
./scripts/bootstrap.sh --with-postgres  # PostgreSQL 까지 (psql 있으면 유지)
```

> 새로 설치된 런타임이 있으면 PATH 반영을 위해 **새 터미널**을 연다. (PostgreSQL은 원격 DB를 쓰면 설치 불필요.)

그다음 의존성 설치:

```powershell
cd backend; python -m venv .venv; .\.venv\Scripts\python -m pip install -r requirements.txt
cd ..\frontend; pnpm install
```

> 이미 `scaffold.ps1`로 생성한 프로젝트는 백엔드 venv·프론트 의존성이 설치된 상태다. 위 단계는 **다른 머신에서 clone 한 경우**에 필요하다.

## 실행

```powershell
# 백엔드
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000

# 프론트엔드 (다른 터미널)
cd frontend
pnpm dev
```

브라우저에서 http://localhost:5173 접속 → 로그인 없이 **공개 홈 화면**이 보인다. `admin`(비밀번호는 `backend/.env` 의 `DEFAULT_ADMIN_PASSWORD`)으로 로그인하면 상단에 **관리자 콘솔** 링크가 생긴다.

### 기본 인증 / 계정

스캐폴드에는 자체 계정(username/password) 로그인 플로우가 내장돼 있다:

- 처음 백엔드를 실행하면 기본 관리자 **`admin`** 이 자동 생성된다(없을 때만, lifespan 시드). 비밀번호는 스캐폴드가 무작위로 만들어
  `backend/.env` 의 `DEFAULT_ADMIN_PASSWORD` 에 넣고 완료 메시지에 출력한다 — 공용 기본 비밀번호는 없다.
  시드는 `SEED_DEFAULT_ADMIN=true` 일 때만 돌고, ⛔ `APP_ENV=production` 에서 켜져 있으면 기동을 거부한다.
- 흐름: 공개 홈(`/`)·공지(`/notices`)는 로그인 없이 본다. 로그인이 필요한 화면(`/me`)·관리자 콘솔(`/admin/*`)은 비로그인이면 `/login?next=<원래 위치>` 로 보내고, 로그인 후 그 위치로 돌아온다. 관리자가 아니면 `/admin` 은 403 화면이다.
- `users` 테이블은 `role`(일반 `user` / 관리자 `admin`)로 권한을 구분한다. 관리자 전용 API 는 `require_admin` 의존성으로 보호한다.
- 토큰: access JWT(15분)는 **브라우저 메모리에만** 두고, refresh 토큰은 백엔드가 심는 **httpOnly 쿠키**(`refresh_token`, `Path=/api/v1/auth`)다(`REFRESH_TOKEN_TRANSPORT=cookie`). 새로고침하면 앱 시작 시 `POST /auth/refresh` 로 세션을 복원하고,
  API 가 401 이면 refresh 를 한 번만 호출해 원 요청을 재시도한다. refresh 는 DB 세션(`auth_sessions`)으로 회전·재사용 감지·즉시 폐기된다.
- 로그인 연속 실패가 `LOGIN_MAX_FAILURES`(5) 회면 `LOGIN_LOCKOUT_MINUTES`(15) 분 동안 **429** 로 잠긴다(`login_throttles`).
- 테이블: `app_meta`(헬스 체크용), `users`, `auth_sessions`(refresh 세션), `login_throttles`(로그인 시도 제한), `notices`·`notice_attachments`·`banners` — 모두 Alembic(`0001`~`0004`).
- 상세는 `ARCHITECTURE.md` §9(백엔드 계약)·§14(프론트 흐름).
- ⚠️ 운영 배포 시 기본 관리자 비밀번호를 **즉시 변경**하라.

## 화면 구성

프론트엔드는 **공개 사용자 화면**(라우트 그룹 `frontend/src/routes/(site)/`)과 **관리자 콘솔**(`frontend/src/routes/admin/`) 두 레이아웃으로 나뉜다. 상세 규칙은 [`ARCHITECTURE.md` §14 "화면 구성 · 레이아웃 · 관리자 가드"](ARCHITECTURE.md#14-프론트엔드-인증-흐름)를 따른다.

| 영역 | 경로 | 내용 |
|------|------|------|
| 사용자 (상단 내비) | `/` | 배너 캐러셀(없으면 기본 히어로) · 주요 서비스 · 최신 공지 · 내 계정 |
| | `/notices`, `/notices/[id]` | 공지 목록(고정·검색·페이지) · 상세(본문·첨부 다운로드) |
| | `/login`, `/me` | 로그인(원래 위치로 복귀) · 내 정보/로그아웃(로그인 필요) |
| 관리자 콘솔 (사이드바) | `/admin` | 대시보드 — 사용자·세션·잠금·공지·배너·DB 상태 |
| | `/admin/notices` | 공지 작성·수정(리치 텍스트 에디터 — 이미지·유튜브), 첨부 업로드·다운로드, 저장하지 않은 변경 이탈 확인 |
| | `/admin/banners` | 배너 이미지 업로드, 링크·노출 기간, 활성 토글, 순서 변경 |
| | `/admin/users`, `/admin/sessions`, `/admin/login-throttles` | 권한·활성 변경, 세션 강제 종료, 로그인 잠금 해제 |
| | `/admin/system` | 백엔드·DB 헬스 체크, Alembic 리비전 |

- `/admin/*` 는 비로그인이면 로그인 화면으로, 로그인했지만 관리자가 아니면 403 화면으로 보낸다(`routes/admin/+layout.ts`). 권한 경계는 백엔드(`/api/v1/admin/*` 의 `require_admin`)다.
- 디자인 토큰은 `DESIGN.md` → `frontend/src/app.css` 의 `@theme` 다. 화면의 `[대괄호]` 문구(히어로·서비스 카드·푸터)와 자리표시 메뉴(서비스·고객지원)는 프로젝트에 맞게 바꾼다.
- 업로드 파일은 백엔드 `UPLOAD_DIR`(기본 `backend/uploads/`, `.gitignore` 대상)에 저장되고, 개발 서버는 `/api` 와 `/uploads` 를 백엔드로 프록시한다. 운영은 정적 호스팅 앞단 리버스 프록시가 `/api`·`/uploads` 를 백엔드로 넘긴다(ARCHITECTURE.md §14 "오리진 배치").

### 브라우저 수동 점검 (jsdom 으로 확인할 수 없는 것)

리치 에디터는 `document.execCommand`·canvas 를 쓰므로 단위 테스트(jsdom)로는 서식 명령·자르기를 확인할 수 없다. 에디터나 관리자 화면을 고치면 브라우저에서 다음을 확인한다.

- 공지 작성: 굵게·제목·목록·정렬·링크·형광펜 → Ctrl+Z/Ctrl+Shift+Z 로 되돌리기·다시 실행
- 이미지: 버튼·붙여넣기·드래그로 넣기 → 자르기(비율·회전) → 모서리 핸들·프리셋으로 크기 조절 → 대체 텍스트·교체·삭제 후 Ctrl+Z
- 유튜브 링크 넣기·크기 조절·링크 바꾸기, 잘못된 링크 오류
- 저장 → 수정 화면으로 전환·첨부 여러 개 업로드(진행률)·관리자 다운로드 파일명, 변경 후 다른 메뉴 클릭 시 확인 다이얼로그·새로고침 시 브라우저 확인
- 공개 상세에서 본문·이미지·영상·첨부 다운로드, 배너 캐러셀(자동 넘김·멈춤·링크), 좁은 화면의 관리자 메뉴 서랍

## DB 스키마 변경 (ARCHITECTURE.md §11)

```powershell
cd backend
.\.venv\Scripts\python -m alembic revision --autogenerate -m "변경요약"
.\.venv\Scripts\python -m alembic upgrade head
```

## 테스트 · 린트

```powershell
cd backend
.\.venv\Scripts\python -m pytest -q          # 백엔드 테스트
.\.venv\Scripts\python -m ruff check .       # 백엔드 린트 (ruff)
cd ..\frontend; pnpm lint                     # 프론트 린트 (eslint)
pnpm check                                     # 프론트 타입 체크 (svelte-check)
pnpm test                                      # 프론트 테스트 (vitest)
```

## CI (ARCHITECTURE.md §20)

`.github/workflows/ci.yml` 이 push/PR(main) 마다 자동 실행한다 — 백엔드(ruff + pytest) / 프론트(eslint + svelte-check + vitest + build).
CI는 push 이후 도는 **사후 안전망**이다. ⛔ 게이트는 push 전 로컬 검증(위 명령)이며, `main` 직접 커밋이 기본이고 브랜치·PR은 선택이다.
협업자가 생기면 `main` 브랜치 보호와 CI 필수 검사를 켜고 PR 흐름을 기본으로 되돌린다.
