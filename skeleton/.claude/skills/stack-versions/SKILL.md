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

## 2. 버전 스냅샷 (2026-10-02 기준)
- **런타임**: Python ≥ 3.13 · Node ≥ 24 · pnpm ≥ 11 (PostgreSQL 고정 없음, 14+ 권장)
- **백엔드**: FastAPI 0.142.2 · Uvicorn 0.54.0 · SQLAlchemy 2.1.1 · Alembic 1.20.0 · Pydantic 2.13.5 / settings 2.15.0 · psycopg2-binary 2.9.13 · PyJWT 2.15.1 · bcrypt 5.0.0 · python-multipart 0.0.32 · httpx2 2.13.1 · pytest 9.1.1 · ruff 0.16.9
- **프론트**: svelte `5.57` · @sveltejs/kit `3.0` · @sveltejs/adapter-static `4.0` · @sveltejs/vite-plugin-svelte `7.3` · @sveltejs/load-config `0.2` · vite `8.3 (Rolldown)` · typescript `6.0` · svelte-check `4.7` · @tanstack/svelte-query `6.3` · axios `1.20` · tailwindcss `4.3` · @tailwindcss/vite `4.3` · eslint `10.11` · typescript-eslint `8.71` · eslint-plugin-svelte `3.23` · @types/node `24.x` · pnpm `11.28`

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
  ⚠️ 예외 기록(2026-10-02): `@sveltejs/kit@^3.0.0`·`@sveltejs/adapter-static@^4.0.0`(2026-10-01 17:20Z 배포)은 **사용자 결정으로 24시간 경과 전에 핀**했다.
  **2026-10-02 17:22 UTC 이전**의 신규 설치는 위 exclude 블록이 자동 삽입된다(실측: kit·adapter-static·vite 8.3.2·globals 17.13.0 4줄). 그 시각 이후엔 정상.
  검증 때만 우회: `pnpm_config_minimum_release_age=0` 환경변수(⚠️ `npm_config_*` 는 **pnpm 11 이 무시**한다).
  `pnpm <script>` 실행 전에도 lockfile 을 정책으로 재검증하므로 install 만 플래그로 넘겨서는 `pnpm check`/`build` 가 `ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION` 으로 막힌다 → 환경변수로 세션 전체에 적용.
- `package.json` 의 `packageManager` 필드로 pnpm 버전 고정(corepack).

### Vite
- Vite 8 은 번들러가 **Rolldown**(Rollup 아님). Rollup 전용 플러그인/옵션을 가정하지 말 것.
- native plugin v2 기본, 기본 브라우저 타깃 상향, `import.meta.hot.accept` 폴백 제거.
- `@sveltejs/vite-plugin-svelte@7` peer 가 `vite: ^8.0.0` — **plugin 7 은 Vite 8 전용**이다.
- ⛔ **`@sveltejs/kit@3` peer 는 `vite ^8.0.12` · `svelte ^5.57.1` · `typescript ^6` · `@sveltejs/vite-plugin-svelte ^7`** — Vite 7 이하로 내릴 수 없다. 현재 핀: `8.3 (Rolldown)`.

### SvelteKit 3 (2 → 3 에서 바뀐 것 — 2.x 문서/예제 복붙 주의)
- ⛔ **`svelte.config.js` 가 없다.** 있으면 `config_file_unsupported` 에러로 sync/check/build 가 전부 실패한다.
  Kit 설정(adapter·preprocess·alias 등)은 **`vite.config.ts` 의 `sveltekit({ ... })` 플러그인 옵션**으로 넘긴다(`kit: { }` 래핑 없이 평평하게).
- ⛔ **`$lib` 별칭이 없어졌다** → `package.json` 의 `"imports": { "#lib/*": "./src/lib/*" }`(Node subpath imports)로 **`#lib`** 를 쓴다.
  **확장자 필수**: `#lib/api/client.js`(실제 파일은 `.ts` — TS 규약대로 `.js` 로 적는다), `.svelte.ts` 는 `#lib/stores/auth.svelte.js`.
- `$app/environment` → **`$app/env`**, `$app/stores` 제거(→ `$app/state`), `pushState`/`replaceState` → `goto(url, { shallow: true, state })`, `invalidateAll` → `refreshAll`.
- ⚠️ **`resolve()` 의 pathname 은 앞의 `/` 없이** 쓴다: `resolve("login")`, `resolve("landing")`, 루트는 **`resolve("")`**.
  `"/..."` 는 **라우트 ID** 로 해석돼 그룹까지 적어야 한다(`"/(protected)/my"`). 2.x 식 `resolve("/landing")` 은 svelte-check 타입 에러.
- `goto()` 는 앱 라우트로 해석되지 않는 목적지를 **reject** 한다 → 외부 이동은 `window.location.href`.
- `tsconfig.json` 은 **`"extends": "$app/tsconfig"`**(생성 위치 `node_modules/$app`, `svelte-kit sync` 가 만든다) + `"include": ["src"]`. `.svelte-kit/tsconfig.json` 이 아니다.
- eslint 는 `svelte.config.js` 를 import 할 수 없으므로 **`@sveltejs/load-config`** 의 `loadConfig("./", { traverse: false })` 로 vite 설정에서 svelte 설정을 읽어 `svelteConfig` 로 넘긴다.
- ⚠️ `eslint-plugin-svelte@3.23` 의 SvelteKit 전용 규칙(`svelte/no-navigation-without-resolve` 등)은 조건이 `svelteKitVersions: 1·2` 라 **Kit 3 에서 조용히 꺼진다**. `resolve()` 사용은 lint 가 아니라 규칙·리뷰·svelte-check 로 지킨다.
- 공식 자동 마이그레이션: `pnpm dlx sv migrate sveltekit-3 --tasks all`(⚠️ `npx sv` 는 pnpm 전용 `runtime:` 의존성 때문에 npm 에서 실패). 결과물은 세미콜론·작은따옴표가 섞이므로 이 저장소 스타일로 되돌린다.
- CSRF 보호는 필수(`checkOrigin` → `csrf.trustedOrigins`), dev 정적 자산 CORS 는 Vite 담당 — 이 SPA(서버 없음 + /api 프록시)에는 영향 없음.

### SvelteKit (SPA 모드)
- 이 스캐폴드는 **정적 SPA**다. `vite.config.ts` 의 `sveltekit({ adapter: adapter({ fallback: 'index.html', strict: false }) })` (adapter-static 4).
  ⚠️ **`strict: false` 가 필요하다** — 라우트 그룹 `(protected)` 때문에 strict 모드면 "prerender 되지 않은 경로" 로 빌드가 실패할 수 있다.
- 루트 `src/routes/+layout.ts` 에 `export const ssr = false` · `export const prerender = true`. 이게 SPA 를 성립시키는 핵심이니 지우지 말 것.
  이 조합은 **정상**이다: prerender 가 빈 셸을 만들고 adapter-static 이 fallback 으로 덮어쓴다 → 빌드 로그의 `Overwriting build/index.html with fallback page.` 는 **에러가 아니다**.
- ⚠️ **prerender 단계는 Node 에서 돈다** → 브라우저 API(`location`, 쿠키 전송 요청 등)를 load 에서 바로 쓰면 빌드가 깨진다.
  `lib/auth/session.ts` 의 `restoreSession()` 은 `$app/env` 의 **`browser` 가드**로 no-op 이 되고, `(protected)/+layout.ts` 가드도 `if (!browser) return` 후 판단한다.
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
- **svelte 어댑터 v6** 을 쓴다(현재 핀 `6.3`). React 판과 **API 이름이 다르다**: `useQuery` 아님 → **`createQuery`**, `useMutation` 아님 → **`createMutation`**. (`useQueryClient` 는 동일 이름)
- ⚠️ **옵션은 객체가 아니라 함수(accessor)** 로 넘긴다 — `createQuery(() => ({ queryKey, queryFn }))`, `createMutation(() => ({ mutationFn }))`. 함수 본문이 룬처럼 반응형으로 재평가된다. ⛔ v4 의 store 전달 방식 아님.
- ⚠️ 반환값은 store 가 아니라 **rune 기반 반응형 객체** → `$query.data` 아님, **`query.data` / `query.isPending` / `query.isSuccess` / `query.isError`**.
- ⛔ **컴포넌트 초기화 시점(`<script>` 최상단)에서만 호출.** 이벤트 핸들러 안에서 호출하면 `No QueryClient was found in Svelte context` 로 터진다. (래퍼 `lib/queries/*.ts` 는 룬을 안 쓰므로 평범한 `.ts` 로 둔다.)
- 프로바이더는 `src/routes/+layout.svelte` 에서 한 번만 마운트한다. props = `{ client, children }`, 내부는 `{@render children()}`.
- ⚠️ React 문서/예제를 그대로 복붙하면 깨진다. 정확한 시그니처는 설치된 버전의 타입 정의를 확인한다.

### TypeScript / svelte-check
- 타입 검사는 **`svelte-check`** 로 한다(`pnpm check` = `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json`). ⛔ `tsc -b` 로 대체하지 말 것 — `.svelte` 파일을 못 본다.
- ⛔ **TS 7 로 올릴 수 없다**(npm `latest` 가 이미 7 이어도). `typescript-eslint@8` peer 는 `>=4.8.4 <6.1.0`, `svelte-check@4` peer 는 `^5 || ^6` — 둘 다 TS 7 미지원. **`~6.0` 에 머문다.**
- `frontend/tsconfig.json` 은 **`$app/tsconfig`** 를 **`extends`** 한다(Kit 3). `moduleResolution`·`verbatimModuleSyntax` 등 기반 옵션은 거기서 온다. 별칭은 `package.json` `"imports"`(`#lib`)로 해석되므로 ⛔ `baseUrl`·`paths` 를 직접 쓰지 말 것.
- `node_modules/$app/`(tsconfig·생성 타입)과 `.svelte-kit/` 이 없으면 검사·빌드가 실패한다 → `pnpm exec svelte-kit sync` 먼저(`pnpm check` 가 자동 수행).
- TypeScript 6: **`types` 기본값이 `[]`**(이전엔 모든 `@types/*` 자동 포함). node 전역(`__dirname` 등)이나 앰비언트 타입이 필요한 tsconfig 에는 `"types": ["node", ...]` 를 **명시**해야 한다.

### ESLint (9 → 10)
- ESLint 는 **10** 이다(`@eslint/js` 도 10 동반). `typescript-eslint@8` · `eslint-plugin-svelte@3` 모두 `eslint: ^10` peer 지원.
- `eslint-plugin-svelte@3` 의 `svelte/no-navigation-without-resolve` 는 recommended 포함이지만 **Kit 1·2 에서만 동작**한다(Kit 3 에서는 비활성 — 위 SvelteKit 3 절).
  그래도 내부 이동은 `$app/paths` 의 **`resolve()`** 로 감싼다: `href={resolve("landing")}`, `goto(resolve(""))`, `redirect(302, resolve("login"))`. (경로가 svelte-check 로 타입 체크된다. 라우트 그룹 이름은 경로에 쓰지 않는다.)
- flat config(`frontend/eslint.config.js`)에 **`svelteConfig`** 를 넘겨야 한다 — `.svelte`/`.svelte.ts` 블록의 `languageOptions.parserOptions` 에 `{ parser: tseslint.parser, extraFileExtensions: [".svelte"], svelteConfig }`. (Kit 3: `svelteConfig` 는 `@sveltejs/load-config` 로 읽는다.)
- `js.configs.recommended` 의 `no-undef` 가 `.svelte` 에도 걸리므로 `languageOptions.globals` 에 **`globals.browser` + `globals.node`** 를 넣는다(그래서 `globals` 가 devDependency).

### FastAPI 0.142 + Starlette 1.x
- TestClient 는 **httpx2** 를 쓴다(httpx 아님). `requirements.txt` 에 `httpx2`. ⛔ `httpx` 로 되돌리면 deprecation 경고.
- 서버↔서버 HTTP 클라이언트도 `httpx2`.

### SQLAlchemy 2.1 / Alembic 1.20
- SQLAlchemy 2.0 → 2.1: 이 스캐폴드의 사용 범위(`Mapped`/`mapped_column`/`select`/`sessionmaker`)에서는 코드 변경 없이 통과(`pytest -W error::DeprecationWarning` 0건).
- Alembic 1.16+: `alembic.ini` 에 **`path_separator = os`** 가 없으면 `prepend_sys_path` 해석 시 DeprecationWarning. ⚠️ `alembic.ini` 는 **ASCII 로 유지**한다 — Windows(cp949)에서 한글 주석이 있으면 `UnicodeDecodeError` 로 alembic 이 안 뜬다.
- 테스트 픽스처는 끝에 `engine.dispose()` — StaticPool 의 sqlite 연결을 안 닫으면 `-W error` 에서 `ResourceWarning` 으로 실패.

### bcrypt 5
- bcrypt 5 는 **72바이트 초과 입력에 `ValueError`**(4.x 는 조용히 절단). 그대로 두면 500 이 난다.
  → `core/security.py` 의 `MAX_PASSWORD_BYTES = 72` 로 `hash_password` 는 명시적 거부, `verify_password` 는 `False`, `LoginRequest` 스키마는 **UTF-8 바이트 기준**으로 검증해 **422** 를 돌려준다(한글 1자 = 3바이트). 회원가입 등 비밀번호 입력 스키마를 추가하면 같은 검증을 붙인다.

### ruff 0.16
- `UP042`: `class X(str, enum.Enum)` → **`enum.StrEnum`** (py311+). 값 비교(`.value`)·DB 저장 동작은 동일.
- CI 게이트는 `ruff check` 뿐이다(`ruff format --check` 는 미적용 — 기존 코드가 포맷 기준과 다르다).

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
2. 백엔드: `python -m venv .venv` → `pip install -r requirements.txt` → `ruff check .` → `pytest -q` (메이저/마이너 상향 시 `pytest -q -W error::DeprecationWarning` 도 1회)
   + 실제 PostgreSQL 로 `alembic upgrade head` → `alembic check`(예: `docker run --rm -e POSTGRES_PASSWORD=postgres -p 55434:5432 postgres:16`)
3. 프론트: `pnpm install` → `pnpm lint` → `pnpm check`(svelte-check) → `pnpm build`. install 전후로 `pnpm-workspace.yaml` 이 바뀌지 않았는지 diff 로 확인
   (24시간 이내 배포 버전을 검증할 때만 `pnpm_config_minimum_release_age=0` 환경변수 — §3 pnpm 절)
4. 통과 시 핀 고정 후 **갱신할 곳을 모두**: SoT 파일 + `README.md` 표(+기준일) + 필요 시 `ARCHITECTURE.md` + **이 스킬의 스냅샷/주의(§2·§3)**. 커밋/PR은 [pr-workflow].
