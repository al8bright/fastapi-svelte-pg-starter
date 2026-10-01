<script lang="ts">
  import type { ActiveState } from "./editorDom.js"
  import EditorIcon from "./EditorIcon.svelte"
  import { TOOLBAR_GROUPS, type ToolbarCommand } from "./toolbar.js"

  // 에디터 툴바 — role="toolbar" + 화살표 키 이동(roving tabindex), 토글은 aria-pressed.
  // 버튼은 mousedown 기본 동작을 막아 편집 영역의 선택·포커스를 유지한다.
  interface Props {
    active: ActiveState
    controlsId: string
    onCommand: (command: ToolbarCommand) => void
  }

  const { active, controlsId, onCommand }: Props = $props()
  let focusIndex = $state(0)
  let root: HTMLDivElement | undefined = $state()

  const onkeydown = (e: KeyboardEvent) => {
    const buttons = Array.from(root?.querySelectorAll<HTMLButtonElement>("button[data-index]") ?? [])
    if (!buttons.length) return
    let next: number | null = null
    if (e.key === "ArrowRight") next = (focusIndex + 1) % buttons.length
    else if (e.key === "ArrowLeft") next = (focusIndex - 1 + buttons.length) % buttons.length
    else if (e.key === "Home") next = 0
    else if (e.key === "End") next = buttons.length - 1
    if (next === null) return
    e.preventDefault()
    focusIndex = next
    buttons[next].focus()
  }
</script>

<div
  bind:this={root}
  role="toolbar"
  tabindex="-1"
  aria-label="서식 도구"
  aria-controls={controlsId}
  {onkeydown}
  class="flex flex-wrap items-center gap-0.5 border-b border-outline-variant bg-surface-container-lowest p-1"
>
  {#each TOOLBAR_GROUPS as group, gi (gi)}
    <div class="flex items-center gap-0.5">
      {#if gi > 0}
        <span role="separator" aria-orientation="vertical" class="mx-1 h-6 w-px bg-outline-variant"></span>
      {/if}
      {#each group as item (item.command)}
        {@const pressed = item.pressed?.(active)}
        <button
          type="button"
          data-index={item.index}
          tabindex={item.index === focusIndex ? 0 : -1}
          aria-label={item.label}
          title={item.label}
          aria-pressed={item.pressed ? Boolean(pressed) : undefined}
          onmousedown={(e) => e.preventDefault()}
          onfocus={() => (focusIndex = item.index)}
          onclick={() => onCommand(item.command)}
          class="inline-flex h-11 w-11 items-center justify-center rounded-lg text-on-surface-variant transition-colors hover:bg-surface-container hover:text-on-surface focus-visible:outline-2 focus-visible:outline-primary {pressed
            ? 'bg-primary text-on-primary hover:bg-primary hover:text-on-primary'
            : ''}"
        >
          <EditorIcon name={item.icon} />
        </button>
      {/each}
    </div>
  {/each}
</div>
