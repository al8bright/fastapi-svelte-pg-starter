import { error } from "@sveltejs/kit"

// 사용자 화면의 404 — 어떤 라우트에도 맞지 않는 주소를 받아 (site)/+error.svelte 를 레이아웃 안에서 보여 준다.
// (/admin/* 는 더 구체적인 admin/[...rest] 가 먼저 받는다.)
export const prerender = false

export const load = () => {
  error(404, "페이지를 찾을 수 없습니다")
}
