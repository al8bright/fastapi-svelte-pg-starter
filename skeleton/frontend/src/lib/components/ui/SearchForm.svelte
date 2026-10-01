<script lang="ts">
  import Icon from "./Icon.svelte"
  import { ui } from "./styles.js"

  // 제목 검색 폼 — 제출할 때만 onSearch(공백 제거, 100자). 보이는 라벨은 sr-only 로 둔다(placeholder 는 라벨이 아니다).
  // initial 은 처음 한 번만 읽는다 — URL 의 q 가 바뀌면 호출부가 {#key q} 로 다시 만든다.
  interface Props {
    label: string
    initial: string
    onSearch: (q: string) => void
    placeholder?: string
  }

  const { label, initial, onSearch, placeholder }: Props = $props()
  const id = $props.id()
  // svelte-ignore state_referenced_locally
  let value = $state(initial)

  const onsubmit = (e: SubmitEvent) => {
    e.preventDefault()
    onSearch(value.trim().slice(0, 100))
  }
</script>

<form role="search" {onsubmit} class="flex w-full gap-2 sm:w-auto">
  <label for={id} class="sr-only">{label}</label>
  <input
    {id}
    type="search"
    bind:value
    maxlength={100}
    placeholder={placeholder ?? label}
    class="{ui.input} mt-0 min-w-0 flex-1 sm:w-64"
  />
  <button type="submit" class={ui.btnNeutral}>
    <Icon name="search" size={16} />
    검색
  </button>
</form>
