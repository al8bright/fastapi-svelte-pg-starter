import type { User } from "#lib/api/auth.js"

// 클라이언트 전역 상태 (ARCHITECTURE.md §13, §14).
// zustand 같은 별도 라이브러리 없이 Svelte 5 runes($state)로 대체한다 — 그래서 파일명이 .svelte.ts 다.
//
// access 토큰은 메모리($state)에만 둔다 — localStorage/sessionStorage 금지 (XSS 탈취 방지, §14).
// 새로고침하면 사라지는데, 앱 시작 시 #lib/auth/session.ts 의 restoreSession() 이
// httpOnly refresh 쿠키(POST /auth/refresh)로 다시 받아 온다.
// 모듈 수준 상태라 prerender(Node) 단계에서도 import 되지만, 값은 null 로만 존재하고
// 쓰기는 전부 브라우저에서 일어난다(쓰는 쪽이 browser 가드를 가진다).
class AuthStore {
  token = $state<string | null>(null)
  user = $state<User | null>(null)

  setSession(token: string): void {
    this.token = token
  }

  setUser(user: User | null): void {
    this.user = user
  }

  // 상태만 비운다 — 서버 세션 폐기(POST /auth/logout)·쿼리 캐시 정리·이동은 session.ts 의 signOut 이 맡는다.
  clear(): void {
    this.token = null
    this.user = null
  }

  get isAuthenticated(): boolean {
    return Boolean(this.token)
  }
}

export const authStore = new AuthStore()
