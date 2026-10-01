<script lang="ts">
  import type { Snippet } from "svelte"
  import { ui } from "./styles.js"

  // 작업 결과 알림(성공·실패). 성공은 role="status", 실패는 role="alert".
  const {
    tone,
    children,
    onClose,
  }: { tone: "success" | "error"; children: Snippet; onClose?: () => void } = $props()

  const color = $derived(
    tone === "success"
      ? "bg-tertiary-container text-on-tertiary-container"
      : "bg-error-container text-on-error-container",
  )
</script>

<div
  role={tone === "error" ? "alert" : "status"}
  class="flex items-start justify-between gap-3 rounded-lg px-4 py-3 text-sm {color}"
>
  <p class="pt-0.5">{@render children()}</p>
  {#if onClose}
    <button
      type="button"
      onclick={onClose}
      class="{ui.btnSmall} -my-2 -mr-2 min-w-11 font-semibold"
      aria-label="알림 닫기"
    >
      ×
    </button>
  {/if}
</div>
