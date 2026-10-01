import type { User } from "$lib/api/auth"
import { clearToken, getToken, setToken } from "$lib/auth/token"

// 클라이언트 전역 상태 (ARCHITECTURE.md §13).
// zustand 같은 별도 라이브러리 없이 Svelte 5 runes($state)로 대체한다 — 그래서 파일명이 .svelte.ts 다.
class AuthStore {
  token = $state<string | null>(getToken())
  user = $state<User | null>(null)

  setSession(token: string): void {
    setToken(token)
    this.token = token
  }

  setUser(user: User | null): void {
    this.user = user
  }

  logout(): void {
    clearToken()
    this.token = null
    this.user = null
  }

  get isAuthenticated(): boolean {
    return Boolean(this.token)
  }
}

export const authStore = new AuthStore()
