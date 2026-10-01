import { browser } from "$app/environment"

// 토큰 저장소 (ARCHITECTURE.md §14). 키는 프로젝트별로 분리한다.
// SPA(ssr = false)라도 build 의 prerender 단계는 Node 에서 돌아 localStorage 가 없다 → browser 가드 필수.
const TOKEN_KEY = "__PROJECT_SNAKE___token"

export function getToken(): string | null {
  if (!browser) return null
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string): void {
  if (!browser) return
  localStorage.setItem(TOKEN_KEY, token)
}

export function clearToken(): void {
  if (!browser) return
  localStorage.removeItem(TOKEN_KEY)
}
