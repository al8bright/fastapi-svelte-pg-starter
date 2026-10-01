import { AxiosError } from "axios"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { api } from "#lib/api/client.js"
import { authStore } from "#lib/stores/auth.svelte.js"
import { bearerOf, type Handler, mockAdapter } from "../../test/mockAdapter"
import { EDITOR_IMAGE_ENDPOINT, editorUploadErrorMessage, resolveUploadUrl, uploadEditorImage } from "./upload"

const originalAdapter = api.defaults.adapter

function useHandler(handler: Handler) {
  const spy = vi.fn(handler)
  api.defaults.adapter = mockAdapter(spy)
  return spy
}

describe("uploadEditorImage", () => {
  beforeEach(() => {
    authStore.setSession("admin-token")
  })
  afterEach(() => {
    api.defaults.adapter = originalAdapter
    authStore.clear()
  })

  it("multipart file 필드로 Bearer 와 함께 POST 하고 url·크기를 돌려준다", async () => {
    const spy = useHandler(() => [201, { key: "public/editor/a.webp", url: "/uploads/public/editor/a.webp", width: 640, height: 360 }])
    const result = await uploadEditorImage(new Blob(["x"], { type: "image/webp" }), "a.webp")

    expect(result).toEqual({ url: "/uploads/public/editor/a.webp", width: 640, height: 360 })
    const config = spy.mock.calls[0][0]
    expect(config.method).toBe("post")
    expect(config.url).toBe(EDITOR_IMAGE_ENDPOINT)
    expect(bearerOf(config)).toBe("admin-token")
    expect(config.data).toBeInstanceOf(FormData)
    const file = (config.data as FormData).get("file") as File
    expect(file.name).toBe("a.webp")
  })

  it.each([
    [413, undefined, /5MB/],
    [415, undefined, /PNG·JPEG·WebP·GIF/],
    [422, { detail: "이미지를 읽을 수 없습니다." }, /이미지를 읽을 수 없습니다/],
    [422, { detail: [{ loc: ["body", "file"], msg: "Field required" }] }, /처리할 수 없습니다/],
    [403, undefined, /권한/],
    [500, undefined, /잠시 후/],
  ])("%i → 한국어 문구로 { error } (reject 하지 않음)", async (status, body, message) => {
    useHandler(() => [status, body ?? {}])
    const result = await uploadEditorImage(new Blob(["x"]), "a.png")
    expect("error" in result && result.error).toMatch(message)
  })

  it("네트워크 오류도 { error }", async () => {
    api.defaults.adapter = async (config) => {
      throw new AxiosError("Network Error", AxiosError.ERR_NETWORK, config)
    }
    const result = await uploadEditorImage(new Blob(["x"]), "a.png")
    expect("error" in result && result.error).toMatch(/네트워크/)
  })
})

describe("editorUploadErrorMessage", () => {
  it("axios 오류가 아니면 일반 문구", () => {
    expect(editorUploadErrorMessage(new Error("x"))).toMatch(/올리지 못했습니다/)
  })
})

describe("resolveUploadUrl", () => {
  it("API 를 다른 오리진에 두지 않았으면 루트 상대 경로 그대로", () => {
    expect(resolveUploadUrl("/uploads/a.webp", undefined)).toBe("/uploads/a.webp")
    expect(resolveUploadUrl("/uploads/a.webp", "")).toBe("/uploads/a.webp")
  })
  it("VITE_API_BASE_URL 이 있으면 루트 상대 경로에 그 오리진을 붙인다", () => {
    expect(resolveUploadUrl("/uploads/a.webp", "https://api.example.com/")).toBe("https://api.example.com/uploads/a.webp")
  })
  it("절대 URL·프로토콜 상대 URL 은 그대로", () => {
    expect(resolveUploadUrl("https://cdn.example.com/a.webp", "https://api.example.com")).toBe(
      "https://cdn.example.com/a.webp",
    )
    expect(resolveUploadUrl("//cdn.example.com/a.webp", "https://api.example.com")).toBe("//cdn.example.com/a.webp")
  })
})
