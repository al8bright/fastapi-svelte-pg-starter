import { createMutation, createQuery } from "@tanstack/svelte-query"
import { getMe, login } from "#lib/api/auth.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// 인증 쿼리 (ARCHITECTURE.md §13, §14).
// svelte-query v6 은 옵션을 "함수(accessor)"로 받는다 — 함수 본문이 runes 처럼 반응형으로 재평가된다.
// 컴포넌트 초기화 시점(<script> 최상단)에서만 호출할 것. 이벤트 핸들러 안에서 호출하면 context 를 못 찾는다.

/** 로그인 → 토큰 저장 → 사용자 정보 로드 */
export function createLogin() {
  return createMutation(() => ({
    mutationFn: ({ username, password }: { username: string; password: string }) =>
      login(username, password),
    onSuccess: async (token) => {
      authStore.setSession(token.access_token)
      authStore.setUser(await getMe())
    },
  }))
}

/** 현재 로그인 사용자 (토큰 있을 때만 조회, 스토어에도 반영) */
export function createMe() {
  return createQuery(() => ({
    queryKey: ["auth", "me"],
    queryFn: async () => {
      const user = await getMe()
      authStore.setUser(user)
      return user
    },
    enabled: Boolean(authStore.token),
    retry: false,
  }))
}
