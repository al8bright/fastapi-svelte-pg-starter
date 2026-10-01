import { type AxiosError, isAxiosError } from "axios"
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

/** 서버 `detail` 이 문자열일 때만 살린다 (FastAPI 422 는 객체 배열이라 그대로 보여줄 수 없다). */
function serverDetail(e: AxiosError): string | null {
  const detail = (e.response?.data as { detail?: unknown } | undefined)?.detail
  return typeof detail === "string" && detail.trim() !== "" ? detail : null
}

/**
 * 로그인 실패 원인을 상태코드로 구분해 사용자 문구로 바꾼다.
 * 모든 실패를 "아이디 또는 비밀번호" 로 표시하면 422·네트워크 오류·500 을 오진한다.
 */
export function loginErrorMessage(e: unknown): string {
  if (!isAxiosError(e)) return "알 수 없는 오류가 발생했습니다."
  if (!e.response) return "서버에 연결할 수 없습니다. 백엔드가 실행 중인지 확인하세요."
  // 401 문구는 고정 — 계정 존재 여부를 노출하지 않는다(백엔드도 메시지를 통일한다).
  if (e.response.status === 401) return "아이디 또는 비밀번호가 올바르지 않습니다."
  // 429 = 계정별 연속 실패로 잠김(LOGIN_MAX_FAILURES/LOGIN_LOCKOUT_MINUTES). 비밀번호 오류와 구분해 안내한다.
  if (e.response.status === 429) return "로그인 시도가 너무 많습니다. 잠시 후 다시 시도하세요."
  if (e.response.status === 422)
    return serverDetail(e) ?? "입력값을 확인하세요. (비밀번호는 UTF-8 기준 72 bytes 이하)"
  if (e.response.status >= 500) return "서버 오류가 발생했습니다. 잠시 후 다시 시도하세요."
  return serverDetail(e) ?? "로그인 처리 중 오류가 발생했습니다."
}
