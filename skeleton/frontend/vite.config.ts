import adapter from "@sveltejs/adapter-static"
import { sveltekit } from "@sveltejs/kit/vite"
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte"
import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "vite"

// https://vite.dev/config/
// SvelteKit 3: svelte.config.js 는 더 이상 쓰지 않는다 — 설정은 sveltekit(...) 플러그인 옵션으로 넘긴다.
// 경로 별칭은 package.json "imports" 의 #lib(→ src/lib, Node subpath imports)을 쓰므로 resolve.alias 를 따로 두지 않는다.
export default defineConfig({
  plugins: [
    tailwindcss(),
    // SvelteKit 설정 (ARCHITECTURE.md §13).
    // SPA 모드: 백엔드가 별도 FastAPI 서버이고 JWT 를 localStorage 에 두므로 SSR 을 쓰지 않는다.
    // adapter-static + fallback: index.html → 어떤 경로로 새로고침해도 클라이언트 라우터가 받는다.
    sveltekit({
      preprocess: vitePreprocess(),
      adapter: adapter({
        pages: "build",
        assets: "build",
        fallback: "index.html",
        precompress: false,
        strict: false,
      }),
    }),
  ],
  server: {
    host: true,
    port: 5173,
    proxy: {
      "/api": "http://localhost:8000",
    },
  },
})
