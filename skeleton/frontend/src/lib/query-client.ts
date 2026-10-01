import { QueryClient } from "@tanstack/svelte-query"

// 앱 전역 QueryClient 단일 인스턴스 (ARCHITECTURE.md §13).
// 루트 +layout.svelte 의 QueryClientProvider 에 넘기고, 세션 만료·로그아웃 시
// 이전 사용자의 캐시가 남지 않도록 #lib/api/client.ts·#lib/auth/session.ts 가 clear() 한다.
export const queryClient = new QueryClient()
