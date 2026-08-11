#requires -Version 5.1
<#
.SYNOPSIS
  공통 아키텍처 기반 신규 프로젝트 스캐폴드 (architecture.md 준수).

.DESCRIPTION
  skeleton/ 골격을 복사하고 토큰을 치환한 뒤,
  DESIGN.md(선택) → Tailwind 테마, .env 생성, psql 로 DB 생성,
  Alembic 으로 테이블 생성(upgrade head), 의존성 설치까지 한 번에 수행한다.
  마지막에 uvicorn / pnpm dev 실행 방법을 출력한다.

.EXAMPLE
  .\scaffold.ps1 -Name project_test -Target P:\fastapi\project_test

.EXAMPLE
  .\scaffold.ps1 -Name Demo -Target P:\tmp\Demo -SkipDb -SkipInstall
#>
[CmdletBinding()]
param(
  [string]$Name,
  [string]$Target,
  [switch]$SkipDb,
  [switch]$SkipInstall,
  [switch]$Design,
  [switch]$NoDesign,
  [string]$DbHost = "localhost",
  [int]$DbPort = 5432,
  [string]$DbUser = "postgres",
  [string]$DbPassword,
  [string]$DbName
)

$ErrorActionPreference = "Stop"
# 한글 메시지가 콘솔에서 깨지지 않도록 출력 인코딩을 UTF-8 로 (Windows PowerShell 5.1 대응)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$TemplateDir = $PSScriptRoot
$SkeletonDir = Join-Path $TemplateDir "skeleton"
$DesignFile  = Join-Path $TemplateDir "DESIGN.md"
$Enc = [System.Text.UTF8Encoding]::new($false)

function Write-Step($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn2($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }

# pyenv-win / fnm 활성화 (설치돼 있으면 현재 세션에 적용)
function Enable-VersionManagers {
  $pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
  if (Test-Path $pyenvRoot) {
    $env:PYENV      = $pyenvRoot
    $env:PYENV_ROOT = $pyenvRoot
    $env:PYENV_HOME = $pyenvRoot
    $env:Path = "$pyenvRoot\bin;$pyenvRoot\shims;" + ($env:Path -replace [regex]::Escape("$pyenvRoot\bin;") -replace [regex]::Escape("$pyenvRoot\shims;"))
  }
  if (Get-Command fnm -ErrorAction SilentlyContinue) {
    try { fnm env --use-on-cd | Out-String | Invoke-Expression } catch {}
  }
}
Enable-VersionManagers

# 필수 도구 확인 — 미달이면 bootstrap.ps1 자동 실행
$_Bootstrap   = Join-Path $TemplateDir 'skeleton\scripts\bootstrap.ps1'
$_VersionsEnv = Join-Path $TemplateDir 'skeleton\scripts\versions.env'
$_min = @{}
if (Test-Path $_VersionsEnv) {
  Get-Content $_VersionsEnv | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*([0-9.]+)') { $_min[$matches[1]] = $matches[2] }
  }
}
function _Get-SemVer([string]$raw) {
  if ($raw -and ($raw -match '(\d+)\.(\d+)')) { return @{ Major=[int]$matches[1]; Minor=[int]$matches[2] } }
  return $null
}
function _Meets($have, [string]$minStr) {
  if (-not $have) { return $false }
  $mm = $minStr.Split('.'); $mj = [int]$mm[0]; $mn = if ($mm.Count -gt 1) { [int]$mm[1] } else { 0 }
  return ($have.Major -gt $mj -or ($have.Major -eq $mj -and $have.Minor -ge $mn))
}

$_needBootstrap = $false
if (-not (Get-Command pyenv -ErrorAction SilentlyContinue)) { $_needBootstrap = $true }
if (-not (Get-Command fnm   -ErrorAction SilentlyContinue)) { $_needBootstrap = $true }
# 주의: (try {...} catch {...}) 는 인자 자리에서 try 를 명령어로 해석해 실패한다. 문으로 분리한다.
$_pyRaw = ""
try { $_pyRaw = (python --version 2>&1 | Out-String) } catch { $_pyRaw = "" }
$_pyVer = _Get-SemVer $_pyRaw
# 주의: ?? 는 PowerShell 7 전용 — 5.1 에서는 파싱 단계에서 죽는다. 절대 되돌리지 말 것.
$_minPy = $_min['MIN_PYTHON']
if (-not $_minPy) { $_minPy = '3.10' }
if (-not (_Meets $_pyVer $_minPy)) { $_needBootstrap = $true }

# bootstrap 이 고정한 런타임 버전을 받아둘 임시 폴더 (템플릿 리포를 더럽히지 않기 위함)
$_PinDir = $null
if ($_needBootstrap) {
  if (Test-Path $_Bootstrap) {
    Write-Warn2 "필수 도구(pyenv-win·fnm) 없거나 Python 버전 미달 — bootstrap.ps1 을 먼저 실행합니다 …"
    $_PinDir = Join-Path ([System.IO.Path]::GetTempPath()) ("scaffold-pin-" + [guid]::NewGuid().ToString("N").Substring(0,8))
    New-Item -ItemType Directory -Force -Path $_PinDir | Out-Null
    & $_Bootstrap -ProjectRoot $_PinDir
    Enable-VersionManagers
    # bootstrap 후 Node 버전을 현재 세션에 명시 활성화 (fnm env 만으로는 활성화되지 않는다)
    $_nvmrc = Join-Path $_PinDir ".nvmrc"
    if (Test-Path $_nvmrc) {
      $_pinNode = (Get-Content -Raw $_nvmrc).Trim()
      if ($_pinNode) { try { fnm use $_pinNode 2>$null } catch { } }
    }
  } else {
    Write-Warn2 "bootstrap.ps1 을 찾을 수 없습니다 ($_Bootstrap). 수동으로 먼저 실행하세요."
    exit 1
  }
}

# ---------- 테마(@theme) 생성 ----------
function Get-DefaultTheme {
@'
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
'@
}

function Get-ThemeFromDesign([string]$path) {
  $lines = Get-Content -LiteralPath $path
  $inFront = $false; $section = ""; $colors = [ordered]@{}; $font = $null
  foreach ($line in $lines) {
    if ($line.Trim() -eq "---") {
      if (-not $inFront) { $inFront = $true; continue } else { break }
    }
    if (-not $inFront) { continue }
    if ($line -match '^[A-Za-z]') {
      if ($line -match '^colors:')          { $section = "colors" }
      elseif ($line -match '^typography:')  { $section = "typography" }
      else                                  { $section = "" }
      continue
    }
    if ($section -eq "colors" -and $line -match "^\s+([a-z0-9-]+):\s*'?(#[0-9a-fA-F]{3,8})'?") {
      $colors[$matches[1]] = $matches[2]
    }
    if ($section -eq "typography" -and -not $font -and $line -match "fontFamily:\s*'?([^'\r\n]+?)'?\s*$") {
      $font = $matches[1].Trim()
    }
  }
  if ($colors.Count -eq 0) { return Get-DefaultTheme }
  $fam = if ($font) { $font } else { "Inter" }
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("@theme {")
  [void]$sb.AppendLine("  --font-sans: '$fam', 'Noto Sans KR', system-ui, sans-serif;")
  foreach ($k in $colors.Keys) { [void]$sb.AppendLine("  --color-$($k): $($colors[$k]);") }
  [void]$sb.AppendLine("}")
  return $sb.ToString()
}

# ---------- 1. 입력 수집 ----------
Write-Step "신규 프로젝트 스캐폴드"
if (-not $Name)   { $Name = Read-Host "프로젝트 이름 (예: project_test)" }
if (-not $Name)   { throw "프로젝트 이름이 필요합니다." }
# -Target 미지정 시 기본값: _project-template 의 부모 폴더에 <이름> 으로 생성
if (-not $Target) {
  $defaultTarget = Join-Path (Split-Path $TemplateDir -Parent) $Name
  try { $i = Read-Host "생성 위치 [$defaultTarget]" } catch { $i = "" }
  $Target = if ($i) { $i } else { $defaultTarget }
}

$snake = ($Name -creplace '([a-z0-9])([A-Z])', '$1_$2') -replace '[^A-Za-z0-9]+', '_'
$snake = $snake.Trim('_').ToLower()
if (-not $DbName) { $DbName = $snake }
# 상대 경로는 .NET 프로세스 디렉토리가 아니라 현재 PowerShell 위치 기준으로 해석한다.
# (PS 5.1 호환: 2-인자 GetFullPath 오버로드가 없으므로 직접 결합 후 정규화)
if (-not [System.IO.Path]::IsPathRooted($Target)) {
  $Target = Join-Path (Get-Location).Path $Target
}
$Target = [System.IO.Path]::GetFullPath($Target)
Write-Ok "이름=$Name  snake=$snake  위치=$Target"

# DESIGN.md 사용 여부 (-Design / -NoDesign 우선, 없으면 질문, 비대화형이면 기본 적용)
if ($NoDesign -or -not (Test-Path $DesignFile)) {
  $useDesign = $false
} elseif ($Design) {
  $useDesign = $true
} else {
  try {
    $ans = Read-Host "DESIGN.md 의 색상/타이포그래피를 적용할까요? (Y/n)"
    $useDesign = ($ans -eq "" -or $ans -match '^[Yy]')
  } catch { $useDesign = $true }
}
$themeCss = if ($useDesign) { Get-ThemeFromDesign $DesignFile } else { Get-DefaultTheme }
if ($useDesign) { Write-Ok "DESIGN.md 테마 적용" } else { Write-Ok "기본 테마 적용" }

# DB 접속 정보
if (-not $SkipDb) {
  Write-Step "PostgreSQL 접속 정보 (psql 로 DB 생성)"
  $i = Read-Host "DB host [$DbHost]"; if ($i) { $DbHost = $i }
  $i = Read-Host "DB port [$DbPort]"; if ($i) { $DbPort = [int]$i }
  $i = Read-Host "DB user [$DbUser]"; if ($i) { $DbUser = $i }
  if (-not $DbPassword) { $DbPassword = Read-Host "DB password" }
  $i = Read-Host "DB name [$DbName]"; if ($i) { $DbName = $i }
}
$databaseUrl = "postgresql+psycopg2://${DbUser}:${DbPassword}@${DbHost}:${DbPort}/${DbName}"
# SECRET_KEY 는 JWT 서명 키다. Get-Random(System.Random) 은 CSPRNG 가 아니므로 쓰지 않는다.
$_secBytes = [byte[]]::new(24)
$_rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $_rng.GetBytes($_secBytes) } finally { $_rng.Dispose() }
$secret = -join ($_secBytes | ForEach-Object { $_.ToString('x2') })

# ---------- 2. 골격 복사 ----------
Write-Step "골격 복사 → $Target"
New-Item -ItemType Directory -Force -Path $Target | Out-Null
Copy-Item -Path (Join-Path $SkeletonDir '*') -Destination $Target -Recurse -Force
# 안전장치: 닷파일 누락 시 보강
foreach ($dot in '.gitignore', '.gitattributes') {
  $src = Join-Path $SkeletonDir $dot
  $dst = Join-Path $Target $dot
  if ((Test-Path $src) -and (-not (Test-Path $dst))) { Copy-Item $src $dst -Force }
}
# 안전장치: .claude (스킬/지침 디렉토리) 누락 시 재귀 보강
$claudeSrc = Join-Path $SkeletonDir '.claude'
$claudeDst = Join-Path $Target '.claude'
if ((Test-Path $claudeSrc) -and (-not (Test-Path $claudeDst))) {
  Copy-Item $claudeSrc $claudeDst -Recurse -Force
}
if ($useDesign) { Copy-Item $DesignFile (Join-Path $Target 'docs\DESIGN.md') -Force }
# bootstrap 이 실제로 설치·고정한 런타임 버전을 생성 프로젝트에 반영 (골격의 값은 덮어쓴다)
if ($_PinDir) {
  foreach ($pin in '.python-version', '.nvmrc') {
    $srcPin = Join-Path $_PinDir $pin
    if (Test-Path $srcPin) { Copy-Item $srcPin (Join-Path $Target $pin) -Force }
  }
  Remove-Item -Recurse -Force $_PinDir -ErrorAction SilentlyContinue
}
Write-Ok "복사 완료"

# ---------- 3. 토큰 치환 ----------
Write-Step "토큰 치환"
$inc = '*.ts','*.svelte','*.py','*.css','*.html','*.json','*.md','*.ini','*.mako','*.js','*.example','*.txt'
# -Force: 숨김 속성/닷 디렉토리(.claude, .github) 하위 파일도 치환 대상에 포함시킨다.
$files = Get-ChildItem -Path $Target -Recurse -File -Force -Include $inc
foreach ($f in $files) {
  $t = [System.IO.File]::ReadAllText($f.FullName)
  $o = $t
  $t = $t.Replace('__PROJECT_NAME__', $Name).Replace('__PROJECT_SNAKE__', $snake).Replace('__THEME_CSS__', $themeCss)
  if ($t -ne $o) { [System.IO.File]::WriteAllText($f.FullName, $t, $Enc) }
}
Write-Ok "치환 완료"

# ---------- 4. .env 생성 ----------
Write-Step ".env 생성 (OS 무관 주입 — architecture.md §5)"
$backendEnv = @"
DATABASE_URL=$databaseUrl
SECRET_KEY=$secret
ACCESS_TOKEN_EXPIRE_MINUTES=30
CORS_ORIGINS=http://localhost:5173
FRONTEND_URL=http://localhost:5173
BACKEND_PUBLIC_URL=http://localhost:8000
TZ=Asia/Seoul
"@
[System.IO.File]::WriteAllText((Join-Path $Target 'backend\.env'), $backendEnv, $Enc)
$frontendEnv = "VITE_API_BASE_URL=`nVITE_BACKEND_URL=http://localhost:8000`n"
[System.IO.File]::WriteAllText((Join-Path $Target 'frontend\.env'), $frontendEnv, $Enc)
Write-Ok "backend\.env, frontend\.env 생성 (DATABASE_URL, SECRET_KEY 주입)"

$backend  = Join-Path $Target 'backend'
$frontend = Join-Path $Target 'frontend'

# ---------- 5. 백엔드 설치 ----------
if (-not $SkipInstall) {
  Write-Step "백엔드: venv + 의존성 설치"
  Push-Location $backend
  try {
    python -m venv .venv
    & .\.venv\Scripts\python.exe -m pip install --upgrade pip --quiet
    & .\.venv\Scripts\python.exe -m pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "pip install 미완료 — 'cd backend; .\.venv\Scripts\python -m pip install -r requirements.txt'" }
    else { Write-Ok "백엔드 의존성 설치 완료" }
  } finally { Pop-Location }
} else { Write-Warn2 "SkipInstall: 백엔드 설치 건너뜀" }

# ---------- 6. DB 생성 + 테이블(Alembic) ----------
if (-not $SkipDb) {
  Write-Step "PostgreSQL: 데이터베이스 생성"
  $psql = Get-Command psql -ErrorAction SilentlyContinue
  if (-not $psql) {
    Write-Warn2 "psql 을 PATH 에서 찾을 수 없습니다. DB 생성을 건너뜁니다."
    Write-Warn2 "수동: psql -U $DbUser -c `"CREATE DATABASE $DbName`" 후 alembic upgrade head"
  } else {
    $env:PGPASSWORD = $DbPassword
    try {
      $exists = & psql -h $DbHost -p $DbPort -U $DbUser -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DbName'"
      if ("$exists".Trim() -eq "1") {
        Write-Warn2 "DB 이미 존재: $DbName"
      } else {
        & psql -h $DbHost -p $DbPort -U $DbUser -d postgres -c "CREATE DATABASE `"$DbName`""
        if ($LASTEXITCODE -ne 0) { throw "CREATE DATABASE 실패" }
        Write-Ok "DB 생성: $DbName"
      }
    } finally { Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue }

    if (-not $SkipInstall) {
      Write-Step "Alembic: 테이블 생성 (upgrade head) — DB는 항상 Alembic으로 관리 §11"
      Push-Location $backend
      try {
        & .\.venv\Scripts\python.exe -m alembic upgrade head
        if ($LASTEXITCODE -ne 0) { throw "alembic upgrade 실패" }
        Write-Ok "테이블 생성 완료 (app_meta)"
      } finally { Pop-Location }
    } else {
      Write-Warn2 "SkipInstall: alembic 미실행. 'cd backend; .\.venv\Scripts\python -m alembic upgrade head'"
    }
  }
} else { Write-Warn2 "SkipDb: DB 생성/마이그레이션 건너뜀" }

# ---------- 7. 프론트엔드 설치 ----------
if (-not $SkipInstall) {
  Write-Step "프론트엔드: pnpm install"
  $pnpm = Get-Command pnpm -ErrorAction SilentlyContinue
  if (-not $pnpm) {
    Write-Warn2 "pnpm 이 없습니다. 'npm i -g pnpm' 후 'cd frontend; pnpm install'"
  } else {
    Push-Location $frontend
    try {
      pnpm install
      if ($LASTEXITCODE -ne 0) {
        # 흔한 원인: 빌드 스크립트 차단(ERR_PNPM_IGNORED_BUILDS, esbuild 등). 승인 후 재시도.
        Write-Warn2 "pnpm install 1차 비정상 종료 — 빌드 스크립트 승인 후 재시도"
        pnpm approve-builds --all 2>$null
        pnpm install
      }
      if ($LASTEXITCODE -eq 0) { Write-Ok "프론트 의존성 설치 완료" }
      else { Write-Warn2 "pnpm install 미완료 — 'cd frontend; pnpm install' 로 직접 확인하세요 (백엔드/DB는 정상)" }
    } finally { Pop-Location }
  }
} else { Write-Warn2 "SkipInstall: 프론트 설치 건너뜀" }

# ---------- 8. 실행 안내 ----------
Write-Step "완료! 실행 방법"
Write-Host @"
[백엔드]  새 PowerShell 터미널에서:
  cd "$backend"
  .\.venv\Scripts\Activate.ps1
  uvicorn app.main:app --reload --port 8000

[프론트]  또 다른 터미널에서:
  cd "$frontend"
  pnpm dev              # 개발 서버
  pnpm check            # 타입 검사 (svelte-kit sync + svelte-check)

[확인]    브라우저: http://localhost:5173
          → '백엔드 API'와 '데이터베이스'가 모두 '정상'이면 성공입니다.

[DB 변경] 모델 수정 시 (architecture.md §11):
  cd "$backend"
  .\.venv\Scripts\python -m alembic revision --autogenerate -m "변경요약"
  .\.venv\Scripts\python -m alembic upgrade head
"@ -ForegroundColor White
