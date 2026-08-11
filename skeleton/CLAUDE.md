# __PROJECT_NAME__ 개발 지침

> 이 프로젝트는 **사내 공통 아키텍처**를 따른다.
> 전체 상세 기준(SSOT): `docs/architecture.md` — 필요할 때 읽는다(통째 자동 로드하지 않음).
> 작업 절차는 아래 **작업별 스킬**이 필요할 때 자동으로 안내한다.

## 프로젝트 개요 (작성)

- **목적**: <한 줄 설명>
- **인증**: <그룹웨어 SSO | ERP 계정>
- **주요 도메인**: <예: 주문/계약, 이벤트/설문 등>

## 반드시 지킨다 (시작 전 확인 — 상세는 architecture.md ★MUST 요약)

- **스택 고정**: FastAPI + SQLAlchemy 2.0 + Alembic / SvelteKit(SPA) + Svelte 5 + TS / **PostgreSQL** (정확한 버전·버전별 주의는 [stack-versions] 스킬)
- **DB는 항상 Alembic으로만 관리** — 런타임 `create_all`·자동 DDL·수동 `ALTER` 금지(테스트 in-memory만 예외)
- **설정은 OS 무관 `.env`로 주입** — `$env:`/`export`/`set` 셸 환경변수 의존 금지, `.env` 커밋 금지(`.env.example`만)
- **시각 KST 단일 기준** — naive `datetime.now()`, PostgreSQL `timezone=Asia/Seoul`, 런타임 `TZ=Asia/Seoul`
- **API는 `/api/v1`**, 설정은 `get_settings()`+`@lru_cache`, 공통 의존성은 `app/dependencies.py`
- **계층 분리** — 라우터는 얇게(HTTP만), 도메인 로직은 `services/`, 검증은 `schemas/`
- **프론트**: axios + @tanstack/svelte-query + Svelte 5 runes, 패키지 매니저는 **pnpm**(npm 금지)
- **인증**: Bearer JWT
- **변경은 브랜치 → PR → CI 통과 → 머지** — `main` 직접 푸시 금지, 1 PR은 Structural·Behavioral 중 하나만

## 작업 방식

- 전역 `~/.claude/CLAUDE.md`의 **TDD / Tidy First / 커밋 형식 / PowerShell / pnpm / 한국어** 규칙을 따른다(여기서 반복하지 않음).
- 새 작업은 `plan.md` 순서대로 **실패하는 테스트 하나**부터(Red → Green → Refactor).
- 구조 변경(Structural)과 동작 변경(Behavioral)을 한 커밋/PR에 섞지 않는다.

## 작업별 스킬 (필요할 때 자동 로드)

- **add-backend-domain** — 백엔드 도메인 추가(모델→마이그레이션→스키마→서비스→라우터→테스트, §4·§8)
- **db-migration** — DB 스키마 변경 시 Alembic 워크플로/금지사항(§11)
- **add-frontend-feature** — 프론트 기능 추가(axios+@tanstack/svelte-query+Svelte 5 runes, §13·§14)
- **pr-workflow** — 커밋·브랜치·PR 흐름([Structural]/[Behavioral], §19·§20)
- **stack-versions** — 고정 버전·버전별 함정(pnpm10+/SvelteKit SPA/Svelte 5 runes/httpx2)·업그레이드 검증 절차

각 절차의 근거 상세는 `docs/architecture.md`의 해당 § 참조.

## 프로젝트 고유 결정 (공통 가이드에서 벗어난 부분만 기록)

- <없으면 "없음". 벗어난 결정은 사유와 함께 docs/architecture.md 에도 남긴다.>
