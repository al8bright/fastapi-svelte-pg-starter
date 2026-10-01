<script lang="ts">
  import Icon from "./Icon.svelte"
  import { ui } from "./styles.js"

  // 페이지 이동 — 현재 페이지 주변 최대 5개 번호 + 이전/다음. 한 페이지뿐이면 그리지 않는다.
  interface Props {
    page: number
    size: number
    total: number
    onChange: (page: number) => void
    label?: string
  }

  const { page, size, total, onChange, label = "페이지 이동" }: Props = $props()

  const last = $derived(Math.max(1, Math.ceil(total / size)))
  const pages = $derived.by(() => {
    const start = Math.max(1, Math.min(page - 2, last - 4))
    const end = Math.min(last, start + 4)
    return Array.from({ length: end - start + 1 }, (_, i) => start + i)
  })
  const item = `${ui.btnSmall} min-w-11`
</script>

{#if last > 1}
  <nav aria-label={label} class="flex flex-wrap items-center justify-center gap-1">
    <button
      type="button"
      class="{item} text-on-surface-variant hover:bg-surface-container"
      onclick={() => onChange(page - 1)}
      disabled={page <= 1}
      aria-label="이전 페이지"
    >
      <Icon name="chevronLeft" />
    </button>
    {#each pages as p (p)}
      <button
        type="button"
        class="{item} {p === page ? 'bg-primary text-on-primary' : 'text-on-surface hover:bg-surface-container'}"
        aria-current={p === page ? "page" : undefined}
        aria-label="{p} 페이지"
        onclick={() => onChange(p)}
      >
        {p}
      </button>
    {/each}
    <button
      type="button"
      class="{item} text-on-surface-variant hover:bg-surface-container"
      onclick={() => onChange(page + 1)}
      disabled={page >= last}
      aria-label="다음 페이지"
    >
      <Icon name="chevronRight" />
    </button>
  </nav>
{/if}
