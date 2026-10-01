<script lang="ts">
  import {
    IMAGE_MIN_WIDTH,
    IMAGE_WIDTH_PRESETS,
    type Size,
    sizeForWidth,
    VIDEO_MAX_WIDTH,
    VIDEO_MIN_WIDTH,
    VIDEO_SIZE_PRESETS,
    videoSizeForWidth,
  } from "#lib/editor/imageTransform.js"
  import EditorIcon from "./EditorIcon.svelte"

  // 선택된 이미지/영상 위 오버레이 (editor-spec §4·§6).
  // - 편집 영역 래퍼(position:relative) 안에 absolute 로 놓고, getBoundingClientRect 차이로 배치한다.
  //   스크롤·리사이즈·이미지 로드·크기 변화(ResizeObserver) 때 다시 잰다.
  // - 모서리 핸들 4개: 드래그 중에는 style.width 로 미리보기만 하고 pointerup 에 한 번 커밋(onResize).
  //   커밋은 부모가 selectNode + insertHTML 로 처리한다(undo 스택에 남도록).
  // - 미니 툴바: 이미지(크기 프리셋·폭 입력·대체 텍스트·다시 자르기·교체·삭제) / 영상(크기 프리셋·폭 입력·링크 바꾸기·삭제).
  // 부모는 선택이 바뀔 때 {#key} 로 다시 만든다(폭 입력 초기화).

  interface Props {
    kind: "image" | "video"
    target: HTMLElement
    container: HTMLElement
    /** 이미지 원본 크기(프리셋 상한). 영상은 무시. */
    natural: Size
    /** 현재 저장된 폭(width 속성). */
    currentWidth: number
    canRecrop: boolean
    onResize: (width: number) => void
    onDelete: () => void
    onAltText?: () => void
    onRecrop?: () => void
    onReplace?: () => void
    onChangeLink?: () => void
  }

  const {
    kind,
    target,
    container,
    natural,
    currentWidth,
    canRecrop,
    onResize,
    onDelete,
    onAltText,
    onRecrop,
    onReplace,
    onChangeLink,
  }: Props = $props()

  interface Box {
    /** 래퍼 폭 — 미니 툴바가 오른쪽으로 넘치지 않게 왼쪽 위치를 당긴다. */
    containerWidth: number
    left: number
    top: number
    width: number
    height: number
  }

  type Corner = "nw" | "ne" | "sw" | "se"
  const CORNERS: Corner[] = ["nw", "ne", "sw", "se"]
  const CORNER_POS: Record<Corner, string> = {
    nw: "left-0 top-0 cursor-nwse-resize",
    ne: "left-full top-0 cursor-nesw-resize",
    sw: "left-0 top-full cursor-nesw-resize",
    se: "left-full top-full cursor-nwse-resize",
  }

  let box = $state<Box | null>(null)
  let preview = $state<Size | null>(null)
  // svelte-ignore state_referenced_locally
  let draft = $state(String(currentWidth))
  let drag: { corner: Corner; startX: number; startWidth: number; pointerId: number } | null = null
  const widthId = $props.id()

  // 위치 측정 — rAF 로 모아서 잰다(스크롤·리사이즈가 연달아 와도 프레임당 1회).
  $effect(() => {
    const t = target
    const c = container
    // rAF 가 없는 환경(테스트 등)은 setTimeout 으로 대신한다.
    const raf = window.requestAnimationFrame?.bind(window) ?? ((cb: () => void) => window.setTimeout(cb, 16))
    const caf = window.cancelAnimationFrame?.bind(window) ?? window.clearTimeout.bind(window)
    let frame = 0
    const measure = () => {
      caf(frame)
      frame = raf(() => {
        const tr = t.getBoundingClientRect()
        const cr = c.getBoundingClientRect()
        box = { containerWidth: cr.width, left: tr.left - cr.left, top: tr.top - cr.top, width: tr.width, height: tr.height }
      })
    }
    measure()
    const ro = typeof ResizeObserver === "function" ? new ResizeObserver(measure) : null
    ro?.observe(t)
    ro?.observe(c)
    window.addEventListener("resize", measure)
    window.addEventListener("scroll", measure, true)
    t.addEventListener("load", measure)
    return () => {
      caf(frame)
      ro?.disconnect()
      window.removeEventListener("resize", measure)
      window.removeEventListener("scroll", measure, true)
      t.removeEventListener("load", measure)
    }
  })

  const sizeFor = (width: number): Size => (kind === "image" ? sizeForWidth(natural, width) : videoSizeForWidth(width))
  // 미리보기 대상 — 영상은 래퍼가 아니라 iframe 크기를 바꾼다.
  const previewEl = (): HTMLElement => (kind === "video" ? (target.querySelector("iframe") ?? target) : target)

  const onHandleDown = (corner: Corner) => (e: PointerEvent & { currentTarget: HTMLSpanElement }) => {
    if (e.button !== 0) return
    e.preventDefault()
    e.stopPropagation()
    drag = {
      corner,
      startX: e.clientX,
      startWidth: previewEl().getBoundingClientRect().width || currentWidth,
      pointerId: e.pointerId,
    }
    e.currentTarget.setPointerCapture?.(e.pointerId)
  }

  const onHandleMove = (e: PointerEvent) => {
    if (!drag || drag.pointerId !== e.pointerId) return
    const dx = e.clientX - drag.startX
    const grow = drag.corner === "nw" || drag.corner === "sw" ? -dx : dx
    const size = sizeFor(drag.startWidth + grow)
    const el = previewEl()
    el.style.width = `${size.width}px`
    el.style.height = `${size.height}px`
    preview = size
  }

  const onHandleUp = (e: PointerEvent & { currentTarget: HTMLSpanElement }) => {
    if (!drag || drag.pointerId !== e.pointerId) return
    drag = null
    e.currentTarget.releasePointerCapture?.(e.pointerId)
    const el = previewEl()
    el.style.removeProperty("width")
    el.style.removeProperty("height")
    if (!el.getAttribute("style")) el.removeAttribute("style")
    const size = preview
    preview = null
    if (size && size.width !== currentWidth) onResize(size.width)
  }

  const commitDraft = () => {
    const n = Number.parseInt(draft, 10)
    if (!Number.isFinite(n)) {
      draft = String(currentWidth)
      return
    }
    const size = sizeFor(n)
    draft = String(size.width)
    if (size.width !== currentWidth) onResize(size.width)
  }

  const presets = $derived<Array<{ label: string; width: number }>>(
    kind === "image"
      ? [
          { label: "소", width: IMAGE_WIDTH_PRESETS[0] },
          { label: "중", width: IMAGE_WIDTH_PRESETS[1] },
          { label: "대", width: IMAGE_WIDTH_PRESETS[2] },
          { label: "원본", width: natural.width },
        ]
      : [
          ...VIDEO_SIZE_PRESETS.map(([w, h]) => ({ label: `${w}×${h}`, width: w as number })),
          { label: "전체 폭", width: VIDEO_MAX_WIDTH },
        ],
  )
  const minWidth = $derived(kind === "image" ? Math.min(IMAGE_MIN_WIDTH, natural.width) : VIDEO_MIN_WIDTH)
  const maxWidth = $derived(kind === "image" ? natural.width : VIDEO_MAX_WIDTH)

  const btn =
    "inline-flex min-h-11 min-w-11 items-center justify-center gap-1 rounded-lg px-2 text-sm font-medium text-on-surface hover:bg-surface-container disabled:cursor-not-allowed disabled:opacity-40 aria-pressed:bg-primary aria-pressed:text-on-primary"
</script>

{#if box}
  {@const toolbarAbove = box.top > 64}
  <!-- 미니 툴바 예상 폭(약 360px)만큼 오른쪽 여유가 없으면 왼쪽으로 당긴다. -->
  {@const toolbarLeft = Math.max(0, Math.min(box.left, box.containerWidth - 360))}

  <!-- 선택 테두리 + 모서리 핸들 -->
  <div
    class="pointer-events-none absolute z-10 outline-2 outline-primary"
    style:left="{box.left}px"
    style:top="{box.top}px"
    style:width="{preview?.width ?? box.width}px"
    style:height="{preview?.height ?? box.height}px"
    data-testid="media-overlay"
  >
    {#each CORNERS as c (c)}
      <span
        aria-hidden="true"
        data-corner={c}
        onpointerdown={onHandleDown(c)}
        onpointermove={onHandleMove}
        onpointerup={onHandleUp}
        onpointercancel={onHandleUp}
        class="pointer-events-auto absolute h-7 w-7 -translate-x-1/2 -translate-y-1/2 touch-none after:absolute after:inset-2 after:rounded-sm after:border-2 after:border-primary after:bg-white {CORNER_POS[
          c
        ]}"
      ></span>
    {/each}
    {#if preview}
      <span class="absolute right-2 bottom-2 rounded bg-black/70 px-2 py-0.5 text-xs text-white">
        {preview.width} × {preview.height}
      </span>
    {/if}
  </div>

  <!-- 미니 툴바 -->
  <div
    role="toolbar"
    tabindex="-1"
    aria-label={kind === "image" ? "이미지 도구" : "영상 도구"}
    class="absolute z-20 flex max-w-full flex-wrap items-center gap-0.5 rounded-xl border border-outline-variant bg-surface-container-lowest p-1 shadow-lg"
    style:left="{toolbarLeft}px"
    style:top="{toolbarAbove ? box.top - 8 : box.top + box.height + 8}px"
    style:transform={toolbarAbove ? "translateY(-100%)" : undefined}
    onmousedown={(e) => {
      // 버튼 클릭이 편집 영역 선택을 바꾸지 않도록 (입력칸은 포커스가 필요하다).
      if (!(e.target instanceof HTMLInputElement)) e.preventDefault()
    }}
  >
    <div role="group" aria-label="크기" class="flex flex-wrap gap-0.5">
      {#each presets as p (p.label)}
        <button
          type="button"
          class={btn}
          aria-pressed={currentWidth === p.width}
          disabled={kind === "image" && p.width > natural.width}
          title="폭 {p.width}px"
          onclick={() => onResize(p.width)}
        >
          {p.label}
        </button>
      {/each}
    </div>
    <label for={widthId} class="ml-1 text-xs text-on-surface-variant">폭(px)</label>
    <input
      id={widthId}
      type="number"
      inputmode="numeric"
      min={minWidth}
      max={maxWidth}
      value={draft}
      oninput={(e) => (draft = e.currentTarget.value)}
      onblur={commitDraft}
      onkeydown={(e) => {
        if (e.key === "Enter") {
          e.preventDefault()
          commitDraft()
        }
      }}
      class="min-h-11 w-20 rounded-lg border border-outline-variant bg-surface px-2 text-sm text-on-surface outline-none focus:border-primary"
    />
    <span class="mx-1 h-6 w-px bg-outline-variant" aria-hidden="true"></span>
    {#if kind === "image"}
      <button type="button" class={btn} onclick={onAltText} aria-label="대체 텍스트" title="대체 텍스트">
        <EditorIcon name="alt" />
      </button>
      <button
        type="button"
        class={btn}
        onclick={onRecrop}
        disabled={!canRecrop}
        aria-label="다시 자르기"
        title={canRecrop ? "다시 자르기" : "GIF 는 자를 수 없습니다"}
      >
        <EditorIcon name="crop" />
      </button>
      <button type="button" class={btn} onclick={onReplace} aria-label="이미지 교체" title="이미지 교체">
        <EditorIcon name="replace" />
      </button>
    {:else}
      <button type="button" class={btn} onclick={onChangeLink} aria-label="링크 바꾸기" title="링크 바꾸기">
        <EditorIcon name="link" />
      </button>
    {/if}
    <button
      type="button"
      class="{btn} text-on-error-container"
      onclick={onDelete}
      aria-label={kind === "image" ? "이미지 삭제" : "영상 삭제"}
      title="삭제"
    >
      <EditorIcon name="trash" />
    </button>
  </div>
{/if}
