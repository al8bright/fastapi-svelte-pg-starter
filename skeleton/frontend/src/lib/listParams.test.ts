import { describe, expect, it } from "vitest"
import { readListParams, searchWith } from "./listParams"

describe("readListParams", () => {
  it("page 는 1 이상 정수만, 아니면 1", () => {
    expect(readListParams(new URLSearchParams("page=3&q=공지"))).toEqual({ page: 3, q: "공지" })
    expect(readListParams(new URLSearchParams("page=0"))).toEqual({ page: 1, q: "" })
    expect(readListParams(new URLSearchParams("page=abc"))).toEqual({ page: 1, q: "" })
  })
})

describe("searchWith", () => {
  it("검색어가 바뀌면 1페이지로 돌아간다", () => {
    expect(searchWith(new URLSearchParams("page=3&q=a"), { q: "b" })).toBe("?q=b")
  })
  it("빈 값은 지우고 page=1 은 생략한다", () => {
    expect(searchWith(new URLSearchParams("q=a&role=admin"), { q: "" })).toBe("?role=admin")
    expect(searchWith(new URLSearchParams("q=a"), { page: 1 })).toBe("?q=a")
    expect(searchWith(new URLSearchParams(""), { page: 2 })).toBe("?page=2")
    expect(searchWith(new URLSearchParams("user_id=3"), { user_id: null })).toBe("")
  })
})
