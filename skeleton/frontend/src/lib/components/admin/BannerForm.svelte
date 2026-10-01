<script lang="ts">
  import { createMutation } from "@tanstack/svelte-query"
  import { goto } from "$app/navigation"
  import { resolve } from "$app/paths"
  import { type BannerAdmin, uploadBannerImage } from "#lib/api/banners.js"
  import PageHeader from "#lib/components/layout/PageHeader.svelte"
  import Notice from "#lib/components/ui/Notice.svelte"
  import { ui } from "#lib/components/ui/styles.js"
  import { apiErrorMessage } from "#lib/apiError.js"
  import { editorImageProblem } from "#lib/editor/richText.js"
  import { resolveUploadUrl } from "#lib/editor/upload.js"
  import { fromDateTimeLocal } from "#lib/format.js"
  import { LINK_URL_MAX_LENGTH } from "#lib/linkUrl.js"
  import { createSaveBanner } from "#lib/queries/banners.js"
  import { MAX_IMAGE_MB } from "#lib/uploadRules.js"
  import { type BannerErrors, type BannerValues, bannerValuesOf, validateBanner } from "./bannerForm.js"

  // 배너 작성(/admin/banners/new)·수정(/admin/banners/[id]/edit) 폼.
  // 이미지를 먼저 올려(POST /admin/banners/image, FormData `file`) key 를 받고, 저장 때 image_key 로 참조한다.
  // 노출 기간은 KST 기준 datetime-local 값(초 없이)이며 서버로는 KST naive 문자열로 보낸다.

  const { banner }: { banner: BannerAdmin | null } = $props()

  const save = createSaveBanner()
  const upload = createMutation(() => ({ mutationFn: (file: File) => uploadBannerImage(file) }))

  // svelte-ignore state_referenced_locally
  let values = $state<BannerValues>(bannerValuesOf(banner))
  let errors = $state<BannerErrors>({})
  let serverError = $state<string | null>(null)

  const uid = $props.id()
  const id = {
    image: `${uid}-image`,
    imageErr: `${uid}-image-err`,
    title: `${uid}-title`,
    titleErr: `${uid}-title-err`,
    alt: `${uid}-alt`,
    altErr: `${uid}-alt-err`,
    altHelp: `${uid}-alt-help`,
    link: `${uid}-link`,
    linkErr: `${uid}-link-err`,
    linkHelp: `${uid}-link-help`,
    start: `${uid}-start`,
    end: `${uid}-end`,
    periodErr: `${uid}-period-err`,
  }

  const describe = (...ids: (string | false | undefined)[]) => ids.filter(Boolean).join(" ") || undefined

  const onImage = (e: Event & { currentTarget: HTMLInputElement }) => {
    const file = e.currentTarget.files?.[0]
    e.currentTarget.value = ""
    if (!file) return
    const problem = editorImageProblem(file)
    if (problem) {
      errors = { ...errors, image: problem }
      return
    }
    errors = { ...errors, image: undefined }
    upload.mutate(file, {
      onSuccess: (img) => (values.image = img),
      onError: (err) => (errors = { ...errors, image: apiErrorMessage(err, { maxMb: MAX_IMAGE_MB }) }),
    })
  }

  const onsubmit = (e: SubmitEvent) => {
    e.preventDefault()
    serverError = null
    const next = validateBanner(values)
    errors = next
    const first = (["image", "title", "alt", "link", "period"] as const).find((k) => next[k])
    if (first) {
      const focusId = { image: id.image, title: id.title, alt: id.alt, link: id.link, period: id.start }[first]
      document.getElementById(focusId)?.focus()
      return
    }
    save.mutate(
      {
        id: banner?.id ?? null,
        body: {
          title: values.title.trim(),
          image_key: values.image!.key,
          link_url: values.link.trim() || null,
          alt_text: values.alt.trim(),
          starts_at: fromDateTimeLocal(values.startsAt),
          ends_at: fromDateTimeLocal(values.endsAt),
          is_active: values.active,
        },
      },
      {
        onSuccess: () => void goto(resolve("admin/banners")),
        onError: (err) => (serverError = apiErrorMessage(err)),
      },
    )
  }
</script>

<PageHeader
  title={banner ? "배너 수정" : "새 배너"}
  description="권장 이미지 비율 3:1(예: 1440×480). 모바일에서는 16:9 로 가운데가 잘려 보입니다."
>
  {#snippet actions()}
    <a href={resolve("admin/banners")} class={ui.btnNeutral}>목록으로</a>
  {/snippet}
</PageHeader>

<form novalidate {onsubmit} class="{ui.card} flex max-w-3xl flex-col gap-5 rounded-xl p-5">
  {#if serverError}
    <Notice tone="error">{serverError}</Notice>
  {/if}

  <div>
    <label for={id.image} class={ui.label}>배너 이미지 <span class="text-error">*</span></label>
    {#if values.image}
      <img
        src={resolveUploadUrl(values.image.url)}
        alt="업로드한 배너 미리보기"
        width={values.image.width}
        height={values.image.height}
        class="mt-2 aspect-[3/1] w-full rounded-lg border border-outline-variant bg-surface object-cover"
      />
    {/if}
    <input
      id={id.image}
      type="file"
      accept="image/png,image/jpeg,image/webp,image/gif"
      onchange={onImage}
      disabled={upload.isPending}
      aria-invalid={errors.image ? true : undefined}
      aria-describedby={describe(errors.image && id.imageErr)}
      class="mt-2 block w-full rounded text-sm text-on-surface-variant file:mr-3 file:min-h-11 file:cursor-pointer file:rounded file:border-0 file:bg-primary file:px-4 file:font-semibold file:text-on-primary {ui.focusRing}"
    />
    <p class={ui.help}>
      {upload.isPending
        ? "이미지를 올리는 중…"
        : `PNG·JPEG·WebP·GIF, ${MAX_IMAGE_MB}MB 이하. ${values.image ? "다른 파일을 고르면 교체됩니다." : ""}`}
    </p>
    {#if errors.image}
      <p id={id.imageErr} class={ui.fieldError}>{errors.image}</p>
    {/if}
  </div>

  <div>
    <label for={id.title} class={ui.label}>제목 <span class="text-error">*</span></label>
    <input
      id={id.title}
      bind:value={values.title}
      maxlength={200}
      aria-invalid={errors.title ? true : undefined}
      aria-describedby={describe(errors.title && id.titleErr)}
      class={ui.input}
    />
    {#if errors.title}
      <p id={id.titleErr} class={ui.fieldError}>{errors.title}</p>
    {/if}
  </div>

  <div>
    <label for={id.alt} class={ui.label}>대체 텍스트 <span class="text-error">*</span></label>
    <input
      id={id.alt}
      bind:value={values.alt}
      maxlength={200}
      aria-invalid={errors.alt ? true : undefined}
      aria-describedby={describe(id.altHelp, errors.alt && id.altErr)}
      class={ui.input}
    />
    <p id={id.altHelp} class={ui.help}>화면 낭독기 사용자에게 읽히는 설명입니다. 이미지 속 문구를 그대로 적어 주세요.</p>
    {#if errors.alt}
      <p id={id.altErr} class={ui.fieldError}>{errors.alt}</p>
    {/if}
  </div>

  <div>
    <label for={id.link} class={ui.label}>링크 URL</label>
    <input
      id={id.link}
      bind:value={values.link}
      maxlength={LINK_URL_MAX_LENGTH}
      inputmode="url"
      placeholder="/notices/1 또는 https://example.com"
      aria-invalid={errors.link ? true : undefined}
      aria-describedby={describe(id.linkHelp, errors.link && id.linkErr)}
      class={ui.input}
    />
    <p id={id.linkHelp} class={ui.help}>
      비우면 클릭할 수 없는 배너가 됩니다. / 로 시작하면 사이트 안에서, http(s) 주소는 새 창으로 엽니다.
    </p>
    {#if errors.link}
      <p id={id.linkErr} class={ui.fieldError}>{errors.link}</p>
    {/if}
  </div>

  <fieldset>
    <legend class={ui.label}>노출 기간 (한국 시각)</legend>
    <div class="mt-1 grid gap-3 sm:grid-cols-2">
      <div>
        <label for={id.start} class="text-sm text-on-surface-variant">시작</label>
        <input
          id={id.start}
          type="datetime-local"
          bind:value={values.startsAt}
          aria-invalid={errors.period ? true : undefined}
          aria-describedby={describe(errors.period && id.periodErr)}
          class={ui.input}
        />
      </div>
      <div>
        <label for={id.end} class="text-sm text-on-surface-variant">종료</label>
        <input
          id={id.end}
          type="datetime-local"
          bind:value={values.endsAt}
          aria-invalid={errors.period ? true : undefined}
          aria-describedby={describe(errors.period && id.periodErr)}
          class={ui.input}
        />
      </div>
    </div>
    <p class={ui.help}>비우면 기간 제한 없이 노출합니다.</p>
    {#if errors.period}
      <p id={id.periodErr} class={ui.fieldError}>{errors.period}</p>
    {/if}
  </fieldset>

  <label class="flex min-h-11 cursor-pointer items-center gap-3 text-[15px]">
    <input type="checkbox" bind:checked={values.active} class="size-5 accent-primary" />
    활성 (끄면 기간과 관계없이 숨김)
  </label>

  <div class="flex gap-2 border-t border-surface-container pt-5">
    <button type="submit" class={ui.btnPrimary} disabled={save.isPending || upload.isPending}>
      {save.isPending ? "저장 중…" : "저장"}
    </button>
    <a href={resolve("admin/banners")} class={ui.btnNeutral}>취소</a>
  </div>
</form>
