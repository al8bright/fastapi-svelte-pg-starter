import axios, { type InternalAxiosRequestConfig } from "axios"
import { goto } from "$app/navigation"
import { resolve } from "$app/paths"
import type { TokenResponse } from "#lib/api/auth.js"
import { queryClient } from "#lib/query-client.js"
import { loginWithNext } from "#lib/returnTo.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// axios 인스턴스 (ARCHITECTURE.md §13). baseURL 미설정 시 vite dev proxy(/api/v1) 사용.
//
// 인증 흐름 (ARCHITECTURE.md §14):
// - access 토큰은 스토어(메모리)에만 있고, 요청 인터셉터가 Bearer 로 주입한다.
// - refresh 토큰은 백엔드가 심는 httpOnly 쿠키(refresh_token, Path=/api/v1/auth)라 JS 는 보지 못한다.
//   withCredentials: true — 교차 오리진(VITE_API_BASE_URL)에서도 쿠키를 주고받는다
//   (백엔드 CORS 는 allow_credentials=True + 명시 오리진. 쿠키가 SameSite=lax 라 same-site 배치 전제).
// - 401 이면 refresh 를 single-flight 로 1번만 호출하고 원 요청을 1회 재시도한다.
//   refresh 실패 = 세션 만료 → 상태·쿼리 캐시를 비우고 로그인 화면으로 보낸다(?next= 로 원래 위치를 담는다).
const baseURL = import.meta.env.VITE_API_BASE_URL
  ? `${import.meta.env.VITE_API_BASE_URL}/api/v1`
  : "/api/v1"

export const api = axios.create({ baseURL, withCredentials: true })

// refresh 전용 인스턴스 — 인터셉터가 없어 401 처리와 얽히지 않는다(무한 루프 방지).
const refreshClient = axios.create({ baseURL, withCredentials: true })

// 자기 자신이 401 이어도 refresh 를 타면 안 되는 인증 엔드포인트.
const AUTH_PATHS = ["/auth/login", "/auth/refresh", "/auth/logout"]

// single-flight: 동시에 여러 요청이 401 을 받아도 refresh 는 한 번만 나간다.
// (refresh 토큰은 회전되므로 병렬 호출은 이전 토큰 재사용으로 오인될 수 있다.)
let refreshPromise: Promise<string | null> | null = null

/** httpOnly refresh 쿠키로 access 토큰을 재발급받아 스토어에 넣는다. 실패하면 null (상태는 건드리지 않는다). */
export function refreshAccessToken(): Promise<string | null> {
  refreshPromise ??= refreshClient
    .post<TokenResponse>("/auth/refresh")
    .then(({ data }) => {
      authStore.setSession(data.access_token)
      return data.access_token
    })
    .catch(() => null)
    .finally(() => {
      refreshPromise = null
    })
  return refreshPromise
}

/**
 * 세션 만료 처리 — 상태·쿼리 캐시를 비우고 로그인 화면으로 (이미 로그인 화면이면 이동하지 않는다).
 * 원래 위치를 ?next= 로 넘겨 다시 로그인하면 그 화면으로 돌아간다.
 */
export function expireSession(): void {
  authStore.clear()
  queryClient.clear()
  const loginPath = resolve("login")
  if (location.pathname === loginPath) return
  void goto(loginWithNext(loginPath, `${location.pathname}${location.search}${location.hash}`), { replace: true })
}

api.interceptors.request.use((config) => {
  const token = authStore.token
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

type RetriableConfig = InternalAxiosRequestConfig & { _retried?: boolean }

api.interceptors.response.use(
  (res) => res,
  async (error: unknown) => {
    if (!axios.isAxiosError(error) || error.response?.status !== 401 || !error.config) {
      throw error
    }
    const config: RetriableConfig = error.config
    const url = config.url ?? ""
    // 인증 엔드포인트 자체의 401(로그인 실패 등)과 이미 한 번 재시도한 요청은 그대로 실패시킨다.
    if (config._retried || AUTH_PATHS.some((p) => url.startsWith(p))) throw error

    const token = await refreshAccessToken()
    if (token === null) {
      expireSession()
      throw error
    }
    // 재시도는 1회뿐 — 요청 인터셉터가 새 access 토큰을 다시 주입한다.
    config._retried = true
    return api(config)
  },
)
