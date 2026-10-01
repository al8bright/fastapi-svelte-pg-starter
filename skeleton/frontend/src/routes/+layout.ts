import { restoreSession } from "#lib/auth/session.js"

// SPA 모드 (ARCHITECTURE.md §13).
// 백엔드가 별도 FastAPI 서버이고 인증 상태(access 토큰)가 브라우저 메모리에만 있으므로 SSR 을 쓰지 않는다.
// prerender 로 빈 셸(index.html)만 미리 만들어 두고, 렌더링은 전부 브라우저에서 한다.
// 동적 경로(/notices/[id] 등)는 각 +page.ts 에서 prerender = false — adapter-static 의 fallback(index.html)이 받는다.
export const ssr = false
export const prerender = true

// 앱 시작 시 httpOnly refresh 쿠키로 세션 복원을 먼저 끝낸다 (§14) — 공개 화면(상단 계정 메뉴)도, 로그인 화면도
// 이 결과를 보고 그린다. restoreSession 은 페이지 로드당 1회이고 prerender 에서는 no-op 이다.
// 보호 가드((site)/(protected)·admin 의 +layout.ts)는 레이아웃 load 가 병렬로 돌므로 같은 Promise 를 직접 기다린다.
export const load = async () => {
  await restoreSession()
}
