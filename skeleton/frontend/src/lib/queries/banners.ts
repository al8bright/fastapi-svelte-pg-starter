import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query"
import {
  type BannerAdmin,
  bannerToWrite,
  type BannerWrite,
  createBanner,
  deleteBanner,
  getAdminBanner,
  listAdminBanners,
  listBanners,
  reorderBanners,
  updateBanner,
} from "#lib/api/banners.js"

// 배너 svelte-query (ARCHITECTURE.md §13). 변경은 ["banners"] 전체(공개·관리자)와 대시보드를 무효화한다.
export const bannerKeys = {
  all: ["banners"] as const,
  public: ["banners", "public"] as const,
  adminList: ["banners", "admin", "list"] as const,
  adminDetail: (id: number) => ["banners", "admin", "detail", id] as const,
}

export function createPublicBanners() {
  return createQuery(() => ({ queryKey: bannerKeys.public, queryFn: listBanners, retry: false }))
}

export function createAdminBanners() {
  return createQuery(() => ({ queryKey: bannerKeys.adminList, queryFn: listAdminBanners }))
}

export function createAdminBanner(id: () => number | null) {
  return createQuery(() => {
    const bannerId = id()
    return {
      queryKey: bannerKeys.adminDetail(bannerId ?? 0),
      queryFn: () => getAdminBanner(bannerId as number),
      enabled: bannerId !== null && bannerId > 0,
      retry: false,
    }
  })
}

function useInvalidateBanners() {
  const qc = useQueryClient()
  return () =>
    Promise.all([
      qc.invalidateQueries({ queryKey: bannerKeys.all }),
      qc.invalidateQueries({ queryKey: ["admin", "dashboard"] }),
    ])
}

export function createSaveBanner() {
  const invalidate = useInvalidateBanners()
  return createMutation(() => ({
    mutationFn: ({ id, body }: { id: number | null; body: BannerWrite }) =>
      id === null ? createBanner(body) : updateBanner(id, body),
    onSuccess: () => invalidate(),
  }))
}

/** 활성 토글 — PUT 전체 본문. 목록 캐시를 낙관적으로 바꾸고 실패하면 되돌린다. */
export function createToggleBanner() {
  const qc = useQueryClient()
  const invalidate = useInvalidateBanners()
  return createMutation(() => ({
    mutationFn: (banner: BannerAdmin) =>
      updateBanner(banner.id, { ...bannerToWrite(banner), is_active: !banner.is_active }),
    onMutate: async (banner: BannerAdmin) => {
      await qc.cancelQueries({ queryKey: bannerKeys.adminList })
      const previous = qc.getQueryData<BannerAdmin[]>(bannerKeys.adminList)
      qc.setQueryData<BannerAdmin[]>(bannerKeys.adminList, (list) =>
        list?.map((b) => (b.id === banner.id ? { ...b, is_active: !b.is_active } : b)),
      )
      return { previous }
    },
    onError: (_e, _banner, context) => {
      if (context?.previous) qc.setQueryData(bannerKeys.adminList, context.previous)
    },
    onSettled: () => invalidate(),
  }))
}

export function createReorderBanners() {
  const qc = useQueryClient()
  const invalidate = useInvalidateBanners()
  return createMutation(() => ({
    mutationFn: (ids: number[]) => reorderBanners(ids),
    onSuccess: (list) => {
      qc.setQueryData(bannerKeys.adminList, list)
      return invalidate()
    },
  }))
}

export function createDeleteBanner() {
  const invalidate = useInvalidateBanners()
  return createMutation(() => ({
    mutationFn: (id: number) => deleteBanner(id),
    onSuccess: () => invalidate(),
  }))
}
