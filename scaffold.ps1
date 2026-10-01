#requires -Version 5.1
<#
.SYNOPSIS
  공통 아키텍처 기반 신규 프로젝트 스캐폴드 (ARCHITECTURE.md 준수).

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
$DesignFile  = Join-Path $SkeletonDir "DESIGN.md"
$Enc = [System.Text.UTF8Encoding]::new($false)

function Write-Step($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Warn2($m){ Write-Host "  [!]  $m" -ForegroundColor Yellow }

# 최소 버전 로드 (단일 출처 versions.env — Enable-VersionManagers 의 fnm use 에서도 쓰므로 먼저 읽는다)
$_Bootstrap   = Join-Path $TemplateDir 'skeleton\scripts\bootstrap.ps1'
$_VersionsEnv = Join-Path $TemplateDir 'skeleton\scripts\versions.env'
$_min = @{}
if (Test-Path $_VersionsEnv) {
  Get-Content $_VersionsEnv | ForEach-Object {
    if ($_ -match '^\s*([A-Z_]+)\s*=\s*([0-9.]+)') { $_min[$matches[1]] = $matches[2] }
  }
}

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
    # PS 5.1 은 EAP=Stop 아래에서 네이티브 stderr 한 줄을 NativeCommandError 로 종료 예외화한다
    # (종료 코드 0 일 때도). 그대로 두면 fnm 이 진행 상황을 stderr 로 쓰는 순간 catch 로 떨어져
    # Invoke-Expression 이 실행되지 않고 fnm 환경이 조용히 적용되지 않는다 — 이후 pnpm 을 못 찾는다.
    # 함수 스코프에서만 Continue 로 낮추고 성공/실패는 $LASTEXITCODE 로만 판정한다.
    $ErrorActionPreference = 'Continue'
    try {
      $_fnmEnv = fnm env --use-on-cd 2>&1
      if ($LASTEXITCODE -eq 0) { $_fnmEnv | Out-String | Invoke-Expression }
    } catch {}
    # 템플릿 루트에는 .nvmrc 가 없으므로 최소 Node 버전을 명시해 활성화
    $_nodeDefault = if ($_min['MIN_NODE']) { $_min['MIN_NODE'] } else { '24' }
    try {
      fnm use $_nodeDefault 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) { return }
    } catch {}
  }
}
Enable-VersionManagers

# 필수 도구 확인 — 미달이면 bootstrap.ps1 자동 실행
function _Get-SemVer([string]$raw) {
  if ($raw -and ($raw -match '(\d+)\.(\d+)')) { return @{ Major=[int]$matches[1]; Minor=[int]$matches[2] } }
  return $null
}
function _Meets($have, [string]$minStr) {
  if (-not $have) { return $false }
  $mm = $minStr.Split('.'); $mj = [int]$mm[0]; $mn = if ($mm.Count -gt 1) { [int]$mm[1] } else { 0 }
  return ($have.Major -gt $mj -or ($have.Major -eq $mj -and $have.Minor -ge $mn))
}

# bootstrap 이 필요한 기준은 "런타임이 하한 미달"이다 (versions.env 정책: 이상이면 재사용).
# ⛔ pyenv/fnm 이 없다는 이유만으로 bootstrap 을 강제하지 않는다 — Windows 에서 pyenv-win 은
# 자동 설치 대상이 아니라, 이미 조건을 만족한 환경까지 골격 생성 전에 막아버린다.
$_needBootstrap = $false
$_pyVer = _Get-SemVer $(try { python --version 2>&1 | Out-String } catch { "" })
# PS 5.1 호환: '??'(null 병합, PS7+) 대신 if 식 사용. 폴백은 versions.env 와 동일한 3.13.
$_minPython = if ($_min['MIN_PYTHON']) { $_min['MIN_PYTHON'] } else { '3.13' }
if (-not (_Meets $_pyVer $_minPython)) { $_needBootstrap = $true }
$_nodeHave = _Get-SemVer $(try { node --version 2>&1 | Out-String } catch { "" })
$_minNode = if ($_min['MIN_NODE']) { $_min['MIN_NODE'] } else { '24' }
if (-not (_Meets $_nodeHave $_minNode)) { $_needBootstrap = $true }
$_pnpmHave = _Get-SemVer $(try { pnpm --version 2>&1 | Out-String } catch { "" })
$_minPnpm = if ($_min['MIN_PNPM']) { $_min['MIN_PNPM'] } else { '11' }
if (-not (_Meets $_pnpmHave $_minPnpm)) { $_needBootstrap = $true }
# skeleton\.python-version 핀 처리
#  - pyenv 가 있으면: 핀된 정확한 버전이 실제 설치돼 있어야 한다(없으면 bootstrap 이 설치).
#  - pyenv 가 없으면: 핀을 강제할 수단이 없다. 하한을 충족하는 Python 을 그대로 쓰되,
#    CI 는 .python-version 을 읽으므로 버전이 다르면 경고만 남긴다.
$_pyPinFile = Join-Path $SkeletonDir '.python-version'
$_pyPin = if (Test-Path $_pyPinFile) { "$(Get-Content $_pyPinFile -TotalCount 1)".Trim() } else { "" }
if ($_pyPin) {
  if (Get-Command pyenv -ErrorAction SilentlyContinue) {
    if (-not $_needBootstrap) {
      $_pyenvInstalled = $(try { pyenv versions --bare 2>&1 | Out-String } catch { "" })
      $_installedList = "$_pyenvInstalled" -split '\r?\n' | ForEach-Object { $_.Trim() }
      if ($_installedList -notcontains $_pyPin) { $_needBootstrap = $true }
    }
  } elseif (-not $_needBootstrap) {
    $_pyActual = ($(try { python --version 2>&1 | Out-String } catch { "" }) -replace '[^0-9.]', '').Trim()
    if ($_pyActual -and $_pyActual -ne $_pyPin -and -not $_pyActual.StartsWith("$_pyPin.")) {
      Write-Warn2 "Python 핀($_pyPin)과 설치본($_pyActual)이 다릅니다 — CI 는 .python-version 을 읽으므로 로컬과 다른 버전을 씁니다."
      Write-Host "        일치시키려면 pyenv-win 을 설치해 핀 버전을 쓰거나, 생성 후 프로젝트의 .python-version 을 설치본에 맞추세요." -ForegroundColor Yellow
    }
  }
}

# bootstrap 이 고정한 런타임 버전을 받아둘 임시 폴더.
# ⛔ -ProjectRoot 없이 실행하면 bootstrap 이 템플릿의 skeleton\.python-version·.nvmrc 를
#    덮어써 리포를 오염시킨다. 임시 폴더에 받아 둔 뒤 복사 단계에서 생성 프로젝트로 옮긴다.
$_PinDir = $null
if ($_needBootstrap) {
  if (Test-Path $_Bootstrap) {
    Write-Warn2 "필수 도구 또는 Python·Node·pnpm 버전이 기준 미달 — bootstrap.ps1 을 먼저 실행합니다 …"
    $_PinDir = Join-Path ([System.IO.Path]::GetTempPath()) ("scaffold-pin-" + [guid]::NewGuid().ToString("N").Substring(0,8))
    New-Item -ItemType Directory -Force -Path $_PinDir | Out-Null
    # PS 5.1 은 스크립트/네이티브 명령 실패를 자동 예외화하지 않고, in-process 호출의
    # $LASTEXITCODE 는 내부 마지막 네이티브 명령의 잔존값이라 신뢰할 수 없다.
    # → 예외 포착 + bootstrap 결과(실제 런타임 버전) 검증으로 실패를 감지한다 (scaffold.sh 와 동일하게 실패 시 중단).
    # 검증 기준은 "런타임이 하한을 충족하는가"이지 "pyenv·fnm 이 설치됐는가"가 아니다 —
    # 관리자 없이 기존 설치본을 재사용하는 경로가 정상 경로이기 때문이다.
    $_bootstrapOk = $true
    try { & $_Bootstrap -ProjectRoot $_PinDir } catch {
      Write-Warn2 "bootstrap.ps1 실행 중 오류: $($_.Exception.Message)"
      $_bootstrapOk = $false
    }
    Enable-VersionManagers
    if ($_bootstrapOk -and (Get-Command fnm -ErrorAction SilentlyContinue)) {
      $_nodeVer = if ($_min['MIN_NODE']) { $_min['MIN_NODE'] } else { '24' }
      try {
        fnm use $_nodeVer 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "종료 코드 $LASTEXITCODE" }
      } catch {
        Write-Warn2 "bootstrap 후 Node $_nodeVer 활성화 실패: $($_.Exception.Message)"
        $_bootstrapOk = $false
      }
    }
    $_pyAfter = _Get-SemVer $(try { python --version 2>&1 | Out-String } catch { "" })
    if ($_bootstrapOk -and -not (_Meets $_pyAfter $_minPython)) {
      Write-Warn2 "bootstrap 후에도 Python 이 $_minPython 이상이 아닙니다."
      $_bootstrapOk = $false
    }
    $_nodeAfter = _Get-SemVer $(try { node --version 2>&1 | Out-String } catch { "" })
    if ($_bootstrapOk -and -not (_Meets $_nodeAfter $_minNode)) {
      Write-Warn2 "bootstrap 후에도 Node 가 $_minNode 이상이 아닙니다."
      $_bootstrapOk = $false
    }
    $_pnpmAfter = _Get-SemVer $(try { pnpm --version 2>&1 | Out-String } catch { "" })
    if ($_bootstrapOk -and -not (_Meets $_pnpmAfter $_minPnpm)) {
      Write-Warn2 "bootstrap 후에도 pnpm 이 $_minPnpm 이상이 아닙니다."
      $_bootstrapOk = $false
    }
    # 핀이 pyenv 에 설치됐는지는 경고 대상이지 중단 사유가 아니다.
    # bootstrap 이 핀을 설치하지 못해도 하한을 충족하는 Python 으로 폴백했을 수 있고, 그 경우
    # 위의 런타임 검증을 이미 통과했다. 여기서 중단하면 폴백 경로가 의미를 잃는다.
    if ($_bootstrapOk -and (Get-Command pyenv -ErrorAction SilentlyContinue)) {
      $_pyPinFile2 = Join-Path $SkeletonDir '.python-version'
      if (Test-Path $_pyPinFile2) {
        $_pyPin2 = "$(Get-Content $_pyPinFile2 -TotalCount 1)".Trim()
        if ($_pyPin2) {
          $_installed2 = $(try { pyenv versions --bare 2>&1 | Out-String } catch { "" })
          $_installedList2 = "$_installed2" -split '\r?\n' | ForEach-Object { $_.Trim() }
          if ($_installedList2 -notcontains $_pyPin2) {
            Write-Warn2 "Python 핀 $_pyPin2 이 pyenv 에 없습니다 — 하한을 충족하는 설치본으로 진행합니다. CI 는 핀을 사용합니다."
          }
        }
      }
    }
    if (-not $_bootstrapOk) {
      Write-Warn2 "bootstrap.ps1 실패 — 스캐폴드를 중단합니다. 위 로그의 오류를 해결한 뒤 다시 실행하세요."
      Remove-Item -Recurse -Force $_PinDir -ErrorAction SilentlyContinue
      exit 1
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
Write-Step ".env 생성 (OS 무관 주입 — ARCHITECTURE.md §5)"
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

[DB 변경] 모델 수정 시 (ARCHITECTURE.md §11):
  cd "$backend"
  .\.venv\Scripts\python -m alembic revision --autogenerate -m "변경요약"
  .\.venv\Scripts\python -m alembic upgrade head
"@ -ForegroundColor White
