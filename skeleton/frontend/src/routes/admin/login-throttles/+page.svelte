<script lang="ts">
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import Chip from "#lib/components/ui/Chip.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { formatDateTime } from "#lib/format.js"
  import { createLoginThrottles, createUnlockThrottle } from "#lib/queries/admin.js"

  // 로그인 잠금 — 잠긴 계정 우선, 최근 24시간 실패 기록(최대 200). 잠금 해제는 실패 기록을 지운다(멱등).
  // 존재하지 않는 아이디도 기록된다(계정 존재 비노출 정책).
  const throttles = createLoginThrottles()
  const unlock = createUnlockThrottle()
  let message = $state<{ tone: "success" | "error"; text: string } | null>(null)
  const lockedCount = $derived(throttles.data?.filter((t) => t.is_locked).length ?? 0)

  const onUnlock = (username: string, locked: boolean) =>
    unlock.mutate(username, {
      onSuccess: () =>
        (message = {
          tone: "success",
          text: locked ? `${username} 의 잠금을 해제했습니다.` : `${username} 의 실패 기록을 지웠습니다.`,
        }),
      onError: (err) => (message = { tone: "error", text: apiErrorMessage(err) }),
    })
</script>

<svelte:head>
  <title>로그인 잠금 · 관리자 콘솔</title>
</svelte:head>

<PageHeader
  title="로그인 잠금"
  description={throttles.data
    ? `잠김 ${lockedCount}건 · 최근 24시간 실패 기록 ${throttles.data.length}건`
    : "연속 로그인 실패 기록"}
>
  {#snippet actions()}
    <button
      type="button"
      class={ui.btnNeutral}
      onclick={() => void throttles.refetch()}
      disabled={throttles.isFetching}
    >
      {throttles.isFetching ? "새로고침 중…" : "새로고침"}
    </button>
  {/snippet}
</PageHeader>
<div class="flex flex-col gap-4">
  {#if message}
    <Notice tone={message.tone} onClose={() => (message = null)}>{message.text}</Notice>
  {/if}
  {#if throttles.isPending}
    <Loading />
  {:else if throttles.isError}
    <ErrorState message="잠금 목록을 불러오지 못했습니다." onRetry={() => void throttles.refetch()} />
  {:else if throttles.data && throttles.data.length === 0}
    <EmptyState>최근 로그인 실패 기록이 없습니다.</EmptyState>
  {:else if throttles.data}
    <div class="{ui.card} overflow-x-auto">
      <table class="w-full min-w-[640px] border-collapse">
        <thead>
          <tr>
            <th scope="col" class={ui.th}>아이디</th>
            <th scope="col" class={ui.th}>상태</th>
            <th scope="col" class={ui.th}>실패 횟수</th>
            <th scope="col" class={ui.th}>마지막 실패</th>
            <th scope="col" class={ui.th}>잠금 해제 예정</th>
            <th scope="col" class={ui.th}><span class="sr-only">작업</span></th>
          </tr>
        </thead>
        <tbody>
          {#each throttles.data as t (t.username)}
            <tr class={t.is_locked ? "bg-error-container/60" : undefined}>
              <th scope="row" class="{ui.td} text-left font-medium">{t.username}</th>
              <td class={ui.td}>
                {#if t.is_locked}<Chip tone="danger">잠김</Chip>{:else}<Chip>기록만</Chip>{/if}
              </td>
              <td class={ui.td}>{t.failed_count}회</td>
              <td class="{ui.td} text-on-surface-variant">{formatDateTime(t.last_failed_at)}</td>
              <td class="{ui.td} text-on-surface-variant">{t.is_locked ? formatDateTime(t.locked_until) : "-"}</td>
              <td class="{ui.td} text-right">
                <button
                  type="button"
                  class="{ui.btnSmall} {t.is_locked
                    ? 'border border-error bg-surface-container-lowest font-semibold text-on-error-container'
                    : 'text-on-surface-variant hover:bg-surface-container-low'}"
                  disabled={unlock.isPending && unlock.variables === t.username}
                  onclick={() => onUnlock(t.username, t.is_locked)}
                >
                  {t.is_locked ? "잠금 해제" : "기록 지우기"}<span class="sr-only"> ({t.username})</span>
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>
