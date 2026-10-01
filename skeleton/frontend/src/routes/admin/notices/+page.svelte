<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import Chip from "#lib/components/ui/Chip.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Pagination from "#lib/components/ui/Pagination.svelte"
  import SearchForm from "#lib/components/ui/SearchForm.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { formatDate, formatDateTime, formatNumber } from "#lib/format.js"
  import { readListParams, searchWith } from "#lib/listParams.js"
  import { createAdminNotices } from "#lib/queries/notices.js"

  // 관리자 공지 목록 — 임시저장 포함, 제목 검색·페이지(URL), 게시 상태·고정·첨부 표시.
  const PAGE_SIZE = 20

  const params = $derived(readListParams(page.url.searchParams))
  const notices = createAdminNotices(() => ({ page: params.page, size: PAGE_SIZE, q: params.q }))

  const update = (changes: Record<string, string | number | null>) =>
    goto(`${resolve("admin/notices")}${searchWith(page.url.searchParams, changes)}`, { reset: false })

  const description = $derived(
    notices.data
      ? `${params.q ? `“${params.q}” 검색 결과 ` : "전체 "}${formatNumber(notices.data.total)}건`
      : "공지 작성·게시 관리",
  )
</script>

<svelte:head>
  <title>공지사항 · 관리자 콘솔</title>
</svelte:head>

<PageHeader title="공지사항" {description}>
  {#snippet actions()}
    <a href={resolve("admin/notices/new")} class={ui.btnPrimary}>새 공지</a>
  {/snippet}
</PageHeader>

<div class="mb-4">
  {#key params.q}
    <SearchForm label="공지 제목 검색" initial={params.q} onSearch={(value) => update({ q: value })} />
  {/key}
</div>

{#if notices.isPending}
  <Loading />
{:else if notices.isError}
  <ErrorState message="공지 목록을 불러오지 못했습니다." onRetry={() => void notices.refetch()} />
{:else if notices.data && notices.data.items.length === 0}
  <EmptyState>
    {params.q ? "검색 결과가 없습니다." : "아직 작성한 공지가 없습니다. ‘새 공지’로 시작하세요."}
  </EmptyState>
{:else if notices.data}
  <div class="{ui.card} overflow-x-auto">
    <table class="w-full min-w-[720px] border-collapse">
      <thead>
        <tr>
          <th scope="col" class={ui.th}>제목</th>
          <th scope="col" class={ui.th}>상태</th>
          <th scope="col" class={ui.th}>게시일</th>
          <th scope="col" class="{ui.th} text-right">조회</th>
          <th scope="col" class={ui.th}>작성자</th>
          <th scope="col" class={ui.th}>수정</th>
        </tr>
      </thead>
      <tbody>
        {#each notices.data.items as n (n.id)}
          <tr class="hover:bg-surface-container-low">
            <td class={ui.td}>
              <span class="flex items-center gap-2">
                {#if n.is_pinned}<Chip tone="primary">고정</Chip>{/if}
                <a href={resolve(`admin/notices/${n.id}/edit`)} class="{ui.link} font-medium text-on-surface">{n.title}</a>
                {#if n.has_attachments}
                  <span class="text-on-surface-variant" title="첨부 파일 있음">
                    <Icon name="clip" size={16} />
                    <span class="sr-only">(첨부 파일 있음)</span>
                  </span>
                {/if}
              </span>
            </td>
            <td class={ui.td}>
              {#if n.is_published}<Chip tone="success">게시</Chip>{:else}<Chip>임시저장</Chip>{/if}
            </td>
            <td class="{ui.td} text-on-surface-variant">{formatDate(n.published_at)}</td>
            <td class="{ui.td} text-right text-on-surface-variant">{formatNumber(n.view_count)}</td>
            <td class="{ui.td} text-on-surface-variant">{n.author_username ?? "-"}</td>
            <td class="{ui.td} whitespace-nowrap text-on-surface-variant">{formatDateTime(n.updated_at)}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}
{#if notices.data}
  <div class="mt-6">
    <Pagination page={params.page} size={PAGE_SIZE} total={notices.data.total} onChange={(p) => update({ page: p })} />
  </div>
{/if}
