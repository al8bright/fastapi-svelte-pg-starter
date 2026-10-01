<script lang="ts">
  import type { Snippet } from "svelte"

  // 관리자 화면 머리 — h1 제목 + 설명 + 오른쪽 작업 버튼.
  interface Props {
    title: string
    description?: Snippet | string
    actions?: Snippet
  }

  const { title, description, actions }: Props = $props()
</script>

<div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
  <div class="flex flex-col gap-1">
    <h1 class="text-2xl font-semibold tracking-tight sm:text-[28px]">{title}</h1>
    {#if typeof description === "string"}
      <p class="text-sm text-on-surface-variant">{description}</p>
    {:else if description}
      <p class="text-sm text-on-surface-variant">{@render description()}</p>
    {/if}
  </div>
  {#if actions}
    <div class="flex flex-wrap gap-2">{@render actions()}</div>
  {/if}
</div>
