<script lang="ts">
  import type { Snippet } from "svelte"

  // 인증 가드는 형제 파일 +layout.ts 가 담당한다. 여기서는 자식 라우트만 그린다.
  const { children }: { children: Snippet } = $props()
</script>

{@render children()}
