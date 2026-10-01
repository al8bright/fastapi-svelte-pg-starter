<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import { loginErrorMessage } from "#lib/api/auth.js"
  import { createLogin } from "#lib/queries/auth.js"
  import { safeNext } from "#lib/returnTo.js"
  import { SITE_NAME } from "#lib/site.js"
  import { authStore } from "#lib/stores/auth.svelte.js"

  // 로그인 화면 (ARCHITECTURE.md §14). 성공 시 원래 위치(?next=)로, 없으면 홈(/)으로.
  // next 는 가드·세션 만료·상단 "로그인" 버튼이 붙인다 — 사이트 내부 경로만 받는다(safeNext, 오픈 리다이렉트 방지).
  // 성공하면 백엔드가 httpOnly refresh 쿠키를 심고, access 토큰은 메모리 스토어에만 저장된다.
  const loginMutation = createLogin()

  let username = $state("")
  let password = $state("")

  const destination = $derived(safeNext(page.url.searchParams.get("next"), resolve("login")) ?? resolve(""))

  // 401 = 자격증명 오류, 429 = 계정 잠금, 422·5xx·네트워크 오류도 각각 구분해 안내한다.
  const errorMessage = $derived(loginMutation.error ? loginErrorMessage(loginMutation.error) : null)

  // 이미 로그인 상태면 목적지로 (세션 복원은 루트 +layout.ts load 가 끝낸 뒤다).
  $effect(() => {
    if (authStore.isAuthenticated) void goto(destination, { replace: true })
  })

  const onSubmit = (e: SubmitEvent) => {
    e.preventDefault()
    loginMutation.mutate({ username, password })
  }
</script>

<main class="flex min-h-screen items-center justify-center bg-surface px-4">
  <form
    onsubmit={onSubmit}
    class="w-full max-w-sm rounded-2xl border border-outline-variant bg-surface-container-lowest p-8 shadow-sm"
  >
    <span class="inline-block rounded-full bg-primary px-4 py-1 text-sm font-semibold text-on-primary">
      {SITE_NAME}
    </span>
    <h1 class="mt-4 text-2xl font-bold text-on-surface">로그인</h1>
    <p class="mt-1 text-sm text-on-surface-variant">계정으로 로그인하세요.</p>

    <label class="mt-6 block text-sm font-medium text-on-surface" for="username">아이디</label>
    <!-- svelte-ignore a11y_autofocus -->
    <input
      id="username"
      class="mt-1 w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-on-surface outline-none focus:border-primary"
      bind:value={username}
      autocomplete="username"
      autofocus
    />

    <label class="mt-4 block text-sm font-medium text-on-surface" for="password">비밀번호</label>
    <input
      id="password"
      type="password"
      class="mt-1 w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-on-surface outline-none focus:border-primary"
      bind:value={password}
      autocomplete="current-password"
    />

    {#if errorMessage}
      <p role="alert" class="mt-3 rounded-lg bg-error-container px-3 py-2 text-sm text-on-error-container">
        {errorMessage}
      </p>
    {/if}

    <button
      type="submit"
      disabled={loginMutation.isPending}
      class="mt-6 w-full rounded-lg bg-primary py-2.5 font-semibold text-on-primary disabled:opacity-60"
    >
      {loginMutation.isPending ? "로그인 중…" : "로그인"}
    </button>
    <a
      href={resolve("")}
      class="mt-4 flex min-h-11 items-center justify-center rounded text-sm text-on-surface-variant hover:text-on-surface"
    >
      ← 홈으로
    </a>
  </form>
</main>
