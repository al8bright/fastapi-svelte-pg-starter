<script lang="ts">
  import { resolve } from "$app/paths"
  import type { BannerAdmin } from "#lib/api/banners.js"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import ConfirmDialog from "#lib/components/ui/ConfirmDialog.svelte"
  import EmptyState from "#lib/components/ui/EmptyState.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { resolveUploadUrl } from "#lib/editor/upload.js"
  import { formatDateTime } from "#lib/format.js"
  import {
    createAdminBanners,
    createDeleteBanner,
    createReorderBanners,
    createToggleBanner,
  } from "#lib/queries/banners.js"

  // 배너 목록 — 썸네일·제목·노출 기간·활성 토글(PUT 전체 본문)·순서 이동(PATCH order)·삭제.
  const banners = createAdminBanners()
  const toggle = createToggleBanner()
  const reorder = createReorderBanners()
  const remove = createDeleteBanner()

  let message = $state<{ tone: "success" | "error"; text: string } | null>(null)
  let deleting = $state<BannerAdmin | null>(null)

  const onError = (err: unknown) => (message = { tone: "error", text: apiErrorMessage(err) })

  function period(b: BannerAdmin): string {
    if (!b.starts_at && !b.ends_at) return "기간 제한 없음"
    return `${b.starts_at ? formatDateTime(b.starts_at) : "처음부터"} ~ ${b.ends_at ? formatDateTime(b.ends_at) : "계속"}`
  }

  const move = (list: BannerAdmin[], index: number, delta: -1 | 1) => {
    const ids = list.map((b) => b.id)
    const target = index + delta
    if (target < 0 || target >= ids.length) return
    ;[ids[index], ids[target]] = [ids[target], ids[index]]
    const title = list[index].title
    reorder.mutate(ids, {
      onSuccess: () => (message = { tone: "success", text: `“${title}” 의 순서를 바꿨습니다.` }),
      onError,
    })
  }

  const confirmDelete = () => {
    const target = deleting
    if (!target) return
    remove.mutate(target.id, {
      onSuccess: () => (message = { tone: "success", text: `“${target.title}” 배너를 삭제했습니다.` }),
      onError,
      onSettled: () => (deleting = null),
    })
  }
</script>

<svelte:head>
  <title>배너 · 관리자 콘솔</title>
</svelte:head>

<PageHeader title="배너" description="홈 화면 캐러셀에 노출 순서대로 보입니다. 활성이고 노출 기간 안인 배너만 보입니다.">
  {#snippet actions()}
    <a href={resolve("admin/banners/new")} class={ui.btnPrimary}>새 배너</a>
  {/snippet}
</PageHeader>

<div class="flex flex-col gap-4">
  {#if message}
    <Notice tone={message.tone} onClose={() => (message = null)}>{message.text}</Notice>
  {/if}
  {#if banners.isPending}
    <Loading />
  {:else if banners.isError}
    <ErrorState message="배너 목록을 불러오지 못했습니다." onRetry={() => void banners.refetch()} />
  {:else if banners.data && banners.data.length === 0}
    <EmptyState>등록된 배너가 없습니다. 배너가 없으면 홈 화면에 기본 히어로가 보입니다.</EmptyState>
  {:else if banners.data}
    {@const list = banners.data}
    <ol class="flex flex-col gap-3" aria-label="배너 노출 순서">
      {#each list as b, i (b.id)}
        <li class="{ui.card} flex flex-col gap-3 p-3 sm:flex-row sm:items-center">
          <img
            src={resolveUploadUrl(b.image_url)}
            alt=""
            width={b.image_width}
            height={b.image_height}
            loading="lazy"
            class="aspect-[3/1] w-full rounded bg-surface object-cover sm:w-40"
          />
          <div class="flex min-w-0 flex-1 flex-col gap-1">
            <span class="flex items-center gap-2">
              <span class="text-xs font-semibold text-on-surface-variant">{i + 1}</span>
              <a href={resolve(`admin/banners/${b.id}/edit`)} class="{ui.link} truncate font-medium text-on-surface">
                {b.title}
              </a>
            </span>
            <span class="text-sm text-on-surface-variant">{period(b)}</span>
            {#if b.link_url}
              <span class="truncate text-sm text-on-surface-variant">링크: {b.link_url}</span>
            {/if}
          </div>
          <div class="flex flex-wrap items-center gap-1">
            <button
              type="button"
              role="switch"
              aria-checked={b.is_active}
              aria-label="{b.title} 활성"
              onclick={() => toggle.mutate(b, { onError })}
              class="{ui.btnSmall} gap-2 text-on-surface hover:bg-surface-container-low"
            >
              <span
                aria-hidden="true"
                class="relative inline-block h-6 w-10 rounded-full transition-colors {b.is_active ? 'bg-primary' : 'bg-outline'}"
              >
                <span
                  class="absolute top-0.5 size-5 rounded-full bg-surface-container-lowest transition-all {b.is_active
                    ? 'left-[18px]'
                    : 'left-0.5'}"
                ></span>
              </span>
              {b.is_active ? "활성" : "비활성"}
            </button>
            <button
              type="button"
              class="{ui.btnSmall} min-w-11 text-on-surface-variant hover:bg-surface-container-low"
              onclick={() => move(list, i, -1)}
              disabled={i === 0 || reorder.isPending}
              aria-label="{b.title} 위로 이동"
            >
              <Icon name="up" />
            </button>
            <button
              type="button"
              class="{ui.btnSmall} min-w-11 text-on-surface-variant hover:bg-surface-container-low"
              onclick={() => move(list, i, 1)}
              disabled={i === list.length - 1 || reorder.isPending}
              aria-label="{b.title} 아래로 이동"
            >
              <Icon name="down" />
            </button>
            <a href={resolve(`admin/banners/${b.id}/edit`)} class="{ui.btnSmall} text-primary hover:bg-primary-fixed">
              수정<span class="sr-only"> ({b.title})</span>
            </a>
            <button
              type="button"
              class="{ui.btnSmall} text-error hover:bg-error-container"
              onclick={() => (deleting = b)}
            >
              삭제<span class="sr-only"> ({b.title})</span>
            </button>
          </div>
        </li>
      {/each}
    </ol>
  {/if}
</div>

{#if deleting}
  {@const target = deleting}
  <ConfirmDialog
    title="배너를 삭제할까요?"
    confirmLabel="삭제"
    danger
    pending={remove.isPending}
    onConfirm={confirmDelete}
    onCancel={() => (deleting = null)}
  >
    “{target.title}” 배너와 이미지가 삭제되며 되돌릴 수 없습니다.
  </ConfirmDialog>
{/if}
