<script lang="ts">
  import { afterNavigate } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import RichContent from "#lib/components/RichContent.svelte"
  import Chip from "#lib/components/ui/Chip.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorStatus } from "#lib/apiError.js"
  import { resolveUploadUrl } from "#lib/editor/upload.js"
  import { formatBytes, formatDate, formatNumber } from "#lib/format.js"
  import { createPublicNotice } from "#lib/queries/notices.js"

  // 공개 공지 상세 — 제목·게시일·조회수, 서버가 정화한 본문(RichContent), 첨부 다운로드, 목록으로.
  const noticeId = $derived(Number(page.params.id))
  const valid = $derived(Number.isInteger(noticeId) && noticeId > 0)
  const notice = createPublicNotice(() => noticeId)
  const notFound = $derived(!valid || (notice.isError && apiErrorStatus(notice.error) === 404))

  // 목록에서 왔으면 그 목록(검색어·페이지)으로 돌아간다.
  const listPath = resolve("notices")
  let backHref = $state(listPath)
  afterNavigate(({ from }) => {
    if (from?.url.pathname === listPath) backHref = `${listPath}${from.url.search}`
  })
</script>

<svelte:head>
  <title>{notice.data?.title ?? "공지사항"}</title>
</svelte:head>

{#snippet backLink()}
  <a href={backHref} class={ui.btnNeutral}>
    <Icon name="back" size={16} />
    목록으로
  </a>
{/snippet}

{#if notFound}
  <div class="mx-auto max-w-[960px] px-4 py-16 text-center sm:px-6">
    <h1 class="text-2xl font-semibold">공지사항을 찾을 수 없습니다</h1>
    <p class="mt-3 text-on-surface-variant">삭제되었거나 게시가 중단된 공지입니다.</p>
    <div class="mt-6">{@render backLink()}</div>
  </div>
{:else}
  <div class="mx-auto max-w-[960px] px-4 py-10 sm:px-6">
    {#if notice.isPending}
      <Loading />
    {:else if notice.isError}
      <ErrorState message="공지사항을 불러오지 못했습니다." onRetry={() => void notice.refetch()} />
    {:else if notice.data}
      {@const n = notice.data}
      <article class="{ui.card} rounded-xl">
        <header class="border-b border-surface-container px-5 py-6 sm:px-8">
          {#if n.is_pinned}
            <div class="mb-2"><Chip tone="primary">고정</Chip></div>
          {/if}
          <h1 class="text-2xl leading-8 font-semibold tracking-tight break-words">{n.title}</h1>
          <dl class="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-sm text-on-surface-variant">
            <div class="flex gap-1.5">
              <dt>게시일</dt>
              <dd class="text-on-surface">{formatDate(n.published_at)}</dd>
            </div>
            <div class="flex gap-1.5">
              <dt>조회수</dt>
              <dd class="text-on-surface">{formatNumber(n.view_count)}</dd>
            </div>
          </dl>
        </header>

        <RichContent html={n.body_html} class="px-5 py-8 sm:px-8" />

        {#if n.attachments.length > 0}
          <section aria-labelledby="notice-attachments" class="border-t border-surface-container px-5 py-6 sm:px-8">
            <h2 id="notice-attachments" class="text-base font-semibold">
              첨부 파일 <span class="text-on-surface-variant">({n.attachments.length})</span>
            </h2>
            <ul class="mt-3 flex flex-col gap-2">
              {#each n.attachments as a (a.id)}
                <li>
                  <!-- 공개 다운로드 API(/api/v1/notices/…/attachments/…) — 앱 라우트가 아니라 파일이라 라우터를 거치지 않는다. -->
                  <a
                    href={resolveUploadUrl(a.download_url)}
                    download={a.original_name}
                    data-sveltekit-reload
                    class="flex min-h-11 items-center gap-3 rounded-lg border border-outline-variant px-3 py-2 text-sm hover:bg-surface-container-low {ui.focusRing}"
                  >
                    <Icon name="download" size={16} class="text-primary" />
                    <span class="min-w-0 flex-1 truncate font-medium">{a.original_name}</span>
                    <span class="shrink-0 text-on-surface-variant">{formatBytes(a.size_bytes)}</span>
                    <span class="sr-only">다운로드</span>
                  </a>
                </li>
              {/each}
            </ul>
          </section>
        {/if}
      </article>
    {/if}
    <div class="mt-6">{@render backLink()}</div>
  </div>
{/if}
