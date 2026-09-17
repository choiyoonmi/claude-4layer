<#
.SYNOPSIS
    클로드 코드 설정 점검 — 로드되는 CLAUDE.md, 설치된 스킬·플러그인, 제자리 밖에 방치된 스킬을 한 화면에 보여준다.

.DESCRIPTION
    기본은 '보기만' 한다. 아무것도 옮기거나 지우지 않는다.
    -Fix 를 붙였을 때만 .claude\skills 밖에 있는 스킬 폴더를 제자리로 옮긴다.

.PARAMETER Roots
    제자리 밖 스킬을 찾을 폴더 목록. 생략하면 현재 폴더·홈·다운로드·문서·바탕화면·OneDrive를 훑는다.

.PARAMETER Depth
    각 폴더에서 몇 단계까지 내려갈지. 기본 4.

.PARAMETER Fix
    붙이면 제자리 밖 스킬 폴더를 개인 스킬 폴더로 실제 이동한다. 기본은 이동하지 않는다.

.EXAMPLE
    .\check-skills.ps1
    .\check-skills.ps1 -Fix
    .\check-skills.ps1 -Roots 'C:\Users\me\작업' -Depth 6
#>
[CmdletBinding()]
param(
    [string[]]$Roots,
    [int]$Depth = 4,
    [switch]$Fix
)

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$ErrorActionPreference = 'Continue'
$claudeHome  = Join-Path $HOME '.claude'
$userSkills  = Join-Path $claudeHome 'skills'
$pluginCache = Join-Path $claudeHome 'plugins'

function Write-Head {
    param([string]$Text)
    Write-Host ''
    Write-Host ("=" * 68) -ForegroundColor DarkGray
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 68) -ForegroundColor DarkGray
}

function Read-SkillMeta {
    param([string]$Path)
    $name = ''; $desc = ''; $hasFm = $false
    try { $lines = Get-Content -LiteralPath $Path -Encoding UTF8 -TotalCount 60 }
    catch { return [pscustomobject]@{ Name = ''; Description = ''; HasFrontmatter = $false } }

    $inFm = $false
    foreach ($ln in $lines) {
        if ($ln -match '^---\s*$') {
            if ($inFm) { break }
            $inFm = $true; $hasFm = $true
            continue
        }
        if (-not $inFm) { continue }
        if ($ln -match '^\s*name\s*:\s*(.+)$')        { $name = $Matches[1].Trim().Trim('"',"'") }
        elseif ($ln -match '^\s*description\s*:\s*(.+)$') { $desc = $Matches[1].Trim().Trim('"',"'") }
    }
    return [pscustomobject]@{ Name = $name; Description = $desc; HasFrontmatter = $hasFm }
}

function Show-Skill {
    param([System.IO.FileInfo]$File, [string]$Indent = '  ')
    $meta   = Read-SkillMeta -Path $File.FullName
    $folder = Split-Path -Leaf $File.DirectoryName
    Write-Host "$Indent/$folder" -ForegroundColor White -NoNewline

    if (-not $meta.HasFrontmatter) {
        Write-Host '   [!] 프론트매터 없음 - 발동 안 됨' -ForegroundColor Red
    }
    elseif ([string]::IsNullOrWhiteSpace($meta.Description)) {
        Write-Host '   [!] description 없음 - 발동 안 됨' -ForegroundColor Red
    }
    elseif ($meta.Name -and $meta.Name -ne $folder) {
        Write-Host "   [!] name($($meta.Name)) != 폴더명 - 명령어는 폴더명 기준" -ForegroundColor Yellow
    }
    else { Write-Host '' }

    if ($meta.Description) {
        $d = $meta.Description
        if ($d.Length -gt 76) { $d = $d.Substring(0, 76) + '...' }
        Write-Host "$Indent    $d" -ForegroundColor DarkGray
    }
}

function Test-IsPluginSource {
    # 플러그인 소스 저장소 안의 skills/ 는 제자리 밖이 아니다 (조상에 .claude-plugin 이 있음)
    param([string]$StartDir)
    $dir = $StartDir
    for ($i = 0; $i -lt 5 -and $dir; $i++) {
        if (Test-Path (Join-Path $dir '.claude-plugin')) { return $true }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $false
}

# ----------------------------------------------------------------------
Write-Head '1. 지금 읽히는 CLAUDE.md'

$mdFound = 0
$personalMd = Join-Path $claudeHome 'CLAUDE.md'
if (Test-Path $personalMd) {
    $n = (Get-Content -LiteralPath $personalMd -Encoding UTF8 | Measure-Object -Line).Lines
    $flag = ''
    if ($n -gt 200) { $flag = '  [!] 200줄 초과 - 뒤쪽부터 무시됨' }
    Write-Host "  [개인]     $personalMd  ($n 줄)$flag" -ForegroundColor White
    $mdFound++
} else {
    Write-Host "  [개인]     없음  ($personalMd)" -ForegroundColor DarkGray
}

$dir = (Get-Location).Path
$chain = @()
while ($dir) {
    $p = Join-Path $dir 'CLAUDE.md'
    if (Test-Path $p) { $chain += $p }
    $parent = Split-Path -Parent $dir
    if ($parent -eq $dir) { break }
    $dir = $parent
}
if ($chain.Count -gt 0) {
    [array]::Reverse($chain)
    foreach ($p in $chain) {
        $n = (Get-Content -LiteralPath $p -Encoding UTF8 | Measure-Object -Line).Lines
        $flag = ''
        if ($n -gt 200) { $flag = '  [!] 200줄 초과 - 뒤쪽부터 무시됨' }
        Write-Host "  [프로젝트] $p  ($n 줄)$flag" -ForegroundColor White
        $mdFound++
    }
} else {
    Write-Host "  [프로젝트] 현재 폴더와 상위에 CLAUDE.md 없음" -ForegroundColor DarkGray
}
if ($mdFound -eq 0) {
    Write-Host '  -> 규칙 파일이 하나도 없습니다. /claude-4layer:md-init 으로 만드세요.' -ForegroundColor Yellow
}

# ----------------------------------------------------------------------
Write-Head '2. 개인 스킬 (모든 폴더에서 사용)'

if (Test-Path $userSkills) {
    $mine = @(Get-ChildItem -LiteralPath $userSkills -Directory -ErrorAction SilentlyContinue)
    if ($mine.Count -eq 0) { Write-Host '  (비어 있음)' -ForegroundColor DarkGray }
    foreach ($d in $mine) {
        $sk = Join-Path $d.FullName 'SKILL.md'
        if (Test-Path $sk) { Show-Skill -File (Get-Item -LiteralPath $sk) }
        else { Write-Host "  /$($d.Name)   [!] SKILL.md 없음 - 인식 안 됨" -ForegroundColor Red }
    }
    Write-Host "  위치: $userSkills" -ForegroundColor DarkGray
} else {
    Write-Host "  폴더 자체가 없음: $userSkills" -ForegroundColor DarkGray
}

# ----------------------------------------------------------------------
Write-Head '3. 프로젝트 스킬 (이 폴더에서만)'

$projSkills = Join-Path (Get-Location).Path '.claude\skills'
if (Test-Path $projSkills) {
    $pj = @(Get-ChildItem -LiteralPath $projSkills -Directory -ErrorAction SilentlyContinue)
    if ($pj.Count -eq 0) { Write-Host '  (비어 있음)' -ForegroundColor DarkGray }
    foreach ($d in $pj) {
        $sk = Join-Path $d.FullName 'SKILL.md'
        if (Test-Path $sk) { Show-Skill -File (Get-Item -LiteralPath $sk) }
        else { Write-Host "  /$($d.Name)   [!] SKILL.md 없음 - 인식 안 됨" -ForegroundColor Red }
    }
    Write-Host "  위치: $projSkills" -ForegroundColor DarkGray
} else {
    Write-Host "  이 폴더엔 프로젝트 스킬이 없음 ($projSkills)" -ForegroundColor DarkGray
}

# ----------------------------------------------------------------------
Write-Head '4. 설치된 플러그인'

if (Test-Path $pluginCache) {
    $manifests = @(Get-ChildItem -LiteralPath $pluginCache -Recurse -Depth 6 -Filter 'plugin.json' -File -Force -ErrorAction SilentlyContinue)
    if ($manifests.Count -eq 0) { Write-Host '  (설치된 플러그인 없음)' -ForegroundColor DarkGray }
    foreach ($m in $manifests) {
        $pname = Split-Path -Leaf (Split-Path -Parent $m.DirectoryName)
        $pver  = ''
        try {
            $j = Get-Content -LiteralPath $m.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.name)    { $pname = $j.name }
            if ($j.version) { $pver  = " v$($j.version)" }
        } catch { }
        $root  = Split-Path -Parent $m.DirectoryName
        $inner = @(Get-ChildItem -LiteralPath (Join-Path $root 'skills') -Directory -ErrorAction SilentlyContinue)
        Write-Host "  $pname$pver" -ForegroundColor White
        foreach ($s in $inner) { Write-Host "      /${pname}:$($s.Name)" -ForegroundColor DarkGray }
    }
    Write-Host "  위치: $pluginCache" -ForegroundColor DarkGray
} else {
    Write-Host "  폴더 자체가 없음: $pluginCache" -ForegroundColor DarkGray
}

# ----------------------------------------------------------------------
Write-Head '5. 제자리 밖에 방치된 스킬  <- 안 먹히는 이유 1순위'

if (-not $Roots -or $Roots.Count -eq 0) {
    $cand = @(
        (Get-Location).Path,
        $HOME,
        (Join-Path $HOME 'Downloads'),
        (Join-Path $HOME 'Documents'),
        (Join-Path $HOME 'Desktop'),
        (Join-Path $HOME 'OneDrive')
    )
    $Roots = @($cand | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
}

Write-Host "  훑는 중... (깊이 $Depth)" -ForegroundColor DarkGray
foreach ($r in $Roots) { Write-Host "    - $r" -ForegroundColor DarkGray }

$orphans = @()
$seen    = @{}
foreach ($r in $Roots) {
    $hits = @(Get-ChildItem -LiteralPath $r -Recurse -Depth $Depth -Filter 'SKILL.md' -File -Force -ErrorAction SilentlyContinue)
    foreach ($h in $hits) {
        $full = $h.FullName
        if ($seen.ContainsKey($full)) { continue }
        $seen[$full] = $true
        if ($full -match '\\\.claude\\skills\\')  { continue }   # 제자리
        if ($full -match '\\\.claude\\plugins\\') { continue }   # 설치된 플러그인
        if ($full -match '\\node_modules\\')      { continue }
        if ($full -match '\\AppData\\')           { continue }
        if (Test-IsPluginSource -StartDir $h.DirectoryName) { continue }  # 플러그인 소스 저장소
        $orphans += $h
    }
}

if ($orphans.Count -eq 0) {
    Write-Host ''
    Write-Host '  [OK] 제자리 밖에 있는 스킬 없음.' -ForegroundColor Green
} else {
    Write-Host ''
    Write-Host "  [!] $($orphans.Count)개 발견 - 여기 있으면 클로드가 인식하지 못합니다." -ForegroundColor Red
    foreach ($o in $orphans) {
        $folder = Split-Path -Leaf $o.DirectoryName
        Write-Host ''
        Write-Host "   * $($o.DirectoryName)" -ForegroundColor Yellow
        $meta = Read-SkillMeta -Path $o.FullName
        if ($meta.Description) {
            $d = $meta.Description
            if ($d.Length -gt 72) { $d = $d.Substring(0, 72) + '...' }
            Write-Host "     $d" -ForegroundColor DarkGray
        }
        $dest = Join-Path $userSkills $folder
        if (Test-Path $dest) {
            Write-Host "     [!] 같은 이름이 이미 제자리에 있음: $dest" -ForegroundColor Red
        } else {
            Write-Host "     옮기면 -> /$folder  사용 가능" -ForegroundColor Green
        }
    }

    if ($Fix) {
        Write-Head '이동 실행 (-Fix)'
        if (-not (Test-Path $userSkills)) { New-Item -ItemType Directory -Path $userSkills -Force | Out-Null }
        foreach ($o in $orphans) {
            $folder = Split-Path -Leaf $o.DirectoryName
            $dest   = Join-Path $userSkills $folder
            if (Test-Path $dest) {
                Write-Host "  건너뜀 (이름 충돌): $folder" -ForegroundColor Yellow
                continue
            }
            try {
                Move-Item -LiteralPath $o.DirectoryName -Destination $dest -ErrorAction Stop
                Write-Host "  옮김: $folder  ->  $dest" -ForegroundColor Green
            } catch {
                Write-Host "  실패: $folder  ($($_.Exception.Message))" -ForegroundColor Red
            }
        }
        Write-Host ''
        Write-Host '  새 세션을 열어야 반영됩니다.' -ForegroundColor Cyan
    } else {
        Write-Host ''
        Write-Host '  옮기려면 같은 명령에 -Fix 를 붙여 다시 실행하세요.' -ForegroundColor Cyan
    }
}

Write-Host ''
Write-Host ("-" * 68) -ForegroundColor DarkGray
Write-Host "  CLAUDE.md $($mdFound)개 · 제자리 밖 스킬 $($orphans.Count)개" -ForegroundColor Cyan
Write-Host ("-" * 68) -ForegroundColor DarkGray
Write-Host ''
