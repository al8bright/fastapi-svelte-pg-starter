import adapter from "@sveltejs/adapter-static"
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte"

// SvelteKit 설정 (architecture.md §13).
// SPA 모드: 백엔드가 별도 FastAPI 서버이고 JWT 를 localStorage 에 두므로 SSR 을 쓰지 않는다.
// adapter-static + fallback: index.html → 어떤 경로로 새로고침해도 클라이언트 라우터가 받는다.
/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter({
      pages: "build",
      assets: "build",
      fallback: "index.html",
      precompress: false,
      strict: false,
    }),
  },
}

export default config
