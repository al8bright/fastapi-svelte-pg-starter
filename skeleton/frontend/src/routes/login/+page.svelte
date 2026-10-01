<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { createLogin } from "#lib/queries/auth.js"
  import { authStore } from "#lib/stores/auth.svelte.js"

  // 로그인 화면 (ARCHITECTURE.md §14). 성공 시 메인(/)으로 이동.
  const loginMutation = createLogin()

  let username = $state("")
  let password = $state("")

  // 이미 로그인 상태면 메인으로.
  $effect(() => {
    if (authStore.isAuthenticated) goto(resolve(""), { replaceState: true })
  })

  const onSubmit = (e: SubmitEvent) => {
    e.preventDefault()
    loginMutation.mutate(
      { username, password },
      { onSuccess: () => goto(resolve(""), { replaceState: true }) },
    )
  }
</script>

<main class="flex min-h-screen items-center justify-center bg-surface px-4">
  <form
    onsubmit={onSubmit}
    class="w-full max-w-sm rounded-2xl border border-outline-variant bg-surface-container-lowest p-8 shadow-sm"
  >
    <span class="inline-block rounded-full bg-primary px-4 py-1 text-sm font-semibold text-on-primary">
      __PROJECT_NAME__
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

    {#if loginMutation.isError}
      <p class="mt-3 rounded-lg bg-error-container px-3 py-2 text-sm text-on-error-container">
        아이디 또는 비밀번호가 올바르지 않습니다.
      </p>
    {/if}

    <button
      type="submit"
      disabled={loginMutation.isPending}
      class="mt-6 w-full rounded-lg bg-primary py-2.5 font-semibold text-on-primary disabled:opacity-60"
    >
      {loginMutation.isPending ? "로그인 중…" : "로그인"}
    </button>

    <p class="mt-4 text-center text-xs text-on-surface-variant">
      기본 관리자 계정: <code class="font-mono">admin / admin123</code>
    </p>
  </form>
</main>
