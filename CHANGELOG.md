# Changelog

스캐폴드 템플릿 `fastapi-svelte-pg-starter` 의 변경 이력.
형식은 [Keep a Changelog](https://keepachangelog.com/) 를 느슨히 따른다.

---

## 2026-08-11

`fastapi-react-pg-starter` 로부터 프론트엔드를 **SvelteKit** 으로 이식해 신규 저장소로 분기.

### Added (추가)

- **SvelteKit SPA 프론트엔드 골격** — `@sveltejs/adapter-static`의 `index.html` fallback과 루트 레이아웃의 `ssr = false`·`prerender = true`를 적용했다.
- **파일 기반 라우팅** `src/routes/` — `/login`과 보호 라우트 그룹 `(protected)` 아래 `/`·`/landing`·`/my` 화면 및 인증 가드를 구성했다.
- **서버·클라이언트 상태 관리** — `@tanstack/svelte-query`로 서버 상태를 관리하고 Svelte 5 runes의 `$state`로 전역 인증 상태를 관리한다.
- **Svelte 품질 게이트** — eslint와 `eslint-plugin-svelte`, `svelte-check`를 사용하며 CI에서 설치·린트·타입 검사·빌드를 순서대로 수행한다.

### Changed (변경)

- **프론트 프레임워크**를 SvelteKit(SPA) + Svelte 5 + TypeScript로 교체하고, 기존 명시적 라우터 대신 SvelteKit 파일 기반 라우팅을 사용한다.
- **서버 상태 계층**을 `@tanstack/svelte-query`로, **클라이언트 상태 계층**을 별도 라이브러리 없는 Svelte 5 runes로 교체했다.
- **타입 검사**를 `tsc -b`에서 `svelte-check`로 교체했다. axios·Tailwind CSS v4·pnpm·Bearer JWT는 그대로 사용한다.
- **문서·스킬·스캐폴드 스크립트**의 프론트 관련 경로, 명령, 설명을 SvelteKit 구조와 `src/app.css` 테마 주입 방식에 맞게 갱신했다.

### Unchanged (그대로 유지)

- 백엔드(FastAPI · SQLAlchemy 2.0 · Alembic · pytest · ruff)와 PostgreSQL, 기본 인증 유저플로우, KST 단일 기준, `.env` 주입 규칙, TDD/Tidy First/PR 규칙은 원본과 동일하다.
- 런타임 최소는 Python ≥ 3.13 · Node ≥ 24 · pnpm ≥ 11이며, 백엔드 의존성은 원본의 정확 핀을 유지한다.

### 작업 관례 (다음 세션 참고)

- **버전 핀 정책**: `requirements.txt`는 `==` 정확 핀(재현성). 프론트 패키지는 실제로 호환되는 버전을 고정하며, 런타임 최소 상향만으로 핀을 자동으로 올리지 않는다. 상향 시 임시 스캐폴드에서 `pnpm install` → `pnpm lint` → `pnpm check` → `pnpm build`를 실제 검증한 뒤 핀한다(상세는 `stack-versions` 스킬 §5).
- **PR 흐름**: 브랜치 → 커밋(`[Structural]`/`[Behavioral]`) → push → `gh pr create` → squash 머지(`pr-workflow` 스킬).
- 정확한 버전·버전별 함정은 항상 `stack-versions` 스킬과 SoT 파일(`versions.env`·`requirements.txt`·`package.json`)을 기준으로 확인한다.

### 남은 후속 (미진행)

- 프론트 패키지 핀은 전체 품질 게이트를 실제 통과한 조합으로 확정한다.
- 도메인 기능은 **각 프로젝트에서 PRD 작성 후** 진행한다(스캐폴드는 공통 기반까지).
- 후보: 회원가입/사용자 관리(관리자 화면)·비밀번호 변경·토큰 만료/refresh.
- CI 머지 게이트 강제는 **GitHub 저장소 설정**(main 브랜치 보호 + 필수 체크)이 필요한 저장소 관리자 작업이다.
- 원본 `fastapi-react-pg-starter`의 상세 변경 이력은 해당 저장소의 CHANGELOG를 참조한다.
