import { flushSync, mount, unmount } from "svelte"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import type { BannerPublic } from "#lib/api/banners.js"
import { isNavActive } from "#lib/components/layout/adminNav.js"
import BannerCarousel from "./BannerCarousel.svelte"

// 홈 배너 캐러셀(APG carousel) 연기 테스트 — svelte mount() 로 jsdom 에 그린다.

const banner = (id: number, link: string | null = null): BannerPublic => ({
  id,
  title: `배너 ${id}`,
  image_url: `/uploads/public/banners/${id}.webp`,
  width: 1440,
  height: 480,
  link_url: link,
  alt_text: `배너 ${id} 설명`,
})

let cleanup: (() => void) | null = null
let reduced = false

beforeEach(() => {
  reduced = false
  vi.stubGlobal("matchMedia", (query: string) => ({
    matches: query.includes("reduce") ? reduced : false,
    media: query,
    addEventListener: () => {},
    removeEventListener: () => {},
  }))
})

afterEach(() => {
  cleanup?.()
  cleanup = null
  document.body.innerHTML = ""
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

function render(banners: BannerPublic[]) {
  const target = document.createElement("div")
  document.body.appendChild(target)
  const instance = mount(BannerCarousel, { target, props: { banners } })
  cleanup = () => unmount(instance)
  flushSync()
  return target
}

const visibleTitle = (el: HTMLElement) =>
  Array.from(el.querySelectorAll<HTMLElement>('[aria-roledescription="slide"]')).find((s) => !s.hidden)?.getAttribute("aria-label")

const button = (el: HTMLElement, label: string) => el.querySelector<HTMLButtonElement>(`button[aria-label="${label}"]`)!

describe("BannerCarousel", () => {
  it("배너가 없으면 아무것도 그리지 않는다", () => {
    expect(render([]).querySelector("section")).toBeNull()
  })

  it("이전/다음·점 버튼으로 넘기고 현재 점에 aria-current", () => {
    const el = render([banner(1), banner(2), banner(3)])
    expect(visibleTitle(el)).toBe("1 / 3: 배너 1")
    button(el, "다음 배너").click()
    flushSync()
    expect(visibleTitle(el)).toBe("2 / 3: 배너 2")
    button(el, "이전 배너").click()
    button(el, "이전 배너").click()
    flushSync()
    expect(visibleTitle(el)).toBe("3 / 3: 배너 3")
    expect(button(el, "3번째 배너 보기: 배너 3").getAttribute("aria-current")).toBe("true")
  })

  it("6초마다 자동으로 넘기고, 멈춤 버튼을 누르면 멈춘다", () => {
    vi.useFakeTimers()
    const el = render([banner(1), banner(2)])
    vi.advanceTimersByTime(6000)
    flushSync()
    expect(visibleTitle(el)).toBe("2 / 2: 배너 2")
    button(el, "자동 넘김 멈춤").click()
    flushSync()
    vi.advanceTimersByTime(12000)
    flushSync()
    expect(visibleTitle(el)).toBe("2 / 2: 배너 2")
    expect(button(el, "자동 넘김 시작")).not.toBeNull()
  })

  it("prefers-reduced-motion 이면 자동 넘김도 멈춤 버튼도 없다", () => {
    reduced = true
    vi.useFakeTimers()
    const el = render([banner(1), banner(2)])
    vi.advanceTimersByTime(12000)
    flushSync()
    expect(visibleTitle(el)).toBe("1 / 2: 배너 1")
    expect(el.querySelector('button[aria-label^="자동 넘김"]')).toBeNull()
  })

  it("내부 링크는 같은 탭, 외부 링크는 새 창(noopener)", () => {
    const el = render([banner(1, "/notices/3"), banner(2, "https://example.com")])
    const links = el.querySelectorAll("a")
    expect(links[0].getAttribute("href")).toBe("/notices/3")
    expect(links[0].getAttribute("target")).toBeNull()
    expect(links[1].getAttribute("target")).toBe("_blank")
    expect(links[1].getAttribute("rel")).toBe("noopener noreferrer")
  })
})

describe("isNavActive (관리자 사이드바 현재 메뉴)", () => {
  it("대시보드(end)는 정확히 일치할 때만, 나머지는 하위 경로까지", () => {
    expect(isNavActive("/admin", "/admin", true)).toBe(true)
    expect(isNavActive("/admin/notices", "/admin", true)).toBe(false)
    expect(isNavActive("/admin/notices/3/edit", "/admin/notices")).toBe(true)
    expect(isNavActive("/admin/notices-old", "/admin/notices")).toBe(false)
  })
})
