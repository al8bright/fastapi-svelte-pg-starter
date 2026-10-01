<script lang="ts">
  import { EDITOR_ICONS, type EditorIconName } from "./editorIcons.js"

  // 에디터 아이콘 — 색은 currentColor 를 따르고, 스크린 리더에는 숨긴다(버튼의 aria-label 이 이름을 준다).
  const { name, size = 20 }: { name: EditorIconName; size?: number } = $props()
</script>

<svg
  viewBox="0 0 24 24"
  width={size}
  height={size}
  fill="none"
  stroke="currentColor"
  stroke-width="2"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
  focusable="false"
>
  {#each EDITOR_ICONS[name] as [tag, attrs], i (i)}
    <svelte:element this={tag} xmlns="http://www.w3.org/2000/svg" {...attrs} />
  {/each}
</svg>
