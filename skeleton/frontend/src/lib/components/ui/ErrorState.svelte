<script lang="ts">
  import { ui } from "./styles.js"

  // 조회 실패 — role="alert" 로 즉시 읽히게 하고, 재시도 버튼을 둔다.
  const { message, onRetry }: { message: string; onRetry?: () => void } = $props()
</script>

<div
  role="alert"
  class="flex flex-col items-center gap-3 rounded-lg bg-error-container px-4 py-6 text-center text-sm text-on-error-container"
>
  <p>{message}</p>
  {#if onRetry}
    <button type="button" class={ui.btnNeutral} onclick={onRetry}>다시 시도</button>
  {/if}
</div>
