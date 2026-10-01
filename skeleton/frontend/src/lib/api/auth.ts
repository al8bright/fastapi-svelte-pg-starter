import { api } from "#lib/api/client.js"

// 인증 API (ARCHITECTURE.md §13, §14).
export type UserRole = "user" | "admin"

export interface User {
  id: number
  username: string
  role: UserRole
  is_active: boolean
}

export interface TokenResponse {
  access_token: string
  token_type: string
}

export async function login(username: string, password: string): Promise<TokenResponse> {
  const { data } = await api.post<TokenResponse>("/auth/login", { username, password })
  return data
}

export async function getMe(): Promise<User> {
  const { data } = await api.get<User>("/auth/me")
  return data
}
