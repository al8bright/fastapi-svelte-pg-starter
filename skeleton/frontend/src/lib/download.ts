// Blob 을 파일로 저장 — Bearer 가 필요한 다운로드(관리자 첨부)는 <a href> 로 받을 수 없어
// axios 로 blob 을 받은 뒤 임시 object URL 로 저장한다.
export function saveBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = filename
  a.rel = "noopener"
  document.body.append(a)
  a.click()
  a.remove()
  // 클릭 직후 해제하면 일부 브라우저가 다운로드를 시작하기 전에 URL 이 사라진다.
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}
