import { describe, expect, it } from "vitest"
import { loginWithNext, safeNext } from "./returnTo"

describe("safeNext", () => {
  it.each(["/", "/admin", "/admin/notices?page=2", "/notices/3#top", "/me"])("허용: %s", (v) => {
    expect(safeNext(v, "/login")).toBe(v)
  })
  it.each([null, undefined, "", "admin", "https://evil.example", "//evil.example", "/\\evil.example", "/login", "/login?next=/admin"])(
    "거부: %j",
    (v) => {
      expect(safeNext(v, "/login")).toBeNull()
    },
  )
})

describe("loginWithNext", () => {
  it("원래 위치를 인코딩해 next 로 붙인다", () => {
    expect(loginWithNext("/login", "/admin/notices?page=2")).toBe("/login?next=%2Fadmin%2Fnotices%3Fpage%3D2")
  })
  it("홈·로그인 화면·외부 주소는 next 없이", () => {
    expect(loginWithNext("/login", "/")).toBe("/login")
    expect(loginWithNext("/login", "/login")).toBe("/login")
    expect(loginWithNext("/login", "//evil.example")).toBe("/login")
  })
})
