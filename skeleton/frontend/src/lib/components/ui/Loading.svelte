<script lang="ts">
  // 조회 중 표시.
  const { label = "불러오는 중…" }: { label?: string } = $props()
</script>

<p role="status" class="py-8 text-center text-sm text-on-surface-variant">{label}</p>
