import type { AxiosProgressEvent } from "axios"
import { api } from "#lib/api/client.js"
import { cleanParams, type Page, type PageParams } from "#lib/api/common.js"

// 공지사항 API (백엔드 schemas/notice.py 와 동기화, ARCHITECTURE.md §8).
// 날짜는 KST naive ISO 문자열이다.

export interface Attachment {
  id: number
  original_name: string
  size_bytes: number
  content_type: string
  /** 공개 다운로드 URL(게시된 공지만 동작). 관리자 화면은 downloadAdminAttachment 를 쓴다. */
  download_url: string
}

export interface NoticeListItem {
  id: number
  title: string
  is_pinned: boolean
  published_at: string | null
  view_count: number
  has_attachments: boolean
}

export interface NoticeDetail {
  id: number
  title: string
  /** 서버가 저장 시 정화한 HTML — RichContent 에 그대로 넣는다. */
  body_html: string
  is_pinned: boolean
  published_at: string | null
  view_count: number
  created_at: string
  updated_at: string
  attachments: Attachment[]
}

export interface AdminNoticeListItem {
  id: number
  title: string
  is_pinned: boolean
  is_published: boolean
  published_at: string | null
  view_count: number
  has_attachments: boolean
  author_id: number | null
  author_username: string | null
  created_at: string
  updated_at: string
}

export interface AdminNoticeDetail extends AdminNoticeListItem {
  body_html: string
  attachments: Attachment[]
}

/** 생성(POST)·수정(PUT) 공통 본문 — PUT 은 전체 교체. */
export interface NoticeWrite {
  title: string
  body_html: string
  is_pinned: boolean
  is_published: boolean
}

// ---------- 공개 ----------

export async function listNotices(params: PageParams = {}): Promise<Page<NoticeListItem>> {
  const { data } = await api.get<Page<NoticeListItem>>("/notices", { params: cleanParams(params) })
  return data
}

/** 상세 — 서버가 조회수를 올린 뒤의 값을 준다. 임시저장·미존재는 404. */
export async function getNotice(id: number): Promise<NoticeDetail> {
  const { data } = await api.get<NoticeDetail>(`/notices/${id}`)
  return data
}

// ---------- 관리자 ----------

export async function listAdminNotices(params: PageParams = {}): Promise<Page<AdminNoticeListItem>> {
  const { data } = await api.get<Page<AdminNoticeListItem>>("/admin/notices", {
    params: cleanParams(params),
  })
  return data
}

export async function getAdminNotice(id: number): Promise<AdminNoticeDetail> {
  const { data } = await api.get<AdminNoticeDetail>(`/admin/notices/${id}`)
  return data
}

export async function createNotice(body: NoticeWrite): Promise<AdminNoticeDetail> {
  const { data } = await api.post<AdminNoticeDetail>("/admin/notices", body)
  return data
}

export async function updateNotice(id: number, body: NoticeWrite): Promise<AdminNoticeDetail> {
  const { data } = await api.put<AdminNoticeDetail>(`/admin/notices/${id}`, body)
  return data
}

export async function deleteNotice(id: number): Promise<void> {
  await api.delete(`/admin/notices/${id}`)
}

/** 첨부 업로드 — multipart `file`. 413 용량, 422 형식, 409 10개 초과. */
export async function uploadAttachment(
  noticeId: number,
  file: File,
  onProgress?: (percent: number) => void,
): Promise<Attachment> {
  const form = new FormData()
  form.append("file", file, file.name)
  const { data } = await api.post<Attachment>(`/admin/notices/${noticeId}/attachments`, form, {
    onUploadProgress: (e: AxiosProgressEvent) => {
      if (onProgress && e.total) onProgress(Math.round((e.loaded / e.total) * 100))
    },
  })
  return data
}

export async function deleteAttachment(noticeId: number, attachmentId: number): Promise<void> {
  await api.delete(`/admin/notices/${noticeId}/attachments/${attachmentId}`)
}

/** 관리자 다운로드(임시저장 공지 포함) — Bearer 가 필요해 blob 으로 받는다. */
export async function downloadAdminAttachment(noticeId: number, attachmentId: number): Promise<Blob> {
  const { data } = await api.get<Blob>(`/admin/notices/${noticeId}/attachments/${attachmentId}`, {
    responseType: "blob",
  })
  return data
}
