import { redirect } from "@sveltejs/kit"
import { browser } from "$app/env"
import { resolve } from "$app/paths"

// 관리자 콘솔 안의 없는 주소는 대시보드로 보낸다(가드는 상위 admin/+layout.ts 가 먼저 돈다).
export const prerender = false

export const load = () => {
  if (browser) redirect(307, resolve("admin"))
}
