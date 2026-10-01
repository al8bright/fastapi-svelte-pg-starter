import { api } from "#lib/api/client.js"
import type { UploadedImage } from "#lib/api/common.js"

// 배너 API (백엔드 schemas/banner.py 와 동기화, ARCHITECTURE.md §8).

/** 공개 배너 — 활성 + 노출 기간 안, sort_order → id 순. */
export interface BannerPublic {
  id: number
  title: string
  image_url: string
  width: number
  height: number
  link_url: string | null
  alt_text: string
}

export interface BannerAdmin {
  id: number
  title: string
  image_key: string
  image_url: string
  image_width: number
  image_height: number
  link_url: string | null
  alt_text: string
  /** KST naive ISO. null 이면 기간 제한 없음. */
  starts_at: string | null
  ends_at: string | null
  sort_order: number
  is_active: boolean
  created_at: string
  updated_at: string
}

/** 생성(POST)·수정(PUT) 공통 본문 — sort_order 를 생략하면 생성 시 맨 뒤·수정 시 유지. */
export interface BannerWrite {
  title: string
  image_key: string
  link_url?: string | null
  alt_text?: string
  starts_at?: string | null
  ends_at?: string | null
  sort_order?: number | null
  is_active?: boolean
}

export async function listBanners(): Promise<BannerPublic[]> {
  const { data } = await api.get<BannerPublic[]>("/banners")
  return data
}

export async function listAdminBanners(): Promise<BannerAdmin[]> {
  const { data } = await api.get<BannerAdmin[]>("/admin/banners")
  return data
}

export async function getAdminBanner(id: number): Promise<BannerAdmin> {
  const { data } = await api.get<BannerAdmin>(`/admin/banners/${id}`)
  return data
}

/** 배너 이미지 업로드 — multipart `file` → `{key,url,width,height}`. 413, 422. */
export async function uploadBannerImage(file: File): Promise<UploadedImage> {
  const form = new FormData()
  form.append("file", file, file.name)
  const { data } = await api.post<UploadedImage>("/admin/banners/image", form)
  return data
}

export async function createBanner(body: BannerWrite): Promise<BannerAdmin> {
  const { data } = await api.post<BannerAdmin>("/admin/banners", body)
  return data
}

export async function updateBanner(id: number, body: BannerWrite): Promise<BannerAdmin> {
  const { data } = await api.put<BannerAdmin>(`/admin/banners/${id}`, body)
  return data
}

export async function deleteBanner(id: number): Promise<void> {
  await api.delete(`/admin/banners/${id}`)
}

/** 노출 순서 변경 — 나열한 순서대로 0..n-1, 빠진 배너는 기존 순서대로 뒤. 변경된 전체 목록을 돌려준다. */
export async function reorderBanners(ids: number[]): Promise<BannerAdmin[]> {
  const { data } = await api.patch<BannerAdmin[]>("/admin/banners/order", { ids })
  return data
}

/** 기존 배너를 PUT 전체 교체 본문으로 바꾼다(활성 토글 등 일부만 바꿀 때). */
export function bannerToWrite(banner: BannerAdmin): BannerWrite {
  return {
    title: banner.title,
    image_key: banner.image_key,
    link_url: banner.link_url,
    alt_text: banner.alt_text,
    starts_at: banner.starts_at,
    ends_at: banner.ends_at,
    sort_order: banner.sort_order,
    is_active: banner.is_active,
  }
}
