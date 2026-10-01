<script lang="ts">
  import type { Snippet } from "svelte"
  import { afterNavigate } from "$app/navigation"
  import AdminSidebar from "#lib/components/layout/AdminSidebar.svelte"
  import SkipLink from "#lib/components/layout/SkipLink.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import { ui } from "#lib/components/ui/styles.js"

  // 관리자 콘솔 레이아웃 (디자인 A — 그룹형 사이드바 콘솔). 가드는 형제 파일 +layout.ts.
  // ≥1024px: 248px 고정 사이드바 + 본문. 그보다 좁으면 상단 바의 "메뉴" 버튼이 사이드바를 위에서 펼친다.
  const { children }: { children: Snippet } = $props()

  let drawerOpen = $state(false)
  let drawer: HTMLDivElement | undefined = $state()
  let toggle: HTMLButtonElement | undefined = $state()

  // 이동하면 서랍을 닫는다.
  afterNavigate(() => {
    drawerOpen = false
  })

  $effect(() => {
    if (!drawerOpen) return
    drawer?.querySelector<HTMLElement>("a, button")?.focus()
    const button = toggle
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") drawerOpen = false
    }
    document.addEventListener("keydown", onKey)
    return () => {
      document.removeEventListener("keydown", onKey)
      button?.focus({ preventScroll: true })
    }
  })
</script>

<div class="min-h-screen bg-surface text-on-surface lg:grid lg:grid-cols-[248px_minmax(0,1fr)]">
  <SkipLink target="admin-main" />

  <!-- 넓은 화면 — 고정 사이드바 -->
  <aside class="border-r border-surface-container-highest bg-surface-container-lowest max-lg:hidden">
    <div class="sticky top-0 h-screen overflow-y-auto">
      <AdminSidebar />
    </div>
  </aside>

  <!-- 좁은 화면 — 상단 바 + 서랍 -->
  <div
    class="sticky top-0 z-30 flex h-14 items-center justify-between border-b border-surface-container-highest bg-surface-container-lowest px-2 lg:hidden"
  >
    <button
      bind:this={toggle}
      type="button"
      aria-expanded={drawerOpen}
      aria-controls="admin-drawer"
      onclick={() => (drawerOpen = !drawerOpen)}
      class="{ui.btnSmall} gap-2 text-on-surface hover:bg-surface-container-low"
    >
      <Icon name={drawerOpen ? "close" : "menu"} />
      {drawerOpen ? "메뉴 닫기" : "메뉴"}
    </button>
    <span class="pr-3 text-sm font-semibold">관리자 콘솔</span>
  </div>
  {#if drawerOpen}
    <div
      class="fixed inset-0 top-14 z-20 bg-black/30 lg:hidden"
      aria-hidden="true"
      onclick={() => (drawerOpen = false)}
    ></div>
    <div
      id="admin-drawer"
      bind:this={drawer}
      class="fixed inset-x-0 top-14 z-30 max-h-[calc(100vh-3.5rem)] overflow-y-auto border-b border-surface-container-highest bg-surface-container-lowest shadow-[0_12px_40px_rgba(0,0,0,0.1)] lg:hidden"
    >
      <AdminSidebar />
    </div>
  {/if}

  <main id="admin-main" tabindex="-1" class="min-w-0 px-4 py-6 outline-none sm:px-6 lg:px-10 lg:py-8">
    {@render children()}
  </main>
</div>
