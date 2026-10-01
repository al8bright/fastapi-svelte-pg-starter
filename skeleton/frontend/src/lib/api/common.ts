// 공통 응답 타입 (백엔드 schemas/common.py 와 동기화).

/** 목록 페이지 응답 — page 는 1부터, total 은 필터 적용 후 전체 건수. */
export interface Page<T> {
  items: T[]
  total: number
  page: number
  size: number
}

/** 목록 조회 공통 파라미터 — page 기본 1, size 기본 20(1–100), q ≤100자. */
export interface PageParams {
  page?: number
  size?: number
  q?: string
}

/** 이미지 업로드 응답 — key 는 이후 요청(배너 저장 등)에서 참조, url 은 바로 표시용. */
export interface UploadedImage {
  key: string
  url: string
  width: number
  height: number
}

/** 빈 문자열·undefined 파라미터를 빼서 axios params 로 넘긴다(`?q=` 같은 빈 검색 방지). */
export function cleanParams<T extends object>(params: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== ""),
  ) as Partial<T>
}
