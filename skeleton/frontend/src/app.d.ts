// SvelteKit 전역 타입 선언 (ARCHITECTURE.md §13).
// SPA 모드라 서버 전용 타입(Locals/Platform)은 쓰지 않지만, 확장 지점으로 남겨 둔다.
declare global {
  namespace App {
    // interface Error {}
    // interface Locals {}
    // interface PageData {}
    /** goto(url, { state }) 로 다음 화면에 넘기는 히스토리 상태 — page.state 로 읽는다. */
    interface PageState {
      /** 작업 결과 알림(예: 새 공지 저장 후 수정 화면으로 옮겨 가며 띄우는 문구). */
      flash?: { tone: "success" | "error"; text: string }
    }
    // interface Platform {}
  }
}

export {}
