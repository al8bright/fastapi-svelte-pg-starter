<script lang="ts">
  import { MediaQuery } from "svelte/reactivity"
  import type { BannerPublic } from "#lib/api/banners.js"
  import Icon from "#lib/components/ui/Icon.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { resolveUploadUrl } from "#lib/editor/upload.js"
  import { isInternalLink } from "#lib/linkUrl.js"

  // 홈 배너 캐러셀 (WAI-ARIA APG Carousel 패턴).
  // - 자동 넘김 6초. 마우스를 올리거나 안쪽에 포커스가 있으면 멈추고, 일시정지 버튼으로 끌 수 있다(WCAG 2.2.2).
  // - prefers-reduced-motion 이면 자동 넘김을 하지 않는다.
  // - 내부 링크(/...)는 같은 탭(SvelteKit 라우터가 가로챈다), 외부 링크는 새 창(rel="noopener noreferrer")으로 연다.
  //   link_url 은 서버가 검증한 값(http(s) 또는 "/" 내부 경로)이라 정적 경로가 아니어서 resolve() 로 감싸지 않는다.

  const AUTO_ADVANCE_MS = 6000

  const { banners }: { banners: BannerPublic[] } = $props()

  let index = $state(0)
  let hovered = $state(false)
  let focused = $state(false)
  let stopped = $state(false)
  const reducedMotion = new MediaQuery("prefers-reduced-motion: reduce", false)

  const count = $derived(banners.length)
  const current = $derived(count ? index % count : 0)
  const autoPlay = $derived(count > 1 && !stopped && !reducedMotion.current)
  const rotating = $derived(autoPlay && !hovered && !focused)

  $effect(() => {
    if (!rotating) return
    const n = count
    const timer = window.setInterval(() => (index = (index + 1) % n), AUTO_ADVANCE_MS)
    return () => window.clearInterval(timer)
  })

  const go = (next: number) => (index = (next + count) % count)

  const control = `flex size-11 items-center justify-center rounded-full bg-surface-container-lowest/90 text-on-surface shadow hover:bg-surface-container-lowest ${ui.focusRing}`
  const linkClass = `block size-full ${ui.focusRing} focus-visible:ring-inset`
</script>

{#snippet bannerImage(banner: BannerPublic, eager: boolean)}
  <img
    src={resolveUploadUrl(banner.image_url)}
    alt={banner.alt_text || banner.title}
    width={banner.width}
    height={banner.height}
    loading={eager ? "eager" : "lazy"}
    class="size-full object-cover"
  />
{/snippet}

{#if count > 0}
  <section
    aria-roledescription="carousel"
    aria-label="주요 배너"
    class="relative overflow-hidden rounded-xl bg-surface-container"
    onmouseenter={() => (hovered = true)}
    onmouseleave={() => (hovered = false)}
    onfocusin={() => (focused = true)}
    onfocusout={(e) => {
      if (!e.currentTarget.contains(e.relatedTarget as Node | null)) focused = false
    }}
  >
    <div class="relative aspect-[16/9] sm:aspect-[3/1]" aria-live={rotating ? "off" : "polite"}>
      {#each banners as banner, i (banner.id)}
        <div
          role="group"
          aria-roledescription="slide"
          aria-label="{i + 1} / {count}: {banner.title}"
          hidden={i !== current}
          class="absolute inset-0"
        >
          {#if !banner.link_url}
            {@render bannerImage(banner, i === 0)}
          {:else if isInternalLink(banner.link_url)}
            <a href={banner.link_url} class={linkClass}>
              {@render bannerImage(banner, i === 0)}
            </a>
          {:else}
            <a href={banner.link_url} target="_blank" rel="noopener noreferrer" class={linkClass}>
              {@render bannerImage(banner, i === 0)}
              <span class="sr-only">(새 창에서 열림)</span>
            </a>
          {/if}
        </div>
      {/each}
    </div>

    {#if count > 1}
      <button
        type="button"
        class="{control} absolute top-1/2 left-3 -translate-y-1/2"
        onclick={() => go(current - 1)}
        aria-label="이전 배너"
      >
        <Icon name="chevronLeft" />
      </button>
      <button
        type="button"
        class="{control} absolute top-1/2 right-3 -translate-y-1/2"
        onclick={() => go(current + 1)}
        aria-label="다음 배너"
      >
        <Icon name="chevronRight" />
      </button>
      <div class="absolute inset-x-0 bottom-1 flex items-center justify-center gap-1">
        {#if !reducedMotion.current}
          <button
            type="button"
            class="{control} size-9 min-h-9"
            onclick={() => (stopped = !stopped)}
            aria-label={stopped ? "자동 넘김 시작" : "자동 넘김 멈춤"}
          >
            <Icon name={stopped ? "play" : "pause"} size={14} />
          </button>
        {/if}
        {#each banners as banner, i (banner.id)}
          <button
            type="button"
            onclick={() => go(i)}
            aria-label="{i + 1}번째 배너 보기: {banner.title}"
            aria-current={i === current ? "true" : undefined}
            class="flex size-11 items-center justify-center rounded-full {ui.focusRing}"
          >
            <span
              aria-hidden="true"
              class="block h-2.5 rounded-full border border-on-surface/40 transition-all {i === current
                ? 'w-6 bg-primary'
                : 'w-2.5 bg-surface-container-lowest'}"
            ></span>
          </button>
        {/each}
      </div>
    {/if}
  </section>
{/if}
