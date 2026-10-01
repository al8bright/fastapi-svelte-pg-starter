# __PROJECT_NAME__ 작업 계획 (PLAN.md)

> TDD 순서대로 진행한다. **한 번에 실패하는 테스트 하나**(Red) → 최소 구현(Green) → 정리(Refactor).
> 구조 변경(Structural)과 동작 변경(Behavioral)을 분리한다.

## 0. 부트스트랩 (ARCHITECTURE.md §21 체크리스트)

- [ ] 저장소 구조 생성 (`backend/`, `frontend/`, `docs/`, `.env.example`, `.gitignore`)
- [ ] 백엔드 `app/` 골격: `main.py`, `config.py`, `dependencies.py`, `db/`, `core/security.py`
- [ ] `Settings` + `get_settings()`, CORS, `TZ=Asia/Seoul`
- [ ] PostgreSQL `connect_args` KST 고정
- [ ] Alembic 초기화 + 초기 마이그레이션
- [ ] `pytest` + SQLite in-memory + `conftest.py` 픽스처
- [ ] SvelteKit `src/` 골격: axios `lib/api/client.ts`, runes 인증 스토어(`lib/stores/auth.svelte.ts`), `+layout.svelte`의 QueryClientProvider
- [ ] `(protected)/+layout.ts` 인증 가드 + 로그인 흐름
- [ ] SvelteKit SPA 설정(`adapter-static` + `ssr = false`)
- [ ] Tailwind v4 `@theme`, pnpm, ESLint + svelte-check
- [ ] CI 동작 확인 — push 이후 사후 안전망(게이트는 push 전 로컬 검증). 협업자가 생기면 `main` 보호 + PR 흐름

## 1. <첫 기능>

- [ ] (Red) 실패 테스트: <테스트명>
- [ ] (Green) 최소 구현
- [ ] (Refactor) 정리

## 2. <다음 기능>

- [ ] ...
