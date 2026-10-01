import { redirect } from "@sveltejs/kit"
import { browser } from "$app/env"
import { resolve } from "$app/paths"
import { getToken } from "#lib/auth/token.js"

// 보호 라우트 가드 (ARCHITECTURE.md §14). 미인증 시 로그인 화면으로 보낸다.
// (protected) 는 라우트 그룹이라 URL 에는 나타나지 않는다 — /, /landing, /my 가 전부 이 가드를 탄다.
// prerender 단계에서는 browser 가 false 라 리다이렉트하지 않고 빈 셸만 만든다.
export const load = () => {
  if (browser && !getToken()) redirect(302, resolve("login"))
}
