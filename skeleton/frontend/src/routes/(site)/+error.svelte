<script lang="ts">
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import { ui } from "#lib/components/ui/styles.js"

  // 사용자 화면 안의 오류 — 상단 내비·푸터((site)/+layout.svelte)를 그대로 두고 본문 자리에 그린다.
  // 없는 주소는 (site)/[...rest] 가 error(404) 를 던져 여기로 온다.
</script>

<div class="mx-auto max-w-[1200px] px-4 py-20 text-center sm:px-6">
  {#if page.status === 404}
    <p class="text-sm font-semibold tracking-wider text-primary">404</p>
    <h1 class="mt-2 text-2xl font-semibold">페이지를 찾을 수 없습니다</h1>
    <p class="mt-3 text-on-surface-variant">주소가 바뀌었거나 삭제된 페이지입니다.</p>
  {:else}
    <p class="text-sm font-semibold tracking-wider text-error">{page.status}</p>
    <h1 class="mt-2 text-2xl font-semibold">화면을 표시하지 못했습니다</h1>
    <p class="mt-3 text-on-surface-variant">
      일시적인 문제일 수 있습니다. 새로고침한 뒤에도 같으면 관리자에게 알려 주세요.
    </p>
  {/if}
  <a href={resolve("")} class="{ui.btnPrimary} mt-6">홈으로 이동</a>
</div>
