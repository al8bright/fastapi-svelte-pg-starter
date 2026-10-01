import { createMutation, createQuery, keepPreviousData, useQueryClient } from "@tanstack/svelte-query"
import {
  type AdminSessionParams,
  type AdminUserParams,
  type AdminUserUpdate,
  getDashboard,
  listLoginThrottles,
  listSessions,
  listUsers,
  revokeSession,
  revokeUserSessions,
  unlockLoginThrottle,
  updateUser,
} from "#lib/api/admin.js"

// 관리자 콘솔 svelte-query — 대시보드·사용자·세션·로그인 잠금 (ARCHITECTURE.md §13).
export const adminKeys = {
  dashboard: ["admin", "dashboard"] as const,
  users: (params: AdminUserParams) => ["admin", "users", params] as const,
  sessions: (params: AdminSessionParams) => ["admin", "sessions", params] as const,
  throttles: ["admin", "login-throttles"] as const,
}

export function createDashboard() {
  return createQuery(() => ({ queryKey: adminKeys.dashboard, queryFn: getDashboard }))
}

export function createAdminUsers(params: () => AdminUserParams) {
  return createQuery(() => {
    const p = params()
    return { queryKey: adminKeys.users(p), queryFn: () => listUsers(p), placeholderData: keepPreviousData }
  })
}

export function createAdminSessions(params: () => AdminSessionParams) {
  return createQuery(() => {
    const p = params()
    return { queryKey: adminKeys.sessions(p), queryFn: () => listSessions(p), placeholderData: keepPreviousData }
  })
}

export function createLoginThrottles() {
  return createQuery(() => ({ queryKey: adminKeys.throttles, queryFn: listLoginThrottles }))
}

/** 사용자·세션 변경은 서로 집계가 얽혀(세션 수·대시보드) 관련 키를 함께 무효화한다. */
function useInvalidateAccounts() {
  const qc = useQueryClient()
  return () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: ["admin", "users"] }),
      qc.invalidateQueries({ queryKey: ["admin", "sessions"] }),
      qc.invalidateQueries({ queryKey: adminKeys.dashboard }),
    ])
}

export function createUpdateUser() {
  const invalidate = useInvalidateAccounts()
  return createMutation(() => ({
    mutationFn: ({ id, body }: { id: number; body: AdminUserUpdate }) => updateUser(id, body),
    onSuccess: () => invalidate(),
  }))
}

export function createRevokeUserSessions() {
  const invalidate = useInvalidateAccounts()
  return createMutation(() => ({
    mutationFn: (userId: number) => revokeUserSessions(userId),
    onSuccess: () => invalidate(),
  }))
}

export function createRevokeSession() {
  const invalidate = useInvalidateAccounts()
  return createMutation(() => ({
    mutationFn: (sessionId: number) => revokeSession(sessionId),
    onSuccess: () => invalidate(),
  }))
}

export function createUnlockThrottle() {
  const qc = useQueryClient()
  return createMutation(() => ({
    mutationFn: (username: string) => unlockLoginThrottle(username),
    onSuccess: () =>
      Promise.all([
        qc.invalidateQueries({ queryKey: adminKeys.throttles }),
        qc.invalidateQueries({ queryKey: adminKeys.dashboard }),
      ]),
  }))
}
