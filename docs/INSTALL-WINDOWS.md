# Windows Setup

## Install `bd`

Recommended:

```powershell
irm https://raw.githubusercontent.com/steveyegge/beads/main/install.ps1 | iex
```

Verify:

```powershell
bd version
```

## Install `dolt`

Install Dolt on the machine and verify:

```powershell
dolt version
```

## Install Python

The workflow helpers use Python. Ensure either `py`, `python`, or `python3` is on `PATH`.

Verify:

```powershell
py -3 --version
```

## Per-Repo Setup

```powershell
pwsh -File .\scripts\windows\bootstrap-new-repo.ps1 -RepoPath D:\path\to\repo -Prefix yourprefix [-WithCodex]
```

The bootstrap script initializes git if needed, runs `bd init -p yourprefix --server --skip-agents --skip-hooks`, installs Claude integration (and Codex only with `-WithCodex`), and scaffolds the shared workflow files.

For the full stage-1 then stage-2 adoption flow, see [SETUP-NEW-REPO.md](SETUP-NEW-REPO.md).
