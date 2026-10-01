// 에디터 전용 선(stroke) 아이콘 도형 — EditorIcon.svelte 가 <svelte:element> 로 그린다.
// 프로젝트에 아이콘 세트가 없어 의존성 없이 인라인 SVG 로 둔다({@html} 을 쓰지 않도록 도형 목록으로 표현).
export type EditorIconName =
  | "undo" | "redo" | "paragraph" | "h2" | "h3" | "bold" | "italic" | "underline" | "strike"
  | "highlight" | "clear" | "alignLeft" | "alignCenter" | "alignRight" | "ul" | "ol" | "quote"
  | "hr" | "link" | "unlink" | "image" | "video" | "rotateLeft" | "rotateRight" | "trash"
  | "crop" | "replace" | "alt" | "close"

export type IconShape = [tag: "path" | "rect" | "circle", attrs: Record<string, string>]

const p = (...ds: string[]): IconShape[] => ds.map((d) => ["path", { d }])

export const EDITOR_ICONS: Record<EditorIconName, IconShape[]> = {
  undo: p("M9 14 4 9l5-5", "M4 9h10.5a5.5 5.5 0 0 1 0 11H11"),
  redo: p("m15 14 5-5-5-5", "M20 9H9.5a5.5 5.5 0 0 0 0 11H13"),
  paragraph: p("M13 4v16", "M17 4v16", "M19 4H9.5a4.5 4.5 0 0 0 0 9H13"),
  h2: p("M4 12h8", "M4 18V6", "M12 18V6", "M21 18h-4c0-4 4-3 4-6 0-1.5-2-2.5-4-1"),
  h3: p("M4 12h8", "M4 18V6", "M12 18V6", "M17.5 10.5c1.7-1 3.5 0 3.5 1.5a2 2 0 0 1-2 2", "M17 17.5c2 1.5 4 .3 4-1.5a2 2 0 0 0-2-2"),
  bold: p("M6 12h9a4 4 0 0 1 0 8H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h7a4 4 0 0 1 0 8"),
  italic: p("M19 4h-9", "M14 20H5", "M15 4 9 20"),
  underline: p("M6 4v6a6 6 0 0 0 12 0V4", "M4 20h16"),
  strike: p("M16 4H9a3 3 0 0 0-2.83 4", "M14 12a4 4 0 0 1 0 8H6", "M4 12h16"),
  highlight: p("m9 11-6 6v3h9l3-3", "m22 12-4.6 4.6a2 2 0 0 1-2.8 0l-5.2-5.2a2 2 0 0 1 0-2.8L14 4"),
  clear: p("M4 7V4h16v3", "M5 20h6", "M13 4 8 20", "m15 15 5 5", "m20 15-5 5"),
  alignLeft: p("M21 6H3", "M15 12H3", "M17 18H3"),
  alignCenter: p("M21 6H3", "M17 12H7", "M19 18H5"),
  alignRight: p("M21 6H3", "M21 12H9", "M21 18H7"),
  ul: p("M3 6h.01", "M3 12h.01", "M3 18h.01", "M8 6h13", "M8 12h13", "M8 18h13"),
  ol: p("M10 6h11", "M10 12h11", "M10 18h11", "M4 6h1v4", "M4 10h2", "M6 18H4c0-1 2-2 2-3s-1-1.5-2-1"),
  quote: p(
    "M3 21c3 0 7-1 7-8V5c0-1.25-.76-2-2-2H4c-1.25 0-2 .75-2 1.97V11c0 1.25.75 2 2 2 1 0 1 0 1 1v1c0 1-1 2-2 2s-1 .01-1 1.03V20c0 1 0 1 1 1z",
    "M15 21c3 0 7-1 7-8V5c0-1.25-.76-2-2-2h-4c-1.25 0-2 .75-2 1.97V11c0 1.25.75 2 2 2h.75c0 2.25.25 4-2.75 4v3c0 1 0 1 1 1z",
  ),
  hr: [["path", { d: "M3 12h18" }], ["path", { d: "M8 7h8", opacity: ".4" }], ["path", { d: "M8 17h8", opacity: ".4" }]],
  link: p("M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71", "M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"),
  unlink: p(
    "m18.84 12.25 1.72-1.71a5 5 0 0 0-7.07-7.07l-1.72 1.71",
    "m5.17 11.75-1.71 1.71a5 5 0 0 0 7.07 7.07l1.71-1.71",
    "M8 2v3",
    "M2 8h3",
    "M16 22v-3",
    "M22 16h-3",
  ),
  image: [
    ["rect", { x: "3", y: "3", width: "18", height: "18", rx: "2" }],
    ["circle", { cx: "9", cy: "9", r: "2" }],
    ["path", { d: "m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21" }],
  ],
  video: [["rect", { x: "2", y: "5", width: "20", height: "14", rx: "3" }], ["path", { d: "m10 9 5 3-5 3z" }]],
  rotateLeft: p("M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8", "M3 3v5h5"),
  rotateRight: p("M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8", "M21 3v5h-5"),
  trash: p("M3 6h18", "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6", "M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"),
  crop: p("M6 2v14a2 2 0 0 0 2 2h14", "M18 22V8a2 2 0 0 0-2-2H2"),
  replace: p("M3 12a9 9 0 0 1 15-6.7L21 8", "M21 3v5h-5", "M21 12a9 9 0 0 1-15 6.7L3 16", "M8 16H3v5"),
  alt: p("M4 7V4h16v3", "M9 20h6", "M12 4v16"),
  close: p("M18 6 6 18", "m6 6 12 12"),
}
