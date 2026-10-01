<script lang="ts">
  import { resolve } from "$app/paths"
  import { signOut } from "#lib/auth/session.js"
  import { ui } from "#lib/components/ui/styles.js"
  import { createMe } from "#lib/queries/auth.js"

  // 내 정보 화면 (ARCHITECTURE.md §14) — 사용자 레이아웃 안, (protected) 가드 하위.
  const me = createMe()
  let loggingOut = $state(false)

  // 로그아웃 = POST /auth/logout(서버 세션 폐기 + refresh 쿠키 삭제) → 상태·캐시 정리 → 공개 홈.
  // ⛔ authStore.clear() 를 직접 부르지 않는다 — 서버 세션과 쿼리 캐시가 남는다.
  const onLogout = async () => {
    loggingOut = true
    try {
      await signOut()
    } finally {
      loggingOut = false
    }
  }
</script>

<div class="mx-auto max-w-md px-4 py-12">
  <section class="{ui.card} rounded-xl p-8">
    <h1 class="text-2xl font-semibold text-on-surface">내 정보</h1>

    {#if me.isPending}
      <p class="mt-4 text-on-surface-variant" role="status">불러오는 중…</p>
    {:else}
      <dl class="mt-4 space-y-3">
        <div class="flex justify-between border-b border-outline-variant pb-2">
          <dt class="text-on-surface-variant">아이디</dt>
          <dd class="font-medium text-on-surface">{me.data?.username}</dd>
        </div>
        <div class="flex justify-between border-b border-outline-variant pb-2">
          <dt class="text-on-surface-variant">권한</dt>
          <dd class="font-medium text-on-surface">{me.data?.role === "admin" ? "관리자" : "일반 사용자"}</dd>
        </div>
      </dl>
    {/if}

    <div class="mt-6 flex flex-col gap-3">
      {#if me.data?.role === "admin"}
        <a href={resolve("admin")} class={ui.btnSecondary}>관리자 콘솔로 이동</a>
      {/if}
      <button type="button" onclick={onLogout} disabled={loggingOut} class={ui.btnDanger}>
        {loggingOut ? "로그아웃 중…" : "로그아웃"}
      </button>
    </div>
  </section>
</div>
