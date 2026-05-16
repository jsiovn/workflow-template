param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [string]$Prefix,
    [string]$TemplateRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RepoPath)) {
    throw "RepoPath does not exist: $RepoPath"
}

function Get-PythonCommand {
    foreach ($cmd in @("py", "python", "python3")) {
        $resolved = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($resolved) {
            return $cmd
        }
    }
    throw "Python is required for scaffold-repo-files.ps1"
}

$pythonCmd = Get-PythonCommand
$workflowSource = Join-Path $TemplateRoot "templates\BEADS_WORKFLOW.md"
$troubleshootingSource = Join-Path $TemplateRoot "docs\TROUBLESHOOTING.md"
$codexBuildSkillSource = Join-Path $TemplateRoot "templates\.codex\skills\build-and-test"
$skillsSource = Join-Path $TemplateRoot "skills"
$agentsSnippet = Join-Path $TemplateRoot "templates\AGENTS.snippet.md"
$claudeSnippet = Join-Path $TemplateRoot "templates\CLAUDE.snippet.md"
$windowsStatusScript = Join-Path $TemplateRoot "scripts\windows\workflow-status.ps1"
$windowsAgentMailScript = Join-Path $TemplateRoot "scripts\windows\agent-mail.ps1"
$posixStatusScript = Join-Path $TemplateRoot "scripts\posix\workflow-status.sh"
$posixAgentMailScript = Join-Path $TemplateRoot "scripts\posix\agent-mail.sh"
$sharedAgentMailScript = Join-Path $TemplateRoot "scripts\shared\agent_mail.py"
$sharedManageInstructionsScript = Join-Path $TemplateRoot "scripts\shared\manage_instructions.py"

Copy-Item -Force $workflowSource (Join-Path $RepoPath "BEADS_WORKFLOW.md")
Write-Host "Copied BEADS_WORKFLOW.md"

$beadsDir = Join-Path $RepoPath ".beads"
New-Item -ItemType Directory -Force -Path $beadsDir | Out-Null
Copy-Item -Force (Join-Path $TemplateRoot "templates\PRIME.md") (Join-Path $beadsDir "PRIME.md")
Copy-Item -Force (Join-Path $TemplateRoot "templates\.beads\.gitignore") (Join-Path $beadsDir ".gitignore")
Copy-Item -Force (Join-Path $TemplateRoot "templates\.beads\README.md") (Join-Path $beadsDir "README.md")
Write-Host "Copied .beads/PRIME.md"
Write-Host "Copied .beads/.gitignore"
Write-Host "Copied .beads/README.md"

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".codex\skills") | Out-Null
if (-not (Test-Path (Join-Path $RepoPath ".codex\skills\build-and-test"))) {
    Copy-Item -Recurse -Force $codexBuildSkillSource (Join-Path $RepoPath ".codex\skills\build-and-test")
    Write-Host "Copied Codex build-and-test skill"
} else {
    Write-Host "Preserved existing Codex build-and-test skill"
}
$codexAttachSkillSource = Join-Path $TemplateRoot "templates\.codex\skills\attach-web-screenshots"
if (-not (Test-Path (Join-Path $RepoPath ".codex\skills\attach-web-screenshots"))) {
    Copy-Item -Recurse -Force $codexAttachSkillSource (Join-Path $RepoPath ".codex\skills\attach-web-screenshots")
    Write-Host "Copied Codex attach-web-screenshots skill"
} else {
    Write-Host "Preserved existing Codex attach-web-screenshots skill"
}

Get-ChildItem $skillsSource -Directory | ForEach-Object {
    $destination = Join-Path $RepoPath ".codex\skills\$($_.Name)"
    Remove-Item -Recurse -Force $destination -ErrorAction SilentlyContinue
    Copy-Item -Recurse -Force $_.FullName $destination
    Write-Host "Copied Codex skill: $($_.Name)"
}
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\plan-debate") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\plan-critic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\start-epic-worktree") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\game-action-harness") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\target-runtime-exec") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\executor-once") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\executor-loop") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\executor-loop-epic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\swarm-epic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\review-epic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\execute-bead-worker") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".codex\skills\test-on-android-device") -ErrorAction SilentlyContinue
Get-ChildItem (Join-Path $TemplateRoot "templates\.codex\skills") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -ne "build-and-test" -and $_.Name -ne "attach-web-screenshots") {
        $destination = Join-Path $RepoPath ".codex\skills\$($_.Name)"
        Remove-Item -Recurse -Force $destination -ErrorAction SilentlyContinue
        Copy-Item -Recurse -Force $_.FullName $destination
        Write-Host "Copied Codex provider skill: $($_.Name)"
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".claude\skills") | Out-Null
if (-not (Test-Path (Join-Path $RepoPath ".claude\skills\build-and-test"))) {
    Copy-Item -Recurse -Force $codexBuildSkillSource (Join-Path $RepoPath ".claude\skills\build-and-test")
    Write-Host "Copied Claude build-and-test skill"
} else {
    Write-Host "Preserved existing Claude build-and-test skill"
}
if (-not (Test-Path (Join-Path $RepoPath ".claude\skills\attach-web-screenshots"))) {
    Copy-Item -Recurse -Force $codexAttachSkillSource (Join-Path $RepoPath ".claude\skills\attach-web-screenshots")
    Write-Host "Copied Claude attach-web-screenshots skill"
} else {
    Write-Host "Preserved existing Claude attach-web-screenshots skill"
}

Get-ChildItem $skillsSource -Directory | ForEach-Object {
    $destination = Join-Path $RepoPath ".claude\skills\$($_.Name)"
    Remove-Item -Recurse -Force $destination -ErrorAction SilentlyContinue
    Copy-Item -Recurse -Force $_.FullName $destination
    Write-Host "Copied Claude skill: $($_.Name)"
}
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\plan-debate") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\plan-critic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\start-epic-worktree") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\game-action-harness") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\target-runtime-exec") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\executor-once") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\executor-loop") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\executor-loop-epic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\swarm-epic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\review-epic") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\execute-bead-worker") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath ".claude\skills\test-on-android-device") -ErrorAction SilentlyContinue
Get-ChildItem (Join-Path $TemplateRoot "templates\.claude\skills") -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -ne "build-and-test") {
        $destination = Join-Path $RepoPath ".claude\skills\$($_.Name)"
        Remove-Item -Recurse -Force $destination -ErrorAction SilentlyContinue
        Copy-Item -Recurse -Force $_.FullName $destination
        Write-Host "Copied Claude provider skill: $($_.Name)"
    }
}

# Shared agents — copied to both providers (same pattern as skills/).
$sharedAgentsSource = Join-Path $TemplateRoot "agents"
if (Test-Path $sharedAgentsSource) {
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".codex\agents") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".claude\agents") | Out-Null
    Get-ChildItem $sharedAgentsSource -File | ForEach-Object {
        Copy-Item -Force $_.FullName (Join-Path $RepoPath ".codex\agents\$($_.Name)")
        Copy-Item -Force $_.FullName (Join-Path $RepoPath ".claude\agents\$($_.Name)")
        Write-Host "Copied shared agent: $($_.Name)"
    }
}
# Provider-specific agent overrides (applied after shared, so they win).
$codexAgentsSource = Join-Path $TemplateRoot "templates\.codex\agents"
if (Test-Path $codexAgentsSource) {
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".codex\agents") | Out-Null
    Get-ChildItem $codexAgentsSource -File | ForEach-Object {
        Copy-Item -Force $_.FullName (Join-Path $RepoPath ".codex\agents\$($_.Name)")
        Write-Host "Copied Codex agent override: $($_.Name)"
    }
}
$claudeAgentsSource = Join-Path $TemplateRoot "templates\.claude\agents"
if (Test-Path $claudeAgentsSource) {
    New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".claude\agents") | Out-Null
    Get-ChildItem $claudeAgentsSource -File | ForEach-Object {
        Copy-Item -Force $_.FullName (Join-Path $RepoPath ".claude\agents\$($_.Name)")
        Write-Host "Copied Claude agent override: $($_.Name)"
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath "scripts\windows") | Out-Null
Copy-Item -Force $windowsStatusScript (Join-Path $RepoPath "scripts\windows\workflow-status.ps1")
Copy-Item -Force $windowsAgentMailScript (Join-Path $RepoPath "scripts\windows\agent-mail.ps1")
Copy-Item -Force (Join-Path $TemplateRoot "scripts\windows\restore-workflow-backup.ps1") (Join-Path $RepoPath "scripts\windows\restore-workflow-backup.ps1")
Copy-Item -Force (Join-Path $TemplateRoot "scripts\windows\sync-workflow-backup.ps1") (Join-Path $RepoPath "scripts\windows\sync-workflow-backup.ps1")
Remove-Item -Force (Join-Path $RepoPath "scripts\windows\shared-beads.ps1") -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $RepoPath "scripts\windows\start-epic-worktree.ps1") -ErrorAction SilentlyContinue
Write-Host "Copied scripts/windows/*"

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath "scripts\posix") | Out-Null
Copy-Item -Force $posixStatusScript (Join-Path $RepoPath "scripts\posix\workflow-status.sh")
Copy-Item -Force $posixAgentMailScript (Join-Path $RepoPath "scripts\posix\agent-mail.sh")
Copy-Item -Force (Join-Path $TemplateRoot "scripts\posix\restore-workflow-backup.sh") (Join-Path $RepoPath "scripts\posix\restore-workflow-backup.sh")
Copy-Item -Force (Join-Path $TemplateRoot "scripts\posix\sync-workflow-backup.sh") (Join-Path $RepoPath "scripts\posix\sync-workflow-backup.sh")
Remove-Item -Force (Join-Path $RepoPath "scripts\posix\shared-beads.sh") -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $RepoPath "scripts\posix\start-epic-worktree.sh") -ErrorAction SilentlyContinue
Write-Host "Copied scripts/posix/*"

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath "scripts\shared") | Out-Null
Copy-Item -Force $sharedAgentMailScript (Join-Path $RepoPath "scripts\shared\agent_mail.py")
Copy-Item -Force $sharedManageInstructionsScript (Join-Path $RepoPath "scripts\shared\manage_instructions.py")
Remove-Item -Force (Join-Path $RepoPath "scripts\shared\run_plan_critic.py") -ErrorAction SilentlyContinue
Copy-Item -Force (Join-Path $TemplateRoot "scripts\shared\sync_workflow_backup.py") (Join-Path $RepoPath "scripts\shared\sync_workflow_backup.py")
Copy-Item -Force (Join-Path $TemplateRoot "scripts\shared\workflow_backup.py") (Join-Path $RepoPath "scripts\shared\workflow_backup.py")
Remove-Item -Force (Join-Path $RepoPath "scripts\shared\shared_beads.py") -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $RepoPath "scripts\shared\start_epic_worktree.py") -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $RepoPath "scripts\shared\harness.py") -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $RepoPath "scripts\shared\harness_backends") -ErrorAction SilentlyContinue
Remove-Item -Force (Join-Path $RepoPath "scripts\shared\target_runtime.py") -ErrorAction SilentlyContinue
Write-Host "Copied scripts/shared/*"

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath "docs") | Out-Null
Copy-Item -Force $troubleshootingSource (Join-Path $RepoPath "docs\TROUBLESHOOTING.md")
Write-Host "Copied docs/TROUBLESHOOTING.md"

New-Item -ItemType Directory -Force -Path (Join-Path $RepoPath ".github\workflows") | Out-Null
Copy-Item -Force (Join-Path $TemplateRoot "templates\.github\workflows\cleanup-screenshots.yml") (Join-Path $RepoPath ".github\workflows\cleanup-screenshots.yml")
Write-Host "Copied .github/workflows/cleanup-screenshots.yml"

if ($pythonCmd -eq "py") {
    & py -3 (Join-Path $TemplateRoot "scripts\shared\sync_workflow_backup.py") ensure-ignore --repo $RepoPath
} else {
    & $pythonCmd (Join-Path $TemplateRoot "scripts\shared\sync_workflow_backup.py") ensure-ignore --repo $RepoPath
}
Write-Host "Updated .gitignore managed workflow block"

if ($pythonCmd -eq "py") {
    & py -3 $sharedManageInstructionsScript (Join-Path $RepoPath "AGENTS.md") $agentsSnippet
    & py -3 $sharedManageInstructionsScript (Join-Path $RepoPath "CLAUDE.md") $claudeSnippet
} else {
    & $pythonCmd $sharedManageInstructionsScript (Join-Path $RepoPath "AGENTS.md") $agentsSnippet
    & $pythonCmd $sharedManageInstructionsScript (Join-Path $RepoPath "CLAUDE.md") $claudeSnippet
}
Write-Host "Updated AGENTS.md managed block"
Write-Host "Updated CLAUDE.md managed block"
