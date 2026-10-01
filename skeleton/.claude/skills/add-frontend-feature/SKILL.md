---
name: add-frontend-feature
description: __PROJECT_NAME__ 프론트엔드에 기능·페이지·API 호출을 추가할 때 사용. axios + @tanstack/svelte-query + Svelte 5 runes 표준(lib/api/<domain>.ts → lib/queries → routes/컴포넌트)과 보호 라우트/인증 흐름을 ARCHITECTURE.md §13·§14 기준으로 안내한다.
---

# 프론트엔드 기능 추가

표준 스택: **axios + @tanstack/svelte-query + Svelte 5 runes** (ARCHITECTURE.md §13). 패키지 매니저는 **pnpm**(⛔ npm 금지).
프레임워크는 **SvelteKit(SPA 모드)** — `adapter-static` + `ssr = false`. 서버 전용 기능은 쓰지 않는다([stack-versions] 참조).

## 순서

1. **API 함수** `frontend/src/lib/api/<domain>.ts`
   - 공용 axios 인스턴스(`#lib/api/client.js`)를 import해서 사용. baseURL·쿠키 전송(`withCredentials`)·Bearer 주입·401 → refresh 재시도는 인스턴스가 담당.
   ```ts
   import { api } from "#lib/api/client.js"
   export const listEvents = () => api.get("/events").then(r => r.data)
   export const createEvent = (data: EventCreate) => api.post("/events", data).then(r => r.data)
   ```

2. **서버 상태 함수** `frontend/src/lib/queries/<domain>.ts` — svelte-query **v6**
   ```ts
   import { createQuery, createMutation, useQueryClient } from "@tanstack/svelte-query"
   import { listEvents, createEvent } from "#lib/api/events.js"

   export function createEventsQuery() {
     return createQuery(() => ({ queryKey: ["events"], queryFn: listEvents }))
   }

   export function createEventMutation() {
     const qc = useQueryClient()
     return createMutation(() => ({
       mutationFn: createEvent,
       onSuccess: () => qc.invalidateQueries({ queryKey: ["events"] }),
     }))
   }
   ```
   - ⚠️ v6 은 옵션을 **함수(accessor)** 로 받는다 — `createQuery(() => ({ ... }))`. 객체를 그대로 넘기는 v4/React 스타일은 안 된다.
   - 반환값은 store 가 아니라 **rune 기반 반응형 객체** → `$q.data` 아님, **`q.data` / `q.isPending` / `q.isSuccess` / `q.isError`** 로 바로 접근.
   - ⛔ **서버 상태를 `$state` + `$effect`로 직접 패칭 금지.** 캐싱/무효화는 svelte-query로.
   - `createQuery`/`createMutation`/`useQueryClient` 는 **컴포넌트 초기화 시점(`<script>` 최상단)** 에서만 호출한다.
     이벤트 핸들러 안에서 호출하면 `No QueryClient was found in Svelte context` 로 터진다.
     (래퍼인 `lib/queries/*.ts` 는 자신이 룬을 쓰지 않으므로 평범한 `.ts` 로 둔다.)

3. **타입** `frontend/src/lib/api/<domain>.ts` — 해당 API 모듈 안에 함께 둔다(`lib/api/auth.ts` 가 이미 그 방식).
   백엔드 스키마와 동기화. 유니온은 리터럴(`'active' | 'closed'`).

4. **컴포넌트/페이지** `frontend/src/routes/.../+page.svelte`(라우트) 또는 `frontend/src/lib/components/PascalCase.svelte`(공유 컴포넌트)
   - 공유 컴포넌트 파일명 = 컴포넌트명, `PascalCase.svelte`.
   - **Svelte 5 runes** 문법을 쓴다: `$state`, `$derived`, `$props`, 슬롯 대신 `{@render children()}`.
     ⛔ 레거시 `export let` / `<slot/>` / `$:` 금지.
   ```svelte
   <script lang="ts">
     import { createEventsQuery } from "#lib/queries/events.js"
     let { title }: { title: string } = $props()
     const events = createEventsQuery()   // ← <script> 최상단에서만
     let keyword = $state("")
   </script>

   {#if events.isPending}불러오는 중…{:else}{events.data?.length} 건{/if}
   ```
   - 데이터는 `lib/queries/` 를 통해서만 접근. 클라이언트 상태(access 토큰·UI 토글)는 `$state`(전역이면 `lib/stores/*.svelte.ts`).
     전역 스토어는 클래스 + 필드 `$state` 로 두고 인스턴스를 export 한다. `isAuthenticated` 같은 파생값은 **getter**(괄호 없이 접근).
   - 한 라우트에서만 쓰는 조각은 파일을 늘리지 말고 **`{#snippet}` + `{@render}`** 로 그 라우트 파일 안에 둔다(스캐폴드 `landing/+page.svelte` 가 그 방식). 여러 라우트가 공유할 때만 `lib/components/` 로 승격.
   - a11y: `<label for="x">` + `<input id="x">` 쌍은 **필수**(없으면 svelte-check 경고), `autofocus` 는 바로 위에 `<!-- svelte-ignore a11y_autofocus -->` 가 필요하다.

5. **라우트** `frontend/src/routes/` — SvelteKit **파일 기반 라우팅**
   - 디렉토리 = URL. `routes/events/+page.svelte` → `/events`.
   - 인증 필요한 화면은 `src/routes/(protected)/` 하위에 만든다 — 그룹 `+layout.ts` 가드가 자동 적용된다(미인증 시 `/login` 리다이렉트, §14).
   - `(protected)` 같은 **라우트 그룹은 괄호 이름이 URL 에 나타나지 않는다**(`(protected)/my/+page.svelte` → `/my`).
   - 공통 레이아웃은 `+layout.svelte` + `{@render children()}`.
   - ⚠️ **모든 내부 이동은 `$app/paths` 의 `resolve()` 로 감싼다** — `href={resolve("events")}`, `goto(resolve(""))`, `redirect(302, resolve("login"))`.
     ⚠️ **SvelteKit 3: pathname 은 앞의 `/` 없이** 쓴다(루트 = `""`). `"/..."` 로 시작하면 **라우트 ID** 로 해석돼 그룹 이름까지 포함해야 한다(`"/(protected)/my"`).
     라우트를 새로 추가하면 `svelte-kit sync` 후 `resolve()` 가 그 경로를 타입으로 인식한다 → 오타·잘못된 경로는 `pnpm check`(svelte-check)가 잡는다.
     (현재 `eslint-plugin-svelte@3.23` 의 `svelte/no-navigation-without-resolve` 는 SvelteKit 1·2 에서만 켜져 **Kit 3 에서는 lint 가 잡지 않는다** — 규칙으로 지킨다.)

## 인증/토큰 (§14)
- access 토큰은 **메모리에만**(`authStore.token`, `lib/stores/auth.svelte.ts`). ⛔ `localStorage`/`sessionStorage` 저장 금지.
- refresh 토큰은 백엔드가 심는 **httpOnly 쿠키**(`REFRESH_TOKEN_TRANSPORT=cookie`) — JS 로 읽거나 보내지 않는다. 응답 본문의 `refresh_token` 은 항상 `null`.
- 새로고침 후 세션은 `lib/auth/session.ts` 의 `restoreSession()`(루트·`(protected)` `+layout.ts` load 가 기다림)이 `POST /auth/refresh` 로 복원한다.
  새 보호 페이지는 `routes/(protected)/` 아래에 두기만 하면 된다 — 직접 토큰을 확인하지 않는다.
- ⚠️ 세션 관련 코드에는 `$app/env` 의 **`browser` 가드 필수** — 빌드의 prerender 단계는 Node 에서 돈다(쿠키·`location` 없음).
- 로그아웃은 `signOut()`(POST `/auth/logout` → 상태·쿼리 캐시 정리 → `/login`). 상태만 비우는 `authStore.clear()` 를 직접 쓰지 않는다.
- SSO: 로그인 페이지에서 `window.location.href = \`${import.meta.env.VITE_BACKEND_URL}/api/v1/auth/login\``.
- 401은 `lib/api/client.ts` interceptor가 일괄 처리 — single-flight refresh 후 원 요청 1회 재시도, refresh 실패 시 상태·쿼리 캐시 정리 + `/login`.
  `/auth/login`·`/auth/refresh`·`/auth/logout` 의 401 은 재시도하지 않는다. 로그인 429(잠금)는 화면에서 별도 문구로 보여 준다.

## 스타일 (§15)
- Tailwind v4 CSS-first(`@import "tailwindcss"` + `@theme`, `src/app.css`). 별도 `tailwind.config.js` 지양.
- 한글 기본 폰트 Pretendard(+ Noto Sans KR 폴백) 권장.

## 설정
- API 호스트는 `import.meta.env.VITE_API_BASE_URL`(없으면 dev proxy `/api/v1`). ⛔ 셸 환경변수 의존 금지, `.env`로만.
- ⛔ `$env/dynamic/*` 금지 — 정적 SPA 빌드라 동작하지 않는다. `VITE_` 접두 환경변수만 쓴다.

## 마무리
- 린트 경고 0 + `pnpm check`(svelte-check) 통과 + 동작 확인 후 커밋. 커밋/PR은 [pr-workflow] 스킬 참조.
