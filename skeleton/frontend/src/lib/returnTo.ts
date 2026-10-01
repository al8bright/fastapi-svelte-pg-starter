// 로그인 후 원래 위치로 복귀 (ARCHITECTURE.md §14).
// 가드·세션 만료·"로그인" 버튼이 로그인 화면 주소에 `?next=<원래 경로+검색+해시>` 를 붙이고,
// 로그인 화면은 성공 후 그 값으로 이동한다. 쿼리 파라미터라 새로고침해도 복귀 정보가 남는다.
// $app/* 를 import 하지 않는 순수 모듈이다(로그인 경로는 호출부가 resolve("login") 으로 넘긴다).

/**
 * 복귀 경로로 써도 되는 값만 돌려준다(아니면 null) — 오픈 리다이렉트 방지.
 * 사이트 내부 절대 경로("/...")만 허용하고, "//host"·"/\host"(브라우저가 외부로 해석)와 로그인 화면 자신은 거부한다.
 */
export function safeNext(raw: string | null | undefined, loginPath: string): string | null {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//") || raw.startsWith("/\\")) return null
  const path = raw.split(/[?#]/, 1)[0]
  if (path === loginPath) return null
  return raw
}

/** 로그인 화면 주소 — from(경로+검색+해시)을 next 로 담는다. 홈("/")이나 허용되지 않는 값이면 붙이지 않는다. */
export function loginWithNext(loginPath: string, from: string): string {
  const next = safeNext(from, loginPath)
  if (!next || next === "/") return loginPath
  return `${loginPath}?next=${encodeURIComponent(next)}`
}
