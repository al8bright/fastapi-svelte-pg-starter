<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import type { AdminSession } from "#lib/api/admin.js"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import ConfirmDialog from "#lib/components/ui/ConfirmDialog.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import Pagination from "#lib/components/ui/Pagination.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { formatDateTime, formatNumber } from "#lib/format.js"
  import { readListParams, searchWith } from "#lib/listParams.js"
  import { createAdminSessions, createRevokeSession } from "#lib/queries/admin.js"

  // 활성 세션 — 최근 사용순, 페이지, 사용자 필터(?user_id= — 사용자 화면의 세션 수 링크), 강제 종료.
  const PAGE_SIZE = 20

  const params = $derived(readListParams(page.url.searchParams))
  const userId = $derived.by(() => {
    const raw = Number(page.url.searchParams.get("user_id"))
    return Number.isInteger(raw) && raw > 0 ? raw : undefined
  })
  const sessions = createAdminSessions(() => ({ page: params.page, size: PAGE_SIZE, user_id: userId }))
  const revoke = createRevokeSession()

  let target = $state<AdminSession | null>(null)
  let message = $state<{ tone: "success" | "error"; text: string } | null>(null)

  const filteredName = $derived(userId ? (sessions.data?.items[0]?.username ?? `#${userId}`) : null)

  const update = (changes: Record<string, string | number | null>) =>
    goto(`${resolve("admin/sessions")}${searchWith(page.url.searchParams, changes)}`, { reset: false })

  const confirm = () => {
    const s = target
    if (!s) return
    revoke.mutate(s.id, {
      onSuccess: () => (message = { tone: "success", text: `${s.username} 의 세션 #${s.id} 을(를) 종료했습니다.` }),
      onError: (err) => (message = { tone: "error", text: apiErrorMessage(err) }),
      onSettled: () => (target = null),
    })
  }
</script>

<svelte:head>
  <title>세션 · 관리자 콘솔</title>
</svelte:head>

<PageHeader
  title="세션"
  description={sessions.data ? `활성 세션 ${formatNumber(sessions.data.total)}개 · 최근 사용순` : "만료·폐기 전 로그인 세션"}
/>
<div class="flex flex-col gap-4">
  {#if userId}
    <div class="flex flex-wrap items-center gap-3 rounded-lg bg-primary-fixed px-4 py-2 text-sm text-on-primary-fixed">
      <span>사용자 <strong>{filteredName}</strong> 의 세션만 보는 중</span>
      <button type="button" class="{ui.btnSmall} font-semibold underline" onclick={() => update({ user_id: null })}>
        필터 해제
      </button>
    </div>
  {/if}
  {#if message}
    <Notice tone={message.tone} onClose={() => (message = null)}>{message.text}</Notice>
  {/if}
  {#if sessions.isPending}
    <Loading />
  {:else if sessions.isError}
    <ErrorState message="세션 목록을 불러오지 못했습니다." onRetry={() => void sessions.refetch()} />
  {:else if sessions.data && sessions.data.items.length === 0}
    <EmptyState>활성 세션이 없습니다.</EmptyState>
  {:else if sessions.data}
    <div class="{ui.card} overflow-x-auto">
      <table class="w-full min-w-[680px] border-collapse">
        <thead>
          <tr>
            <th scope="col" class={ui.th}>세션</th>
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
              <td class="{ui.td} text-on-surface-variant">#{s.id}</td>
              <td class={ui.td}>
                <button
                  type="button"
                  class="{ui.link} font-medium text-on-surface"
                  onclick={() => update({ user_id: s.user_id })}
                >
                  {s.username}<span class="sr-only"> 의 세션만 보기</span>
                </button>
              </td>
              <td class="{ui.td} text-on-surface-variant">{formatDateTime(s.created_at)}</td>
              <td class="{ui.td} text-on-surface-variant">{formatDateTime(s.last_used_at)}</td>
              <td class="{ui.td} text-on-surface-variant">{formatDateTime(s.expires_at)}</td>
              <td class="{ui.td} text-right">
                <button
                  type="button"
                  class="{ui.btnSmall} border border-error text-error hover:bg-error-container"
                  onclick={() => (target = s)}
                >
                  강제 종료<span class="sr-only"> (세션 #{s.id}, {s.username})</span>
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
  {#if sessions.data}
    <Pagination page={params.page} size={PAGE_SIZE} total={sessions.data.total} onChange={(p) => update({ page: p })} />
  {/if}
</div>

{#if target}
  {@const s = target}
  <ConfirmDialog
    title="세션을 강제 종료할까요?"
    confirmLabel="강제 종료"
    danger
    pending={revoke.isPending}
    onConfirm={confirm}
    onCancel={() => (target = null)}
  >
    {s.username} 의 세션 #{s.id} 이(가) 즉시 끊기고 다시 로그인해야 합니다. 내 세션이면 나도 로그아웃됩니다.
  </ConfirmDialog>
{/if}
