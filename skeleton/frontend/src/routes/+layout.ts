import { restoreSession } from "#lib/auth/session.js"

// SPA 모드 (ARCHITECTURE.md §13).
// 백엔드가 별도 FastAPI 서버이고 인증 상태(access 토큰)가 브라우저 메모리에만 있으므로 SSR 을 쓰지 않는다.
// prerender 로 빈 셸(index.html)만 미리 만들어 두고, 렌더링은 전부 브라우저에서 한다.
export const ssr = false
export const prerender = true

// 앱 시작 시 httpOnly refresh 쿠키로 세션 복원을 먼저 끝낸다 (§14) — 로그인 화면도 이 결과를 보고
// 이미 로그인 상태면 메인으로 보낸다. restoreSession 은 페이지 로드당 1회이고 prerender 에서는 no-op 이다.
export const load = async () => {
  await restoreSession()
}
