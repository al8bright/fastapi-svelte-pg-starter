<script lang="ts">
  import { createMutation } from "@tanstack/svelte-query"
  import { type Attachment, downloadAdminAttachment, uploadAttachment } from "#lib/api/notices.js"
  import ConfirmDialog from "#lib/components/ui/ConfirmDialog.svelte"
  import Icon from "#lib/components/ui/Icon.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { saveBlob } from "#lib/download.js"
  import { formatBytes } from "#lib/format.js"
  import { createAdminNotice, createDeleteAttachment, useInvalidateNotices } from "#lib/queries/notices.js"
  import {
    ATTACHMENT_ACCEPT,
    ATTACHMENT_EXTENSIONS,
    attachmentProblem,
    MAX_ATTACHMENT_MB,
    MAX_ATTACHMENTS_PER_NOTICE,
  } from "#lib/uploadRules.js"

  // 공지 첨부 패널 — 공지가 저장된 뒤에만 쓴다(첨부는 공지 id 에 붙는다).
  // 여러 파일을 고르면 사전 검사(확장자·용량·개수) 후 하나씩 순서대로 올리고 파일별 진행률·오류를 보여 준다.
  // 업로드는 공용 axios 인스턴스로 FormData 필드 `file`(Bearer 주입·401 refresh 재시도 그대로).
  // 관리자 다운로드는 Bearer 가 필요해 blob 으로 받아 원래 파일명(original_name)으로 저장한다.

  type UploadStatus = "waiting" | "uploading" | "done" | "error"

  interface UploadItem {
    key: string
    name: string
    status: UploadStatus
    progress: number
    error: string | null
  }

  const STATUS_LABEL: Record<UploadStatus, string> = {
    waiting: "대기",
    uploading: "올리는 중",
    done: "완료",
    error: "실패",
  }

  const { noticeId }: { noticeId: number } = $props()

  const notice = createAdminNotice(() => noticeId)
  const attachments = $derived(notice.data?.attachments ?? [])
  const refresh = useInvalidateNotices()
  const remove = createDeleteAttachment(() => noticeId)
  const upload = createMutation(() => ({
    mutationFn: ({ file, onProgress }: { file: File; onProgress: (p: number) => void }) =>
      uploadAttachment(noticeId, file, onProgress),
  }))

  let queue = $state<UploadItem[]>([])
  let busy = $state(false)
  let message = $state<{ tone: "success" | "error"; text: string } | null>(null)
  let deleting = $state<Attachment | null>(null)
  const uid = $props.id()
  const inputId = `${uid}-file`
  const helpId = `${uid}-help`

  const patch = (key: string, changes: Partial<UploadItem>) => {
    const item = queue.find((it) => it.key === key)
    if (item) Object.assign(item, changes)
  }

  const onchange = async (e: Event & { currentTarget: HTMLInputElement }) => {
    const files = Array.from(e.currentTarget.files ?? [])
    e.currentTarget.value = ""
    if (!files.length) return
    let slots = MAX_ATTACHMENTS_PER_NOTICE - attachments.length
    const picked = files.map((file, i) => {
      let problem = attachmentProblem(file)
      if (!problem) {
        if (slots <= 0) problem = `첨부 파일은 공지당 ${MAX_ATTACHMENTS_PER_NOTICE}개까지 올릴 수 있습니다.`
        else slots -= 1
      }
      const item: UploadItem = {
        key: `${Date.now()}-${i}-${file.name}`,
        name: file.name,
        status: problem ? "error" : "waiting",
        progress: 0,
        error: problem,
      }
      return { file, item }
    })
    queue = picked.map((p) => p.item)
    message = null
    busy = true
    let uploaded = 0
    for (const { file, item } of picked) {
      if (item.status === "error") continue
      patch(item.key, { status: "uploading" })
      try {
        await upload.mutateAsync({ file, onProgress: (p) => patch(item.key, { progress: p }) })
        patch(item.key, { status: "done", progress: 100 })
        uploaded += 1
      } catch (err) {
        patch(item.key, { status: "error", error: apiErrorMessage(err, { maxMb: MAX_ATTACHMENT_MB }) })
      }
    }
    if (uploaded) await refresh()
    busy = false
  }

  const download = async (a: Attachment) => {
    try {
      saveBlob(await downloadAdminAttachment(noticeId, a.id), a.original_name)
    } catch (err) {
      message = { tone: "error", text: apiErrorMessage(err, { fallback: "파일을 내려받지 못했습니다." }) }
    }
  }

  const confirmDelete = () => {
    const target = deleting
    if (!target) return
    remove.mutate(target.id, {
      onSuccess: () => (message = { tone: "success", text: `${target.original_name} 을(를) 삭제했습니다.` }),
      onError: (err) => (message = { tone: "error", text: apiErrorMessage(err) }),
      onSettled: () => (deleting = null),
    })
  }
</script>

<section aria-labelledby="{uid}-title" class="{ui.card} flex flex-col gap-4 rounded-xl p-5">
  <div>
    <h2 id="{uid}-title" class="text-lg font-semibold">
      첨부 파일 <span class="text-on-surface-variant">({attachments.length}/{MAX_ATTACHMENTS_PER_NOTICE})</span>
    </h2>
  </div>

  {#if message}
    <Notice tone={message.tone} onClose={() => (message = null)}>{message.text}</Notice>
  {/if}

  {#if attachments.length === 0}
    <p class="text-sm text-on-surface-variant">첨부 파일이 없습니다.</p>
  {:else}
    <ul class="flex flex-col gap-2">
      {#each attachments as a (a.id)}
        <li class="flex flex-wrap items-center gap-2 rounded-lg border border-outline-variant px-3 py-1.5">
          <Icon name="clip" size={16} class="text-on-surface-variant" />
          <span class="min-w-0 flex-1 truncate text-sm font-medium">{a.original_name}</span>
          <span class="text-sm text-on-surface-variant">{formatBytes(a.size_bytes)}</span>
          <button type="button" class="{ui.btnSmall} text-primary hover:bg-primary-fixed" onclick={() => void download(a)}>
            내려받기<span class="sr-only"> ({a.original_name})</span>
          </button>
          <button type="button" class="{ui.btnSmall} text-error hover:bg-error-container" onclick={() => (deleting = a)}>
            삭제<span class="sr-only"> ({a.original_name})</span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}

  <div>
    <label for={inputId} class={ui.label}>파일 올리기</label>
    <input
      id={inputId}
      type="file"
      multiple
      accept={ATTACHMENT_ACCEPT}
      disabled={busy || attachments.length >= MAX_ATTACHMENTS_PER_NOTICE}
      onchange={(e) => void onchange(e)}
      aria-describedby={helpId}
      class="mt-2 block w-full rounded text-sm text-on-surface-variant file:mr-3 file:min-h-11 file:cursor-pointer file:rounded file:border-0 file:bg-primary file:px-4 file:font-semibold file:text-on-primary disabled:opacity-60 {ui.focusRing}"
    />
    <p id={helpId} class={ui.help}>
      {ATTACHMENT_EXTENSIONS.join(", ")} · 파일당 {MAX_ATTACHMENT_MB}MB 이하 · 공지당 {MAX_ATTACHMENTS_PER_NOTICE}개까지
    </p>
  </div>

  {#if queue.length > 0}
    <ul aria-label="업로드 진행 상황" aria-live="polite" class="flex flex-col gap-2">
      {#each queue as it (it.key)}
        <li class="rounded-lg bg-surface-container-low px-3 py-2 text-sm">
          <div class="flex items-center gap-2">
            <span class="min-w-0 flex-1 truncate">{it.name}</span>
            <span class={it.status === "error" ? "font-semibold text-error" : "text-on-surface-variant"}>
              {STATUS_LABEL[it.status]}{it.status === "uploading" ? ` ${it.progress}%` : ""}
            </span>
          </div>
          {#if it.status === "uploading"}
            <progress
              class="mt-1 h-1.5 w-full accent-primary"
              max={100}
              value={it.progress}
              aria-label="{it.name} 업로드 진행률"
            ></progress>
          {/if}
          {#if it.error}
            <p class="mt-1 text-error">{it.error}</p>
          {/if}
        </li>
      {/each}
    </ul>
  {/if}
</section>

{#if deleting}
  {@const target = deleting}
  <ConfirmDialog
    title="첨부 파일을 삭제할까요?"
    confirmLabel="삭제"
    danger
    pending={remove.isPending}
    onConfirm={confirmDelete}
    onCancel={() => (deleting = null)}
  >
    {target.original_name} 이(가) 바로 삭제되며 되돌릴 수 없습니다.
  </ConfirmDialog>
{/if}
