<#
.SYNOPSIS
    이 PC의 ~/.claude 에서 수정한 내용을 저장소(claude/)로 가져온다. install.ps1 의 반대 방향.

.DESCRIPTION
    저장소에 이미 있는 항목만 가져온다 (관리 대상 = 저장소에 있는 파일).
    - claude/CLAUDE.oh-my-orchestra.md (~/.claude/CLAUDE.md 는 PC별 규칙이라 가져오지 않는다)
    - claude/agents/ 에 있는 파일
    - claude/skills/ 에 있는 폴더
    - claude/settings.json 의 최상위 키 (값을 이 PC 기준으로 갱신)
    새 에이전트·스킬을 관리 대상에 추가하려면 claude/ 아래에 같은 이름으로 먼저 복사해 둔다.
    끝나면 git diff 로 변경을 확인한 뒤 직접 커밋한다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\export.ps1
#>
param(
    [string]$ClaudeHome = (Join-Path $HOME '.claude')
)

$ErrorActionPreference = 'Stop'
$RepoClaude = Join-Path $PSScriptRoot 'claude'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Pull-Item($rel) {
    $src = Join-Path $ClaudeHome $rel
    $dest = Join-Path $RepoClaude $rel
    if (-not (Test-Path $src)) {
        Write-Host "  [없음] $rel (이 PC에 없어 건너뜀)"
        return
    }
    if (Test-Path $src -PathType Container) {
        Remove-Item -Path $dest -Recurse -Force -Confirm:$false
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
    } else {
        Copy-Item -Path $src -Destination $dest -Force
    }
    Write-Host "  [가져옴] $rel"
}

Write-Host "oh-my-orchestra 내보내기: $ClaudeHome → $RepoClaude"

Pull-Item 'CLAUDE.oh-my-orchestra.md'
Get-ChildItem (Join-Path $RepoClaude 'agents') -File | ForEach-Object { Pull-Item "agents\$($_.Name)" }
Get-ChildItem (Join-Path $RepoClaude 'skills') -Directory | ForEach-Object { Pull-Item "skills\$($_.Name)" }

# settings.json: 저장소에 있는 최상위 키만 이 PC 값으로 갱신
$repoSettingsPath = Join-Path $RepoClaude 'settings.json'
$localSettingsPath = Join-Path $ClaudeHome 'settings.json'
if (Test-Path $localSettingsPath) {
    $repoSettings = [IO.File]::ReadAllText($repoSettingsPath, $Utf8NoBom) | ConvertFrom-Json
    $localSettings = [IO.File]::ReadAllText($localSettingsPath, $Utf8NoBom) | ConvertFrom-Json
    foreach ($prop in @($repoSettings.PSObject.Properties)) {
        $local = $localSettings.PSObject.Properties[$prop.Name]
        if ($null -ne $local) { $repoSettings.($prop.Name) = $local.Value }
    }
    [IO.File]::WriteAllText($repoSettingsPath, ($repoSettings | ConvertTo-Json -Depth 32), $Utf8NoBom)
    Write-Host "  [갱신] settings.json (관리 키만)"
}

Write-Host "완료. git diff 로 변경을 확인한 뒤 커밋하세요."
