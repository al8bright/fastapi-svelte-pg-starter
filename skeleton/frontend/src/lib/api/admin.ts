import { api } from "#lib/api/client.js"
import type { UserRole } from "#lib/api/auth.js"
import { cleanParams, type Page, type PageParams } from "#lib/api/common.js"

// 관리자 API — 대시보드·사용자·세션·로그인 잠금 (백엔드 schemas/admin.py 와 동기화).

export interface Dashboard {
  users: { total: number; active: number; inactive: number }
  active_sessions: number
  locked_accounts: number
  notices: { published: number; draft: number }
  active_banners: number
  db: "ok" | "error"
  /** 적용된 Alembic 리비전. alembic_version 테이블이 없으면 null. */
  alembic_revision: string | null
}

export interface AdminUser {
  id: number
  username: string
  role: UserRole
  is_active: boolean
  created_at: string
  active_session_count: number
}

/** 부분 수정 — 보낸 필드만 바꾼다. 409 self_modification·last_admin. */
export interface AdminUserUpdate {
  role?: UserRole
  is_active?: boolean
}

export interface AdminUserParams extends PageParams {
  role?: UserRole
}

export interface AdminSession {
  id: number
  user_id: number
  username: string
  created_at: string
  last_used_at: string
  expires_at: string
}

export interface AdminSessionParams {
  user_id?: number
  page?: number
  size?: number
}

export interface LoginThrottle {
  username: string
  failed_count: number
  locked_until: string | null
  last_failed_at: string
  is_locked: boolean
}

export async function getDashboard(): Promise<Dashboard> {
  const { data } = await api.get<Dashboard>("/admin/dashboard")
  return data
}

export async function listUsers(params: AdminUserParams = {}): Promise<Page<AdminUser>> {
  const { data } = await api.get<Page<AdminUser>>("/admin/users", { params: cleanParams(params) })
  return data
}

export async function updateUser(id: number, body: AdminUserUpdate): Promise<AdminUser> {
  const { data } = await api.patch<AdminUser>(`/admin/users/${id}`, body)
  return data
}

export async function revokeUserSessions(id: number): Promise<{ revoked: number }> {
  const { data } = await api.delete<{ revoked: number }>(`/admin/users/${id}/sessions`)
  return data
}

export async function listSessions(params: AdminSessionParams = {}): Promise<Page<AdminSession>> {
  const { data } = await api.get<Page<AdminSession>>("/admin/sessions", { params: cleanParams(params) })
  return data
}

/** 강제 종료 — 멱등 204. */
export async function revokeSession(id: number): Promise<void> {
  await api.delete(`/admin/sessions/${id}`)
}

export async function listLoginThrottles(): Promise<LoginThrottle[]> {
  const { data } = await api.get<LoginThrottle[]>("/admin/login-throttles")
  return data
}

/** 잠금 해제(실패 기록 삭제) — 멱등 204. */
export async function unlockLoginThrottle(username: string): Promise<void> {
  await api.delete(`/admin/login-throttles/${encodeURIComponent(username)}`)
}
