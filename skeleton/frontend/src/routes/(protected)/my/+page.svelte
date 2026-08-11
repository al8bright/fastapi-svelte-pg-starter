<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { createMe } from "$lib/queries/auth"
  import { authStore } from "$lib/stores/auth.svelte"

  // My 화면 (architecture.md §14). 로그인 사용자 정보 + 로그아웃.
  const me = createMe()

  const onLogout = () => {
    authStore.logout()
    goto(resolve("/login"), { replaceState: true })
  }
</script>

<main class="flex min-h-screen flex-col items-center justify-center bg-surface px-4">
  <div class="w-full max-w-sm rounded-2xl border border-outline-variant bg-surface-container-lowest p-8">
    <h1 class="text-2xl font-bold text-on-surface">내 정보</h1>

    {#if me.isPending}
      <p class="mt-4 text-on-surface-variant">불러오는 중…</p>
    {:else}
      <dl class="mt-4 space-y-3">
        <div class="flex justify-between border-b border-outline-variant pb-2">
          <dt class="text-on-surface-variant">아이디</dt>
          <dd class="font-medium text-on-surface">{me.data?.username}</dd>
        </div>
        <div class="flex justify-between border-b border-outline-variant pb-2">
          <dt class="text-on-surface-variant">권한</dt>
          <dd class="font-medium text-on-surface">
            {me.data?.role === "admin" ? "관리자" : "일반 사용자"}
          </dd>
        </div>
      </dl>
    {/if}

    <button
      type="button"
      onclick={onLogout}
      class="mt-6 w-full rounded-lg bg-error-container py-2.5 font-semibold text-on-error-container"
    >
      로그아웃
    </button>
    <a
      href={resolve("/")}
      class="mt-3 block text-center text-sm text-on-surface-variant hover:text-on-surface"
    >
      ← 메인으로
    </a>
  </div>
</main>
