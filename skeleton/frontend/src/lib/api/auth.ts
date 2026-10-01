import { api } from "#lib/api/client.js"

// 인증 API (ARCHITECTURE.md §13, §14).
export type UserRole = "user" | "admin"

export interface User {
  id: number
  username: string
  role: UserRole
  is_active: boolean
}

// cookie 전송 모드 응답 — refresh 토큰은 httpOnly 쿠키로만 오고 본문은 항상 null 이다.
export interface TokenResponse {
  access_token: string
  refresh_token: null
  token_type: string
  expires_in: number
  refresh_expires_in: number
}

export async function login(username: string, password: string): Promise<TokenResponse> {
  const { data } = await api.post<TokenResponse>("/auth/login", { username, password })
  return data
}

/** 서버 세션 폐기 + refresh 쿠키 삭제. 백엔드는 쿠키 유무와 무관하게 항상 204 로 응답한다. */
export async function logout(): Promise<void> {
  await api.post("/auth/logout")
}

export async function getMe(): Promise<User> {
  const { data } = await api.get<User>("/auth/me")
  return data
}
