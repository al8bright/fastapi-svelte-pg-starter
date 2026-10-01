# Changelog

스캐폴드 템플릿 `fastapi-svelte-pg-starter` 의 변경 이력.
형식은 [Keep a Changelog](https://keepachangelog.com/) 를 느슨히 따른다.

---

## 2026-10-02

의존성 전체를 최신 안정판으로 상향했다. 프론트는 **SvelteKit 3 메이저 마이그레이션**을 포함한다.

### Changed (변경)

- **백엔드 핀 상향** — FastAPI 0.142.2 · Uvicorn 0.54.0 · SQLAlchemy 2.1.1 · Alembic 1.20.0 · psycopg2-binary 2.9.13 · Pydantic 2.13.5 / pydantic-settings 2.15.0 · PyJWT 2.15.1 · bcrypt 5.0.0 · httpx2 2.13.1 · ruff 0.16.9 (python-multipart 0.0.32 · pytest 9.1.1 은 유지).
- **프론트 상향** — `@sveltejs/kit` ^3.0.0 · `@sveltejs/adapter-static` ^4.0.0 · svelte ^5.57.1 · vite ^8.3.2 · `@sveltejs/vite-plugin-svelte` ^7.3.1 · `@tanstack/svelte-query` ^6.3.0 · axios ^1.20.0 · eslint ^10.11.0 · typescript-eslint ^8.71.0 · eslint-plugin-svelte ^3.23.0 · globals ^17.13.0 · svelte-check ^4.7.6 · `@types/node` ^24.19.0 · `packageManager` pnpm@11.28.3. typescript 는 `~6.0.3` 유지(TS 7 비호환).
- **SvelteKit 3 마이그레이션** — `svelte.config.js` 를 삭제하고 adapter·preprocess 설정을 `vite.config.ts` 의 `sveltekit({ ... })` 옵션으로 옮겼다. `$lib` 별칭을 `package.json` `"imports"` 의 `#lib/*`(확장자 `.js` 명시)로, `$app/environment` 를 `$app/env` 로 교체했다. `resolve()` 경로를 Kit 3 pathname 형식(`"login"`, 루트 `""`)으로 바꾸고, `tsconfig.json` 은 `$app/tsconfig` 를 상속한다. eslint 는 `@sveltejs/load-config` 로 svelte 설정을 읽는다(devDependency 추가).
- **ruff 0.16 대응** — `UserRole` 을 `enum.StrEnum` 으로 변경(UP042). 값·DB 저장 동작은 같다.
- **Alembic 경고 제거** — `alembic.ini` 에 `path_separator = os` 를 추가했다(Alembic 1.16+ DeprecationWarning).
- **문서·스킬** — `README` 버전 표, `docs/architecture.md`, `CLAUDE.md`, `add-frontend-feature`·`add-backend-domain`·`stack-versions` 스킬을 새 버전과 SvelteKit 3 규칙(`#lib`, `$app/env`, `resolve()` 형식, 설정 위치)에 맞췄다. `stack-versions` 에 SvelteKit 3 · bcrypt 5 · SQLAlchemy 2.1/Alembic · ruff 0.16 주의사항을 추가했다.

### Added (추가)

- **bcrypt 5 회귀 테스트** — bcrypt 5 는 72바이트 초과 입력에 `ValueError` 를 던진다. 기존 바이트 상한 검증으로 500 이 아닌 422 가 반환되는지(영문 73바이트, 한글 25자), `hash_password` 거부, `verify_password` 의 절단 우회 차단을 테스트로 고정했다(총 10건).

### Fixed (수정)

- 테스트 픽스처에서 SQLite 엔진을 `dispose()` 하지 않아 `-W error` 실행 시 `ResourceWarning` 으로 실패하던 문제를 고쳤다.

### 검증

- 임시 프로젝트(Windows)에서 `ruff check` · `pytest`(10건, `-W error` 포함) · PostgreSQL 16 상대 `alembic upgrade head`/`downgrade base`/`check` · `pnpm install`/`lint`/`check`/`build` 를 모두 통과했다. `pnpm-workspace.yaml` 은 검증 설치로 변경되지 않았다.

### 남은 후속 (미진행)

- `@sveltejs/kit@3.0.0` · `@sveltejs/adapter-static@4.0.0` 은 2026-10-01 17:20 UTC 에 배포돼 pnpm 11 의 `minimum-release-age`(24시간)에 걸린다. **2026-10-02 17:22 UTC 이전**에 새 프로젝트를 만들면 `pnpm install` 이 `pnpm-workspace.yaml` 에 `minimumReleaseAgeExclude` 를 자동 삽입한다. 그 이후에는 해소되며 템플릿에는 exclude 를 넣지 않았다.
- `eslint-plugin-svelte@3.23` 의 SvelteKit 전용 규칙(`svelte/no-navigation-without-resolve` 등)은 Kit 1·2 에서만 동작해 Kit 3 에서는 비활성이다. 플러그인이 Kit 3 를 지원하면 다시 확인한다.
- Windows PowerShell 5.1 에서 `scripts/bootstrap.ps1` 이 파싱 오류(184행 `Unexpected token '}'`)로 실행되지 않는다. BOM 없는 UTF-8 한글 파일을 5.1 이 ANSI 로 읽는 문제로 보이며, 이번 범위에서는 고치지 않았다.

---

## 2026-10-02 — 기본 문서 세트 정리 (AGENTS.md 도입, 문서 루트 배치)

생성 프로젝트의 기준 문서 6종을 골격 루트에 두고, `docs/` 는 프로젝트 고유 문서(PRD·유저 플로우·기획서 등) 전용으로 비웠다.
네 형제 템플릿(react·nextjs·nuxt·svelte)이 같은 구성을 갖는다.

```
skeleton/
├── README.md  AGENTS.md  CLAUDE.md  ARCHITECTURE.md  DESIGN.md  PLAN.md
└── docs/README.md   # 프로젝트 고유 문서 안내
```

### Changed (변경)

- **`plan.md` → `PLAN.md`** — 대문자로 통일하고 모든 참조(문서·스킬·랜딩 화면 안내 문구)를 고쳤다.
- **`docs/architecture.md` → `ARCHITECTURE.md`** (골격 루트) — 대문자로 개명하고 저장소 안의 모든 참조와 §3 구조도를 갱신했다.
- **`DESIGN.md` (템플릿 루트) → `skeleton/DESIGN.md`** — 생성 프로젝트는 `-Design`/`-NoDesign` 과 무관하게 항상 `DESIGN.md` 를 받는다.
  두 옵션은 이제 `@theme` 주입 여부만 결정하며, 스캐폴드의 별도 복사 단계(`docs/DESIGN.md`)는 제거했다.
- **`CLAUDE.md` → `AGENTS.md`** — 에이전트 공통 지침의 원본을 `AGENTS.md` 로 옮겼다(`git mv`, 이력 유지).
  새 `CLAUDE.md` 는 `@AGENTS.md` 를 import 하고 Claude Code 전용 내용만 둔다. Claude Code 는 `CLAUDE.md` 가 있으면
  `AGENTS.md` 를 스스로 읽지 않으므로, import 없이 두 파일을 따로 두면 규칙이 갈라진다.
  전역 `~/.claude/CLAUDE.md` 에 기대던 작업 규칙(TDD·Tidy First·커밋 형식·PowerShell·pnpm·한국어)은 `AGENTS.md` 에 직접 적었다 — 다른 에이전트는 그 전역 파일을 읽지 않기 때문이다.
- **변경 반영 규칙을 `main` 직접 커밋(브랜치·PR 선택)으로 통일** — 형제 저장소(react·nextjs)와 같은 규칙으로 맞췄다.
  `AGENTS.md`, `ARCHITECTURE.md`(★MUST 15·§20·§21 체크리스트), 골격 `README.md`·`PLAN.md`, `ci.yml` 주석을 갱신했다. 게이트는 push 전 로컬 검증이고 CI 는 사후 안전망이다.
- **`pr-workflow` 스킬** — macOS/Linux 명령을 함께 싣고, push 전 검증 명령을 이 골격의 실제 `package.json` 스크립트에 맞췄다(없는 스크립트를 부르지 않도록).

### Added (추가)

- **`docs/README.md`** — `docs/` 의 용도(프로젝트 고유 문서)와 루트 기준 문서 목록을 안내한다. 빈 폴더가 git 에 남도록 하는 역할도 한다.

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
