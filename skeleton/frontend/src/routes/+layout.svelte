<script lang="ts">
  import { QueryClientProvider } from "@tanstack/svelte-query"
  import type { Snippet } from "svelte"
  import { queryClient } from "#lib/query-client.js"
  import "../app.css"

  // 부트스트랩 (ARCHITECTURE.md §13): svelte-query Provider 를 최상위에 한 번만 둔다.
  // QueryClient 는 모듈 단일 인스턴스(#lib/query-client) — 세션 만료·로그아웃 시 캐시를 비우기 위해서다.
  const { children }: { children: Snippet } = $props()
</script>

<QueryClientProvider client={queryClient}>
  {@render children()}
</QueryClientProvider>
