<script lang="ts">
  import type { Snippet } from "svelte"

  // 빈 목록 안내.
  const { children }: { children: Snippet } = $props()
</script>

<div class="rounded-lg border border-dashed border-outline-variant px-4 py-10 text-center text-sm text-on-surface-variant">
  {@render children()}
</div>
