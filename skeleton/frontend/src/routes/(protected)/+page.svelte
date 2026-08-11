<script lang="ts">
  import { resolve } from "$app/paths"
  import { createMe } from "$lib/queries/auth"

  // 메인 화면 (로그인 후 홈). 랜딩(시스템 상태) / My 로 이동.
  const me = createMe()
</script>

<main class="flex min-h-screen flex-col items-center justify-center bg-surface px-4">
  <div class="w-full max-w-md text-center">
    <span class="inline-block rounded-full bg-primary px-4 py-1 text-sm font-semibold text-on-primary">
      __PROJECT_NAME__
    </span>
    <h1 class="mt-4 text-3xl font-bold text-on-surface">
      {me.data ? `${me.data.username} 님, 환영합니다 👋` : "환영합니다 👋"}
    </h1>
    <p class="mt-2 text-on-surface-variant">메인 화면입니다. 아래에서 이동하세요.</p>

    <div class="mt-8 grid gap-3">
      <a
        href={resolve("/landing")}
        class="rounded-lg border border-outline-variant bg-surface-container-lowest px-5 py-4 text-left font-semibold text-on-surface hover:border-primary"
      >
        시스템 상태(랜딩) →
        <span class="block text-sm font-normal text-on-surface-variant">
          백엔드 / DB 연결 상태 확인
        </span>
      </a>
      <a
        href={resolve("/my")}
        class="rounded-lg border border-outline-variant bg-surface-container-lowest px-5 py-4 text-left font-semibold text-on-surface hover:border-primary"
      >
        My →
        <span class="block text-sm font-normal text-on-surface-variant">
          내 정보 / 로그아웃
        </span>
      </a>
    </div>
  </div>
</main>
