<script lang="ts">
  import { page } from "$app/state"
  import BannerForm from "#lib/components/admin/BannerForm.svelte"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import ErrorState from "#lib/components/ui/ErrorState.svelte"
  import Loading from "#lib/components/ui/Loading.svelte"
  import { apiErrorMessage, apiErrorStatus } from "#lib/apiError.js"
  import { createAdminBanner } from "#lib/queries/banners.js"

  // 배너 수정 — 상세를 불러온 뒤 폼을 그린다(폼 값은 처음 한 번만 읽으므로 배너가 바뀌면 {#key}).
  const bannerId = $derived(Number(page.params.id))
  const valid = $derived(Number.isInteger(bannerId) && bannerId > 0)
  const banner = createAdminBanner(() => (valid ? bannerId : -1))
</script>

<svelte:head>
  <title>배너 수정 · 관리자 콘솔</title>
</svelte:head>

{#if !valid || (banner.isError && apiErrorStatus(banner.error) === 404)}
  <PageHeader title="배너 수정" />
  <ErrorState message="배너를 찾을 수 없습니다. 이미 삭제되었을 수 있습니다." />
{:else if banner.isError}
  <ErrorState message={apiErrorMessage(banner.error)} onRetry={() => void banner.refetch()} />
{:else if banner.isPending || !banner.data}
  <Loading />
{:else}
  {#key banner.data.id}
    <BannerForm banner={banner.data} />
  {/key}
{/if}
