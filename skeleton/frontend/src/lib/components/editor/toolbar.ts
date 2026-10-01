import type { ActiveState } from "./editorDom.js"
import type { EditorIconName } from "./editorIcons.js"

// 에디터 툴바 정의 — 버튼 순서·라벨·아이콘·토글 판정. EditorToolbar.svelte 가 그린다.

export type ToolbarCommand =
  | "undo" | "redo" | "p" | "h2" | "h3" | "bold" | "italic" | "underline" | "strike" | "mark"
  | "clear" | "align-left" | "align-center" | "align-right" | "ul" | "ol" | "blockquote" | "hr"
  | "link" | "unlink" | "image" | "video"

export interface ToolbarItem {
  command: ToolbarCommand
  label: string
  icon: EditorIconName
  /** 토글 버튼이면 활성 여부. 일반 버튼이면 undefined(aria-pressed 미표시). */
  pressed?: (s: ActiveState) => boolean
  /** roving tabindex 순번(그룹을 펼친 순서). */
  index: number
}

const GROUPS: Omit<ToolbarItem, "index">[][] = [
  [
    { command: "undo", label: "실행 취소 (Ctrl+Z)", icon: "undo" },
    { command: "redo", label: "다시 실행 (Ctrl+Shift+Z)", icon: "redo" },
  ],
  [
    { command: "p", label: "본문", icon: "paragraph", pressed: (s) => s.block === "p" },
    { command: "h2", label: "제목 2", icon: "h2", pressed: (s) => s.block === "h2" },
    { command: "h3", label: "제목 3", icon: "h3", pressed: (s) => s.block === "h3" },
  ],
  [
    { command: "bold", label: "굵게 (Ctrl+B)", icon: "bold", pressed: (s) => s.bold },
    { command: "italic", label: "기울임 (Ctrl+I)", icon: "italic", pressed: (s) => s.italic },
    { command: "underline", label: "밑줄 (Ctrl+U)", icon: "underline", pressed: (s) => s.underline },
    { command: "strike", label: "취소선", icon: "strike", pressed: (s) => s.strike },
    { command: "mark", label: "형광펜", icon: "highlight", pressed: (s) => s.mark },
    { command: "clear", label: "서식 지우기", icon: "clear" },
  ],
  [
    { command: "align-left", label: "왼쪽 정렬", icon: "alignLeft", pressed: (s) => s.align === "left" },
    { command: "align-center", label: "가운데 정렬", icon: "alignCenter", pressed: (s) => s.align === "center" },
    { command: "align-right", label: "오른쪽 정렬", icon: "alignRight", pressed: (s) => s.align === "right" },
  ],
  [
    { command: "ul", label: "글머리 목록", icon: "ul", pressed: (s) => s.ul },
    { command: "ol", label: "번호 목록", icon: "ol", pressed: (s) => s.ol },
    { command: "blockquote", label: "인용", icon: "quote", pressed: (s) => s.block === "blockquote" },
    { command: "hr", label: "구분선", icon: "hr" },
  ],
  [
    { command: "link", label: "링크 걸기", icon: "link", pressed: (s) => s.link },
    { command: "unlink", label: "링크 풀기", icon: "unlink" },
    { command: "image", label: "이미지", icon: "image" },
    { command: "video", label: "영상", icon: "video" },
  ],
]

/** 그룹별 버튼 + roving tabindex 순번(미리 계산). */
export const TOOLBAR_GROUPS: ToolbarItem[][] = (() => {
  let n = 0
  return GROUPS.map((group) => group.map((item) => ({ ...item, index: n++ })))
})()
