<script lang="ts">
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import Chip from "#lib/components/ui/Chip.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { createDashboard } from "#lib/queries/admin.js"
  import { createDbHealth, createHealth } from "#lib/queries/health.js"

  // 시스템 상태 — 헬스 체크(GET /health, /health/db) + 대시보드의 DB 상태·Alembic 리비전.
  // (이전 스캐폴드의 /landing "백엔드·DB 연결 상태" 화면이 여기로 옮겨 왔다.)
  const health = createHealth()
  const db = createDbHealth()
  const dashboard = createDashboard()

  type RowState = "loading" | "ok" | "error"
  const stateOf = (q: { isPending: boolean; isError: boolean }, ok: boolean): RowState =>
    q.isPending ? "loading" : !q.isError && ok ? "ok" : "error"

  const refresh = () => {
    void health.refetch()
    void db.refetch()
    void dashboard.refetch()
  }
</script>

<svelte:head>
  <title>시스템 상태 · 관리자 콘솔</title>
</svelte:head>

{#snippet statusRow(label: string, detail: string, state: RowState)}
  <div
    class="flex flex-col gap-2 border-b border-surface-container px-5 py-4 last:border-b-0 sm:flex-row sm:items-center sm:justify-between"
  >
    <div>
      <p class="font-semibold">{label}</p>
      <p class="text-sm break-all text-on-surface-variant">{detail}</p>
    </div>
    {#if state === "loading"}
      <Chip>확인 중…</Chip>
    {:else if state === "ok"}
      <Chip tone="success">정상</Chip>
    {:else}
      <Chip tone="danger">연결 안 됨</Chip>
    {/if}
  </div>
{/snippet}

<PageHeader title="시스템 상태" description="백엔드·데이터베이스 연결과 마이그레이션 상태">
  {#snippet actions()}
    <button type="button" class={ui.btnNeutral} onclick={refresh}>새로고침</button>
  {/snippet}
</PageHeader>
<div class="grid gap-6 xl:grid-cols-2">
  <section aria-labelledby="sys-health" class="{ui.card} rounded-xl">
    <h2 id="sys-health" class="border-b border-surface-container px-5 py-4 text-lg font-semibold">헬스 체크</h2>
    {@render statusRow("백엔드 API", "GET /api/v1/health", stateOf(health, health.data?.status === "ok"))}
    {@render statusRow(
      "데이터베이스",
      db.data ? `GET /api/v1/health/db — ${db.data.table} (${db.data.rows} rows)` : "GET /api/v1/health/db",
      stateOf(db, db.data?.db === "ok"),
    )}
  </section>

  <section aria-labelledby="sys-db" class="{ui.card} rounded-xl">
    <h2 id="sys-db" class="border-b border-surface-container px-5 py-4 text-lg font-semibold">데이터베이스</h2>
    <dl class="divide-y divide-surface-container">
      <div class="flex justify-between gap-4 px-5 py-4">
        <dt class="text-on-surface-variant">상태 (대시보드 집계)</dt>
        <dd>
          {#if dashboard.isPending}
            확인 중…
          {:else if dashboard.data?.db === "ok"}
            <Chip tone="success">정상</Chip>
          {:else}
            <Chip tone="danger">오류</Chip>
          {/if}
        </dd>
      </div>
      <div class="flex justify-between gap-4 px-5 py-4">
        <dt class="text-on-surface-variant">Alembic 리비전</dt>
        <dd class="font-mono text-sm">
          {dashboard.data?.alembic_revision ?? (dashboard.isPending ? "…" : "확인 불가")}
        </dd>
      </div>
      <div class="flex justify-between gap-4 px-5 py-4">
        <dt class="text-on-surface-variant">프론트엔드 빌드</dt>
        <dd class="text-sm">{import.meta.env.MODE}</dd>
      </div>
    </dl>
  </section>
</div>
