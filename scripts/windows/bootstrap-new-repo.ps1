param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [switch]$WithScreenshots,
    [switch]$WithCodex,
    [string]$TemplateRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "check-prereqs.ps1") -RequireCodex:$WithCodex

if (-not (Test-Path $RepoPath)) {
    New-Item -ItemType Directory -Path $RepoPath | Out-Null
}

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    git -C $RepoPath init | Out-Null
    Write-Host "Initialized git repository"
}

Write-Host "Repo:    $RepoPath"
Write-Host "Prefix:  $Prefix"
if ($WithCodex) {
    Write-Host "AI:      Claude Code (primary) + Codex"
} else {
    Write-Host "AI:      Claude Code (primary)"
}

Push-Location $RepoPath
try {
    bd init -p $Prefix --server --skip-agents --skip-hooks
    # Claude Code is the primary AI and is always set up. Codex is opt-in.
    bd setup claude
    if ($WithCodex) {
        bd setup codex
    }
} finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot "scaffold-repo-files.ps1") -RepoPath $RepoPath -Prefix $Prefix -WithScreenshots:$WithScreenshots -WithCodex:$WithCodex -TemplateRoot $TemplateRoot
python (Join-Path $TemplateRoot "scripts\shared\ensure_stage1_beads.py") $RepoPath
Write-Host "Bootstrap complete."
