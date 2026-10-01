// SPA 모드 (ARCHITECTURE.md §13).
// 백엔드가 별도 FastAPI 서버이고 JWT 를 localStorage 에 두므로 SSR 을 쓰지 않는다.
// prerender 로 빈 셸(index.html)만 미리 만들어 두고, 렌더링은 전부 브라우저에서 한다.
export const ssr = false
export const prerender = true
