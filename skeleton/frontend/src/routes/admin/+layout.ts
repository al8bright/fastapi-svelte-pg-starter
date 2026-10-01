import { error, redirect } from "@sveltejs/kit"
import { browser } from "$app/env"
import { resolve } from "$app/paths"
import { getMe } from "#lib/api/auth.js"
import { restoreSession } from "#lib/auth/session.js"
import { queryClient } from "#lib/query-client.js"
import { loginWithNext } from "#lib/returnTo.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// 관리자 가드 (ARCHITECTURE.md §14) — /admin/* 전체.
// 1) 세션 복원(restoreSession)을 직접 기다린다(레이아웃 load 는 병렬이라 루트 복원을 기다린다는 보장이 없다).
// 2) 비로그인 → 로그인 화면(?next= 원래 위치).
// 3) GET /auth/me 의 role 이 admin 이 아니면 error(403) → 루트 +error.svelte 가 403 화면(홈 링크)을 그린다.
// 사용자 정보는 createMe() 와 같은 쿼리 키(["auth","me"])로 받아 캐시를 공유한다.
// 이 가드는 화면 노출을 정하는 UX 장치이고 권한 경계는 백엔드 require_admin(비로그인 401, 일반 사용자 403)이다.
// url 은 미인증일 때만 읽는다 — load 가 url 에 의존하지 않아 콘솔 안에서 이동할 때마다 다시 돌지 않는다.
export const load = async ({ url }) => {
  if (!browser) return
  await restoreSession()
  if (!authStore.isAuthenticated) redirect(302, loginWithNext(resolve("login"), `${url.pathname}${url.search}`))
  const user = await queryClient.fetchQuery({ queryKey: ["auth", "me"], queryFn: getMe, staleTime: 30_000 })
  authStore.setUser(user)
  if (user.role !== "admin") error(403, "관리자 권한이 필요합니다.")
}
