<script lang="ts">
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import Icon from "#lib/components/ui/Icon.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { createDashboard } from "#lib/queries/admin.js"
  import { createMe } from "#lib/queries/auth.js"
  import { SITE_MARK } from "#lib/site.js"
  import { ADMIN_NAV, isNavActive } from "./adminNav.js"

  // 관리자 사이드바 — 그룹 라벨 + 메뉴, 현재 메뉴는 aria-current="page" + 강조 배경.
  // "로그인 잠금" 에는 잠긴 계정 수 배지(대시보드 집계)를 붙인다.
  const me = createMe()
  const dashboard = createDashboard()
  const locked = $derived(dashboard.data?.locked_accounts ?? 0)
  // 넓은 화면 사이드바와 좁은 화면 서랍이 동시에 그려질 수 있어 id 가 겹치지 않게 접두사를 둔다.
  const idPrefix = $props.id()
</script>

<div class="flex h-full flex-col gap-6 px-4 py-5">
  <a
    href={resolve("admin")}
    class="flex min-h-11 items-center gap-2.5 rounded px-2 text-base font-bold text-on-surface {ui.focusRing}"
  >
    <span aria-hidden="true" class="flex size-8 items-center justify-center rounded-lg bg-primary text-sm text-on-primary">
      {SITE_MARK}
    </span>
    관리자 콘솔
  </a>

  <nav aria-label="관리자 메뉴" class="flex flex-col gap-4">
    {#each ADMIN_NAV as group, gi (group.label)}
      {@const groupId = `${idPrefix}-group-${gi}`}
      <div class="flex flex-col gap-0.5">
        <p id={groupId} class="px-3 pb-1.5 text-xs font-semibold tracking-wider text-outline">{group.label}</p>
        <ul aria-labelledby={groupId} class="flex flex-col gap-0.5">
          {#each group.items as item (item.path)}
            {@const href = resolve(item.path)}
            {@const active = isNavActive(page.url.pathname, href, item.end)}
            <li>
              <a
                {href}
                aria-current={active ? "page" : undefined}
                class="flex min-h-11 items-center gap-3 rounded-lg border-l-[3px] px-3 text-[15px] {ui.focusRing} {active
                  ? 'border-primary bg-primary-fixed font-semibold text-primary'
                  : 'border-transparent text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface'}"
              >
                <Icon name={item.icon} />
                <span class="flex-1">{item.label}</span>
                {#if item.badge === "locked" && locked > 0}
                  <span class="rounded-full bg-error-container px-2 py-0.5 text-xs font-semibold text-on-error-container">
                    {locked}<span class="sr-only">개 계정 잠김</span>
                  </span>
                {/if}
              </a>
            </li>
          {/each}
        </ul>
      </div>
    {/each}
  </nav>

  <div class="mt-auto flex flex-col gap-2 border-t border-surface-container-highest pt-4">
    <a
      href={resolve("")}
      class="flex min-h-11 items-center gap-2.5 rounded-lg px-3 text-sm text-on-surface-variant hover:bg-surface-container-low hover:text-on-surface {ui.focusRing}"
    >
      <Icon name="back" />
      사용자 화면으로
    </a>
    <p class="px-3 py-2 text-[13px] text-on-surface-variant">
      {me.data ? `${me.data.username} · 관리자` : "관리자"}
    </p>
  </div>
</div>
