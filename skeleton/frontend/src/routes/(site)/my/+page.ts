import { redirect } from "@sveltejs/kit"
import { browser } from "$app/env"
import { resolve } from "$app/paths"

// 이전 경로 호환 — /my 는 /me 로 옮겼다.
export const load = () => {
  if (browser) redirect(308, resolve("me"))
}
