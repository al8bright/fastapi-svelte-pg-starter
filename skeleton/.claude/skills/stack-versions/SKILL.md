---
name: stack-versions
description: __PROJECT_NAME__ 의 고정 스택 버전과 버전별 주의사항(gotcha)을 정의한다. 의존성 추가·업그레이드, pnpm/Vite/SvelteKit/tsconfig/테스트 설정 작업, 또는 버전에 따라 동작이 달라지는 코드를 작성·디버깅할 때 사용. 정확한 버전의 출처 파일과 SvelteKit(SPA 모드)/Svelte 5 runes/svelte-query/pnpm 10+/Starlette httpx2 등 버전별 함정, 업그레이드 검증 절차를 안내한다.
---

# 스택 버전 & 버전별 주의

## 1. 정확한 버전의 출처 (SSOT) — 항상 여기서 확인
- **런타임 최소**: `scripts/versions.env`
- **백엔드**: `backend/requirements.txt` (`==` 정확 핀)
- **프론트**: `frontend/package.json` (`^`/`~` 범위)

> 아래 2·3은 참고용 스냅샷이다. **실제 값은 위 파일을 읽어서** 확인한다.

## 2. 버전 스냅샷 (2026-08-11 기준)
- **런타임**: Python ≥ 3.13 · Node ≥ 24 · pnpm ≥ 11 (PostgreSQL 고정 없음, 14+ 권장)
- **백엔드**: FastAPI 0.137.2 · SQLAlchemy 2.0.51 · Alembic 1.18.5 · Pydantic 2.13.4 / settings 2.14.2 · psycopg2-binary 2.9.12 · PyJWT 2.13.0 · bcrypt 4.3.0 · httpx2 2.5.0 · pytest 9.1.1 · ruff 0.14.0
- **프론트**: svelte `5.56` · @sveltejs/kit `2.70` · @sveltejs/adapter-static `3.0` · @sveltejs/vite-plugin-svelte `7.3` · vite `8.2 (Rolldown)` · typescript `6.0` · svelte-check `4.7` · @tanstack/svelte-query `6.1` · axios `1.19` · tailwindcss `4.3` · @tailwindcss/vite `4.3` · eslint `10.8` · typescript-eslint `8.66` · eslint-plugin-svelte `3.22`

## 3. ⚠️ 버전별 함정 (코드·설정 작성 시 반드시)

### pnpm 10+ (현재 11)
- 의존성 **빌드 스크립트가 기본 차단**된다. 허용은 `frontend/pnpm-workspace.yaml` 의 **`allowBuilds` 맵**으로 한다.
  ⚠️ **pnpm 11 에서 키가 바뀌었다** — pnpm 10 의 리스트형 `onlyBuiltDependencies` 는 **더 이상 인식되지 않는다.**
  그대로 두면 `ERR_PNPM_IGNORED_BUILDS` 가 나고, **pnpm 이 이 파일에 `allowBuilds` 맵을 자동으로 끼워 넣어 템플릿을 오염시킨다**(실측 확인).
  ```yaml
  allowBuilds:
    esbuild: true
    '@tailwindcss/oxide': true
  ```
  (현재 목록은 **안전망 용도**다. Vite 8 은 esbuild 대신 rolldown 을 쓰므로 esbuild 는 트리에 아예 없고, `@tailwindcss/oxide` 도 플랫폼 바이너리를 미리 받아 실제 실행되는 postinstall 이 없다.)
- ⚠️ pnpm 11 의 **`minimum-release-age` 기본값이 24시간**이다(`pnpm config get` 은 `undefined` 로 보이지만 내부 기본값이 있다).
  **배포 24시간 이내 버전을 `^` 로 핀하면 `pnpm install` 이 `pnpm-workspace.yaml` 에 `minimumReleaseAgeExclude:` 블록을 자동으로 써 넣어 템플릿 파일이 오염된다.**
  (실제 사례: `typescript-eslint@^8.67.0`(전날 배포) → exclude 11줄 삽입. `^8.66.0` 으로 한 단계 낮춰 회피.)
  ⛔ 스캐폴드 템플릿은 install 이 파일을 고치면 안 된다 → **"배포 후 24시간 경과한 버전만 핀"**.
- `package.json` 의 `packageManager` 필드로 pnpm 버전 고정(corepack).

### Vite
- Vite 8 은 번들러가 **Rolldown**(Rollup 아님). Rollup 전용 플러그인/옵션을 가정하지 말 것.
- native plugin v2 기본, 기본 브라우저 타깃 상향, `import.meta.hot.accept` 폴백 제거.
- **Vite 8 그대로 사용 가능**(다운 불필요). `@sveltejs/vite-plugin-svelte@7` peer 가 `vite: ^8.0.0` — **plugin 7 은 오히려 Vite 8 전용**이다. `@sveltejs/kit@2` peer 는 `^5||^6||^7||^8`.
- ⚠️ Vite 를 7 이하로 내리려면 **vite-plugin-svelte 6.x** 를 함께 써야 한다. 현재 핀: `8.2 (Rolldown)`.

### SvelteKit (SPA 모드)
- 이 스캐폴드는 **정적 SPA**다. `svelte.config.js` 는 `@sveltejs/adapter-static({ fallback: 'index.html', strict: false })`.
  ⚠️ **`strict: false` 가 필요하다** — 라우트 그룹 `(protected)` 때문에 strict 모드면 "prerender 되지 않은 경로" 로 빌드가 실패할 수 있다.
- 루트 `src/routes/+layout.ts` 에 `export const ssr = false` · `export const prerender = true`. 이게 SPA 를 성립시키는 핵심이니 지우지 말 것.
  이 조합은 **정상**이다: prerender 가 빈 셸을 만들고 adapter-static 이 fallback 으로 덮어쓴다 → 빌드 로그의 `Overwriting build/index.html with fallback page.` 는 **에러가 아니다**.
- ⚠️ **prerender 단계는 Node 에서 돈다** → `localStorage` 를 직접 만지면 빌드가 깨진다.
  `lib/auth/token.ts` 의 `getToken`/`setToken`/`clearToken` 전부에 `$app/environment` 의 **`browser` 가드 필수**, `(protected)/+layout.ts` 가드도 `if (browser && !getToken())` 형태여야 한다.
- ⛔ **SSR 전용 기능 금지** — `+page.server.ts`, `+layout.server.ts`, `hooks.server.ts`, `$env/dynamic/*`. 정적 빌드라 실행될 서버가 없어 동작하지 않는다.
- 데이터 로딩은 클라이언트에서 axios + svelte-query 로 한다(§13). 백엔드는 별도 FastAPI 서버.
- `(protected)` 같은 **라우트 그룹은 URL 에 나타나지 않는다**. 인증 가드는 그룹 `+layout.ts` 에 둔다(§14).

### Svelte 5 runes
- 반응성은 룬으로: `$state` / `$derived` / `$props` / `$effect`.
- ⛔ 레거시 문법 금지 — `export let`(→ `$props()`), `<slot/>`(→ `{@render children()}`), `$:`(→ `$derived`/`$effect`).
- **`.svelte.ts` 확장자**여야 `.svelte` 밖의 모듈에서도 룬이 컴파일된다. 평범한 `.ts` 에 `$state` 를 쓰면 컴파일 에러.
- 전역 상태는 **클래스 + 필드 `$state`** 를 `lib/stores/*.svelte.ts` 에 두고 **인스턴스를 export** 한다(`export const authStore = new AuthStore()`).
  파생값(`isAuthenticated`)은 zustand 처럼 함수가 아니라 **getter** 다 → `authStore.isAuthenticated` (⛔ 괄호 없음).
- `$effect` 는 부수효과 전용. ⛔ 서버 데이터 패칭 용도로 쓰지 말 것(→ svelte-query).

### @tanstack/svelte-query
- **svelte 어댑터 v6** 을 쓴다(현재 핀 `6.1`). React 판과 **API 이름이 다르다**: `useQuery` 아님 → **`createQuery`**, `useMutation` 아님 → **`createMutation`**. (`useQueryClient` 는 동일 이름)
- ⚠️ **옵션은 객체가 아니라 함수(accessor)** 로 넘긴다 — `createQuery(() => ({ queryKey, queryFn }))`, `createMutation(() => ({ mutationFn }))`. 함수 본문이 룬처럼 반응형으로 재평가된다. ⛔ v4 의 store 전달 방식 아님.
- ⚠️ 반환값은 store 가 아니라 **rune 기반 반응형 객체** → `$query.data` 아님, **`query.data` / `query.isPending` / `query.isSuccess` / `query.isError`**.
- ⛔ **컴포넌트 초기화 시점(`<script>` 최상단)에서만 호출.** 이벤트 핸들러 안에서 호출하면 `No QueryClient was found in Svelte context` 로 터진다. (래퍼 `lib/queries/*.ts` 는 룬을 안 쓰므로 평범한 `.ts` 로 둔다.)
- 프로바이더는 `src/routes/+layout.svelte` 에서 한 번만 마운트한다. props = `{ client, children }`, 내부는 `{@render children()}`.
- ⚠️ React 문서/예제를 그대로 복붙하면 깨진다. 정확한 시그니처는 설치된 버전의 타입 정의를 확인한다.

### TypeScript / svelte-check
- 타입 검사는 **`svelte-check`** 로 한다(`pnpm check` = `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json`). ⛔ `tsc -b` 로 대체하지 말 것 — `.svelte` 파일을 못 본다.
- ⛔ **TS 7 로 올릴 수 없다**(npm `latest` 가 이미 7 이어도). `typescript-eslint@8` peer 는 `>=4.8.4 <6.1.0`, `svelte-check@4` peer 는 `^5 || ^6` — 둘 다 TS 7 미지원. **`~6.0` 에 머문다.**
- `frontend/tsconfig.json` 은 `.svelte-kit/tsconfig.json` 을 **`extends`** 한다. 경로 별칭(`$lib`)·`baseUrl`·`paths`·`include`/`exclude` 는 **SvelteKit 이 생성·관리**하므로 ⛔ 직접 쓰지 말 것(덮으면 별칭이 깨진다).
- `.svelte-kit/` 이 없으면 검사·빌드가 실패한다 → `pnpm exec svelte-kit sync` 먼저.
- TypeScript 6: **`types` 기본값이 `[]`**(이전엔 모든 `@types/*` 자동 포함). node 전역(`__dirname` 등)이나 앰비언트 타입이 필요한 tsconfig 에는 `"types": ["node", ...]` 를 **명시**해야 한다.

### ESLint (9 → 10)
- ESLint 는 **10** 이다(`@eslint/js` 도 10 동반). `typescript-eslint@8` · `eslint-plugin-svelte@3` 모두 `eslint: ^10` peer 지원.
- ⚠️ `eslint-plugin-svelte@3` 의 **`svelte/no-navigation-without-resolve` 가 recommended 기본 포함** → `href="/landing"`, `goto("/login")` 이 전부 **에러**다.
  `$app/paths` 의 **`resolve()`** 로 감싼다: `href={resolve("/landing")}`, `goto(resolve("/"))`, `redirect(302, resolve("/login"))`. (부수효과로 경로가 타입 체크된다. 라우트 그룹 이름은 경로에 쓰지 않는다.)
- flat config(`frontend/eslint.config.js`)에 **`svelteConfig`** 를 넘겨야 한다 — `.svelte`/`.svelte.ts` 블록의 `languageOptions.parserOptions` 에 `{ parser: tseslint.parser, extraFileExtensions: [".svelte"], svelteConfig }`.
- `js.configs.recommended` 의 `no-undef` 가 `.svelte` 에도 걸리므로 `languageOptions.globals` 에 **`globals.browser` + `globals.node`** 를 넣는다(그래서 `globals` 가 devDependency).

### FastAPI 0.137 + Starlette 1.x
- TestClient 는 **httpx2** 를 쓴다(httpx 아님). `requirements.txt` 에 `httpx2`. ⛔ `httpx` 로 되돌리면 deprecation 경고.
- 서버↔서버 HTTP 클라이언트도 `httpx2`.

### Pydantic 2.x
- v2 API(`model_config`, `@field_validator`, `SettingsConfigDict`). ⛔ v1 패턴(`class Config`, `@validator`) 금지.

### 인증 / 린트·CI
- 자체 계정 비밀번호는 **bcrypt** 해시(`core/security` 의 `hash_password`/`verify_password`). JWT `sub` = user id.
- 백엔드 린트는 **ruff**(`backend/pyproject.toml`): FastAPI `Depends` 등은 **B008 예외**(`extend-immutable-calls`), `alembic/` 제외, line-length 120. 새 의존성으로 lint 가 깨지면 이 설정을 먼저 본다.
- 프론트 린트는 **eslint + typescript-eslint + eslint-plugin-svelte**(`frontend/eslint.config.js`, flat config).
- **CI**(`.github/workflows/ci.yml`)가 push·PR(main) 마다 backend(ruff+pytest) / frontend(**eslint + svelte-check + build**) 를 실행. 워크플로는 생성 프로젝트(루트)에서만 동작한다.

## 4. 백엔드 핀 정책
- `requirements.txt` 는 **`==` 정확 핀, 재현성 우선**(ARCHITECTURE.md §2).
- 런타임 최소를 올린다고(예: 3.13) 핀을 자동으로 올리지 말 것 — **호환되면 유지**(현재 핀은 3.13 호환 확인됨).
- 핀 상향은 보안/기능 목적의 **의식적 결정**으로. FastAPI 는 "최신이 아닌 안정화된 마이너" 선호.

## 5. 업그레이드 검증 절차 (필수)
버전을 올릴 땐 추측 금지 — **임시 스캐폴드로 실제 검증한 뒤** 핀을 고정한다:
1. `scaffold.ps1 -Name tmp -Target <스크래치경로> -SkipDb -SkipInstall -NoDesign`
2. 백엔드: `python -m venv .venv` → `pip install -r requirements.txt` → `ruff check .` → `pytest -q`
3. 프론트: `pnpm install` → `pnpm lint` → `pnpm check`(svelte-check) → `pnpm build`
4. 통과 시 핀 고정 후 **갱신할 곳을 모두**: SoT 파일 + `README.md` 표(+기준일) + 필요 시 `ARCHITECTURE.md` + **이 스킬의 스냅샷/주의(§2·§3)**. 커밋/PR은 [pr-workflow].
