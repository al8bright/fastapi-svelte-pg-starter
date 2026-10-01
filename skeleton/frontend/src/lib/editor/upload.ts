// 에디터 이미지 업로드 기본 구현 (editor-spec §0-7·§4 ⑤).
// 에디터(RichTextEditor)는 백엔드를 직접 부르지 않고 `uploadImage` prop 으로 받은 함수만 쓴다.
// 관리자 화면은 보통 이 함수를 그대로 넘긴다: <RichTextEditor uploadImage={uploadEditorImage} … />
//
// 공용 axios 인스턴스(lib/api/client.ts)를 써서 Bearer 주입·401 single-flight refresh·재시도를 그대로 탄다(§13·§14).
import { isAxiosError } from "axios"
import { api } from "#lib/api/client.js"

/** 업로드 성공 — 본문 `<img>` 에 넣을 공개 URL 과 서버가 재인코딩한 실제 크기. */
export interface EditorUploadSuccess {
  url: string
  width: number
  height: number
}

/** 업로드 실패 — 에디터 하단에 그대로 보여 줄 한국어 문구. */
export interface EditorUploadFailure {
  error: string
}

export type EditorUploadResult = EditorUploadSuccess | EditorUploadFailure

/** 에디터가 받는 업로드 함수 계약 — reject 하지 않고 실패는 `{ error }` 로 돌려준다. */
export type UploadImageFn = (file: Blob, filename: string) => Promise<EditorUploadResult>

/** 백엔드 응답 (`POST /api/v1/admin/editor/images`). */
export interface EditorImageResponse {
  key: string
  url: string
  width: number
  height: number
}

export const EDITOR_IMAGE_ENDPOINT = "/admin/editor/images"

/**
 * 백엔드가 준 `url` 을 브라우저에서 쓸 주소로 맞춘다.
 * - 절대 URL 은 그대로.
 * - 루트 상대(`/uploads/...`)는 백엔드를 다른 오리진(VITE_API_BASE_URL)에 둔 경우에만 그 오리진을 붙인다.
 *   dev 에서는 Vite proxy(`/uploads`)가 같은 오리진으로 넘겨 준다.
 */
export function resolveUploadUrl(url: string, apiBase: string | undefined = import.meta.env.VITE_API_BASE_URL): string {
  if (!url.startsWith("/") || url.startsWith("//") || !apiBase) return url
  return `${apiBase.replace(/\/+$/, "")}${url}`
}

/** 업로드 오류 → 사용자 문구. 상태코드로 구분한다(§13 — 모든 실패를 한 문구로 뭉개지 않는다). */
export function editorUploadErrorMessage(error: unknown): string {
  if (!isAxiosError(error)) return "이미지를 올리지 못했습니다. 잠시 후 다시 시도해 주세요."
  if (!error.response) return "네트워크 오류로 이미지를 올리지 못했습니다. 연결을 확인해 주세요."
  const { status, data } = error.response
  const detail = (data as { detail?: unknown } | undefined)?.detail
  switch (status) {
    case 413:
      return "이미지는 5MB 이하만 올릴 수 있습니다."
    case 415:
      return "PNG·JPEG·WebP·GIF 이미지만 올릴 수 있습니다."
    case 422:
      // FastAPI 검증 오류의 detail 은 객체 배열이다 — 문자열일 때만 그대로 보여 준다.
      return typeof detail === "string" && detail
        ? detail
        : "이미지를 처리할 수 없습니다. 다른 파일로 다시 시도해 주세요."
    case 401:
      return "로그인이 만료되었습니다. 다시 로그인한 뒤 올려 주세요."
    case 403:
      return "이미지를 올릴 권한이 없습니다."
    default:
      return "이미지를 올리지 못했습니다. 잠시 후 다시 시도해 주세요."
  }
}

/** 관리자 에디터 이미지 업로드 — multipart `file` 필드. 실패해도 reject 하지 않는다. */
export async function uploadEditorImage(file: Blob, filename: string): Promise<EditorUploadResult> {
  const form = new FormData()
  form.append("file", file, filename)
  try {
    // Content-Type 은 지정하지 않는다 — axios 가 FormData 를 보고 boundary 를 포함해 채운다.
    const { data } = await api.post<EditorImageResponse>(EDITOR_IMAGE_ENDPOINT, form)
    return { url: resolveUploadUrl(data.url), width: data.width, height: data.height }
  } catch (error) {
    return { error: editorUploadErrorMessage(error) }
  }
}
