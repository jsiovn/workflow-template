param(
    [string]$BackupRepo,
    [string]$ProjectName,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Find-Python {
    foreach ($candidate in @("py", "python", "python3")) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $candidate
        }
    }
    throw "Python is required for restore-workflow-backup.ps1"
}

$python = Find-Python
$scriptPath = Join-Path $PSScriptRoot "..\shared\sync_workflow_backup.py"
$argsList = @("restore")
if ($BackupRepo) {
    $argsList += @("--backup-repo", $BackupRepo)
}
if ($ProjectName) {
    $argsList += @("--project-name", $ProjectName)
}
if ($DryRun) {
    $argsList += "--dry-run"
}

if ($python -eq "py") {
    & py -3 $scriptPath @argsList
} else {
    & $python $scriptPath @argsList
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
