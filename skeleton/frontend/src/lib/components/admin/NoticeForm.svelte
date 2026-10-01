<script lang="ts">
  import { beforeNavigate, goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { page } from "$app/state"
  import type { AdminNoticeDetail } from "#lib/api/notices.js"
  import RichTextEditor from "#lib/components/editor/RichTextEditor.svelte"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import Chip from "#lib/components/ui/Chip.svelte"
  import ConfirmDialog from "#lib/components/ui/ConfirmDialog.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { isRichTextEmpty } from "#lib/editor/richText.js"
  import { uploadEditorImage } from "#lib/editor/upload.js"
  import { createDeleteNotice, createSaveNotice } from "#lib/queries/notices.js"
  import AttachmentsPanel from "./AttachmentsPanel.svelte"

  // 공지 작성(/admin/notices/new)·수정(/admin/notices/[id]/edit) 폼.
  // - 처음 저장(POST)하면 수정 URL 로 바꿔(goto + page.state.flash) 첨부 패널을 연다.
  // - 에디터는 비제어 컴포넌트라 공지가 바뀌면 호출부가 {#key notice.id} 로 다시 만든다(editor-spec §8).
  // - 저장하지 않은 변경이 있으면 앱 안 이동(beforeNavigate → 확인 다이얼로그)과
  //   새로고침·닫기·외부 이동(beforeunload → 브라우저 확인)을 막는다.

  const TITLE_MAX = 200

  interface Values {
    title: string
    body: string
    pinned: boolean
    published: boolean
  }

  type Flash = { tone: "success" | "error"; text: string } | null

  const { notice }: { notice: AdminNoticeDetail | null } = $props()

  function valuesOf(n: AdminNoticeDetail | null): Values {
    return {
      title: n?.title ?? "",
      body: n?.body_html ?? "",
      pinned: n?.is_pinned ?? false,
      published: n?.is_published ?? false,
    }
  }

  const sameValues = (a: Values, b: Values) =>
    a.title === b.title && a.body === b.body && a.pinned === b.pinned && a.published === b.published

  const save = createSaveNotice()
  const remove = createDeleteNotice()

  // 폼 값은 처음 한 번만 notice 에서 읽는다(이후 notice prop 은 머리의 상태 칩 등 표시용).
  // svelte-ignore state_referenced_locally
  let values = $state<Values>(valuesOf(notice))
  // svelte-ignore state_referenced_locally
  let baseline = $state<Values>(valuesOf(notice))
  let errors = $state<{ title?: string; body?: string }>({})
  let flash = $state<Flash>(page.state.flash ?? null)
  let confirmDelete = $state(false)
  // 확인 다이얼로그가 떠 있는 동안 보류한 이동 대상.
  let pendingLeave = $state<string | null>(null)
  // 저장·삭제 직후·확인 후의 이동은 막지 않는다.
  let allowLeave = false

  const uid = $props.id()
  const ids = {
    title: `${uid}-title`,
    titleErr: `${uid}-title-err`,
    body: `${uid}-body`,
    bodyErr: `${uid}-body-err`,
    pubHelp: `${uid}-pub-help`,
  }

  const dirty = $derived(!sameValues(values, baseline))

  beforeNavigate((nav) => {
    // 새로고침·닫기·외부 주소(type "leave")는 아래 beforeunload 가 맡는다.
    if (allowLeave || !dirty || nav.type === "leave" || !nav.to) return
    if (nav.to.url.pathname === page.url.pathname) return
    nav.cancel()
    pendingLeave = `${nav.to.url.pathname}${nav.to.url.search}${nav.to.url.hash}`
  })

  $effect(() => {
    if (!dirty) return
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault()
      e.returnValue = ""
    }
    window.addEventListener("beforeunload", onBeforeUnload)
    return () => window.removeEventListener("beforeunload", onBeforeUnload)
  })

  const leave = (to: string) => {
    allowLeave = true
    pendingLeave = null
    void goto(to)
  }

  const validate = (): boolean => {
    const next: typeof errors = {}
    const title = values.title.trim()
    if (!title) next.title = "제목을 입력하세요."
    else if (title.length > TITLE_MAX) next.title = `제목은 ${TITLE_MAX}자 이하로 입력하세요.`
    if (isRichTextEmpty(values.body)) next.body = "본문을 입력하세요."
    errors = next
    if (next.title) document.getElementById(ids.title)?.focus()
    else if (next.body)
      document.getElementById(ids.body)?.parentElement?.querySelector<HTMLElement>("[contenteditable]")?.focus()
    return !next.title && !next.body
  }

  const onsubmit = (e: SubmitEvent) => {
    e.preventDefault()
    flash = null
    if (!validate()) return
    const submitted = { ...values, title: values.title.trim() }
    save.mutate(
      {
        id: notice?.id ?? null,
        body: {
          title: submitted.title,
          body_html: submitted.body,
          is_pinned: submitted.pinned,
          is_published: submitted.published,
        },
      },
      {
        onSuccess: (saved) => {
          baseline = { ...submitted }
          values = { ...submitted }
          if (notice === null) {
            allowLeave = true
            void goto(resolve(`admin/notices/${saved.id}/edit`), {
              replace: true,
              state: { flash: { tone: "success", text: "공지를 저장했습니다. 이제 첨부 파일을 올릴 수 있습니다." } },
            })
          } else {
            flash = {
              tone: "success",
              text: saved.is_published ? "저장했습니다. 사용자 화면에 게시 중입니다." : "임시저장했습니다.",
            }
          }
        },
        onError: (err) => (flash = { tone: "error", text: apiErrorMessage(err) }),
      },
    )
  }

  const onDelete = () => {
    if (!notice) return
    remove.mutate(notice.id, {
      onSuccess: () => {
        allowLeave = true
        void goto(resolve("admin/notices"), { replace: true })
      },
      onError: (err) => {
        confirmDelete = false
        flash = { tone: "error", text: apiErrorMessage(err) }
      },
    })
  }
</script>

<PageHeader title={notice ? "공지 수정" : "새 공지"}>
  {#snippet description()}
    {#if notice}
      <span class="inline-flex flex-wrap items-center gap-2">
        {#if notice.is_published}<Chip tone="success">게시</Chip>{:else}<Chip>임시저장</Chip>{/if}
        #{notice.id} · 작성자 {notice.author_username ?? "-"} · 조회 {notice.view_count}
      </span>
    {:else}
      제목과 본문을 쓰고 저장하세요. 첨부 파일은 처음 저장한 뒤 올릴 수 있습니다.
    {/if}
  {/snippet}
  {#snippet actions()}
    <a href={resolve("admin/notices")} class={ui.btnNeutral}>목록으로</a>
    {#if notice?.is_published}
      <a href={resolve(`notices/${notice.id}`)} class={ui.btnNeutral}>사용자 화면에서 보기</a>
    {/if}
  {/snippet}
</PageHeader>

<div class="flex flex-col gap-6">
  {#if flash}
    <Notice tone={flash.tone} onClose={() => (flash = null)}>{flash.text}</Notice>
  {/if}

  <form novalidate {onsubmit} class="{ui.card} flex flex-col gap-5 rounded-xl p-5">
    <div>
      <label for={ids.title} class={ui.label}>제목 <span class="text-error">*</span></label>
      <input
        id={ids.title}
        bind:value={values.title}
        maxlength={TITLE_MAX}
        aria-invalid={errors.title ? true : undefined}
        aria-describedby={errors.title ? ids.titleErr : undefined}
        aria-required="true"
        class={ui.input}
      />
      {#if errors.title}
        <p id={ids.titleErr} class={ui.fieldError}>{errors.title}</p>
      {/if}
    </div>

    <div>
      <p id={ids.body} class="{ui.label} mb-1">본문 <span class="text-error">*</span></p>
      <RichTextEditor
        initialHtml={notice?.body_html ?? ""}
        onChange={(html) => (values.body = html)}
        uploadImage={uploadEditorImage}
        labelId={ids.body}
      />
      {#if errors.body}
        <p id={ids.bodyErr} class={ui.fieldError} role="alert">{errors.body}</p>
      {/if}
    </div>

    <fieldset class="flex flex-col gap-1">
      <legend class="{ui.label} mb-1">설정</legend>
      <label class="flex min-h-11 cursor-pointer items-center gap-3 text-[15px]">
        <input type="checkbox" bind:checked={values.pinned} class="size-5 accent-primary" />
        상단 고정
      </label>
      <label class="flex min-h-11 cursor-pointer items-center gap-3 text-[15px]">
        <input
          type="checkbox"
          bind:checked={values.published}
          aria-describedby={ids.pubHelp}
          class="size-5 accent-primary"
        />
        게시
      </label>
      <p id={ids.pubHelp} class="{ui.help} mt-0">
        게시하면 사용자 화면에 보입니다. 끄면 임시저장으로 관리자만 볼 수 있습니다.
      </p>
    </fieldset>

    <div class="flex flex-wrap items-center gap-2 border-t border-surface-container pt-5">
      <button type="submit" class={ui.btnPrimary} disabled={save.isPending}>
        {save.isPending ? "저장 중…" : "저장"}
      </button>
      {#if dirty}
        <span class="text-sm text-on-surface-variant">저장하지 않은 변경 사항이 있습니다.</span>
      {/if}
      {#if notice}
        <button type="button" class="{ui.btnDanger} ml-auto" onclick={() => (confirmDelete = true)}>삭제</button>
      {/if}
    </div>
  </form>

  {#if notice}
    <AttachmentsPanel noticeId={notice.id} />
  {:else}
    <p class="{ui.card} rounded-xl p-5 text-sm text-on-surface-variant">
      첨부 파일은 공지를 처음 저장한 뒤 올릴 수 있습니다.
    </p>
  {/if}
</div>

{#if confirmDelete && notice}
  <ConfirmDialog
    title="공지를 삭제할까요?"
    confirmLabel="삭제"
    danger
    pending={remove.isPending}
    onConfirm={onDelete}
    onCancel={() => (confirmDelete = false)}
  >
    “{notice.title}” 과 첨부 파일 {notice.attachments.length}개가 삭제되며 되돌릴 수 없습니다.
  </ConfirmDialog>
{/if}

{#if pendingLeave}
  {@const to = pendingLeave}
  <ConfirmDialog
    title="저장하지 않고 나갈까요?"
    confirmLabel="나가기"
    cancelLabel="계속 작성"
    danger
    onConfirm={() => leave(to)}
    onCancel={() => (pendingLeave = null)}
  >
    저장하지 않은 변경 사항이 사라집니다.
  </ConfirmDialog>
{/if}
