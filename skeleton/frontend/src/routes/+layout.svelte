<script lang="ts">
  import { QueryClient, QueryClientProvider } from "@tanstack/svelte-query"
  import type { Snippet } from "svelte"
  import "../app.css"

  // 부트스트랩 (architecture.md §13): svelte-query Provider 를 최상위에 한 번만 둔다.
  const { children }: { children: Snippet } = $props()

  const queryClient = new QueryClient()
</script>

<QueryClientProvider client={queryClient}>
  {@render children()}
</QueryClientProvider>
