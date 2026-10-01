import { createMutation, createQuery, keepPreviousData, useQueryClient } from "@tanstack/svelte-query"
import type { PageParams } from "#lib/api/common.js"
import {
  createNotice,
  deleteAttachment,
  deleteNotice,
  getAdminNotice,
  getNotice,
  listAdminNotices,
  listNotices,
  type NoticeWrite,
  updateNotice,
} from "#lib/api/notices.js"

// 공지사항 svelte-query (ARCHITECTURE.md §13). 변경은 ["notices"] 전체(공개·관리자)와 대시보드를 무효화한다.
// 파라미터는 getter 로 받는다 — accessor 함수 안에서 읽어야 URL(page.url)·props 가 바뀔 때 쿼리가 따라 바뀐다.
// 모든 create*/use* 는 컴포넌트 <script> 최상단에서만 호출한다(svelte-query v6 규칙).
export const noticeKeys = {
  all: ["notices"] as const,
  publicList: (params: PageParams) => ["notices", "public", "list", params] as const,
  publicDetail: (id: number) => ["notices", "public", "detail", id] as const,
  adminList: (params: PageParams) => ["notices", "admin", "list", params] as const,
  adminDetail: (id: number) => ["notices", "admin", "detail", id] as const,
}

export function createPublicNotices(params: () => PageParams) {
  return createQuery(() => {
    const p = params()
    return { queryKey: noticeKeys.publicList(p), queryFn: () => listNotices(p), placeholderData: keepPreviousData }
  })
}

export function createPublicNotice(id: () => number) {
  return createQuery(() => {
    const noticeId = id()
    return {
      queryKey: noticeKeys.publicDetail(noticeId),
      queryFn: () => getNotice(noticeId),
      enabled: Number.isInteger(noticeId) && noticeId > 0,
      retry: false,
      // 상세 조회마다 서버가 조회수를 올린다 — 창 포커스·재마운트마다 다시 부르지 않게 한다.
      staleTime: 5 * 60_000,
      refetchOnWindowFocus: false,
    }
  })
}

export function createAdminNotices(params: () => PageParams) {
  return createQuery(() => {
    const p = params()
    return {
      queryKey: noticeKeys.adminList(p),
      queryFn: () => listAdminNotices(p),
      placeholderData: keepPreviousData,
    }
  })
}

export function createAdminNotice(id: () => number | null) {
  return createQuery(() => {
    const noticeId = id()
    return {
      queryKey: noticeKeys.adminDetail(noticeId ?? 0),
      queryFn: () => getAdminNotice(noticeId as number),
      enabled: noticeId !== null && noticeId > 0,
      retry: false,
    }
  })
}

/** 공지·대시보드 캐시 무효화 함수 — 컴포넌트 초기화 시점에 만들어 두고 나중(업로드 완료 등)에 부른다. */
export function useInvalidateNotices() {
  const qc = useQueryClient()
  return () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: noticeKeys.all }),
      qc.invalidateQueries({ queryKey: ["admin", "dashboard"] }),
    ])
}

/** 저장 — id 가 없으면 생성(POST), 있으면 전체 교체(PUT). */
export function createSaveNotice() {
  const qc = useQueryClient()
  const invalidate = useInvalidateNotices()
  return createMutation(() => ({
    mutationFn: ({ id, body }: { id: number | null; body: NoticeWrite }) =>
      id === null ? createNotice(body) : updateNotice(id, body),
    onSuccess: (saved) => {
      qc.setQueryData(noticeKeys.adminDetail(saved.id), saved)
      return invalidate()
    },
  }))
}

export function createDeleteNotice() {
  const qc = useQueryClient()
  const invalidate = useInvalidateNotices()
  return createMutation(() => ({
    mutationFn: (id: number) => deleteNotice(id),
    onSuccess: (_: void, id: number) => {
      qc.removeQueries({ queryKey: noticeKeys.adminDetail(id) })
      return invalidate()
    },
  }))
}

export function createDeleteAttachment(noticeId: () => number) {
  const invalidate = useInvalidateNotices()
  return createMutation(() => ({
    mutationFn: (attachmentId: number) => deleteAttachment(noticeId(), attachmentId),
    onSuccess: () => invalidate(),
  }))
}
