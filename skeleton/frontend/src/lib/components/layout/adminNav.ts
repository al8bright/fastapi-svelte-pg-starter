import type { IconName } from "#lib/components/ui/icons.js"

// 관리자 콘솔 사이드바 메뉴 (디자인 A — 그룹형 사이드바). 메뉴를 추가하면 여기와 routes/admin/ 아래 라우트를 함께 만든다.
// path 는 resolve() 에 넘기는 pathname(앞의 "/" 없음) — 라우트가 없으면 svelte-check 가 타입 오류로 잡는다.
export interface AdminNavItem {
  path: "admin" | "admin/notices" | "admin/banners" | "admin/users" | "admin/sessions" | "admin/login-throttles" | "admin/system"
  label: string
  icon: IconName
  /** 하위 경로(/admin/notices/3/edit)에서도 활성으로 볼지. 대시보드(/admin)만 true(정확히 일치할 때만 활성). */
  end?: boolean
  /** 배지 종류 — 잠긴 계정 수. */
  badge?: "locked"
}

export interface AdminNavGroup {
  label: string
  items: AdminNavItem[]
}

export const ADMIN_NAV: AdminNavGroup[] = [
  { label: "개요", items: [{ path: "admin", label: "대시보드", icon: "dashboard", end: true }] },
  {
    label: "콘텐츠",
    items: [
      { path: "admin/notices", label: "공지사항", icon: "notice" },
      { path: "admin/banners", label: "배너", icon: "banner" },
    ],
  },
  {
    label: "회원·보안",
    items: [
      { path: "admin/users", label: "사용자", icon: "users" },
      { path: "admin/sessions", label: "세션", icon: "session" },
      { path: "admin/login-throttles", label: "로그인 잠금", icon: "lock", badge: "locked" },
    ],
  },
  { label: "시스템", items: [{ path: "admin/system", label: "시스템 상태", icon: "system" }] },
]

/** 현재 경로가 메뉴 항목에 해당하는가 — end 면 정확히 일치, 아니면 하위 경로까지. */
export function isNavActive(pathname: string, href: string, end = false): boolean {
  const path = pathname.length > 1 ? pathname.replace(/\/+$/, "") : pathname
  return end ? path === href : path === href || path.startsWith(`${href}/`)
}
