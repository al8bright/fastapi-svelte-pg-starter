<script lang="ts">
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import BannerCarousel from "#lib/components/BannerCarousel.svelte"
  import HomeHero from "#lib/components/HomeHero.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { formatDate } from "#lib/format.js"
  import { createMe } from "#lib/queries/auth.js"
  import { createPublicBanners } from "#lib/queries/banners.js"
  import { createPublicNotices } from "#lib/queries/notices.js"
  import { loginWithNext } from "#lib/returnTo.js"
  import { SITE_NAME } from "#lib/site.js"
  import { authStore } from "#lib/stores/auth.svelte.js"

  // 공개 첫 화면 (디자인 A). 배너(없으면 히어로) → 주요 서비스 → 최신 공지 5건 + 내 계정.
  // 자리표시 내비(/#services 등)는 SvelteKit 이 해시 위치로 스크롤해 준다.

  // 자리표시 서비스 카드 — 프로젝트에 맞게 바꾼다.
  const SERVICES = [
    { title: "[서비스 1]", body: "[서비스 1 설명 — 한두 문장]" },
    { title: "[서비스 2]", body: "[서비스 2 설명 — 한두 문장]" },
    { title: "[서비스 3]", body: "[서비스 3 설명 — 한두 문장]" },
  ]

  const banners = createPublicBanners()
  const notices = createPublicNotices(() => ({ page: 1, size: 5 }))
  const me = createMe()
  const loginHref = $derived(loginWithNext(resolve("login"), `${page.url.pathname}${page.url.search}`))
</script>

<svelte:head>
  <title>{SITE_NAME}</title>
</svelte:head>

{#if banners.isPending}
  <!-- 첫 로딩 동안은 같은 높이의 자리만 잡는다(히어로 → 배너로 번쩍 바뀌지 않게). -->
  <div class="h-[420px] bg-surface-container-low" aria-hidden="true"></div>
{:else if !banners.data?.length}
  <!-- 배너가 없거나 조회에 실패하면 기본 히어로. -->
  <HomeHero />
{:else}
  <div class="mx-auto max-w-[1200px] px-4 pt-6 sm:px-6">
    <h1 class="sr-only">{SITE_NAME}</h1>
    <BannerCarousel banners={banners.data} />
  </div>
{/if}

<section
  id="services"
  aria-labelledby="home-services"
  class="mx-auto flex max-w-[1200px] scroll-mt-4 flex-col gap-6 px-4 py-12 sm:px-6"
>
  <div class="flex items-end justify-between">
    <h2 id="home-services" class="text-2xl font-semibold">주요 서비스</h2>
  </div>
  <div class="grid gap-5 md:grid-cols-3">
    {#each SERVICES as card (card.title)}
      <article class="{ui.card} flex flex-col gap-3 rounded-xl p-6">
        <span class="flex size-10 items-center justify-center rounded-[10px] bg-primary-fixed text-primary">
          <Icon name="card" size={20} />
        </span>
        <h3 class="text-lg font-semibold">{card.title}</h3>
        <p class="text-[15px] leading-6 text-on-surface-variant">{card.body}</p>
      </article>
    {/each}
  </div>
</section>

<div class="mx-auto grid max-w-[1200px] gap-5 px-4 pb-14 sm:px-6 md:grid-cols-2">
  <section aria-labelledby="home-notices" class="{ui.card} flex flex-col gap-3 rounded-xl p-6">
    <div class="flex items-center justify-between">
      <h2 id="home-notices" class="text-lg font-semibold">공지사항</h2>
      <a href={resolve("notices")} class="{ui.link} text-sm font-medium">전체 보기</a>
    </div>
    {#if notices.isPending}
      <p class="py-3 text-sm text-on-surface-variant">불러오는 중…</p>
    {:else if notices.isError}
      <p class="py-3 text-sm text-on-surface-variant">공지사항을 불러오지 못했습니다.</p>
    {:else if notices.data && notices.data.items.length === 0}
      <p class="py-3 text-sm text-on-surface-variant">등록된 공지사항이 없습니다.</p>
    {:else if notices.data}
      <ul>
        {#each notices.data.items as n (n.id)}
          <li class="border-t border-surface-container">
            <a
              href={resolve(`notices/${n.id}`)}
              class="flex min-h-11 items-center justify-between gap-4 py-3 text-[15px] text-on-surface hover:text-primary {ui.focusRing}"
            >
              <span class="flex min-w-0 items-center gap-2">
                {#if n.is_pinned}
                  <span class="shrink-0 text-xs font-semibold text-primary">[고정]</span>
                {/if}
                <span class="truncate">{n.title}</span>
              </span>
              <span class="shrink-0 text-sm text-on-surface-variant">{formatDate(n.published_at)}</span>
            </a>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <section aria-labelledby="home-account" class="{ui.card} flex flex-col gap-4 rounded-xl p-6">
    <h2 id="home-account" class="text-lg font-semibold">내 계정</h2>
    {#if authStore.isAuthenticated && me.data}
      <p class="text-[15px] text-on-surface-variant">
        {me.data.username} 님으로 로그인되어 있습니다. 권한:
        <strong class="text-primary">{me.data.role === "admin" ? "관리자" : "일반 사용자"}</strong>
      </p>
      <div class="flex flex-wrap gap-3">
        {#if me.data.role === "admin"}
          <a href={resolve("admin")} class={ui.btnPrimary}>관리자 콘솔로 이동</a>
        {/if}
        <a href={resolve("me")} class={ui.btnNeutral}>내 정보</a>
      </div>
    {:else}
      <p class="text-[15px] text-on-surface-variant">로그인하면 내 정보와 계정 기능을 이용할 수 있습니다.</p>
      <div>
        <a href={loginHref} class={ui.btnPrimary}>로그인</a>
      </div>
    {/if}
  </section>
</div>
