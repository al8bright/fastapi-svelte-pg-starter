import { type Component, flushSync, mount, unmount } from "svelte"
import { afterEach, describe, expect, it, vi } from "vitest"
import RichContent from "#lib/components/RichContent.svelte"
import RichTextEditor from "./RichTextEditor.svelte"

// 컴포넌트 연기 테스트 — 별도 테스트 라이브러리 없이 svelte 의 mount 로 jsdom 에 그린다.
// jsdom 에는 execCommand·canvas 가 없어 편집 명령 자체는 브라우저에서 확인한다(editorDom 의 exec 폴백 경로만 탄다).

let cleanup: (() => void) | null = null
afterEach(() => {
  cleanup?.()
  cleanup = null
  document.body.innerHTML = ""
})

function render<P extends object>(component: Component<P>, props: P) {
  const target = document.createElement("div")
  document.body.appendChild(target)
  const instance = mount(component as unknown as Component<Record<string, unknown>>, {
    target,
    props: props as Record<string, unknown>,
  })
  cleanup = () => unmount(instance)
  flushSync()
  return target
}

describe("RichContent", () => {
  it(".rich-text 래퍼 안에 (서버가 정화한) HTML 을 그대로 렌더한다", () => {
    const el = render(RichContent, { html: `<h2 class="align-center">제목</h2><ul><li>항목</li></ul>`, class: "mt-4" })
    const root = el.querySelector(".rich-text")!
    expect(root.classList.contains("mt-4")).toBe(true)
    expect(root.querySelector("h2.align-center")?.textContent).toBe("제목")
    expect(root.querySelector("ul > li")?.textContent).toBe("항목")
  })
})

describe("RichTextEditor", () => {
  const upload = vi.fn(async () => ({ url: "/uploads/public/editor/a.webp", width: 640, height: 360 }))

  it("툴바(22개 버튼)와 편집 영역을 그리고 initialHtml 을 한 번 넣는다", () => {
    const onChange = vi.fn()
    const el = render(RichTextEditor, { initialHtml: "<p>안녕</p>", onChange, uploadImage: upload, labelId: "lbl" })
    expect(el.querySelectorAll('[role="toolbar"] button').length).toBe(22)
    const editor = el.querySelector<HTMLElement>('[role="textbox"]')!
    expect(editor.getAttribute("contenteditable")).toBe("true")
    expect(editor.getAttribute("aria-labelledby")).toBe("lbl")
    expect(editor.innerHTML).toBe("<p>안녕</p>")
    expect(onChange).not.toHaveBeenCalled()
  })

  it("입력하면 편집 전용 속성을 지운 직렬화 HTML 로 onChange", () => {
    const onChange = vi.fn()
    const el = render(RichTextEditor, { onChange, uploadImage: upload })
    const editor = el.querySelector<HTMLElement>('[role="textbox"]')!
    expect(editor.dataset.empty).toBe("true")
    editor.innerHTML = '<p>본문 <img src="/a.png" width="10" height="10" data-selected="true" style="width:5px"></p>'
    editor.dispatchEvent(new Event("input", { bubbles: true }))
    flushSync()
    expect(onChange).toHaveBeenLastCalledWith('<p>본문 <img src="/a.png" width="10" height="10"></p>')
    expect(editor.dataset.empty).toBeUndefined()
  })

  it("영상 버튼은 유튜브 링크 다이얼로그를 body 에 띄우고, 잘못된 링크는 오류를 보여 준다", () => {
    const el = render(RichTextEditor, { onChange: vi.fn(), uploadImage: upload })
    el.querySelector<HTMLButtonElement>('button[aria-label="영상"]')!.click()
    flushSync()
    const dialog = document.body.querySelector<HTMLElement>('[role="dialog"]')!
    expect(dialog.textContent).toContain("유튜브 영상 넣기")
    expect(el.contains(dialog)).toBe(false)
    const input = dialog.querySelector("input")!
    input.value = "https://example.com/watch?v=x"
    input.dispatchEvent(new Event("input", { bubbles: true }))
    flushSync()
    Array.from(dialog.querySelectorAll("button"))
      .find((b) => b.textContent?.trim() === "넣기")!
      .click()
    flushSync()
    expect(dialog.querySelector('[role="alert"]')?.textContent).toContain("유튜브 링크만 넣을 수 있습니다.")
  })

  it("이미지를 누르면 선택 오버레이(미니 툴바)가 열린다", async () => {
    const el = render(RichTextEditor, {
      initialHtml: '<p><img src="/a.png" alt="" width="640" height="360"></p>',
      onChange: vi.fn(),
      uploadImage: upload,
    })
    el.querySelector<HTMLImageElement>('[role="textbox"] img')!.click()
    flushSync()
    await new Promise((r) => setTimeout(r, 40))
    flushSync()
    expect(el.querySelector('[role="toolbar"][aria-label="이미지 도구"]')).not.toBeNull()
    expect(el.querySelector("[data-selected]")).not.toBeNull()
  })
})
