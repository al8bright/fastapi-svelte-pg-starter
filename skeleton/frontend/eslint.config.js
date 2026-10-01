import js from "@eslint/js"
import svelte from "eslint-plugin-svelte"
import globals from "globals"
import tseslint from "typescript-eslint"
import { loadConfig } from "@sveltejs/load-config"

// SvelteKit 3 은 svelte.config.js 가 없다 — vite.config.ts 의 sveltekit(...) 옵션을 읽어 eslint-plugin-svelte 에 넘긴다.
const svelteConfig = (await loadConfig("./", { traverse: false }))?.config

export default tseslint.config(
  { ignores: [".svelte-kit", "build", "dist", "node_modules"] },
  {
    extends: [js.configs.recommended, ...tseslint.configs.recommended, ...svelte.configs.recommended],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
    },
  },
  {
    // .svelte / .svelte.ts 는 svelte-eslint-parser 가 처리하고, 내부 <script lang="ts"> 는 ts 파서에 넘긴다.
    files: ["**/*.svelte", "**/*.svelte.ts"],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
        extraFileExtensions: [".svelte"],
        svelteConfig,
      },
    },
  },
)
