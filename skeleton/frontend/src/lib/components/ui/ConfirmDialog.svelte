<script lang="ts">
  import type { Snippet } from "svelte"
  import EditorDialog from "#lib/components/editor/EditorDialog.svelte"
  import { ui } from "./styles.js"

  // 확인 다이얼로그 — 삭제·강제 종료 같은 되돌리기 어려운 작업 전에 띄운다.
  // 포커스 가둠·Esc 닫기·포커스 복귀는 공용 모달(EditorDialog)이 맡는다. 첫 포커스는 "취소"(data-autofocus).
  interface Props {
    title: string
    children?: Snippet
    confirmLabel?: string
    cancelLabel?: string
    /** 파괴적 작업이면 확인 버튼을 오류 색으로. */
    danger?: boolean
    pending?: boolean
    onConfirm: () => void
    onCancel: () => void
  }

  const {
    title,
    children,
    confirmLabel = "확인",
    cancelLabel = "취소",
    danger = false,
    pending = false,
    onConfirm,
    onCancel,
  }: Props = $props()
</script>

<EditorDialog {title} onClose={onCancel}>
  {#if children}
    <div class="mt-3 text-sm leading-6 text-on-surface-variant">{@render children()}</div>
  {/if}
  <div class="mt-6 flex justify-end gap-2">
    <button type="button" class={ui.btnNeutral} onclick={onCancel} data-autofocus>{cancelLabel}</button>
    <button type="button" class={danger ? ui.btnDangerSolid : ui.btnPrimary} onclick={onConfirm} disabled={pending}>
      {pending ? "처리 중…" : confirmLabel}
    </button>
  </div>
</EditorDialog>
