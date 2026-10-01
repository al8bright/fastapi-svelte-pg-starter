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

# 런타임 핀 로드 — ⚠️ 반드시 Enable-VersionManagers 보다 먼저 읽어야 한다.
# pyenv 는 "shim 이 PATH 에 있다"와 "어떤 버전을 쓴다"가 별개라, 활성화 시점에 핀 값이 필요하다.
$_pyPinFile   = Join-Path $SkeletonDir '.python-version'
$_pyPin       = if (Test-Path $_pyPinFile) { "$(Get-Content $_pyPinFile -TotalCount 1)".Trim() } else { "" }
$_nodePinFile = Join-Path $SkeletonDir '.nvmrc'
$_nodePin     = if (Test-Path $_nodePinFile) { "$(Get-Content $_nodePinFile -TotalCount 1)".Trim() -replace '^v', '' } else { "" }

# pyenv-win / fnm 활성화 (설치돼 있으면 현재 세션에 적용)
function Enable-VersionManagers {
  $pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
  if (Test-Path $pyenvRoot) {
    $env:PYENV      = $pyenvRoot
    $env:PYENV_ROOT = $pyenvRoot
    $env:PYENV_HOME = $pyenvRoot
    $env:Path = "$pyenvRoot\bin;$pyenvRoot\shims;" + ($env:Path -replace [regex]::Escape("$pyenvRoot\bin;") -replace [regex]::Escape("$pyenvRoot\shims;"))
    # ⛔ PATH 에 shim 을 올리는 것과 "어떤 버전을 쓸지" 는 별개다. pyenv global 이 없거나 핀보다 낮으면
    #    shim 이 실패하거나 옛 버전을 가리켜, bootstrap 이 핀을 설치·재사용한 뒤에도 검증 단계에서 실패한다.
    #    ⚠️ 설치돼 있지 않은 버전을 지정하면 모든 shim 호출이 깨지므로 반드시 설치 여부를 확인한다.
    $_installedNow = @($(try { pyenv versions --bare 2>&1 | Out-String } catch { "" }) -split '\r?\n' |
      ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($_pyPin -and ($_installedNow -contains $_pyPin)) {
      $env:PYENV_VERSION = $_pyPin
    } else {
      # 핀이 설치돼 있지 않으면 하한을 충족하는 설치본 중 가장 높은 것을 고른다 (옛 전역 버전 폴백 방지)
      $_minPy = if ($_min['MIN_PYTHON']) { $_min['MIN_PYTHON'] } else { '3.13' }
      $_cand = $_installedNow | Where-Object { $_ -match '^\d+\.\d+\.\d+$' -and $_.StartsWith("$_minPy.") } |
        Sort-Object { [version]$_ } | Select-Object -Last 1
      if ($_cand) { $env:PYENV_VERSION = $_cand }
    }
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
    # .nvmrc 핀을 우선 존중하고, 실패하면 최소 Node 버전으로 활성화한다
    # (템플릿 루트에는 .nvmrc 가 없으므로 cd 훅만으로는 활성화되지 않는다)
    $_nodeDefault = if ($_min['MIN_NODE']) { $_min['MIN_NODE'] } else { '24' }
    $_nodeWanted  = if ($_nodePin) { $_nodePin } else { $_nodeDefault }
    try {
      fnm use $_nodeWanted 2>&1 | Out-Null
      if ($LASTEXITCODE -ne 0) { fnm use $_nodeDefault 2>&1 | Out-Null }
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
# ($_pyPin 로드는 위 활성화 블록보다 앞에서 이미 끝났다)
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
    # 골격의 핀을 미리 심어 bootstrap 이 "기존 .python-version 핀 존중" 경로를 타게 한다.
    # ⛔ 빈 폴더를 넘기면 bootstrap 이 핀을 못 읽고 임의의 최신 패치를 골라, 생성 프로젝트의
    #    런타임 버전이 "스캐폴드를 돌린 날"에 따라 달라진다(재현 불가).
    if (Test-Path $_pyPinFile)   { Copy-Item $_pyPinFile   (Join-Path $_PinDir '.python-version') -Force }
    if (Test-Path $_nodePinFile) { Copy-Item $_nodePinFile (Join-Path $_PinDir '.nvmrc') -Force }
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
    # bootstrap 이 실제로 고정한 버전을 핀으로 재채택한 뒤 활성화한다.
    # (핀이 pyenv 에 없어 bootstrap 이 다른 패치로 폴백했을 수 있다)
    if (Test-Path (Join-Path $_PinDir '.python-version')) {
      $_pyPin = "$(Get-Content (Join-Path $_PinDir '.python-version') -TotalCount 1)".Trim()
    }
    if (Test-Path (Join-Path $_PinDir '.nvmrc')) {
      $_nodePin = "$(Get-Content (Join-Path $_PinDir '.nvmrc') -TotalCount 1)".Trim() -replace '^v', ''
    }
    # fnm use 는 이 함수 안에서 핀 기준으로 수행된다.
    # ⛔ 활성화 실패를 곧바로 중단 사유로 삼지 않는다 — 관리자 없이 기존 설치본을 재사용하는
    #    정상 경로까지 막아버린다(scaffold.sh 와 동일). 판정은 아래 런타임 재검증이 한다.
    Enable-VersionManagers
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
# 초기 관리자 비밀번호도 무작위로 생성한다.
# ⛔ 하드코딩된 기본값(admin123)을 쓰면 이 템플릿으로 만든 모든 프로젝트가 같은 자격증명을 갖는다.
$_pwBytes = [byte[]]::new(12)
$_rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $_rng.GetBytes($_pwBytes) } finally { $_rng.Dispose() }
$seedAdminPw = [Convert]::ToBase64String($_pwBytes) -replace '[/+=]', ''

# ---------- 2. 골격 복사 ----------
Write-Step "골격 복사 → $Target"
New-Item -ItemType Directory -Force -Path $Target | Out-Null
# 닷파일(.gitignore·.gitattributes·.python-version·.nvmrc·.github·.claude 등) 포함 전체 복사.
# robocopy 는 숨김 속성 항목도 복사하므로 과거의 닷파일·.claude 누락 보강 단계는 필요 없다.
# ⛔ Copy-Item 통째 복사는 쓰지 않는다 — 템플릿 저장소에서 개발/검증을 하면 skeleton\ 안에
#    node_modules(수백 MB)·.venv·.svelte-kit·build 같은 gitignore 산출물이 남는데, 그대로 복사되면
#    생성 프로젝트가 수백 MB 로 부풀고 토큰 치환이 빌드 산출물을 붙잡는다. 복사된 node_modules 는
#    다른 경로에서 만든 것이라 생성 프로젝트의 pnpm install 이 비대화형에서
#    ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY 로 중단되기도 한다. 실제 .env 가 복사되면
#    템플릿의 SECRET_KEY 가 새는 보안 문제도 된다 (scaffold.sh 의 tar --exclude 와 동일 결과).
#    robocopy 는 Windows 기본 탑재이고 /XD·/XF 로 디렉터리·파일을 원천 제외한다.
#    ('build' 는 SvelteKit adapter-static 출력 디렉터리 — 골격에 같은 이름의 소스 디렉터리는 없다.)
$_xd = 'node_modules', '.venv', '.svelte-kit', 'build', '.ruff_cache', '.pytest_cache', '__pycache__'
robocopy $SkeletonDir $Target /E /XD $_xd /XF '.DS_Store' '.env' /NFL /NDL /NJH /NJS /NP | Out-Null
# robocopy 종료 코드: 0~7 = 성공(복사 결과 비트마스크), 8 이상 = 실패
if ($LASTEXITCODE -ge 8) { Write-Warn2 "골격 복사 실패 (robocopy 코드 $LASTEXITCODE) — 중단합니다"; exit 1 }
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
# 복사 단계가 산출물을 제외하지만, 기존 디렉토리 위에 덮어쓴 재실행(이미 install/build 된
# 프로젝트)에서는 node_modules·.svelte-kit·build 등이 남아 있다 — 여기서도 걸러야 빌드 산출물을
# 문자열 치환이 붙잡지 않는다(방어 이중화, scaffold.sh 의 find -prune 과 동일).
# 대상 경로 자체(예: C:\build\MyApp)에 같은 이름이 있어도 오탐하지 않도록 $Target 기준 상대 경로로 비교한다.
$files = Get-ChildItem -Path $Target -Recurse -File -Force -Include $inc |
  Where-Object { ('\' + $_.FullName.Substring($Target.Length)) -notmatch '[\\/](node_modules|\.venv|\.svelte-kit|build|\.ruff_cache|\.pytest_cache|__pycache__|\.git)[\\/]' }
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
ACCESS_TOKEN_EXPIRE_MINUTES=15
# 인증 세션·로그인 스로틀 (ARCHITECTURE.md §9) — 코드 기본값과 같지만, 운영자가 .env 만 보고도
# 조절 지점을 알 수 있도록 명시한다.
REFRESH_TOKEN_EXPIRE_DAYS=14
LOGIN_MAX_FAILURES=5
LOGIN_LOCKOUT_MINUTES=15
# refresh 토큰 전달 방식 — 이 템플릿(SvelteKit SPA)은 백엔드가 httpOnly 쿠키로 직접 심는 cookie 다.
# 브라우저 JS 는 refresh 토큰을 보지 못하고, access 토큰은 메모리에만 둔다 (ARCHITECTURE.md §9·§14).
REFRESH_TOKEN_TRANSPORT=cookie
# 로컬 HTTP 개발용. ⛔ HTTPS 운영에서는 true — APP_ENV=production 에서 false 면 기동을 거부한다.
COOKIE_SECURE=false
CORS_ORIGINS=http://localhost:5173
FRONTEND_URL=http://localhost:5173
BACKEND_PUBLIC_URL=http://localhost:8000
TZ=Asia/Seoul
APP_ENV=development
# 초기 관리자 시드 — 코드 기본값은 꺼져 있고(backend/app/config.py) 개발 편의를 위해 여기서만 켠다.
# ⛔ 배포 전 SEED_DEFAULT_ADMIN=false 로 끄고 APP_ENV=production 으로 바꾼다.
SEED_DEFAULT_ADMIN=true
DEFAULT_ADMIN_PASSWORD=$seedAdminPw
"@
# ⛔ .env 는 DB 비밀번호와 JWT 서명키를 담는다. 상속 ACL 을 끊고 현재 사용자에게만 허용한다
#    (scaffold.sh 의 chmod 600 대응).
$_backendEnvPath = Join-Path $Target 'backend\.env'
# ⛔ 기존 .env 를 덮어쓰면 SECRET_KEY 가 재발급되어 발급된 JWT 가 전부 무효가 된다. 백업을 남긴다.
if (Test-Path $_backendEnvPath) {
  $_envBak = "$_backendEnvPath.bak." + (Get-Date -Format 'yyyyMMddHHmmss')
  Copy-Item $_backendEnvPath $_envBak -Force
  Write-Warn2 "기존 backend\.env 를 백업했습니다: $(Split-Path $_envBak -Leaf)"
}
[System.IO.File]::WriteAllText($_backendEnvPath, $backendEnv, $Enc)
try {
  $_acl = Get-Acl $_backendEnvPath
  $_acl.SetAccessRuleProtection($true, $false)
  # 열거 중 컬렉션을 수정하지 않도록 스냅샷(@())을 뜬 뒤 제거한다
  @($_acl.Access) | ForEach-Object { [void]$_acl.RemoveAccessRule($_) }
  [void]$_acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name, 'FullControl', 'Allow')))
  Set-Acl -Path $_backendEnvPath -AclObject $_acl
} catch {
  Write-Warn2 "backend\.env 권한 설정 실패 — 파일 접근 권한을 직접 제한하세요: $($_.Exception.Message)"
}
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

[로그인]  초기 관리자 계정 (backend\.env 의 DEFAULT_ADMIN_PASSWORD):
  아이디: admin
  비밀번호: $seedAdminPw
  ⛔ 배포 전 이 계정의 비밀번호를 바꾸고 SEED_DEFAULT_ADMIN=false, APP_ENV=production 으로 설정하세요.

[확인]    브라우저: http://localhost:5173
          → 공개 홈 화면이 보이면 성공입니다. admin 으로 로그인한 뒤 '관리자 콘솔 > 시스템 상태'에서
            '백엔드 API'와 '데이터베이스'가 모두 '정상'인지 확인하세요.

[DB 변경] 모델 수정 시 (ARCHITECTURE.md §11):
  cd "$backend"
  .\.venv\Scripts\python -m alembic revision --autogenerate -m "변경요약"
  .\.venv\Scripts\python -m alembic upgrade head
"@ -ForegroundColor White
