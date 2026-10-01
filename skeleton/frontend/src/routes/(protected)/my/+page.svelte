<script lang="ts">
  import { resolve } from "$app/paths"
  import { signOut } from "#lib/auth/session.js"
  import { createMe } from "#lib/queries/auth.js"

  // My 화면 (ARCHITECTURE.md §14). 로그인 사용자 정보 + 로그아웃.
  const me = createMe()

  let loggingOut = $state(false)

  // 로그아웃 = POST /auth/logout(서버 세션 폐기 + refresh 쿠키 삭제) → 상태·캐시 정리 → 로그인 화면.
  const onLogout = async () => {
    loggingOut = true
    try {
      await signOut()
    } finally {
      loggingOut = false
    }
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
      disabled={loggingOut}
      class="mt-6 w-full rounded-lg bg-error-container py-2.5 font-semibold text-on-error-container disabled:opacity-60"
    >
      {loggingOut ? "로그아웃 중…" : "로그아웃"}
    </button>
    <a
      href={resolve("")}
      class="mt-3 block text-center text-sm text-on-surface-variant hover:text-on-surface"
    >
      ← 메인으로
    </a>
  </div>
</main>
