<script lang="ts">
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import NoticeForm from "#lib/components/admin/NoticeForm.svelte"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage, apiErrorStatus } from "#lib/apiError.js"
  import { createAdminNotice } from "#lib/queries/notices.js"

  // 공지 수정 — 상세를 불러온 뒤 폼을 그린다. 에디터가 비제어라 공지가 바뀌면 {#key} 로 폼을 다시 만든다.
  const noticeId = $derived(Number(page.params.id))
  const valid = $derived(Number.isInteger(noticeId) && noticeId > 0)
  const notice = createAdminNotice(() => (valid ? noticeId : -1))
</script>

<svelte:head>
  <title>공지 수정 · 관리자 콘솔</title>
</svelte:head>

{#if !valid || (notice.isError && apiErrorStatus(notice.error) === 404)}
  <PageHeader title="공지 수정" />
  <ErrorState message="공지를 찾을 수 없습니다. 이미 삭제되었을 수 있습니다." />
  <a href={resolve("admin/notices")} class="{ui.btnNeutral} mt-4">목록으로</a>
{:else if notice.isError}
  <ErrorState message={apiErrorMessage(notice.error)} onRetry={() => void notice.refetch()} />
{:else if notice.isPending || !notice.data}
  <Loading />
{:else}
  {#key notice.data.id}
    <NoticeForm notice={notice.data} />
  {/key}
{/if}
