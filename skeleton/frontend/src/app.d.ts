// SvelteKit 전역 타입 선언 (architecture.md §13).
// SPA 모드라 서버 전용 타입(Locals/Platform)은 쓰지 않지만, 확장 지점으로 남겨 둔다.
declare global {
  namespace App {
    // interface Error {}
    // interface Locals {}
    // interface PageData {}
    // interface PageState {}
    // interface Platform {}
  }
}

export {}
