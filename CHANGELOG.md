# Changelog

스캐폴드 템플릿 `fastapi-svelte-pg-starter` 의 변경 이력.
형식은 [Keep a Changelog](https://keepachangelog.com/) 를 느슨히 따른다.

---

## 2026-10-02 — 공지사항·배너·관리자 API + 업로드 저장소·본문 HTML 정화 (네 템플릿 공통 백엔드) + 사용자 화면·관리자 콘솔 (SvelteKit)

### Added (백엔드 — 공통)

- **테이블 3종** (alembic `0004_notices_banners`) — `notices`(정화된 `body_html`, 고정·게시·`published_at`·조회수, `author_id` SET NULL),
  `notice_attachments`(공지 CASCADE, 공지당 최대 10개), `banners`(이미지 key·크기, `link_url`, 노출 기간 `starts_at`/`ends_at`, 순서, 활성).
- **공개 API** — `GET /notices`(게시분만, 고정 먼저 → 게시일 최신순, `page·size·q`), `GET /notices/{id}`(조회수 +1, 첨부 목록),
  `GET /notices/{id}/attachments/{aid}`(attachment + RFC 5987 `filename*` 한글 파일명 + nosniff), `GET /banners`(활성 + KST 노출 기간 안).
- **관리자 API** (`/admin/*`, 라우터 단위 `require_admin` — 비로그인 401, 일반 사용자 403) — 대시보드 집계(사용자·세션·잠금·공지·배너·DB 상태·Alembic 리비전),
  사용자 목록·권한/활성 변경(자기 강등·비활성화 금지, 마지막 활성 관리자 보호 409, 비활성화 시 세션 전부 폐기), 세션 목록·강제 폐기,
  로그인 잠금 목록·해제, 공지 CRUD·첨부 업로드/다운로드/삭제, 배너 CRUD·이미지 업로드·순서 변경, 에디터 이미지 업로드(`POST /admin/editor/images` → `{key,url,width,height}`).
- **업로드 저장소** `app/core/storage.py` — `UPLOAD_DIR`(기본 `backend/uploads/`, `.gitignore`) 아래 서버 생성 키로만 저장.
  이미지는 시그니처 + Pillow 검증(PNG·JPEG·WebP·GIF), EXIF 방향 반영 후 메타데이터 없이 재인코딩, 긴 변 2000px 초과 축소, GIF 는 원본 그대로.
  첨부는 확장자 허용 목록·무작위 파일명(원본 이름은 DB). `public/` 만 `/uploads/public` 으로 정적 서빙하고 `private/` 첨부는 API 로만 내려간다.
- **본문 HTML 정화** `app/core/sanitize.py`(nh3) — 유튜브 embed 외 iframe 제거 + sandbox 등 강제, `style`·`on*`·`javascript:`·`data:` 제거,
  링크 `rel="noopener noreferrer"`. 공지 저장 시 서비스 계층에서 항상 정화하고, 정화 후 빈 본문은 422.
- 새 설정 `UPLOAD_DIR`·`PUBLIC_FILES_BASE_URL`·`MAX_IMAGE_UPLOAD_MB`(5)·`MAX_ATTACHMENT_UPLOAD_MB`(20)(`backend/.env.example` 에 설명과 함께 추가),
  의존성 `nh3==0.3.7`·`pillow==12.3.0`.
- `ServiceError`·`StorageError` 전역 핸들러(`app/api/errors.py`) — 코드별 HTTP 상태 표 한 곳, 응답 `{"detail","code"}`.
- 백엔드 테스트 107 → **319** 건(`test_sanitize`·`test_storage`·`test_uploads_serving`·`test_notices`·`test_banners`·`test_admin`).
  백엔드는 react·nextjs·nuxt 저장소의 `skeleton/backend` 와 파일 단위로 같다(`.env.example` 만 이 템플릿 값).

### Added (프론트엔드 — 사용자 화면 디자인 A · 관리자 콘솔 디자인 A)

- **공개 사용자 화면** (라우트 그룹 `routes/(site)/` — 상단 내비 포털): 첫 화면 `/` 를 로그인 없이 공개. 홈은 배너 캐러셀(`GET /banners` — 이전/다음·점 버튼,
  6초 자동 넘김은 마우스 올림·포커스·일시정지 버튼으로 멈춤, `prefers-reduced-motion` 이면 자동 넘김 없음, 외부 링크는 새 창 `noopener`)
  — 배너가 없으면 기본 히어로, 주요 서비스(자리표시), 최신 공지 5건, 내 계정. `/notices`(고정 배지·첨부 표시·제목 검색·페이지, URL 파라미터),
  `/notices/[id]`(게시일·조회수·`RichContent` 본문·첨부 `download_url`·목록으로), `/me`(내 정보, `(site)/(protected)` 가드). 계정 메뉴(내 정보·로그아웃)와 **admin 에게만** "관리자 콘솔" 링크.
- **관리자 콘솔** (`routes/admin/` — 그룹형 사이드바 개요·콘텐츠·회원·보안·시스템, 현재 메뉴 `aria-current`, "로그인 잠금" 잠긴 계정 수 배지,
  1024px 미만은 상단 메뉴 서랍): 대시보드(KPI·최근 세션 강제 종료·잠금 해제), 공지(목록·작성/수정 — 리치 에디터 + `uploadEditorImage`,
  상단 고정·게시, 첫 저장 뒤 수정 URL 로 전환(`page.state.flash`)해 첨부 패널 — 여러 파일 순차 업로드·파일별 진행률/오류·확장자·용량·개수 사전 검사·Bearer blob 다운로드(원래 파일명)·삭제,
  저장하지 않은 변경 이탈 확인 — `beforeNavigate` 확인 다이얼로그 + `beforeunload`), 배너(썸네일·기간·활성 토글 = PUT 전체 본문·위/아래 이동 = `PATCH /order`·삭제,
  작성/수정 — 이미지 업로드 미리보기·대체 텍스트 필수·`link_url` 백엔드와 같은 규칙·`datetime-local` KST 기간), 사용자(검색·역할 필터·권한/활성 변경·세션 모두 종료,
  409 `self_modification`·`last_admin` 한국어 안내), 세션(`?user_id=` 필터·강제 종료), 로그인 잠금(잠김 강조·해제), 시스템 상태(헬스 체크 + DB·Alembic 리비전).
- **관리자 가드** — `routes/admin/+layout.ts` load 가 `restoreSession()` 을 기다린 뒤 비로그인 → `/login?next=<원래 위치>`, `/auth/me` 의 role≠admin → `error(403)`(루트 `+error.svelte` 의 403 화면).
- **자체 리치 텍스트 에디터** (`lib/components/editor/` — 라이브러리 없음, contentEditable + execCommand): 서식·정렬·목록·인용·링크·형광펜, 이미지(버튼·붙여넣기·드롭, 업로드 전 canvas 자르기·회전·
  긴 변 1600px WebP 변환, 모서리 핸들·프리셋 크기 조절, 대체 텍스트·다시 자르기·교체·삭제), 유튜브 임베드, 붙여넣기 정리. 순수 모듈 `lib/editor/richText.ts`·`imageTransform.ts`·`mediaHtml.ts` 는
  React 판과 같은 파일이고, `execCommand` 는 `editorDom.ts` 의 `exec()` 한 곳, 프로그램적 변경은 selectNode → `exec("insertHTML")` 로 커밋한다. 다이얼로그는 `document.body` 로 옮겨 그린다.
- API 모듈 `lib/api/notices.ts`·`banners.ts`·`admin.ts`·`common.ts`(계약과 같은 타입), svelte-query 팩토리 `lib/queries/notices·banners·admin`(파라미터는 getter),
  공용 UI `lib/components/ui/*`(ConfirmDialog·Pagination·Chip·Loading·ErrorState·EmptyState·Notice·SearchForm·Icon·styles), `lib/apiError.ts`·`format.ts`·`linkUrl.ts`·`uploadRules.ts`·
  `download.ts`·`site.ts`·`listParams.ts`(목록 page·q ↔ URL)·`returnTo.ts`(`?next=` — 사이트 내부 경로만).
- 확장 디자인 토큰 기본값(`primary-fixed`·`outline`·`surface-container-low/high/highest`·`tertiary`·`error` 등)과 `.rich-text`·`.editor` 스타일을 `app.css` 에 추가 —
  기본 테마(`-NoDesign`)에서도 동작하고, DESIGN.md 테마가 주입되면 그 값이 이긴다.
- **프론트엔드 테스트 도입** — vitest 5 + jsdom(`pnpm test`, 설정은 `vite.config.ts` 의 `test`). 에디터 순수 모듈(React 판 테스트 그대로)·업로드 오류 문구·배너 폼 검증·`returnTo`·`listParams`,
  그리고 별도 라이브러리 없이 `svelte` 의 `mount()` 로 그리는 컴포넌트 연기 테스트(리치 에디터 툴바·직렬화·유튜브 다이얼로그·이미지 선택 오버레이, 배너 캐러셀) — 9 파일 179 건.
  CI(`skeleton/.github/workflows/ci.yml`·`template-ci.yml`)에 `pnpm test` 추가.

### Changed (프론트엔드)

- 로그인 후 홈이 공개 첫 화면이 됐다(이전: 로그인 필수 메인). `(protected)/+page.svelte`(메인)·`(protected)/landing`(랜딩) 삭제 — 시스템 상태는 관리자 콘솔 `/admin/system` 으로 옮겼다.
  `/my` 는 `/me` 로 리다이렉트. 로그인 화면은 `?next=` 로 원래 위치에 복귀하고 "홈으로" 링크·422/5xx/네트워크 문구(`loginErrorMessage`)를 갖는다. 로그아웃은 공개 홈으로 간다.
- 세션 만료(refresh 실패) 시 로그인 화면 주소에 `?next=<원래 위치>` 를 붙인다.
- SvelteKit 3 의 `goto` 옵션명에 맞춰 `replaceState` → `replace`(목록 갱신은 `reset: false`).
- Vite dev 프록시에 `/uploads` 추가(같은 백엔드). 운영은 앞단 리버스 프록시가 `/api`·`/uploads` 를 백엔드로 넘긴다(ARCHITECTURE §14 "오리진 배치").
- 문서: `ARCHITECTURE.md` §3·§4·§8·§12(백엔드 — React 판과 같은 문구), §13(프론트 트리·테스트)·§14(화면 구성·관리자 가드·이탈 확인)·§17(업로드 키),
  `README.md`(화면 구성·브라우저 수동 점검·nh3/pillow·vitest 버전), 스킬(`add-frontend-feature`·`stack-versions`), 루트 README·스캐폴드 완료 메시지의 확인 안내("홈 화면 → 관리자 콘솔 › 시스템 상태").

### ⚠️ 기존 프로젝트에 반영할 때

- `pip install -r requirements.txt` → `alembic upgrade head`(0004) → `backend/.env` 에 위 4개 키 추가(없으면 기본값). `backend/uploads/` 를 `.gitignore` 에 추가한다.
- 프론트엔드: `frontend/src/routes`(그룹 `(site)`·`admin`)·`lib/*` 새 파일과 `app.css`·`app.d.ts`·`vite.config.ts`(`/uploads` 프록시·vitest)를 옮기고 `pnpm add -D vitest jsdom` 을 실행한다.
  `(protected)/` 아래에 만든 화면은 `(site)/(protected)/`(사용자 레이아웃 안) 또는 `admin/`(관리자 콘솔)로 옮긴다.

## 2026-10-02 — 백엔드 보안 보강 (네 템플릿 공통)

### Added (추가)

- **보안 응답 헤더** — 모든 응답에 `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Cross-Origin-Opener-Policy: same-origin`. HSTS(`max-age=31536000`)는 `COOKIE_SECURE=true` 또는 `APP_ENV=production` 일 때만 보낸다.
- **`/api/v1/auth/*` 캐시 금지** — 성공·401/422/429·쿠키 삭제 응답 모두 `Cache-Control: no-store`.
- **로그인 잠금 429 의 `Retry-After`** — 남은 잠금 초(올림·최소 1). 미존재 계정도 동일하게 받아 계정 존재가 드러나지 않는다.
- `tests/test_security.py` 24건.

### Changed (변경)

- CORS `allow_methods`/`allow_headers` 를 `"*"` 에서 명시 목록(`GET·POST·PUT·PATCH·DELETE·OPTIONS` / `Authorization·Content-Type`)으로 좁히고 `Retry-After` 를 expose 한다.
- CSP 는 `/docs`·`/redoc` 을 깨뜨리므로 백엔드에서 붙이지 않는다(프론트엔드 호스팅 책임). `ARCHITECTURE.md` §9 에 정리했다.

## 2026-10-02 — 공통 백엔드 채택 + 메모리 access 토큰·httpOnly refresh 쿠키 인증 전환

### ⚠️ Breaking (이전에 생성한 프로젝트)

- 백엔드 인증 계약이 바뀌었다. 이전 골격으로 만든 프로젝트에 이 변경을 옮기려면 `backend/` 를 통째로 교체하고 `alembic upgrade head`(`0003_auth_sessions`)를 실행한 뒤,
  `backend/.env` 에 `APP_ENV`·`REFRESH_TOKEN_EXPIRE_DAYS`·`LOGIN_MAX_FAILURES`·`LOGIN_LOCKOUT_MINUTES`·`REFRESH_TOKEN_TRANSPORT=cookie`·`COOKIE_SECURE`·
  `SEED_DEFAULT_ADMIN`·`DEFAULT_ADMIN_PASSWORD` 를 추가해야 한다. **관리자 시드는 기본으로 꺼져 있고 기본 비밀번호(`admin123`)도 없다** — 두 키를 넣지 않으면 관리자가 생성되지 않는다.
- access 토큰에 `sid` 클레임이 추가되고 만료가 30분 → 15분이 됐다. 이전 토큰은 모두 401 이다(재로그인 필요).
- 프론트의 `lib/auth/token.ts`(`localStorage` 래퍼)가 삭제됐다. `getToken`/`setToken`/`clearToken`·`authStore.logout()` 을 쓰던 코드는
  `authStore.token`·`authStore.clear()`·`signOut()`(`lib/auth/session.ts`)으로 옮겨야 한다. 브라우저에 남은 `<project>_token` 키는 더 이상 읽지 않는다.
- `SECRET_KEY` 기본값이 `change-me-in-production-use-32-bytes` 로 바뀌었고, `APP_ENV=production` 에서 기본 키·관리자 시드·`COOKIE_SECURE=false`(cookie 모드)면 기동을 거부한다.

### Changed (변경)

- **백엔드를 공통 백엔드로 교체** (`skeleton/backend/`) — nextjs 저장소의 `skeleton/backend` 와 파일 단위로 동일하다(`.env.example` 만 이 템플릿 값).
  테이블 `app_meta`·`users`·`auth_sessions`(refresh 세션: 회전, 직전 토큰 60초 유예, 재사용 감지 시 세션 폐기, 로그아웃 폐기)·`login_throttles`(계정별 연속 실패 잠금 → 429).
  refresh 토큰 전달 방식 `REFRESH_TOKEN_TRANSPORT=cookie|body` 중 이 템플릿은 **cookie** — login/refresh 가 httpOnly 쿠키 `refresh_token`(`Path=/api/v1/auth`, `SameSite=Lax`,
  `Secure=COOKIE_SECURE`)을 심고 응답 본문의 `refresh_token` 은 `null`, `/auth/refresh` 는 쿠키만 읽으며 실패 시 401 + 쿠키 삭제, `/auth/logout` 은 항상 204 + 쿠키 삭제.
  테스트 83건(`test_auth_sessions.py`·`test_auth_cookie_transport.py`·`test_config.py` 추가).
- **프론트 인증 흐름 교체** (`skeleton/frontend/src/`) — access 토큰은 runes 스토어(`lib/stores/auth.svelte.ts`) **메모리에만** 둔다.
  앱 시작 시 루트·`(protected)` `+layout.ts` load 가 `restoreSession()`(`lib/auth/session.ts`, `POST /auth/refresh`)을 기다린 뒤 인증 여부를 판단해 새로고침 시 로그인 화면 깜빡임이 없다.
  axios 인스턴스는 `withCredentials: true`, 401 이면(`/auth/login`·`refresh`·`logout` 제외) refresh 를 single-flight 로 1회 호출 후 원 요청을 1회 재시도하고,
  refresh 실패 시 스토어·svelte-query 캐시(`lib/query-client.ts` 단일 인스턴스)를 비우고 `/login` 으로 보낸다. 로그아웃은 `POST /auth/logout` 후 정리.
  로그인 화면은 401(자격증명)·429(잠금) 문구를 구분하고, 기본 계정 안내 문구(`admin / admin123`)를 제거했다.
- **스캐폴드 `.env` 생성 정렬** (`scaffold.ps1`·`scaffold.sh`) — nextjs 스캐폴드와 같은 키를 쓴다: `ACCESS_TOKEN_EXPIRE_MINUTES=15`·`REFRESH_TOKEN_EXPIRE_DAYS`·`LOGIN_*`·
  `REFRESH_TOKEN_TRANSPORT=cookie`·`COOKIE_SECURE=false`·`APP_ENV=development`·`SEED_DEFAULT_ADMIN=true`·무작위 `DEFAULT_ADMIN_PASSWORD`(CSPRNG). 완료 메시지에 생성된 관리자 비밀번호를 출력한다.
  재실행 시 기존 `backend/.env` 를 `.env.bak.<시각>` 으로 백업하고, 새 파일은 `chmod 600` / 현재 사용자 단독 ACL 로 제한한다.
  bash 판은 난수 도구(openssl/python3)가 없으면 타임스탬프 키로 진행하지 않고 중단한다.
- **문서** — `ARCHITECTURE.md` §4~§9·§12(백엔드 계약은 공통 문서와 같은 문구), §13·§14(프론트 인증 흐름), §17(환경변수), §21(배포 전 체크리스트),
  `AGENTS.md` 인증 항목, `README.md`(골격·루트), 스킬(`add-frontend-feature`·`stack-versions`·`add-backend-domain`)의 `localStorage`/`token.ts` 안내를 갱신했다.

## 2026-10-02 — 골격 복사 시 빌드 산출물·`.env` 가 생성 프로젝트로 복사되던 문제 수정

### Fixed (수정)

- **골격 복사에서 산출물·비밀 제외** (`scaffold.ps1`·`scaffold.sh`) — 템플릿 저장소에서 개발/검증한 뒤 `skeleton/` 에 남은
  `node_modules`·`.venv`·`.svelte-kit`·`build`·`.ruff_cache`·`.pytest_cache`·`__pycache__`·`.DS_Store`·`.env` 가 생성 프로젝트로
  그대로 복사됐다. 복사된 `node_modules` 때문에 `pnpm install` 이 `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` 로 중단됐고, 실제
  `.env` 가 있으면 템플릿의 `SECRET_KEY` 가 새 프로젝트로 샐 수 있었다. 이제 PowerShell 은 `robocopy /XD /XF`, bash 는
  `tar --exclude` 로 원천 제외한다(nextjs 저장소와 동일한 처리). robocopy 가 숨김 항목도 복사하므로 닷파일·`.claude` 누락 보강
  단계는 제거했다. 토큰 치환 단계도 같은 디렉터리(+ `.git`)를 걸러 재실행 시 산출물을 붙잡지 않는다.

## 2026-10-02 — pyenv 환경에서 스캐폴드가 Python 검증에 실패하던 문제 수정

### Fixed (수정)

- **pyenv 버전을 명시 선택** (`scaffold.ps1`·`scaffold.sh`) — 스캐폴드는 pyenv shim 을 PATH 앞에 올리지만 버전은 고르지 않아,
  `pyenv global` 이 비어 있거나 system 이면 `python` 이 실패하거나 옛 버전을 가리켰다. 그 결과 bootstrap 이 핀(3.13.x)을
  설치·재사용한 뒤에도 "Python 이 3.13 이상이 아닙니다" 로 중단됐다. 이제 골격의 `.python-version` 핀을 활성화보다 먼저 읽고,
  핀이 pyenv 에 설치돼 있으면 그 버전을, 없으면 하한을 충족하는 설치본 중 최신을 `PYENV_VERSION` 으로 지정한다.
- **bootstrap 에 핀 전달** — bootstrap 에 넘기는 임시 폴더에 골격의 `.python-version`·`.nvmrc` 를 미리 심어 핀이 존중되게 하고,
  bootstrap 이 실제로 고정한 버전을 다시 읽어 활성화한다. fnm 도 `.nvmrc` 핀을 우선 사용한다(nextjs 저장소와 동일한 처리).

## 2026-10-02 — Windows PowerShell 5.1 구문 검사 실패 수정

### Fixed (수정)

- **`skeleton/scripts/bootstrap.ps1` 에 UTF-8 BOM 추가** — BOM 이 없어 Windows PowerShell 5.1 이 한글을 ANSI 로 읽고
  구문 오류(6건)로 즉시 실패했다. Windows 에서 `scaffold.ps1` 이 bootstrap 단계에서 멈추던 원인이다.
- **PowerShell 구문 검사를 BOM 달린 스크립트 파일로 분리** — `.github/scripts/check-ps1-syntax.ps1`(템플릿·골격 양쪽).
  Actions 는 `shell: powershell` 인라인 스텝을 BOM 없는 UTF-8 임시 파일로 쓰고, Windows PowerShell 5.1 은 이를 ANSI 로 읽어
  한글 메시지에서 따옴표 짝이 무너진다. `template-ci.yml`·골격 `ci.yml` 의 `powershell-syntax` 잡은 이제 이 파일만 실행한다.

## 2026-10-02

의존성 전체를 최신 안정판으로 상향했다. 프론트는 **SvelteKit 3 메이저 마이그레이션**을 포함한다.

### Changed (변경)

- **백엔드 핀 상향** — FastAPI 0.142.2 · Uvicorn 0.54.0 · SQLAlchemy 2.1.1 · Alembic 1.20.0 · psycopg2-binary 2.9.13 · Pydantic 2.13.5 / pydantic-settings 2.15.0 · PyJWT 2.15.1 · bcrypt 5.0.0 · httpx2 2.13.1 · ruff 0.16.9 (python-multipart 0.0.32 · pytest 9.1.1 은 유지).
- **프론트 상향** — `@sveltejs/kit` ^3.0.0 · `@sveltejs/adapter-static` ^4.0.0 · svelte ^5.57.1 · vite ^8.3.2 · `@sveltejs/vite-plugin-svelte` ^7.3.1 · `@tanstack/svelte-query` ^6.3.0 · axios ^1.20.0 · eslint ^10.11.0 · typescript-eslint ^8.71.0 · eslint-plugin-svelte ^3.23.0 · globals ^17.13.0 · svelte-check ^4.7.6 · `@types/node` ^24.19.0 · `packageManager` pnpm@11.28.3. typescript 는 `~6.0.3` 유지(TS 7 비호환).
- **SvelteKit 3 마이그레이션** — `svelte.config.js` 를 삭제하고 adapter·preprocess 설정을 `vite.config.ts` 의 `sveltekit({ ... })` 옵션으로 옮겼다. `$lib` 별칭을 `package.json` `"imports"` 의 `#lib/*`(확장자 `.js` 명시)로, `$app/environment` 를 `$app/env` 로 교체했다. `resolve()` 경로를 Kit 3 pathname 형식(`"login"`, 루트 `""`)으로 바꾸고, `tsconfig.json` 은 `$app/tsconfig` 를 상속한다. eslint 는 `@sveltejs/load-config` 로 svelte 설정을 읽는다(devDependency 추가).
- **ruff 0.16 대응** — `UserRole` 을 `enum.StrEnum` 으로 변경(UP042). 값·DB 저장 동작은 같다.
- **Alembic 경고 제거** — `alembic.ini` 에 `path_separator = os` 를 추가했다(Alembic 1.16+ DeprecationWarning).
- **문서·스킬** — `README` 버전 표, `docs/architecture.md`, `CLAUDE.md`, `add-frontend-feature`·`add-backend-domain`·`stack-versions` 스킬을 새 버전과 SvelteKit 3 규칙(`#lib`, `$app/env`, `resolve()` 형식, 설정 위치)에 맞췄다. `stack-versions` 에 SvelteKit 3 · bcrypt 5 · SQLAlchemy 2.1/Alembic · ruff 0.16 주의사항을 추가했다.

### Added (추가)

- **bcrypt 5 회귀 테스트** — bcrypt 5 는 72바이트 초과 입력에 `ValueError` 를 던진다. 기존 바이트 상한 검증으로 500 이 아닌 422 가 반환되는지(영문 73바이트, 한글 25자), `hash_password` 거부, `verify_password` 의 절단 우회 차단을 테스트로 고정했다(총 10건).

### Fixed (수정)

- 테스트 픽스처에서 SQLite 엔진을 `dispose()` 하지 않아 `-W error` 실행 시 `ResourceWarning` 으로 실패하던 문제를 고쳤다.

### 검증

- 임시 프로젝트(Windows)에서 `ruff check` · `pytest`(10건, `-W error` 포함) · PostgreSQL 16 상대 `alembic upgrade head`/`downgrade base`/`check` · `pnpm install`/`lint`/`check`/`build` 를 모두 통과했다. `pnpm-workspace.yaml` 은 검증 설치로 변경되지 않았다.

### 남은 후속 (미진행)

- `@sveltejs/kit@3.0.0` · `@sveltejs/adapter-static@4.0.0` 은 2026-10-01 17:20 UTC 에 배포돼 pnpm 11 의 `minimum-release-age`(24시간)에 걸린다. **2026-10-02 17:22 UTC 이전**에 새 프로젝트를 만들면 `pnpm install` 이 `pnpm-workspace.yaml` 에 `minimumReleaseAgeExclude` 를 자동 삽입한다. 그 이후에는 해소되며 템플릿에는 exclude 를 넣지 않았다.
- `eslint-plugin-svelte@3.23` 의 SvelteKit 전용 규칙(`svelte/no-navigation-without-resolve` 등)은 Kit 1·2 에서만 동작해 Kit 3 에서는 비활성이다. 플러그인이 Kit 3 를 지원하면 다시 확인한다.
- Windows PowerShell 5.1 에서 `scripts/bootstrap.ps1` 이 파싱 오류(184행 `Unexpected token '}'`)로 실행되지 않는다. BOM 없는 UTF-8 한글 파일을 5.1 이 ANSI 로 읽는 문제로 보이며, 이번 범위에서는 고치지 않았다.

---

## 2026-10-02 — 기본 문서 세트 정리 (AGENTS.md 도입, 문서 루트 배치)

생성 프로젝트의 기준 문서 6종을 골격 루트에 두고, `docs/` 는 프로젝트 고유 문서(PRD·유저 플로우·기획서 등) 전용으로 비웠다.
네 형제 템플릿(react·nextjs·nuxt·svelte)이 같은 구성을 갖는다.

```
skeleton/
├── README.md  AGENTS.md  CLAUDE.md  ARCHITECTURE.md  DESIGN.md  PLAN.md
└── docs/README.md   # 프로젝트 고유 문서 안내
```

### Changed (변경)

- **`plan.md` → `PLAN.md`** — 대문자로 통일하고 모든 참조(문서·스킬·랜딩 화면 안내 문구)를 고쳤다.
- **`docs/architecture.md` → `ARCHITECTURE.md`** (골격 루트) — 대문자로 개명하고 저장소 안의 모든 참조와 §3 구조도를 갱신했다.
- **`DESIGN.md` (템플릿 루트) → `skeleton/DESIGN.md`** — 생성 프로젝트는 `-Design`/`-NoDesign` 과 무관하게 항상 `DESIGN.md` 를 받는다.
  두 옵션은 이제 `@theme` 주입 여부만 결정하며, 스캐폴드의 별도 복사 단계(`docs/DESIGN.md`)는 제거했다.
- **`CLAUDE.md` → `AGENTS.md`** — 에이전트 공통 지침의 원본을 `AGENTS.md` 로 옮겼다(`git mv`, 이력 유지).
  새 `CLAUDE.md` 는 `@AGENTS.md` 를 import 하고 Claude Code 전용 내용만 둔다. Claude Code 는 `CLAUDE.md` 가 있으면
  `AGENTS.md` 를 스스로 읽지 않으므로, import 없이 두 파일을 따로 두면 규칙이 갈라진다.
  전역 `~/.claude/CLAUDE.md` 에 기대던 작업 규칙(TDD·Tidy First·커밋 형식·PowerShell·pnpm·한국어)은 `AGENTS.md` 에 직접 적었다 — 다른 에이전트는 그 전역 파일을 읽지 않기 때문이다.
- **변경 반영 규칙을 `main` 직접 커밋(브랜치·PR 선택)으로 통일** — 형제 저장소(react·nextjs)와 같은 규칙으로 맞췄다.
  `AGENTS.md`, `ARCHITECTURE.md`(★MUST 15·§20·§21 체크리스트), 골격 `README.md`·`PLAN.md`, `ci.yml` 주석을 갱신했다. 게이트는 push 전 로컬 검증이고 CI 는 사후 안전망이다.
- **`pr-workflow` 스킬** — macOS/Linux 명령을 함께 싣고, push 전 검증 명령을 이 골격의 실제 `package.json` 스크립트에 맞췄다(없는 스크립트를 부르지 않도록).

### Added (추가)

- **`docs/README.md`** — `docs/` 의 용도(프로젝트 고유 문서)와 루트 기준 문서 목록을 안내한다. 빈 폴더가 git 에 남도록 하는 역할도 한다.

## 2026-08-11

`fastapi-react-pg-starter` 로부터 프론트엔드를 **SvelteKit** 으로 이식해 신규 저장소로 분기.

### Added (추가)

- **SvelteKit SPA 프론트엔드 골격** — `@sveltejs/adapter-static`의 `index.html` fallback과 루트 레이아웃의 `ssr = false`·`prerender = true`를 적용했다.
- **파일 기반 라우팅** `src/routes/` — `/login`과 보호 라우트 그룹 `(protected)` 아래 `/`·`/landing`·`/my` 화면 및 인증 가드를 구성했다.
- **서버·클라이언트 상태 관리** — `@tanstack/svelte-query`로 서버 상태를 관리하고 Svelte 5 runes의 `$state`로 전역 인증 상태를 관리한다.
- **Svelte 품질 게이트** — eslint와 `eslint-plugin-svelte`, `svelte-check`를 사용하며 CI에서 설치·린트·타입 검사·빌드를 순서대로 수행한다.

### Changed (변경)

- **프론트 프레임워크**를 SvelteKit(SPA) + Svelte 5 + TypeScript로 교체하고, 기존 명시적 라우터 대신 SvelteKit 파일 기반 라우팅을 사용한다.
- **서버 상태 계층**을 `@tanstack/svelte-query`로, **클라이언트 상태 계층**을 별도 라이브러리 없는 Svelte 5 runes로 교체했다.
- **타입 검사**를 `tsc -b`에서 `svelte-check`로 교체했다. axios·Tailwind CSS v4·pnpm·Bearer JWT는 그대로 사용한다.
- **문서·스킬·스캐폴드 스크립트**의 프론트 관련 경로, 명령, 설명을 SvelteKit 구조와 `src/app.css` 테마 주입 방식에 맞게 갱신했다.

### Unchanged (그대로 유지)

- 백엔드(FastAPI · SQLAlchemy 2.0 · Alembic · pytest · ruff)와 PostgreSQL, 기본 인증 유저플로우, KST 단일 기준, `.env` 주입 규칙, TDD/Tidy First/PR 규칙은 원본과 동일하다.
- 런타임 최소는 Python ≥ 3.13 · Node ≥ 24 · pnpm ≥ 11이며, 백엔드 의존성은 원본의 정확 핀을 유지한다.

### 작업 관례 (다음 세션 참고)

- **버전 핀 정책**: `requirements.txt`는 `==` 정확 핀(재현성). 프론트 패키지는 실제로 호환되는 버전을 고정하며, 런타임 최소 상향만으로 핀을 자동으로 올리지 않는다. 상향 시 임시 스캐폴드에서 `pnpm install` → `pnpm lint` → `pnpm check` → `pnpm build`를 실제 검증한 뒤 핀한다(상세는 `stack-versions` 스킬 §5).
- **PR 흐름**: 브랜치 → 커밋(`[Structural]`/`[Behavioral]`) → push → `gh pr create` → squash 머지(`pr-workflow` 스킬).
- 정확한 버전·버전별 함정은 항상 `stack-versions` 스킬과 SoT 파일(`versions.env`·`requirements.txt`·`package.json`)을 기준으로 확인한다.

### 남은 후속 (미진행)

- 프론트 패키지 핀은 전체 품질 게이트를 실제 통과한 조합으로 확정한다.
- 도메인 기능은 **각 프로젝트에서 PRD 작성 후** 진행한다(스캐폴드는 공통 기반까지).
- 후보: 회원가입/사용자 관리(관리자 화면)·비밀번호 변경·토큰 만료/refresh.
- CI 머지 게이트 강제는 **GitHub 저장소 설정**(main 브랜치 보호 + 필수 체크)이 필요한 저장소 관리자 작업이다.
- 원본 `fastapi-react-pg-starter`의 상세 변경 이력은 해당 저장소의 CHANGELOG를 참조한다.
