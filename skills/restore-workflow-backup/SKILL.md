---
name: restore-workflow-backup
description: "Copy managed workflow files from the backup mirror back into this downstream repo. Use when the user asks to restore the workflow, recover from a fresh clone, or pull workflow files from backup."
---

# Restore Workflow Backup

Copy managed workflow files from the backup mirror into the current downstream repo.

## Steps

1. Detect platform:
   - Windows: run `scripts\windows\restore-workflow-backup.ps1`
   - POSIX: run `bash scripts/posix/restore-workflow-backup.sh`

2. Pass any user-supplied options through:
   - `--backup-repo <path>` if the user specified a custom backup repo location
   - `--project-name <name>` if the user specified a custom project name
   - `--dry-run` if the user wants to preview without writing

3. Report the output: how many files were restored vs skipped (already up to date).

## Hard Rules

- Do not construct or pass `--repo` — restore always runs from the current directory.
- Do not invent a `--backup-repo` unless the user explicitly provided one.
- If the script fails because no backup subtree exists for this project, tell the user to check the backup repo path and project name.
- Restore does not commit or push anything — it only writes local files.
