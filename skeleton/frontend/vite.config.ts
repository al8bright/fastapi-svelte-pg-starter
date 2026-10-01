import adapter from "@sveltejs/adapter-static"
import { sveltekit } from "@sveltejs/kit/vite"
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte"
import tailwindcss from "@tailwindcss/vite"
import { defineConfig } from "vitest/config"

// https://vite.dev/config/
// SvelteKit 3: svelte.config.js 는 더 이상 쓰지 않는다 — 설정은 sveltekit(...) 플러그인 옵션으로 넘긴다.
// 경로 별칭은 package.json "imports" 의 #lib(→ src/lib, Node subpath imports)을 쓰므로 resolve.alias 를 따로 두지 않는다.
// defineConfig 는 vitest/config 판이다 — 같은 파일에 test(vitest) 설정을 함께 둔다(vite 설정과 동일 타입 + test 키).
export default defineConfig({
  plugins: [
    tailwindcss(),
    // SvelteKit 설정 (ARCHITECTURE.md §13).
    // SPA 모드: 백엔드가 별도 FastAPI 서버이고 인증 상태(access 토큰)가 브라우저 메모리에만 있으므로 SSR 을 쓰지 않는다.
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
    // /api 프록시: 개발 중 프론트와 같은 오리진으로 보이므로 refresh 쿠키(Path=/api/v1/auth)가 그대로 오간다.
    // /uploads 프록시: 에디터·배너 이미지와 공개 첨부 다운로드 URL 이 루트 상대(/uploads/...)로 오므로 같은 백엔드로 넘긴다.
    // (운영에서는 정적 호스팅/리버스 프록시가 /api 와 /uploads 를 백엔드로 넘긴다 — ARCHITECTURE.md §14 "운영 배치")
    proxy: {
      "/api": "http://localhost:8000",
      "/uploads": "http://localhost:8000",
    },
  },
  // vitest 에서만: svelte 의 브라우저 빌드를 쓰게 한다(없으면 서버 빌드가 잡혀 컴포넌트 테스트의 mount() 가 실패한다).
  resolve: process.env.VITEST ? { conditions: ["browser"] } : undefined,
  // 단위 테스트 (vitest + jsdom) — 에디터 순수 모듈·폼 검증·업로드 오류 문구, 그리고 svelte mount() 로 그리는
  // 컴포넌트 연기 테스트(*.test.ts — 별도 테스트 라이브러리 없음).
  test: {
    environment: "jsdom",
    include: ["src/**/*.test.ts"],
  },
})
