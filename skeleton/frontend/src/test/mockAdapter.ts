import {
  AxiosError,
  type AxiosAdapter,
  type AxiosResponse,
  type InternalAxiosRequestConfig,
} from "axios"

// 테스트 전용 axios 어댑터 — 네트워크 없이 상태코드·본문을 돌려준다.
// 실제 어댑터처럼 2xx 가 아니면 AxiosError(response 포함)로 reject 한다.
export type Handler = (
  config: InternalAxiosRequestConfig,
) => [number, unknown] | Promise<[number, unknown]>

export function bearerOf(config: InternalAxiosRequestConfig): string | null {
  const value = config.headers.Authorization
  return typeof value === "string" ? value.replace(/^Bearer /, "") : null
}

export function mockAdapter(handler: Handler): AxiosAdapter {
  return async (config) => {
    const [status, data] = await handler(config)
    const response: AxiosResponse = { data, status, statusText: String(status), headers: {}, config }
    if (status >= 200 && status < 300) return response
    throw new AxiosError(
      `Request failed with status code ${status}`,
      AxiosError.ERR_BAD_REQUEST,
      config,
      null,
      response,
    )
  }
}

export const tokenBody = (access: string) => ({
  access_token: access,
  refresh_token: null,
  token_type: "bearer",
  expires_in: 900,
  refresh_expires_in: 1209600,
})
