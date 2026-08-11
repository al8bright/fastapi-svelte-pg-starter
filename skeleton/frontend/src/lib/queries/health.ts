import { createQuery } from "@tanstack/svelte-query"
import { getDbHealth, getHealth } from "$lib/api/health"

// svelte-query 쿼리 (architecture.md §13).
export function createHealth() {
  return createQuery(() => ({ queryKey: ["health"], queryFn: getHealth, retry: false }))
}

export function createDbHealth() {
  return createQuery(() => ({ queryKey: ["health", "db"], queryFn: getDbHealth, retry: false }))
}
