#!/usr/bin/env bash
# 신규 개발 환경 부트스트랩 (macOS / Linux) — 최소 버전 검사 후 부족할 때만 설치.
#
# 정책:
#   - Python : pyenv 로 버전 격리 관리. pyenv 자체가 없으면 brew 로 설치.
#              MIN_PYTHON 계열 최신 패치를 pyenv install 후 .python-version 고정.
#   - Node   : fnm 으로 버전 격리 관리. fnm 자체가 없으면 brew 로 설치.
#              MIN_NODE 버전을 fnm install 후 .nvmrc 고정.
#   - pnpm   : 최소 버전 "이상"이면 재사용, 미만이거나 없을 때만 설치.
#   - PostgreSQL : 있으면 유지, --with-postgres 옵션 시에만 설치.
#
# 사용:
#   ./scripts/bootstrap.sh                  # 런타임만
#   ./scripts/bootstrap.sh --with-postgres  # PostgreSQL 까지
set -euo pipefail

WITH_PG=0
[ "${1:-}" = "--with-postgres" ] && WITH_PG=1

info(){ printf '  [i]  %s\n' "$1"; }
ok(){   printf '  [OK] %s\n' "$1"; }
warn(){ printf '  [!]  %s\n' "$1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 최소 버전 로드 (단일 출처)
# shellcheck disable=SC1091
. "$SCRIPT_DIR/versions.env"
: "${MIN_PYTHON:?versions.env 에서 MIN_PYTHON 누락}"
: "${MIN_NODE:?versions.env 에서 MIN_NODE 누락}"
: "${MIN_PNPM:?versions.env 에서 MIN_PNPM 누락}"

extract_ver(){ printf '%s' "$1" | grep -oE '[0-9]+(\.[0-9]+){0,2}' | head -n1 || true; }
# meets MIN HAVE  -> HAVE >= MIN 이면 0(true)
meets(){
  [ -n "$2" ] || return 1
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]
}

echo "=== 개발 환경 부트스트랩 ($(uname -s)) ==="

# ── 1. pyenv 설치/확인 ──────────────────────────────────────────────────────
if ! command -v pyenv >/dev/null 2>&1; then
  info "pyenv 를 찾을 수 없습니다. brew 로 설치합니다 …"
  if command -v brew >/dev/null 2>&1; then
    brew install pyenv
  else
    warn "Homebrew 없음 — pyenv 를 수동으로 설치하세요: https://github.com/pyenv/pyenv"
    exit 1
  fi
else
  ok "pyenv $(extract_ver "$(pyenv --version 2>/dev/null)") 발견"
fi

# 현재 셸 세션에서 pyenv 활성화
export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path 2>/dev/null || true)"
eval "$(pyenv init - 2>/dev/null || true)"

# ── 2. Python (pyenv 로 버전 고정) ──────────────────────────────────────────
# MIN_PYTHON(예: 3.13) 계열의 최신 패치 버전을 pyenv 목록에서 선택
PYENV_PYTHON="$(pyenv install --list 2>/dev/null \
  | grep -E "^\s+${MIN_PYTHON//./\\.}\.[0-9]+$" \
  | tail -1 \
  | tr -d ' ')"

if [ -z "$PYENV_PYTHON" ]; then
  warn "pyenv 목록에서 Python ${MIN_PYTHON}.x 를 찾지 못했습니다. 'pyenv update' 후 재시도하세요."
  PYENV_PYTHON="$MIN_PYTHON"
fi

if pyenv versions --bare 2>/dev/null | grep -qx "$PYENV_PYTHON"; then
  ok "Python $PYENV_PYTHON 이미 pyenv 에 설치됨 — 재사용"
else
  info "Python $PYENV_PYTHON 설치 (pyenv) …"
  pyenv install "$PYENV_PYTHON"
fi

# 프로젝트 루트에 .python-version 파일로 버전 고정
echo "$PYENV_PYTHON" > "$PROJECT_ROOT/.python-version"
ok "Python $PYENV_PYTHON → $PROJECT_ROOT/.python-version 고정"

# ── 3. fnm 설치/확인 ────────────────────────────────────────────────────────
if ! command -v fnm >/dev/null 2>&1; then
  info "fnm 을 찾을 수 없습니다. brew 로 설치합니다 …"
  if command -v brew >/dev/null 2>&1; then
    brew install fnm
  else
    warn "Homebrew 없음 — fnm 을 수동으로 설치하세요: https://github.com/Schniz/fnm"
    exit 1
  fi
else
  ok "fnm $(extract_ver "$(fnm --version 2>/dev/null)") 발견"
fi

# 현재 셸 세션에서 fnm 활성화
eval "$(fnm env --use-on-cd 2>/dev/null || true)"

# ── 4. Node (fnm 으로 버전 고정) ────────────────────────────────────────────
if fnm list 2>/dev/null | grep -qE "v${MIN_NODE}\."; then
  ok "Node ${MIN_NODE}.x 이미 fnm 에 설치됨 — 재사용"
else
  info "Node ${MIN_NODE} 설치 (fnm) …"
  fnm install "$MIN_NODE"
fi

fnm use "$MIN_NODE"

# 프로젝트 루트에 .nvmrc 파일로 버전 고정
echo "$MIN_NODE" > "$PROJECT_ROOT/.nvmrc"
ok "Node $MIN_NODE → $PROJECT_ROOT/.nvmrc 고정"

# ── 5. pnpm (npm global 설치 — Node 설치 직후라 npm 확실히 존재) ────────────
PNPM="$(extract_ver "$(pnpm --version 2>/dev/null || true)")"
if meets "$MIN_PNPM" "$PNPM"; then
  ok "pnpm $PNPM 재사용 (>= $MIN_PNPM)"
else
  info "pnpm@${MIN_PNPM} 설치 (npm install -g) …"
  if command -v npm >/dev/null 2>&1; then
    npm install -g "pnpm@${MIN_PNPM}" && ok "pnpm 설치 완료" \
      || warn "npm install -g pnpm 실패 — 새 터미널에서 'npm install -g pnpm' 재시도"
  else
    warn "npm 없음 — fnm 으로 Node 설치 후 'npm install -g pnpm'"
  fi
fi

# ── 6. PostgreSQL (선택, 있으면 유지) ───────────────────────────────────────
if [ "$WITH_PG" = "1" ]; then
  if command -v psql >/dev/null 2>&1; then
    ok "PostgreSQL 이미 설치됨 (psql 발견) — 유지"
  else
    info "PostgreSQL 설치 …"
    if command -v brew >/dev/null 2>&1; then brew install postgresql@16 && brew services start postgresql@16
    elif command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y postgresql
    elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y postgresql-server && sudo postgresql-setup --initdb && sudo systemctl enable --now postgresql
    else warn "지원되는 패키지 매니저를 못 찾음 — PostgreSQL 수동 설치 필요"; fi
  fi
else
  warn "PostgreSQL 은 건너뜀. 필요하면 '--with-postgres' 또는 원격 DB 를 사용하세요."
fi

cat <<'EOF'

=== 다음 단계 ===
1) pyenv / fnm 을 새로 설치했다면 ~/.zshrc (또는 ~/.bashrc) 에 아래 줄을 추가하고 새 셸을 여세요:
     # pyenv
     export PYENV_ROOT="$HOME/.pyenv"
     export PATH="$PYENV_ROOT/bin:$PATH"
     eval "$(pyenv init -)"
     # fnm
     eval "$(fnm env --use-on-cd)"
2) 백엔드 의존성:  cd backend && python3 -m venv .venv && ./.venv/bin/python -m pip install -r requirements.txt
3) 프론트 의존성:  cd frontend && pnpm install
4) DB 마이그레이션: backend/.env 의 DATABASE_URL 확인 후  ./.venv/bin/python -m alembic upgrade head
자세한 내용은 README.md 참조.
EOF
