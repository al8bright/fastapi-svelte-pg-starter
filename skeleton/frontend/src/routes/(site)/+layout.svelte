<script lang="ts">
  import type { Snippet } from "svelte"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import AccountMenu from "#lib/components/layout/AccountMenu.svelte"
  import SkipLink from "#lib/components/layout/SkipLink.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { SITE_MARK, SITE_NAME } from "#lib/site.js"

  // 사용자 화면 레이아웃 (디자인 A — 상단 내비 포털). 로그인 없이 볼 수 있는 공개 화면의 틀이다.
  // (site) 는 라우트 그룹이라 URL 에 나타나지 않는다 — /, /notices, /notices/:id, /me 가 이 레이아웃을 쓴다.
  // 좁은 화면(<768px)에서는 내비가 두 번째 줄로 내려가고 가로로 스크롤된다.
  const { children }: { children: Snippet } = $props()

  const home = resolve("")
  const notices = resolve("notices")
  const homeActive = $derived(page.url.pathname === home)
  const noticesActive = $derived(page.url.pathname === notices || page.url.pathname.startsWith(`${notices}/`))

  const navClass = (active: boolean) =>
    `flex min-h-11 shrink-0 items-center rounded-lg px-3.5 text-[15px] whitespace-nowrap ${ui.focusRing} ${
      active
        ? "bg-primary-fixed font-semibold text-primary"
        : "text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface"
    }`
</script>

<div class="flex min-h-screen flex-col bg-surface text-on-surface">
  <SkipLink target="main" />
  <header class="border-b border-surface-container-highest bg-surface-container-lowest">
    <div
      class="mx-auto flex max-w-[1200px] flex-wrap items-center gap-x-8 gap-y-1 px-4 py-2 sm:px-6 md:h-16 md:flex-nowrap md:py-0"
    >
      <a href={home} class="flex min-h-11 items-center gap-2.5 rounded text-lg font-bold text-on-surface {ui.focusRing}">
        <span aria-hidden="true" class="flex size-8 items-center justify-center rounded-lg bg-primary text-sm text-on-primary">
          {SITE_MARK}
        </span>
        {SITE_NAME}
      </a>
      <nav
        aria-label="주 메뉴"
        class="order-last -mx-1 flex w-full gap-1 overflow-x-auto px-1 pb-1 md:order-none md:w-auto md:flex-1 md:pb-0"
      >
        <a href={home} class={navClass(homeActive)} aria-current={homeActive ? "page" : undefined}>홈</a>
        <a href={notices} class={navClass(noticesActive)} aria-current={noticesActive ? "page" : undefined}>공지사항</a>
        <!-- 자리표시 메뉴 — 프로젝트에 맞게 실제 화면으로 바꾼다. -->
        <a href={resolve("#services")} class={navClass(false)}>서비스</a>
        <a href={resolve("#support")} class={navClass(false)}>고객지원</a>
      </nav>
      <div class="ml-auto md:ml-0">
        <AccountMenu />
      </div>
    </div>
  </header>

  <main id="main" tabindex="-1" class="flex-1 outline-none">
    {@render children()}
  </main>

  <footer id="support" class="border-t border-surface-container-highest bg-surface-container-lowest">
    <div
      class="mx-auto flex max-w-[1200px] flex-col gap-2 px-4 py-6 text-[13px] text-on-surface-variant sm:flex-row sm:justify-between sm:px-6"
    >
      <span>© {SITE_NAME}</span>
      <span>이용약관 · 개인정보처리방침</span>
    </div>
  </footer>
</div>
