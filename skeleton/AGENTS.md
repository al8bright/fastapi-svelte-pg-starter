# __PROJECT_NAME__ 에이전트 지침 (AGENTS.md)

> 이 프로젝트는 **공통 아키텍처**를 따른다.
> 전체 상세 기준(SSOT): `ARCHITECTURE.md` — 필요할 때 읽는다(통째 자동 로드하지 않음).
> UI 색상·타이포그래피 기준은 `DESIGN.md`, 작업 순서는 `PLAN.md`, PRD·유저 플로우 등 프로젝트 문서는 `docs/`.
> 이 파일은 모든 AI 코딩 에이전트의 공통 지침이다. Claude Code 는 `CLAUDE.md` 가 이 파일을 import 해 읽는다.
> 작업 절차는 아래 **작업별 스킬**이 필요할 때 자동으로 안내한다.

## 프로젝트 개요 (작성)

- **목적**: <한 줄 설명>
- **인증**: <자체 계정 | OIDC SSO>
- **주요 도메인**: <예: 주문/계약, 이벤트/설문 등>

## 반드시 지킨다 (시작 전 확인 — 상세는 ARCHITECTURE.md ★MUST 요약)

- **스택 고정**: FastAPI + SQLAlchemy 2.1 + Alembic / SvelteKit(SPA) + Svelte 5 + TS / **PostgreSQL** (정확한 버전·버전별 주의는 [stack-versions] 스킬)
- **DB는 항상 Alembic으로만 관리** — 런타임 `create_all`·자동 DDL·수동 `ALTER` 금지(테스트 in-memory만 예외)
- **설정은 OS 무관 `.env`로 주입** — `$env:`/`export`/`set` 셸 환경변수 의존 금지, `.env` 커밋 금지(`.env.example`만)
- **시각 KST 단일 기준** — naive `datetime.now()`, PostgreSQL `timezone=Asia/Seoul`, 런타임 `TZ=Asia/Seoul`
- **API는 `/api/v1`**, 설정은 `get_settings()`+`@lru_cache`, 공통 의존성은 `app/dependencies.py`
- **계층 분리** — 라우터는 얇게(HTTP만), 도메인 로직은 `services/`, 검증은 `schemas/`
- **프론트**: axios + @tanstack/svelte-query + Svelte 5 runes, 패키지 매니저는 **pnpm**(npm 금지)
- **인증**: Bearer JWT
- **변경 흐름**: `main`에서 작업하고 바로 커밋·push 한다. 브랜치와 PR은 선택이다(되돌리기 어렵거나 광범위한 변경, 리뷰가 필요할 때). ⛔ **push 전 테스트·린트 통과가 유일한 게이트**다 — CI는 push 이후 도는 사후 안전망이다. 하나의 커밋에는 Structural 또는 Behavioral 한 유형만 담는다.

## 작업 방식

- 대화와 문서는 한국어를 기본으로 하고, 명령 예시는 현재 OS에 맞게 작성한다(Windows는 PowerShell). 프론트엔드 명령에는 pnpm을 사용한다.
- 새 작업은 `PLAN.md` 순서대로 **실패하는 테스트 하나**부터(Red → Green → Refactor).
- 테스트가 통과하는 상태에서만 리팩터링한다(Tidy First).
- 구조 변경(Structural)과 동작 변경(Behavioral)을 한 커밋/PR에 섞지 않는다. 커밋 제목에는 `[Structural]` 또는 `[Behavioral]` 접두사를 붙인다.

## 작업별 스킬 (필요할 때 자동 로드)

스킬 원문은 `.claude/skills/<이름>/SKILL.md`에 있다. Claude Code는 자동으로 로드하고, 다른 에이전트는 해당 작업 전에 파일을 직접 읽는다.

- **add-backend-domain** — 백엔드 도메인 추가(모델→마이그레이션→스키마→서비스→라우터→테스트, §4·§8)
- **db-migration** — DB 스키마 변경 시 Alembic 워크플로/금지사항(§11)
- **add-frontend-feature** — 프론트 기능 추가(axios+@tanstack/svelte-query+Svelte 5 runes, §13·§14)
- **pr-workflow** — 커밋·브랜치·PR 흐름([Structural]/[Behavioral], §19·§20)
- **stack-versions** — 고정 버전·버전별 함정(pnpm10+/SvelteKit SPA/Svelte 5 runes/httpx2)·업그레이드 검증 절차

각 절차의 근거 상세는 `ARCHITECTURE.md`의 해당 § 참조.

## 프로젝트 고유 결정 (공통 가이드에서 벗어난 부분만 기록)

- <없으면 "없음". 벗어난 결정은 사유와 함께 ARCHITECTURE.md 에도 남긴다.>
