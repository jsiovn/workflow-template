---
name: sync-workflow-backup
description: "Push the current downstream repo's managed workflow files into the backup mirror. Use when the user asks to sync, save, or back up the workflow."
---

# Sync Workflow Backup

Push managed workflow files from this downstream repo into its backup mirror.

## Steps

1. Detect platform:
   - Windows: run `scripts\windows\sync-workflow-backup.ps1`
   - POSIX: run `bash scripts/posix/sync-workflow-backup.sh`

2. Pass any user-supplied options through:
   - `--backup-repo <path>` if the user specified a custom backup repo location
   - `--project-name <name>` if the user specified a custom project name
   - `--no-push` if the user wants to commit locally without pushing
   - `--dry-run` if the user wants to preview without writing

3. Report the output: how many files were copied, whether a commit was made, and whether it was pushed.

## Hard Rules

- Do not construct or pass `--repo` — sync always runs from the current directory.
- Do not invent a `--backup-repo` unless the user explicitly provided one.
- If the script fails because the backup repo has uncommitted changes, tell the user to clean it first.
