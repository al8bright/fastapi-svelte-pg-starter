import { api } from "$lib/api/client"

// 도메인별 API 함수 (ARCHITECTURE.md §13).
export interface DbHealth {
  db: string
  table: string
  rows: number
}

export async function getHealth(): Promise<{ status: string }> {
  const { data } = await api.get<{ status: string }>("/health")
  return data
}

export async function getDbHealth(): Promise<DbHealth> {
  const { data } = await api.get<DbHealth>("/health/db")
  return data
}
