import { createQuery } from "@tanstack/svelte-query"
import { getDbHealth, getHealth } from "#lib/api/health.js"

// svelte-query 쿼리 (ARCHITECTURE.md §13).
export function createHealth() {
  return createQuery(() => ({ queryKey: ["health"], queryFn: getHealth, retry: false }))
}

export function createDbHealth() {
  return createQuery(() => ({ queryKey: ["health", "db"], queryFn: getDbHealth, retry: false }))
}
