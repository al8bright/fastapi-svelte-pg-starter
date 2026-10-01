<script lang="ts">
  import EditorDialog from "./EditorDialog.svelte"

  // 한 줄 입력 다이얼로그 — 링크 걸기·유튜브 링크·대체 텍스트에 쓴다.
  // validate 가 문구를 돌려주면 닫지 않고 오류를 보여 준다.
  interface Props {
    title: string
    label: string
    initialValue?: string
    placeholder?: string
    hint?: string
    submitLabel?: string
    inputType?: "text" | "url"
    /** 문제가 있으면 오류 문구, 없으면 null. */
    validate?: (value: string) => string | null
    onSubmit: (value: string) => void
    onClose: () => void
  }

  const {
    title,
    label,
    initialValue = "",
    placeholder,
    hint,
    submitLabel = "적용",
    inputType = "text",
    validate,
    onSubmit,
    onClose,
  }: Props = $props()

  const uid = $props.id()
  const inputId = `${uid}-input`
  const errorId = `${uid}-error`
  const hintId = `${uid}-hint`
  // svelte-ignore state_referenced_locally
  let value = $state(initialValue)
  let error = $state<string | null>(null)

  const describedBy = $derived([hint ? hintId : "", error ? errorId : ""].filter(Boolean).join(" ") || undefined)

  const submit = () => {
    const problem = validate?.(value) ?? null
    if (problem) {
      error = problem
      return
    }
    onSubmit(value)
  }
</script>

<EditorDialog {title} {onClose}>
  <label for={inputId} class="mt-4 block text-sm font-medium">{label}</label>
  <input
    id={inputId}
    data-autofocus
    type={inputType}
    bind:value
    {placeholder}
    aria-invalid={error ? true : undefined}
    aria-describedby={describedBy}
    oninput={() => (error = null)}
    onkeydown={(e) => {
      if (e.key === "Enter" && !e.isComposing) {
        e.preventDefault()
        submit()
      }
    }}
    class="mt-1 min-h-11 w-full rounded-lg border border-outline-variant bg-surface px-3 py-2 text-on-surface outline-none focus:border-primary"
  />
  {#if hint}
    <p id={hintId} class="mt-1 text-xs text-on-surface-variant">{hint}</p>
  {/if}
  {#if error}
    <p id={errorId} role="alert" class="mt-2 rounded-lg bg-error-container px-3 py-2 text-sm text-on-error-container">
      {error}
    </p>
  {/if}
  <div class="mt-5 flex justify-end gap-2">
    <button
      type="button"
      onclick={onClose}
      class="min-h-11 rounded-lg border border-outline-variant px-4 font-medium text-on-surface hover:bg-surface-container"
    >
      취소
    </button>
    <button
      type="button"
      onclick={submit}
      class="min-h-11 rounded-lg bg-primary px-4 font-semibold text-on-primary hover:opacity-90"
    >
      {submitLabel}
    </button>
  </div>
</EditorDialog>
