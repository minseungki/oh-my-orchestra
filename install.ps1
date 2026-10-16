<#
.SYNOPSIS
    oh-my-orchestra 설정을 ~/.claude 에 설치한다.

.DESCRIPTION
    - claude/CLAUDE.oh-my-orchestra.md, claude/agents/*, claude/skills/* 를 ~/.claude 로 복사한다 (덮어쓰기 전 백업).
    - ~/.claude/CLAUDE.md 는 덮어쓰지 않는다. 공통 지침 import 줄(@~/.claude/CLAUDE.oh-my-orchestra.md)이 없을 때만 맨 끝에 추가한다.
      PC별 규칙(회사 브랜치·커밋 규칙 등)은 ~/.claude/CLAUDE.md 에 그대로 둔다.
    - claude/settings.json 은 기존 ~/.claude/settings.json 에 병합한다.
      객체는 재귀 병합, 배열은 합집합(중복 제거), 값은 저장소 쪽이 우선한다.
    - 링크(심볼릭 링크)로 되어 있는 기존 스킬 폴더는 건드리지 않는다.

.PARAMETER ClaudeHome
    설치 대상 폴더. 기본값은 $HOME\.claude

.PARAMETER DryRun
    실제로 쓰지 않고 무엇을 할지만 출력한다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
#>
param(
    [string]$ClaudeHome = (Join-Path $HOME '.claude'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoClaude = Join-Path $PSScriptRoot 'claude'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $ClaudeHome "backups\oh-my-orchestra-$Stamp"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step($msg) { Write-Host "  $msg" }

function Backup-Item($target) {
    if (-not (Test-Path $target)) { return }
    $rel = $target.Substring($ClaudeHome.Length).TrimStart('\', '/')
    $dest = Join-Path $BackupDir $rel
    if ($DryRun) { Write-Step "[백업 예정] $rel"; return }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    Copy-Item -Path $target -Destination $dest -Recurse -Force
}

function Test-Link($path) {
    if (-not (Test-Path $path)) { return $false }
    $item = Get-Item $path -Force
    return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Copy-Managed($src, $dest) {
    $rel = $dest.Substring($ClaudeHome.Length).TrimStart('\', '/')
    if (Test-Link $dest) {
        Write-Step "[건너뜀] $rel (링크로 연결된 폴더라 그대로 둠)"
        return
    }
    Backup-Item $dest
    if ($DryRun) { Write-Step "[복사 예정] $rel"; return }
    if (Test-Path $src -PathType Container) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -Path $src -Destination $dest -Force
    }
    Write-Step "[복사] $rel"
}

# ---- settings.json 병합 ----
function Merge-Json($base, $patch) {
    foreach ($prop in $patch.PSObject.Properties) {
        $name = $prop.Name
        $pv = $prop.Value
        $existing = $base.PSObject.Properties[$name]
        if ($null -eq $existing) {
            $base | Add-Member -NotePropertyName $name -NotePropertyValue $pv
            continue
        }
        $bv = $existing.Value
        if ($bv -is [System.Management.Automation.PSCustomObject] -and $pv -is [System.Management.Automation.PSCustomObject]) {
            Merge-Json $bv $pv | Out-Null
        } elseif ($bv -is [array] -and $pv -is [array]) {
            $list = New-Object System.Collections.ArrayList
            foreach ($x in $bv) { [void]$list.Add($x) }
            foreach ($x in $pv) { if (-not $list.Contains($x)) { [void]$list.Add($x) } }
            $base.$name = $list.ToArray()
        } else {
            $base.$name = $pv
        }
    }
    return $base
}

function Install-Settings {
    $src = Join-Path $RepoClaude 'settings.json'
    $dest = Join-Path $ClaudeHome 'settings.json'
    $patch = [IO.File]::ReadAllText($src, $Utf8NoBom) | ConvertFrom-Json
    if (Test-Path $dest) {
        $base = [IO.File]::ReadAllText($dest, $Utf8NoBom) | ConvertFrom-Json
        if ($null -eq $base) { $base = New-Object PSObject }
    } else {
        $base = New-Object PSObject
    }
    $merged = Merge-Json $base $patch
    $json = $merged | ConvertTo-Json -Depth 32
    # 병합 결과가 올바른 JSON인지 다시 읽어서 확인
    $null = $json | ConvertFrom-Json
    Backup-Item $dest
    if ($DryRun) { Write-Step "[병합 예정] settings.json"; return }
    [IO.File]::WriteAllText($dest, $json, $Utf8NoBom)
    Write-Step "[병합] settings.json"
}

# ---- CLAUDE.md 에 import 줄 추가 ----
$ImportLine = '@~/.claude/CLAUDE.oh-my-orchestra.md'

function Install-ClaudeMdImport {
    $dest = Join-Path $ClaudeHome 'CLAUDE.md'
    $current = ''
    if (Test-Path $dest) { $current = [IO.File]::ReadAllText($dest, $Utf8NoBom) }
    if ($current -match [regex]::Escape($ImportLine)) {
        Write-Step "[유지] CLAUDE.md (import 줄 이미 있음)"
        return
    }
    Backup-Item $dest
    if ($DryRun) { Write-Step "[추가 예정] CLAUDE.md 끝에 $ImportLine"; return }
    $sep = ''
    if ($current.Length -gt 0 -and -not $current.EndsWith("`n")) { $sep = "`n" }
    $block = "$sep`n# oh-my-orchestra 공통 지침`n$ImportLine`n"
    [IO.File]::WriteAllText($dest, $current + $block, $Utf8NoBom)
    Write-Step "[추가] CLAUDE.md 끝에 $ImportLine"
}

# ---- 실행 ----
Write-Host "oh-my-orchestra 설치 → $ClaudeHome$(if ($DryRun) { ' (DryRun)' })"
if (-not (Test-Path $ClaudeHome)) {
    if ($DryRun) { Write-Step "[생성 예정] $ClaudeHome" } else { New-Item -ItemType Directory -Force -Path $ClaudeHome | Out-Null }
}

Copy-Managed (Join-Path $RepoClaude 'CLAUDE.oh-my-orchestra.md') (Join-Path $ClaudeHome 'CLAUDE.oh-my-orchestra.md')
Install-ClaudeMdImport

Get-ChildItem (Join-Path $RepoClaude 'agents') -File | ForEach-Object {
    Copy-Managed $_.FullName (Join-Path $ClaudeHome "agents\$($_.Name)")
}

Get-ChildItem (Join-Path $RepoClaude 'skills') -Directory | ForEach-Object {
    Copy-Managed $_.FullName (Join-Path $ClaudeHome "skills\$($_.Name)")
}

Install-Settings

if (-not $DryRun -and (Test-Path $BackupDir)) {
    Write-Host "기존 파일 백업: $BackupDir"
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "참고: node가 없습니다. /orchestra의 산출물 검사 스크립트는 node가 필요합니다 (없으면 수동 확인으로 대체됨)."
}
Write-Host "완료. 실행 중인 Claude Code 세션은 다시 시작해야 새 에이전트와 설정이 적용됩니다."
