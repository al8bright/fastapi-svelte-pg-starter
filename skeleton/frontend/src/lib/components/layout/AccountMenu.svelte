<script lang="ts">
  import { afterNavigate } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import { signOut } from "#lib/auth/session.js"
  import Icon from "#lib/components/ui/Icon.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { createMe } from "#lib/queries/auth.js"
  import { loginWithNext } from "#lib/returnTo.js"
  import { authStore } from "#lib/stores/auth.svelte.js"

  // 상단 내비 오른쪽 — 비로그인: 로그인 버튼 / 로그인: 계정 메뉴(내 정보·로그아웃) + 관리자에게만 "관리자 콘솔".
  // 메뉴는 디스클로저 패턴(button aria-expanded + 링크 목록). Esc·바깥 클릭·페이지 이동으로 닫는다.
  // 세션 복원(restoreSession)은 루트 +layout.ts load 가 끝낸 뒤라 여기서는 기다릴 필요가 없다.

  const me = createMe()
  const menuId = $props.id()
  let open = $state(false)
  let root: HTMLDivElement | undefined = $state()
  let button: HTMLButtonElement | undefined = $state()

  const user = $derived(me.data)
  const isAdmin = $derived(user?.role === "admin")
  const loginHref = $derived(
    loginWithNext(resolve("login"), `${page.url.pathname}${page.url.search}${page.url.hash}`),
  )

  afterNavigate(() => {
    open = false
  })

  $effect(() => {
    if (!open) return
    const onPointer = (e: PointerEvent) => {
      if (!root?.contains(e.target as Node)) open = false
    }
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        open = false
        button?.focus()
      }
    }
    document.addEventListener("pointerdown", onPointer)
    document.addEventListener("keydown", onKey)
    return () => {
      document.removeEventListener("pointerdown", onPointer)
      document.removeEventListener("keydown", onKey)
    }
  })

  const onLogout = async () => {
    open = false
    await signOut()
  }

  const initials = (name: string) => name.slice(0, 2).toUpperCase()
  const menuItem = `flex min-h-11 items-center rounded px-3 text-sm hover:bg-surface-container-low ${ui.focusRing}`
</script>

{#if !authStore.isAuthenticated}
  <!-- 로그인 화면 주소 — 현재 위치를 ?next= 로 담아 로그인 후 돌아온다(loginWithNext 가 resolve 된 경로를 받는다). -->
  <a href={loginHref} class={ui.btnSecondary}>로그인</a>
{:else}
  <div class="flex items-center gap-2">
    {#if isAdmin}
      <a href={resolve("admin")} class="{ui.btnSecondary} max-md:hidden">
        <Icon name="shield" size={16} />
        관리자 콘솔
      </a>
    {/if}
    <div bind:this={root} class="relative">
      <button
        bind:this={button}
        type="button"
        aria-expanded={open}
        aria-controls={menuId}
        aria-label="내 계정 메뉴{user ? ` (${user.username})` : ''}"
        onclick={() => (open = !open)}
        class="flex min-h-11 items-center gap-2 rounded-full border border-outline-variant bg-surface-container-lowest py-1.5 pr-3 pl-1.5 text-on-surface hover:bg-surface-container-low {ui.focusRing}"
      >
        <span class="flex size-8 items-center justify-center rounded-full bg-tertiary text-xs font-semibold text-on-primary">
          {user ? initials(user.username) : "··"}
        </span>
        <span class="max-w-28 truncate text-sm font-medium max-sm:hidden">{user?.username ?? "계정"}</span>
        <Icon name="chevronDown" size={16} class="text-on-surface-variant" />
      </button>
      {#if open}
        <div
          id={menuId}
          class="absolute right-0 z-40 mt-2 w-56 rounded-xl border border-outline-variant bg-surface-container-lowest p-2 shadow-[0_12px_40px_rgba(0,0,0,0.1)]"
        >
          {#if user}
            <p class="border-b border-surface-container px-3 pt-1 pb-2 text-sm text-on-surface-variant">
              <span class="font-semibold text-on-surface">{user.username}</span> · {isAdmin ? "관리자" : "일반 사용자"}
            </p>
          {/if}
          <ul class="mt-1 flex flex-col">
            {#if isAdmin}
              <li><a href={resolve("admin")} class={menuItem}>관리자 콘솔</a></li>
            {/if}
            <li><a href={resolve("me")} class={menuItem}>내 정보</a></li>
            <li>
              <button
                type="button"
                onclick={onLogout}
                class="flex min-h-11 w-full items-center rounded px-3 text-left text-sm text-error hover:bg-error-container {ui.focusRing}"
              >
                로그아웃
              </button>
            </li>
          </ul>
        </div>
      {/if}
    </div>
  </div>
{/if}
