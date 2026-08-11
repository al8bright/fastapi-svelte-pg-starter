<script lang="ts">
  import { resolve } from "$app/paths"
  import { createDbHealth, createHealth } from "$lib/queries/health"

  // 랜딩(시스템 상태) 화면 (architecture.md §14). 백엔드 / DB 연결 상태를 보여 준다.
  const health = createHealth()
  const dbHealth = createDbHealth()
</script>

<!-- 원본의 StatusBadge 컴포넌트 대응 — 파일을 늘리지 않고 snippet 으로 둔다. -->
{#snippet statusBadge(label: string, ok: boolean, loading: boolean, detail: string)}
  {@const text = loading ? "확인 중…" : ok ? "정상" : "연결 안 됨"}
  {@const tone = loading
    ? "bg-surface-container text-on-surface-variant"
    : ok
      ? "bg-tertiary-container text-on-tertiary-container"
      : "bg-error-container text-on-error-container"}
  <div
    class="flex items-center justify-between rounded-lg border border-outline-variant bg-surface-container-lowest px-5 py-4"
  >
    <div>
      <p class="font-semibold text-on-surface">{label}</p>
      <p class="text-sm text-on-surface-variant">{detail}</p>
    </div>
    <span class="rounded-full px-3 py-1 text-sm font-semibold {tone}">{text}</span>
  </div>
{/snippet}

<main class="flex min-h-screen flex-col items-center justify-center bg-surface px-4">
  <div class="w-full max-w-xl">
    <header class="mb-8 text-center">
      <span class="inline-block rounded-full bg-primary px-4 py-1 text-sm font-semibold text-on-primary">
        __PROJECT_NAME__
      </span>
      <h1 class="mt-4 text-4xl font-bold tracking-tight text-on-surface">
        프로젝트 스캐폴드 완료 🎉
      </h1>
      <p class="mt-3 text-on-surface-variant">
        공통 아키텍처(FastAPI · Svelte · PostgreSQL) 기반 스타터입니다.
        아래에서 백엔드/DB 연결 상태를 확인하세요.
      </p>
    </header>

    <div class="space-y-3">
      {@render statusBadge(
        "백엔드 API",
        health.isSuccess && health.data?.status === "ok",
        health.isPending,
        "GET /api/v1/health",
      )}
      {@render statusBadge(
        "데이터베이스",
        dbHealth.isSuccess && dbHealth.data?.db === "ok",
        dbHealth.isPending,
        dbHealth.isSuccess
          ? `GET /api/v1/health/db — ${dbHealth.data.table} (${dbHealth.data.rows} rows)`
          : "GET /api/v1/health/db",
      )}
    </div>

    <footer class="mt-8 text-center text-sm text-on-surface-variant">
      다음 단계: <code class="font-mono">plan.md</code> 순서대로 TDD 로 개발을 시작하세요.
      <a href={resolve("/")} class="mt-3 block text-on-surface-variant hover:text-on-surface">
        ← 메인으로
      </a>
    </footer>
  </div>
</main>
