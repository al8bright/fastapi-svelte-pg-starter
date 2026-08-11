#requires -Version 5.1
<#
.SYNOPSIS
  신규 개발 환경 부트스트랩 (Windows) — 최소 버전 검사 후 부족할 때만 설치.

.DESCRIPTION
  정책:
    - Python : pyenv-win 으로 버전 격리 관리. 없으면 winget 으로 설치.
               MIN_PYTHON 계열 최신 패치를 pyenv install 후 .python-version 고정.
    - Node   : fnm 으로 버전 격리 관리. 없으면 winget 으로 설치.
               MIN_NODE 버전을 fnm install 후 .nvmrc 고정.
    - pnpm   : 최소 버전 "이상"이면 재사용, 미만이거나 없을 때만 corepack 으로 설치.
    - PostgreSQL : psql 이 있으면 유지, 없을 때만 (-WithPostgres) winget 으로 설치.

.EXAMPLE
  .\scripts\bootstrap.ps1
.EXAMPLE
  .\scripts\bootstrap.ps1 -WithPostgres
#>
[CmdletBinding()]
param(
  [switch]$WithPostgres,
  # 버전 고정 파일(.python-version/.nvmrc)을 쓸 위치. 미지정 시 이 스크립트의 상위 폴더.
  # scaffold.ps1 은 템플릿 오염을 막기 위해 임시 폴더를 넘긴다.
  [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Info($m){ Write-Host "  [i]  $m" -ForegroundColor Cyan }
function Ok($m)  { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }

# winget 설치 직후 PATH 를 레지스트리(머신+유저) 기준으로 현재 세션에 갱신
function Update-SessionPath {
  $m = [Environment]::GetEnvironmentVariable('Path','Machine')
  $u = [Environment]::GetEnvironmentVariable('Path','User')
  $env:Path = @($m, $u | Where-Object { $_ }) -join ';'
}

# pyenv-win 을 현재 세션에 활성화
function Enable-Pyenv {
  $pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
  if (Test-Path $pyenvRoot) {
    $env:PYENV      = $pyenvRoot
    $env:PYENV_ROOT = $pyenvRoot
    $env:PYENV_HOME = $pyenvRoot
    $env:Path = "$pyenvRoot\bin;$pyenvRoot\shims;" + ($env:Path -replace [regex]::Escape("$pyenvRoot\bin;") -replace [regex]::Escape("$pyenvRoot\shims;"))
  }
}

# "3.13.1" / "v24.3.0" 등에서 major.minor 추출
function Get-Ver([string]$raw){
  if ($raw -and ($raw -match '(\d+)\.(\d+)')) {
    return @{ Major = [int]$matches[1]; Minor = [int]$matches[2] }
  }
  return $null
}
# 설치본($have)이 최소버전($minStr) 이상인가
function Meets($have, [string]$minStr){
  if (-not $have) { return $false }
  $mm = $minStr.Split('.')
  $mj = [int]$mm[0]
  $mn = if ($mm.Count -gt 1) { [int]$mm[1] } else { 0 }
  if ($have.Major -gt $mj) { return $true }
  if ($have.Major -eq $mj -and $have.Minor -ge $mn) { return $true }
  return $false
}
# 명령 실행 결과(버전 문자열) 안전 취득
function Try-Cmd([string]$exe, [string]$arg){
  try { return (& $exe $arg 2>&1 | Out-String) } catch { return "" }
}

Write-Host "`n=== 개발 환경 부트스트랩 (Windows) ===" -ForegroundColor Cyan

# 최소 버전 로드 (단일 출처)
$verFile = Join-Path $PSScriptRoot 'versions.env'
$min = @{}
if (Test-Path $verFile) {
  Get-Content $verFile | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*([0-9.]+)') { $min[$matches[1]] = $matches[2] }
  }
}
foreach ($k in 'MIN_PYTHON','MIN_NODE','MIN_PNPM') {
  if (-not $min[$k]) { throw "versions.env 에서 $k 를 읽지 못했습니다." }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  throw "winget 이 필요합니다. Microsoft Store 에서 'App Installer' 설치 후 다시 실행하세요."
}

if ($ProjectRoot) {
  New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
  $projectRoot = (Resolve-Path $ProjectRoot).Path
} else {
  $projectRoot = Split-Path $PSScriptRoot -Parent
}

# ── 1. pyenv-win 설치/확인 ──────────────────────────────────────────────────
if (-not (Get-Command pyenv -ErrorAction SilentlyContinue)) {
  Info "pyenv-win 을 찾을 수 없습니다. winget 으로 설치합니다 …"
  winget install --id pyenv-win.pyenv-win -e --accept-package-agreements --accept-source-agreements
  Update-SessionPath
} else {
  Ok "pyenv-win $(Try-Cmd 'pyenv' '--version') 발견"
}
Enable-Pyenv

# ── 2. Python (pyenv-win 으로 버전 고정) ────────────────────────────────────
# MIN_PYTHON 계열 최신 패치를 pyenv 목록에서 선택
$pyenvList   = try { pyenv install --list 2>&1 } catch { @() }
$minPyEsc    = [regex]::Escape($min['MIN_PYTHON'])
$pyenvPython = $pyenvList |
  Where-Object { $_ -match "^\s*${minPyEsc}\.\d+\s*$" } |
  Select-Object -Last 1 |
  ForEach-Object { $_.Trim() }

if (-not $pyenvPython) {
  Warn "pyenv 목록에서 Python $($min['MIN_PYTHON']).x 를 찾지 못했습니다. 'pyenv update' 후 재시도하세요."
  $pyenvPython = $min['MIN_PYTHON']
}

$installed = try { pyenv versions 2>&1 | Out-String } catch { "" }
if ($installed -match [regex]::Escape($pyenvPython)) {
  Ok "Python $pyenvPython 이미 pyenv 에 설치됨 — 재사용"
} else {
  Info "Python $pyenvPython 설치 (pyenv-win) …"
  pyenv install $pyenvPython
}

Set-Content -Path (Join-Path $projectRoot '.python-version') -Value $pyenvPython -NoNewline -Encoding ASCII
Ok "Python $pyenvPython → .python-version 고정"
try { pyenv rehash } catch {}

# ── 3. fnm 설치/확인 ────────────────────────────────────────────────────────
if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
  Info "fnm 을 찾을 수 없습니다. winget 으로 설치합니다 …"
  winget install --id Schniz.fnm -e --accept-package-agreements --accept-source-agreements
  Update-SessionPath
} else {
  Ok "fnm $(Try-Cmd 'fnm' '--version') 발견"
}
try { fnm env --use-on-cd | Out-String | Invoke-Expression } catch {}

# ── 4. Node (fnm 으로 버전 고정) ────────────────────────────────────────────
$fnmList = try { fnm list 2>&1 | Out-String } catch { "" }
if ($fnmList -match "v$([regex]::Escape($min['MIN_NODE']))\.") {
  Ok "Node $($min['MIN_NODE']).x 이미 fnm 에 설치됨 — 재사용"
} else {
  Info "Node $($min['MIN_NODE']) 설치 (fnm) …"
  fnm install $min['MIN_NODE']
}
fnm use $min['MIN_NODE']
Set-Content -Path (Join-Path $projectRoot '.nvmrc') -Value $min['MIN_NODE'] -NoNewline -Encoding ASCII
Ok "Node $($min['MIN_NODE']) → .nvmrc 고정"

# ── 5. pnpm (Node 내장 corepack 으로 활성화) ────────────────────────────────
$pnv = Get-Ver (Try-Cmd 'pnpm' '--version')
if (Meets $pnv $min['MIN_PNPM']) {
  Ok ("pnpm {0}.{1} 재사용 (>= {2})" -f $pnv.Major, $pnv.Minor, $min['MIN_PNPM'])
} else {
  Info "pnpm 활성화 (corepack) …"
  try {
    corepack enable
    corepack prepare ("pnpm@{0}" -f $min['MIN_PNPM']) --activate
    Update-SessionPath
    Ok "pnpm 활성화 완료"
  } catch {
    Warn "corepack 활성화 실패 — 새 터미널에서 'corepack enable' 또는 'npm install -g pnpm' 을 시도하세요."
  }
}

# ── 6. PostgreSQL (선택, 있으면 유지) ───────────────────────────────────────
if ($WithPostgres) {
  if (Get-Command psql -ErrorAction SilentlyContinue) {
    Ok "PostgreSQL 이미 설치됨 (psql 발견) — 유지"
  } else {
    Info "PostgreSQL 설치 (winget: PostgreSQL.PostgreSQL) …"
    winget install --id PostgreSQL.PostgreSQL -e --accept-package-agreements --accept-source-agreements
    Update-SessionPath
    Ok "PostgreSQL 설치 완료 — superuser 비밀번호/포트(5432)를 backend\.env 의 DATABASE_URL 에 반영하세요."
  }
} else {
  Warn "PostgreSQL 은 건너뜀. 필요하면 '-WithPostgres' 로 설치하거나 원격 DB 를 사용하세요."
}

Write-Host "`n=== 다음 단계 ===" -ForegroundColor Cyan
Write-Host @"
1) pyenv-win / fnm 을 새로 설치했다면 새 터미널을 열어 PATH 를 반영하세요.
   PowerShell 프로파일(`$PROFILE)에 아래 줄을 추가하면 자동 활성화됩니다:
     # pyenv-win
     `$env:PYENV      = "`$env:USERPROFILE\.pyenv\pyenv-win"
     `$env:PYENV_ROOT = `$env:PYENV
     `$env:PYENV_HOME = `$env:PYENV
     `$env:Path = "`$env:PYENV\bin;`$env:PYENV\shims;`$env:Path"
     # fnm
     fnm env --use-on-cd | Out-String | Invoke-Expression
2) 백엔드 의존성:  cd backend; python -m venv .venv; .\.venv\Scripts\python -m pip install -r requirements.txt
3) 프론트 의존성:  cd frontend; pnpm install
4) DB 마이그레이션: backend\.env 의 DATABASE_URL 확인 후  .\.venv\Scripts\python -m alembic upgrade head
자세한 내용은 README.md 참조.
"@ -ForegroundColor White
