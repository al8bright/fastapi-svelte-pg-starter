<script lang="ts">
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import { ui } from "#lib/components/ui/styles.js"

  // 루트 오류 화면 — 레이아웃 바깥(전체 화면)에서 그린다.
  // - 403: 관리자 가드(routes/admin/+layout.ts)가 error(403) 을 던졌다 — 로그인했지만 관리자 권한이 없다.
  // - 그 밖: 레이아웃 load 실패(사용자 정보 조회 실패 등)·배포 직후 옛 청크를 못 찾는 경우 등.
  // 사용자 화면 안의 404 는 routes/(site)/+error.svelte 가 상단 내비와 함께 그린다.
</script>

<main class="flex min-h-screen items-center justify-center bg-surface px-4">
  {#if page.status === 403}
    <div class="{ui.card} w-full max-w-md p-8 text-center">
      <p class="text-sm font-semibold tracking-wider text-error">403</p>
      <h1 class="mt-2 text-2xl font-semibold text-on-surface">접근 권한이 없습니다</h1>
      <p class="mt-3 text-on-surface-variant">
        관리자 콘솔은 관리자 계정만 이용할 수 있습니다. 권한이 필요하면 관리자에게 문의하세요.
      </p>
      <a href={resolve("")} class="{ui.btnPrimary} mt-6">홈으로 이동</a>
    </div>
  {:else if page.status === 404}
    <div class="{ui.card} w-full max-w-md p-8 text-center">
      <p class="text-sm font-semibold tracking-wider text-primary">404</p>
      <h1 class="mt-2 text-2xl font-semibold">페이지를 찾을 수 없습니다</h1>
      <p class="mt-3 text-on-surface-variant">주소가 바뀌었거나 삭제된 페이지입니다.</p>
      <a href={resolve("")} class="{ui.btnPrimary} mt-6">홈으로 이동</a>
    </div>
  {:else}
    <div role="alert" class="{ui.card} w-full max-w-md p-8 text-center">
      <h1 class="text-2xl font-semibold">화면을 표시하지 못했습니다</h1>
      <p class="mt-3 text-on-surface-variant">
        일시적인 문제일 수 있습니다. 새로고침한 뒤에도 같으면 관리자에게 알려 주세요.
        <span class="mt-1 block text-sm">({page.status} {page.error?.message ?? ""})</span>
      </p>
      <div class="mt-6 flex justify-center gap-2">
        <button type="button" class={ui.btnPrimary} onclick={() => window.location.reload()}>새로고침</button>
        <a href={resolve("")} class={ui.btnNeutral} data-sveltekit-reload>홈으로</a>
      </div>
    </div>
  {/if}
</main>
