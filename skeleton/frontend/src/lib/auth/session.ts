import { browser } from "$app/env"
import { goto } from "$app/navigation"
import { resolve } from "$app/paths"
import { logout } from "#lib/api/auth.js"
import { refreshAccessToken } from "#lib/api/client.js"
import { queryClient } from "#lib/query-client.js"
import { authStore } from "#lib/stores/auth.svelte.js"

// 세션 수명주기 (ARCHITECTURE.md §14).

// 페이지 로드(새로고침)당 1회만 시도한다 — 루트/보호 레이아웃 load 가 같은 Promise 를 공유한다.
let restorePromise: Promise<void> | null = null

/**
 * 앱 시작 시 httpOnly refresh 쿠키로 세션을 복원한다 (POST /auth/refresh).
 * access 토큰은 메모리에만 있어 새로고침하면 사라지므로, 인증 여부를 판단하기 전에 반드시 기다린다
 * — 그래야 로그인 상태에서 새로고침해도 로그인 화면으로 깜빡 튕기지 않는다.
 * 실패(쿠키 없음/만료/폐기)는 조용히 비로그인 상태로 시작한다.
 * prerender(Node) 단계에는 쿠키도 브라우저도 없으므로 아무것도 하지 않는다.
 */
export function restoreSession(): Promise<void> {
  if (!browser) return Promise.resolve()
  restorePromise ??= refreshAccessToken().then(() => undefined)
  return restorePromise
}

/** 로그아웃 — 서버 세션 폐기(실패해도 진행) → 상태·쿼리 캐시 정리 → 공개 홈(/). */
export async function signOut(): Promise<void> {
  try {
    await logout()
  } catch {
    // 네트워크 오류여도 클라이언트 상태는 비운다(서버 세션은 만료로 정리된다).
  }
  authStore.clear()
  queryClient.clear()
  await goto(resolve(""), { replace: true })
}
