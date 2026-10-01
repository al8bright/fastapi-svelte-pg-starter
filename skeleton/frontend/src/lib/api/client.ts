import axios from "axios"
import { clearToken, getToken } from "$lib/auth/token"

// axios 인스턴스 (ARCHITECTURE.md §13). baseURL 미설정 시 vite dev proxy(/api/v1) 사용.
export const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL
    ? `${import.meta.env.VITE_API_BASE_URL}/api/v1`
    : "/api/v1",
})

api.interceptors.request.use((config) => {
  const token = getToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      clearToken()
      if (location.pathname !== "/login") location.href = "/login"
    }
    return Promise.reject(error)
  },
)
