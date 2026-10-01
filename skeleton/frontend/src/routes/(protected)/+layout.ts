import { redirect } from "@sveltejs/kit"
import { browser } from "$app/env"
import { resolve } from "$app/paths"
import { restoreSession } from "#lib/auth/session.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// 보호 라우트 가드 (ARCHITECTURE.md §14). 미인증 시 로그인 화면으로 보낸다.
// (protected) 는 라우트 그룹이라 URL 에는 나타나지 않는다 — /, /landing, /my 가 전부 이 가드를 탄다.
// 레이아웃 load 는 병렬로 돌기 때문에 루트의 복원을 기다린다는 보장이 없다 → 같은 restoreSession()
// Promise 를 직접 기다린 뒤 메모리 상태로 판단한다(새로고침 시 로그인 화면으로 깜빡 튕기지 않는다).
// prerender 단계에서는 browser 가 false 라 리다이렉트하지 않고 빈 셸만 만든다.
export const load = async () => {
  if (!browser) return
  await restoreSession()
  if (!authStore.isAuthenticated) redirect(302, resolve("login"))
}
