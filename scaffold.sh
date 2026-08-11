#!/usr/bin/env bash
# 사내 공통 아키텍처 기반 신규 프로젝트 스캐폴드 (macOS/Linux).
# Windows 는 scaffold.ps1 을 사용한다. 동작은 동일하다.
#
# 사용:
#   ./scaffold.sh --name project_test --target ~/work/project_test
#   ./scaffold.sh --name Demo --target ./Demo --skip-db --skip-install
#
# 사전 요구: python3, pnpm, psql (PATH). 없으면 해당 단계는 건너뛴다.

# ---------- 기본값 / 인자 ----------
NAME=""
TARGET=""
SKIP_DB=0
SKIP_INSTALL=0
DESIGN_FLAG=""        # "yes" | "no" | ""(질문)
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
DB_PASSWORD=""
DB_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --name)         NAME="$2"; shift 2 ;;
    --target)       TARGET="$2"; shift 2 ;;
    --skip-db)      SKIP_DB=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --design)       DESIGN_FLAG="yes"; shift ;;
    --no-design)    DESIGN_FLAG="no"; shift ;;
    --db-host)      DB_HOST="$2"; shift 2 ;;
    --db-port)      DB_PORT="$2"; shift 2 ;;
    --db-user)      DB_USER="$2"; shift 2 ;;
    --db-password)  DB_PASSWORD="$2"; shift 2 ;;
    --db-name)      DB_NAME="$2"; shift 2 ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKELETON_DIR="$SCRIPT_DIR/skeleton"
DESIGN_FILE="$SCRIPT_DIR/DESIGN.md"

c_cyan='\033[36m'; c_green='\033[32m'; c_yellow='\033[33m'; c_reset='\033[0m'
step() { printf "\n${c_cyan}=== %s ===${c_reset}\n" "$1"; }
ok()   { printf "  ${c_green}[OK]${c_reset} %s\n" "$1"; }
warn() { printf "  ${c_yellow}[!]${c_reset}  %s\n" "$1"; }

# pyenv / fnm 이 설치돼 있으면 셸 세션에 활성화 (시스템 Python/Node 대신 버전 관리 도구 우선)
_activate_version_managers() {
  if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path 2>/dev/null || true)"
    eval "$(pyenv init - 2>/dev/null || true)"
  fi
  if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd 2>/dev/null || true)"
    # fnm env 는 환경만 준비할 뿐 버전을 활성화하지 않으므로 명시적으로 use
    fnm use 2>/dev/null || true
  fi
}
_activate_version_managers

# 필수 도구 확인 — 미달이면 bootstrap.sh 자동 실행
_BOOTSTRAP="$SCRIPT_DIR/skeleton/scripts/bootstrap.sh"
_VERSIONS_ENV="$SCRIPT_DIR/skeleton/scripts/versions.env"
_need_bootstrap=0

_ext_ver(){ printf '%s' "$1" | grep -oE '[0-9]+(\.[0-9]+){0,2}' | head -n1 || true; }
_meets(){ [ -n "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }

if [ -f "$_VERSIONS_ENV" ]; then
  # shellcheck disable=SC1090
  . "$_VERSIONS_ENV"
fi

! command -v pyenv >/dev/null 2>&1 && _need_bootstrap=1
! command -v fnm   >/dev/null 2>&1 && _need_bootstrap=1
_PY="$(_ext_ver "$(python3 --version 2>/dev/null || true)")"
_meets "${MIN_PYTHON:-3.10}" "$_PY" || _need_bootstrap=1

if [ "$_need_bootstrap" = "1" ]; then
  if [ -f "$_BOOTSTRAP" ]; then
    warn "필수 도구(pyenv·fnm) 없거나 Python 버전 미달 — bootstrap.sh 를 먼저 실행합니다 …"
    bash "$_BOOTSTRAP"
    _activate_version_managers                                    # bootstrap 후 현재 프로세스에 재적용
    command -v fnm >/dev/null 2>&1 && fnm use "${MIN_NODE:-24}" 2>/dev/null || true  # Node 버전 명시 활성화
  else
    warn "bootstrap.sh 를 찾을 수 없습니다 ($_BOOTSTRAP). 수동으로 먼저 실행하세요."
    exit 1
  fi
fi

# ---------- 테마 ----------
default_theme() {
  cat <<'EOF'
@theme {
  --font-sans: 'Inter', 'Noto Sans KR', system-ui, sans-serif;
  --color-surface: #f8f9fa;
  --color-on-surface: #191c1d;
  --color-on-surface-variant: #424752;
  --color-surface-container: #edeeef;
  --color-surface-container-lowest: #ffffff;
  --color-outline-variant: #c2c6d4;
  --color-primary: #00478d;
  --color-on-primary: #ffffff;
  --color-tertiary-container: #c6f6d5;
  --color-on-tertiary-container: #14532d;
  --color-error-container: #ffdad6;
  --color-on-error-container: #93000a;
}
EOF
}

parse_design() {
  local file="$1" in_front=0 section="" font="" colors=""
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^[[:space:]]*---[[:space:]]*$ ]]; then
      if [ $in_front -eq 0 ]; then in_front=1; continue; else break; fi
    fi
    [ $in_front -eq 0 ] && continue
    if [[ "$line" =~ ^[A-Za-z] ]]; then
      if   [[ "$line" =~ ^colors: ]];     then section="colors"
      elif [[ "$line" =~ ^typography: ]]; then section="typography"
      else section=""; fi
      continue
    fi
    if [ "$section" = "colors" ] && [[ "$line" =~ ^[[:space:]]+([a-z0-9-]+):[[:space:]]*\'?(#[0-9a-fA-F]+)\'? ]]; then
      colors+="  --color-${BASH_REMATCH[1]}: ${BASH_REMATCH[2]};"$'\n'
    fi
    if [ "$section" = "typography" ] && [ -z "$font" ] && [[ "$line" =~ fontFamily:[[:space:]]*\'?([^\'$'\r']+)\'?[[:space:]]*$ ]]; then
      font="${BASH_REMATCH[1]}"
    fi
  done < "$file"
  if [ -z "$colors" ]; then default_theme; return; fi
  printf '@theme {\n'
  printf "  --font-sans: '%s', 'Noto Sans KR', system-ui, sans-serif;\n" "${font:-Inter}"
  printf '%s' "$colors"
  printf '}\n'
}

# ---------- 1. 입력 ----------
step "신규 프로젝트 스캐폴드"
[ -z "$NAME" ]   && read -r -p "프로젝트 이름 (예: project_test): " NAME
[ -z "$NAME" ]   && { echo "프로젝트 이름이 필요합니다." >&2; exit 1; }
# --target 미지정 시 기본값: _project-template 의 부모 폴더에 <이름> 으로 생성
if [ -z "$TARGET" ]; then
  DEFAULT_TARGET="$(dirname "$SCRIPT_DIR")/$NAME"
  [ -t 0 ] && read -r -p "생성 위치 [$DEFAULT_TARGET]: " TARGET
  [ -z "$TARGET" ] && TARGET="$DEFAULT_TARGET"
fi

# ~ 확장 + 상대경로는 현재 위치 기준 절대경로화 (드라이브 문자 경로도 절대로 인식)
TARGET="${TARGET/#\~/$HOME}"
case "$TARGET" in
  /*) ;;                # unix 절대경로
  [A-Za-z]:[\\/]*) ;;   # windows 드라이브 경로 (wsl/git-bash)
  *) TARGET="$PWD/$TARGET" ;;
esac

SNAKE=$(printf '%s' "$NAME" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')
[ -z "$DB_NAME" ] && DB_NAME="$SNAKE"
ok "이름=$NAME  snake=$SNAKE  위치=$TARGET"

# DESIGN.md 사용 여부
USE_DESIGN=0
if [ "$DESIGN_FLAG" = "no" ] || [ ! -f "$DESIGN_FILE" ]; then
  USE_DESIGN=0
elif [ "$DESIGN_FLAG" = "yes" ]; then
  USE_DESIGN=1
elif [ -t 0 ]; then
  read -r -p "DESIGN.md 의 색상/타이포그래피를 적용할까요? (Y/n): " ans
  case "$ans" in ""|[Yy]*) USE_DESIGN=1 ;; *) USE_DESIGN=0 ;; esac
else
  USE_DESIGN=1
fi
if [ $USE_DESIGN -eq 1 ]; then THEME="$(parse_design "$DESIGN_FILE")"; ok "DESIGN.md 테마 적용"
else THEME="$(default_theme)"; ok "기본 테마 적용"; fi

# DB 입력
if [ $SKIP_DB -eq 0 ]; then
  step "PostgreSQL 접속 정보 (psql 로 DB 생성)"
  if [ -t 0 ]; then
    read -r -p "DB host [$DB_HOST]: " i; [ -n "$i" ] && DB_HOST="$i"
    read -r -p "DB port [$DB_PORT]: " i; [ -n "$i" ] && DB_PORT="$i"
    read -r -p "DB user [$DB_USER]: " i; [ -n "$i" ] && DB_USER="$i"
    [ -z "$DB_PASSWORD" ] && { read -r -s -p "DB password: " DB_PASSWORD; echo; }
    read -r -p "DB name [$DB_NAME]: " i; [ -n "$i" ] && DB_NAME="$i"
  fi
fi
DATABASE_URL="postgresql+psycopg2://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
if command -v openssl >/dev/null 2>&1; then SECRET=$(openssl rand -hex 24)
elif command -v python3 >/dev/null 2>&1; then SECRET=$(python3 -c 'import secrets;print(secrets.token_hex(24))')
else SECRET="change-me-$(date +%s)"; fi

# ---------- 2. 복사 ----------
step "골격 복사 → $TARGET"
mkdir -p "$TARGET"
cp -R "$SKELETON_DIR/." "$TARGET/"
[ $USE_DESIGN -eq 1 ] && cp "$DESIGN_FILE" "$TARGET/docs/DESIGN.md"
ok "복사 완료"

# ---------- 3. 토큰 치환 ----------
step "토큰 치환"
replace_tokens() {
  local f="$1" content
  content=$(cat "$f"; printf x); content=${content%x}
  content=${content//__PROJECT_NAME__/$NAME}
  content=${content//__PROJECT_SNAKE__/$SNAKE}
  content=${content//__THEME_CSS__/$THEME}
  printf '%s' "$content" > "$f"
}
while IFS= read -r -d '' f; do replace_tokens "$f"; done < <(
  find "$TARGET" -type f \( -name '*.ts' -o -name '*.svelte' -o -name '*.py' -o -name '*.css' \
    -o -name '*.html' -o -name '*.json' -o -name '*.md' -o -name '*.ini' -o -name '*.mako' \
    -o -name '*.js' -o -name '*.example' -o -name '*.txt' \) -print0 )
ok "치환 완료"

# ---------- 4. .env ----------
step ".env 생성 (OS 무관 주입 — architecture.md §5)"
cat > "$TARGET/backend/.env" <<EOF
DATABASE_URL=$DATABASE_URL
SECRET_KEY=$SECRET
ACCESS_TOKEN_EXPIRE_MINUTES=30
CORS_ORIGINS=http://localhost:5173
FRONTEND_URL=http://localhost:5173
BACKEND_PUBLIC_URL=http://localhost:8000
TZ=Asia/Seoul
EOF
printf 'VITE_API_BASE_URL=\nVITE_BACKEND_URL=http://localhost:8000\n' > "$TARGET/frontend/.env"
ok "backend/.env, frontend/.env 생성 (DATABASE_URL, SECRET_KEY 주입)"

BACKEND="$TARGET/backend"
FRONTEND="$TARGET/frontend"

# ---------- 5. 백엔드 설치 ----------
if [ $SKIP_INSTALL -eq 0 ]; then
  step "백엔드: venv + 의존성 설치"
  if command -v python3 >/dev/null 2>&1; then
    ( cd "$BACKEND" && python3 -m venv .venv && .venv/bin/python -m pip install --upgrade pip -q && .venv/bin/python -m pip install -r requirements.txt ) \
      && ok "백엔드 의존성 설치 완료" || warn "백엔드 설치 중 오류"
  else warn "python3 없음 — 백엔드 설치 건너뜀"; fi
else warn "skip-install: 백엔드 설치 건너뜀"; fi

# ---------- 6. DB + 테이블(Alembic) ----------
if [ $SKIP_DB -eq 0 ]; then
  step "PostgreSQL: 데이터베이스 생성"
  if command -v psql >/dev/null 2>&1; then
    export PGPASSWORD="$DB_PASSWORD"
    exists=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null)
    if [ "$exists" = "1" ]; then warn "DB 이미 존재: $DB_NAME"
    else
      if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\""; then ok "DB 생성: $DB_NAME"
      else warn "DB 생성 실패 — 접속정보 확인"; fi
    fi
    unset PGPASSWORD
    if [ $SKIP_INSTALL -eq 0 ] && [ -x "$BACKEND/.venv/bin/python" ]; then
      step "Alembic: 테이블 생성 (upgrade head) — DB는 항상 Alembic으로 관리 §11"
      ( cd "$BACKEND" && .venv/bin/python -m alembic upgrade head ) && ok "테이블 생성 완료 (app_meta)" || warn "alembic 실패"
    else warn "venv 미설치 — 'cd backend && .venv/bin/python -m alembic upgrade head' 수동 실행"; fi
  else warn "psql 없음 — DB 생성 건너뜀. 수동 생성 후 alembic upgrade head"; fi
else warn "skip-db: DB 생성/마이그레이션 건너뜀"; fi

# ---------- 7. 프론트 설치 ----------
if [ $SKIP_INSTALL -eq 0 ]; then
  step "프론트엔드: pnpm install"
  if command -v pnpm >/dev/null 2>&1; then
    if ( cd "$FRONTEND" && pnpm install ); then
      ok "프론트 의존성 설치 완료"
    else
      # 흔한 원인: 빌드 스크립트 차단(ERR_PNPM_IGNORED_BUILDS). 승인 후 재시도.
      warn "pnpm install 1차 비정상 종료 — 빌드 스크립트 승인 후 재시도"
      if ( cd "$FRONTEND" && pnpm approve-builds --all >/dev/null 2>&1; pnpm install ); then
        ok "프론트 의존성 설치 완료(재시도)"
      else warn "pnpm install 미완료 — 'cd frontend && pnpm install' 로 직접 확인하세요 (백엔드/DB는 정상)"; fi
    fi
  else warn "pnpm 없음 — 'npm i -g pnpm' 후 'cd frontend && pnpm install'"; fi
else warn "skip-install: 프론트 설치 건너뜀"; fi

# ---------- 8. 안내 ----------
step "완료! 실행 방법"
cat <<EOF
[백엔드]  새 터미널에서:
  cd "$BACKEND"
  source .venv/bin/activate
  uvicorn app.main:app --reload --port 8000

[프론트]  또 다른 터미널에서:
  cd "$FRONTEND"
  pnpm dev              # 개발 서버
  pnpm check            # 타입 검사 (svelte-kit sync + svelte-check)

[확인]    브라우저: http://localhost:5173
          → '백엔드 API'와 '데이터베이스'가 모두 '정상'이면 성공입니다.

[DB 변경] 모델 수정 시 (architecture.md §11):
  cd "$BACKEND"
  .venv/bin/python -m alembic revision --autogenerate -m "변경요약"
  .venv/bin/python -m alembic upgrade head
EOF
