<script lang="ts">
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import Chip from "#lib/components/ui/Chip.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Pagination from "#lib/components/ui/Pagination.svelte"
  import SearchForm from "#lib/components/ui/SearchForm.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { formatDate, formatNumber } from "#lib/format.js"
  import { readListParams, searchWith } from "#lib/listParams.js"
  import { createPublicNotices } from "#lib/queries/notices.js"

  // 공개 공지 목록 — 고정 공지 우선, 제목 검색, 페이지 이동(page·q 는 URL 검색 파라미터에).
  const PAGE_SIZE = 10

  const params = $derived(readListParams(page.url.searchParams))
  const notices = createPublicNotices(() => ({ page: params.page, size: PAGE_SIZE, q: params.q }))

  const update = (changes: Record<string, string | number | null>) =>
    goto(`${resolve("notices")}${searchWith(page.url.searchParams, changes)}`, { reset: false })
</script>

<svelte:head>
  <title>공지사항</title>
</svelte:head>

<div class="mx-auto max-w-[960px] px-4 py-10 sm:px-6">
  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
    <div>
      <h1 class="text-2xl font-semibold tracking-tight sm:text-[32px] sm:leading-10">공지사항</h1>
      {#if notices.data}
        <p class="mt-1 text-sm text-on-surface-variant" aria-live="polite">
          {params.q ? `“${params.q}” 검색 결과 ` : "전체 "}{formatNumber(notices.data.total)}건
        </p>
      {/if}
    </div>
    {#key params.q}
      <SearchForm label="공지 제목 검색" initial={params.q} onSearch={(value) => update({ q: value })} />
    {/key}
  </div>

  {#if notices.isPending}
    <Loading />
  {:else if notices.isError}
    <ErrorState message="공지사항을 불러오지 못했습니다." onRetry={() => void notices.refetch()} />
  {:else if notices.data && notices.data.items.length === 0}
    <EmptyState>{params.q ? "검색 결과가 없습니다." : "등록된 공지사항이 없습니다."}</EmptyState>
  {:else if notices.data}
    <ul class="{ui.card} divide-y divide-surface-container">
      {#each notices.data.items as n (n.id)}
        <li class={n.is_pinned ? "bg-surface-container-low" : undefined}>
          <a
            href={resolve(`notices/${n.id}`)}
            class="flex min-h-14 flex-col gap-1 px-4 py-3 hover:bg-surface-container-low sm:flex-row sm:items-center sm:gap-4 sm:px-5 {ui.focusRing} focus-visible:ring-inset"
          >
            <span class="flex min-w-0 flex-1 items-center gap-2">
              {#if n.is_pinned}<Chip tone="primary">고정</Chip>{/if}
              <span class="truncate font-medium text-on-surface">{n.title}</span>
              {#if n.has_attachments}
                <span class="text-on-surface-variant" title="첨부 파일 있음">
                  <Icon name="clip" size={16} />
                  <span class="sr-only">(첨부 파일 있음)</span>
                </span>
              {/if}
            </span>
            <span class="flex shrink-0 gap-3 text-sm text-on-surface-variant">
              <span>{formatDate(n.published_at)}</span>
              <span>조회 {formatNumber(n.view_count)}</span>
            </span>
          </a>
        </li>
      {/each}
    </ul>
  {/if}

  {#if notices.data}
    <div class="mt-6">
      <Pagination page={params.page} size={PAGE_SIZE} total={notices.data.total} onChange={(p) => update({ page: p })} />
    </div>
  {/if}
</div>
