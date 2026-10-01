<script lang="ts">
  import { resolve } from "$app/paths"
  import type { AdminSession, Dashboard } from "#lib/api/admin.js"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import ConfirmDialog from "#lib/components/ui/ConfirmDialog.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { formatDateTime, formatNumber } from "#lib/format.js"
  import {
    createAdminSessions,
    createDashboard,
    createLoginThrottles,
    createRevokeSession,
    createUnlockThrottle,
  } from "#lib/queries/admin.js"

  // 대시보드 (디자인 A) — KPI 타일 + 최근 활성 세션 5건(강제 종료) + 잠긴 계정(잠금 해제).
  interface Kpi {
    label: string
    value: string
    sub: string
    tone?: "primary" | "danger" | "success"
  }

  const KPI_COLOR = { primary: "text-primary", danger: "text-error", success: "text-tertiary" } as const

  const dashboard = createDashboard()
  const sessions = createAdminSessions(() => ({ page: 1, size: 5 }))
  const throttles = createLoginThrottles()
  const revoke = createRevokeSession()
  const unlock = createUnlockThrottle()

  let message = $state<{ tone: "success" | "error"; text: string } | null>(null)
  let target = $state<AdminSession | null>(null)

  const locked = $derived(throttles.data?.filter((t) => t.is_locked) ?? [])

  function kpisOf(data: Dashboard): Kpi[] {
    return [
      {
        label: "전체 사용자",
        value: formatNumber(data.users.total),
        sub: `활성 ${formatNumber(data.users.active)} · 비활성 ${formatNumber(data.users.inactive)}`,
      },
      { label: "활성 세션", value: formatNumber(data.active_sessions), sub: "만료·폐기 전 refresh 세션", tone: "primary" },
      {
        label: "잠긴 계정",
        value: formatNumber(data.locked_accounts),
        sub: data.locked_accounts ? "자동 해제 대기" : "잠긴 계정 없음",
        tone: data.locked_accounts ? "danger" : undefined,
      },
      {
        label: "공지사항",
        value: formatNumber(data.notices.published),
        sub: `게시 중 · 임시저장 ${formatNumber(data.notices.draft)}`,
      },
      { label: "활성 배너", value: formatNumber(data.active_banners), sub: "활성 + 노출 기간 안" },
      {
        label: "DB 상태",
        value: data.db === "ok" ? "정상" : "오류",
        sub: `마이그레이션 ${data.alembic_revision ?? "확인 불가"}`,
        tone: data.db === "ok" ? "success" : "danger",
      },
    ]
  }

  const refresh = () => {
    void dashboard.refetch()
    void sessions.refetch()
    void throttles.refetch()
  }

  const confirmRevoke = () => {
    const s = target
    if (!s) return
    revoke.mutate(s.id, {
      onSuccess: () => (message = { tone: "success", text: `${s.username} 의 세션을 종료했습니다.` }),
      onError: (e) => (message = { tone: "error", text: apiErrorMessage(e) }),
      onSettled: () => (target = null),
    })
  }

  const onUnlock = (username: string) =>
    unlock.mutate(username, {
      onSuccess: () => (message = { tone: "success", text: `${username} 의 잠금을 해제했습니다.` }),
      onError: (e) => (message = { tone: "error", text: apiErrorMessage(e) }),
    })
</script>

<svelte:head>
  <title>대시보드 · 관리자 콘솔</title>
</svelte:head>

<PageHeader title="대시보드" description="시스템 상태와 인증 현황">
  {#snippet actions()}
    <button type="button" class={ui.btnNeutral} onclick={refresh} disabled={dashboard.isFetching}>
      {dashboard.isFetching ? "새로고침 중…" : "새로고침"}
    </button>
  {/snippet}
</PageHeader>

<div class="flex flex-col gap-6">
  {#if message}
    <Notice tone={message.tone} onClose={() => (message = null)}>{message.text}</Notice>
  {/if}

  {#if dashboard.isPending}
    <Loading />
  {:else if dashboard.isError}
    <ErrorState message="대시보드 집계를 불러오지 못했습니다." onRetry={() => void dashboard.refetch()} />
  {:else if dashboard.data}
    <div class="grid grid-cols-1 gap-4 min-[420px]:grid-cols-2 md:grid-cols-3 2xl:grid-cols-6">
      {#each kpisOf(dashboard.data) as k (k.label)}
        <section class="{ui.card} flex flex-col gap-2 rounded-xl p-5">
          <h2 class="text-sm font-medium text-on-surface-variant">{k.label}</h2>
          <p class="text-3xl font-bold {k.tone ? KPI_COLOR[k.tone] : 'text-on-surface'}">{k.value}</p>
          <p class="text-[13px] text-on-surface-variant">{k.sub}</p>
        </section>
      {/each}
    </div>
  {/if}

  <div class="grid gap-4 xl:grid-cols-3">
    <section aria-labelledby="dash-sessions" class="{ui.card} flex min-w-0 flex-col gap-3 rounded-xl p-5 xl:col-span-2">
      <div class="flex items-center justify-between">
        <h2 id="dash-sessions" class="text-lg font-semibold">활성 세션</h2>
        <a href={resolve("admin/sessions")} class="{ui.link} text-sm font-medium">전체 보기</a>
      </div>
      {#if sessions.isPending}
        <Loading />
      {:else if sessions.isError}
        <ErrorState message="세션 목록을 불러오지 못했습니다." onRetry={() => void sessions.refetch()} />
      {:else if sessions.data && sessions.data.items.length === 0}
        <EmptyState>활성 세션이 없습니다.</EmptyState>
      {:else if sessions.data}
        <div class="overflow-x-auto">
          <table class="w-full min-w-[520px] border-collapse">
            <thead>
              <tr>
                <th scope="col" class={ui.th}>사용자</th>
                <th scope="col" class={ui.th}>로그인</th>
                <th scope="col" class={ui.th}>마지막 사용</th>
                <th scope="col" class={ui.th}>만료</th>
                <th scope="col" class={ui.th}><span class="sr-only">작업</span></th>
              </tr>
            </thead>
            <tbody>
              {#each sessions.data.items as s (s.id)}
                <tr>
                  <td class="{ui.td} font-medium">{s.username}</td>
                  <td class="{ui.td} text-on-surface-variant">{formatDateTime(s.created_at)}</td>
                  <td class="{ui.td} text-on-surface-variant">{formatDateTime(s.last_used_at)}</td>
                  <td class="{ui.td} text-on-surface-variant">{formatDateTime(s.expires_at)}</td>
                  <td class="{ui.td} text-right">
                    <button
                      type="button"
                      class="{ui.btnSmall} border border-error text-error hover:bg-error-container"
                      onclick={() => (target = s)}
                    >
                      강제 종료<span class="sr-only"> ({s.username})</span>
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </section>

    <section aria-labelledby="dash-locks" class="{ui.card} flex flex-col gap-3 rounded-xl p-5">
      <div class="flex items-center justify-between">
        <h2 id="dash-locks" class="text-lg font-semibold">로그인 잠금</h2>
        <a href={resolve("admin/login-throttles")} class="{ui.link} text-sm font-medium">전체 보기</a>
      </div>
      <p class="text-[13px] text-on-surface-variant">연속 실패 횟수가 기준을 넘으면 일정 시간 로그인이 잠깁니다.</p>
      {#if throttles.isPending}
        <Loading />
      {:else if throttles.isError}
        <ErrorState message="잠금 목록을 불러오지 못했습니다." onRetry={() => void throttles.refetch()} />
      {:else if locked.length === 0}
        <EmptyState>잠긴 계정이 없습니다.</EmptyState>
      {:else}
        <ul class="flex flex-col gap-2">
          {#each locked as t (t.username)}
            <li class="flex items-center gap-3 rounded-[10px] bg-error-container p-3 text-on-error-container">
              <div class="flex min-w-0 flex-1 flex-col gap-0.5">
                <span class="truncate text-sm font-semibold">{t.username}</span>
                <span class="text-xs">실패 {t.failed_count}회 · {formatDateTime(t.locked_until)}까지</span>
              </div>
              <button
                type="button"
                class="{ui.btnSmall} bg-surface-container-lowest font-semibold text-on-error-container"
                disabled={unlock.isPending && unlock.variables === t.username}
                onclick={() => onUnlock(t.username)}
              >
                잠금 해제<span class="sr-only"> ({t.username})</span>
              </button>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  </div>
</div>

{#if target}
  {@const s = target}
  <ConfirmDialog
    title="세션을 강제 종료할까요?"
    confirmLabel="강제 종료"
    danger
    pending={revoke.isPending}
    onConfirm={confirmRevoke}
    onCancel={() => (target = null)}
  >
    {s.username} 의 세션(#{s.id})이 즉시 끊기고 다시 로그인해야 합니다. 내 세션이면 나도 로그아웃됩니다.
  </ConfirmDialog>
{/if}
