<script lang="ts">
  import { onMount, type Snippet } from "svelte"

  // 에디터·관리자 화면 공용 모달 다이얼로그 — role="dialog" + aria-modal, 포커스 가둠(Tab 순환), Esc 로 닫기,
  // 닫히면 열기 전 포커스로 돌아간다.
  //
  // body 로 옮긴다(portal 액션): 에디터가 <form> 안에 있어도 중첩 form·제출이 생기지 않고, 부모의 overflow·쌓임 맥락에 갇히지 않는다.
  // 다이얼로그는 <form> 을 쓰지 않고 Enter 를 직접 처리한다. Svelte 5 의 이벤트 위임은 document 에도 걸려 있어
  // body 로 옮긴 노드의 onclick·onkeydown 도 그대로 동작한다. 다이얼로그 안 keydown 은 여기서 전파를 끊는다.

  const FOCUSABLE =
    'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

  interface Props {
    title: string
    onClose: () => void
    children: Snippet
    /** 넓은 다이얼로그(자르기). */
    wide?: boolean
  }

  const { title, onClose, children, wide = false }: Props = $props()
  const titleId = $props.id()
  let panel: HTMLDivElement | undefined = $state()

  function portal(node: HTMLElement) {
    document.body.appendChild(node)
    return {
      destroy() {
        node.remove()
      },
    }
  }

  onMount(() => {
    const previous = document.activeElement as HTMLElement | null
    const first = panel?.querySelector<HTMLElement>("[data-autofocus]") ?? panel?.querySelector<HTMLElement>(FOCUSABLE)
    ;(first ?? panel)?.focus()
    return () => {
      if (previous?.isConnected) previous.focus()
    }
  })

  const onkeydown = (e: KeyboardEvent) => {
    e.stopPropagation()
    if (e.key === "Escape") {
      e.preventDefault()
      onClose()
      return
    }
    if (e.key !== "Tab") return
    const items = Array.from(panel?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])
    if (!items.length) {
      e.preventDefault()
      return
    }
    const first = items[0]
    const last = items[items.length - 1]
    const active = document.activeElement
    if (e.shiftKey && (active === first || active === panel)) {
      e.preventDefault()
      last.focus()
    } else if (!e.shiftKey && active === last) {
      e.preventDefault()
      first.focus()
    }
  }
</script>

<div
  use:portal
  class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
  role="presentation"
  onmousedown={(e) => {
    if (e.target === e.currentTarget) onClose()
  }}
>
  <div
    bind:this={panel}
    role="dialog"
    aria-modal="true"
    aria-labelledby={titleId}
    tabindex="-1"
    {onkeydown}
    class="max-h-full w-full overflow-auto rounded-2xl border border-outline-variant bg-surface-container-lowest p-5 text-on-surface shadow-xl outline-none {wide
      ? 'max-w-3xl'
      : 'max-w-md'}"
  >
    <h2 id={titleId} class="text-lg font-semibold">{title}</h2>
    {@render children()}
  </div>
</div>
