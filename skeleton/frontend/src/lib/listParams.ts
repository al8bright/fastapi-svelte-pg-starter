// 목록 화면의 page·q 등을 URL 검색 파라미터에 둔다 — 새로고침·뒤로 가기·링크 공유에도 상태가 유지된다.
// 읽기는 $app/state 의 page.url.searchParams 에서, 쓰기는 searchWith 가 만든 "?..." 를 붙여
// goto(경로 + 검색, { reset: false }) 한다 — 스크롤·포커스를 유지한 채 목록만 바뀐다.

/** URLSearchParams 와 SvelteKit 의 ReadonlyURLSearchParams(page.url.searchParams) 모두 받는다. */
type SearchParamsLike = { get(name: string): string | null; toString(): string }

/** URL 의 page(1 이상 정수, 아니면 1)·q. */
export function readListParams(params: SearchParamsLike): { page: number; q: string } {
  const raw = Number(params.get("page") ?? "1")
  return { page: Number.isInteger(raw) && raw > 0 ? raw : 1, q: params.get("q") ?? "" }
}

/**
 * 바뀐 값을 반영한 검색 문자열("?a=1" 또는 ""). 빈 값은 지우고, page 외의 값이 바뀌면 1페이지로 돌아간다.
 * (useListParams 의 update 와 같은 규칙)
 */
export function searchWith(current: SearchParamsLike, changes: Record<string, string | number | null>): string {
  const next = new URLSearchParams(current.toString())
  for (const [key, value] of Object.entries(changes)) {
    if (value === null || value === "") next.delete(key)
    else next.set(key, String(value))
  }
  if (!("page" in changes)) next.delete("page")
  if (next.get("page") === "1") next.delete("page")
  const s = next.toString()
  return s ? `?${s}` : ""
}
