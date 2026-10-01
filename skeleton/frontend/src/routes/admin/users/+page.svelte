<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import type { AdminUser, AdminUserUpdate } from "#lib/api/admin.js"
  import type { UserRole } from "#lib/api/auth.js"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import Chip from "#lib/components/ui/Chip.svelte"
  import ConfirmDialog from "#lib/components/ui/ConfirmDialog.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import Pagination from "#lib/components/ui/Pagination.svelte"
  import SearchForm from "#lib/components/ui/SearchForm.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { formatDate, formatNumber } from "#lib/format.js"
  import { readListParams, searchWith } from "#lib/listParams.js"
  import { createAdminUsers, createRevokeUserSessions, createUpdateUser } from "#lib/queries/admin.js"
  import { createMe } from "#lib/queries/auth.js"

  // 사용자 관리 — 검색·역할 필터·페이지(URL), 권한·활성 변경(확인 후 PATCH), 세션 모두 종료.
  // 자기 자신 변경(409 self_modification)·마지막 관리자 보호(409 last_admin)는 서버가 거부하고 문구로 안내한다.
  const PAGE_SIZE = 20
  const ROLE_LABEL: Record<UserRole, string> = { admin: "관리자", user: "일반 사용자" }

  type Pending =
    | { kind: "update"; user: AdminUser; body: AdminUserUpdate; title: string; description: string }
    | { kind: "revoke"; user: AdminUser }

  const params = $derived(readListParams(page.url.searchParams))
  const role = $derived.by((): UserRole | undefined => {
    const r = page.url.searchParams.get("role")
    return r === "admin" || r === "user" ? r : undefined
  })
  const users = createAdminUsers(() => ({ page: params.page, size: PAGE_SIZE, q: params.q, role }))
  const me = createMe()
  const updateUser = createUpdateUser()
  const revoke = createRevokeUserSessions()

  let pending = $state.raw<Pending | null>(null)
  let message = $state<{ tone: "success" | "error"; text: string } | null>(null)
  const roleFilterId = $props.id()

  const update = (changes: Record<string, string | number | null>) =>
    goto(`${resolve("admin/users")}${searchWith(page.url.searchParams, changes)}`, { reset: false })

  const askRole = (user: AdminUser, next: UserRole) => {
    pending = {
      kind: "update",
      user,
      body: { role: next },
      title: `${user.username} 의 권한을 바꿀까요?`,
      description: `${ROLE_LABEL[user.role]} → ${ROLE_LABEL[next]}. ${
        next === "admin" ? "관리자 콘솔의 모든 기능을 쓸 수 있게 됩니다." : "관리자 콘솔에 더 이상 들어올 수 없습니다."
      }`,
    }
  }

  const askActive = (user: AdminUser) => {
    pending = {
      kind: "update",
      user,
      body: { is_active: !user.is_active },
      title: user.is_active ? `${user.username} 을(를) 비활성화할까요?` : `${user.username} 을(를) 다시 활성화할까요?`,
      description: user.is_active
        ? "로그인할 수 없게 되고 살아 있는 세션이 모두 종료됩니다."
        : "다시 로그인할 수 있게 됩니다.",
    }
  }

  const confirm = () => {
    const p = pending
    if (!p) return
    const onSettled = () => (pending = null)
    const onError = (err: unknown) => (message = { tone: "error", text: apiErrorMessage(err) })
    if (p.kind === "update") {
      updateUser.mutate(
        { id: p.user.id, body: p.body },
        { onSettled, onError, onSuccess: () => (message = { tone: "success", text: `${p.user.username} 의 정보를 바꿨습니다.` }) },
      )
    } else {
      revoke.mutate(p.user.id, {
        onSettled,
        onError,
        onSuccess: (r) => (message = { tone: "success", text: `${p.user.username} 의 세션 ${r.revoked}개를 종료했습니다.` }),
      })
    }
  }
</script>

<svelte:head>
  <title>사용자 · 관리자 콘솔</title>
</svelte:head>

<PageHeader title="사용자" description={users.data ? `${formatNumber(users.data.total)}명` : "계정 권한·활성 상태 관리"} />
<div class="mb-4 flex flex-col gap-3 sm:flex-row sm:items-end">
  {#key params.q}
    <SearchForm label="아이디 검색" initial={params.q} onSearch={(value) => update({ q: value })} />
  {/key}
  <div class="sm:w-44">
    <label for={roleFilterId} class="sr-only">권한 필터</label>
    <select
      id={roleFilterId}
      value={role ?? ""}
      onchange={(e) => update({ role: e.currentTarget.value })}
      class="{ui.input} mt-0"
    >
      <option value="">모든 권한</option>
      <option value="admin">관리자</option>
      <option value="user">일반 사용자</option>
    </select>
  </div>
</div>

<div class="flex flex-col gap-4">
  {#if message}
    <Notice tone={message.tone} onClose={() => (message = null)}>{message.text}</Notice>
  {/if}
  {#if users.isPending}
    <Loading />
  {:else if users.isError}
    <ErrorState message="사용자 목록을 불러오지 못했습니다." onRetry={() => void users.refetch()} />
  {:else if users.data && users.data.items.length === 0}
    <EmptyState>조건에 맞는 사용자가 없습니다.</EmptyState>
  {:else if users.data}
    <div class="{ui.card} overflow-x-auto">
      <table class="w-full min-w-[760px] border-collapse">
        <thead>
          <tr>
            <th scope="col" class={ui.th}>아이디</th>
            <th scope="col" class={ui.th}>권한</th>
            <th scope="col" class={ui.th}>상태</th>
            <th scope="col" class={ui.th}>가입일</th>
            <th scope="col" class={ui.th}>활성 세션</th>
            <th scope="col" class={ui.th}><span class="sr-only">작업</span></th>
          </tr>
        </thead>
        <tbody>
          {#each users.data.items as u (u.id)}
            {@const isMe = me.data?.id === u.id}
            <tr>
              <th scope="row" class="{ui.td} text-left font-medium">
                {u.username}
                {#if isMe}<span class="ml-1 text-xs text-on-surface-variant">(나)</span>{/if}
              </th>
              <td class={ui.td}>
                <label class="sr-only" for="role-{u.id}">{u.username} 권한</label>
                <!-- 값은 서버 상태를 그대로 보여 준다 — 고르면 원래 값으로 되돌려 두고 확인 후 PATCH(성공하면 목록이 새 값으로 다시 그려진다). -->
                <select
                  id="role-{u.id}"
                  value={u.role}
                  onchange={(e) => {
                    const next = e.currentTarget.value as UserRole
                    e.currentTarget.value = u.role
                    askRole(u, next)
                  }}
                  class="{ui.input} mt-0 w-36"
                >
                  <option value="user">일반 사용자</option>
                  <option value="admin">관리자</option>
                </select>
              </td>
              <td class={ui.td}>
                {#if u.is_active}<Chip tone="success">활성</Chip>{:else}<Chip tone="danger">비활성</Chip>{/if}
              </td>
              <td class="{ui.td} text-on-surface-variant">{formatDate(u.created_at)}</td>
              <td class={ui.td}>
                <a href={resolve(`admin/sessions?user_id=${u.id}`)} class={ui.link}>
                  {u.active_session_count}개<span class="sr-only"> ({u.username} 세션 보기)</span>
                </a>
              </td>
              <td class="{ui.td} text-right whitespace-nowrap">
                <button
                  type="button"
                  class="{ui.btnSmall} {u.is_active
                    ? 'text-error hover:bg-error-container'
                    : 'text-primary hover:bg-primary-fixed'}"
                  onclick={() => askActive(u)}
                >
                  {u.is_active ? "비활성화" : "활성화"}<span class="sr-only"> ({u.username})</span>
                </button>
                <button
                  type="button"
                  class="{ui.btnSmall} text-error hover:bg-error-container"
                  onclick={() => (pending = { kind: "revoke", user: u })}
                  disabled={u.active_session_count === 0}
                >
                  세션 모두 종료<span class="sr-only"> ({u.username})</span>
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
  {#if users.data}
    <Pagination page={params.page} size={PAGE_SIZE} total={users.data.total} onChange={(p) => update({ page: p })} />
  {/if}
</div>

{#if pending?.kind === "update"}
  {@const p = pending}
  <ConfirmDialog
    title={p.title}
    confirmLabel="변경"
    danger={p.body.is_active === false || p.body.role === "user"}
    pending={updateUser.isPending}
    onConfirm={confirm}
    onCancel={() => (pending = null)}
  >
    {p.description}
  </ConfirmDialog>
{:else if pending?.kind === "revoke"}
  {@const p = pending}
  <ConfirmDialog
    title="{p.user.username} 의 세션을 모두 종료할까요?"
    confirmLabel="모두 종료"
    danger
    pending={revoke.isPending}
    onConfirm={confirm}
    onCancel={() => (pending = null)}
  >
    모든 기기에서 즉시 로그아웃됩니다. 계정은 그대로이며 다시 로그인할 수 있습니다.
  </ConfirmDialog>
{/if}
