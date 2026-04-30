# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is a **template/scaffold repo**, not a deployed application. It produces and updates workflow files _in other (downstream) repos_. There is no build, no test suite, and no runtime service here — the "output" is files copied into downstream checkouts by the scripts in `scripts/`.

Concretely: editing a file under `skills/`, `agents/`, or `templates/` only takes effect after running `update-skills` (or `bootstrap-new-repo` for a fresh repo) against a downstream repo and then syncing that repo's backup mirror. Nothing in this repo runs on its own.

## Mental Model: How Changes Propagate

Three surfaces get written into every downstream repo:

1. **Shared workflow skills** — one source in `skills/<name>/`, copied into both `<downstream>/.codex/skills/<name>/` and `<downstream>/.claude/skills/<name>/`.
2. **Shared agents** — one source in `agents/<name>.md`, copied into both `<downstream>/.codex/agents/<name>.md` and `<downstream>/.claude/agents/<name>.md`. Provider-specific overrides can be placed in `templates/.codex/agents/` or `templates/.claude/agents/` and are applied on top.
3. **Provider-specific skills** — sources in `templates/.codex/skills/<name>/` (and `templates/.claude/skills/<name>/` if present), copied only into the matching provider dir. The generic stage-1 `build-and-test` skill lives here and is the one file `update-skills` _preserves_ in the downstream if it already exists (downstream specialization).
4. **Repo-root scaffolding** — `templates/BEADS_WORKFLOW.md`, `templates/PRIME.md`, `templates/.beads/*`, the managed snippets `templates/AGENTS.snippet.md` and `templates/CLAUDE.snippet.md` (merged into the downstream's `AGENTS.md` / `CLAUDE.md` between `<!-- BEGIN/END TEMPLATE BD WORKFLOW -->` markers by `scripts/shared/manage_instructions.py`), plus helper scripts under `scripts/posix/`, `scripts/windows/`, and `scripts/shared/`.

`scripts/posix/scaffold-repo-files.sh` and its `.ps1` twin are the authority on exactly what gets copied, what gets deleted (e.g. removed legacy skills like `plan-debate`, `start-epic-worktree`), and what is profile-gated. Read that script before adding or renaming anything that ships downstream.

### Downstream Git is local-only for the workflow surface

The scaffolded workflow files (`AGENTS.md`, `CLAUDE.md`, `BEADS_WORKFLOW.md`, `docs/plans/`, `.codex/`, `.claude/`, scaffolded scripts) are added to the downstream's `.gitignore` managed block by `scripts/shared/workflow_backup.py`. The remote history for those files lives in a sibling backup repo `agentic-workflows/<project>/` (override via `AGENTIC_WORKFLOWS_REPO`). `scripts/shared/sync_workflow_backup.py` pushes the current downstream surface into that mirror. Any change you make here must survive that round-trip: edit here → `update-skills` in the downstream → `sync-workflow-backup` in the downstream → backup repo commit.

## Primary Entry Points

All user-facing operations are invoked through these scripts (POSIX `.sh` and Windows `.ps1` are paired twins — keep them in sync when editing):

| Purpose                                          | POSIX                                                           | Windows                                                     |
| ------------------------------------------------ | --------------------------------------------------------------- | ----------------------------------------------------------- |
| New downstream repo                              | `scripts/posix/bootstrap-new-repo.sh <repo> <prefix> [profile]` | `scripts/windows/bootstrap-new-repo.ps1`                    |
| Refresh shared workflow surface                  | `scripts/posix/update-skills.sh <repo> [profile]`               | `scripts/windows/update-skills.ps1`                         |
| Sync downstream → backup mirror                  | `scripts/posix/sync-workflow-backup.sh`                         | `scripts/windows/sync-workflow-backup.ps1`                  |
| Restore backup mirror → downstream               | `scripts/posix/restore-workflow-backup.sh`                      | `scripts/windows/restore-workflow-backup.ps1`               |
| Migrate legacy downstream to backup-mirror model | `scripts/posix/migrate-downstream-to-workflow-backup.sh`        | `scripts/windows/migrate-downstream-to-workflow-backup.ps1` |
| Migrate legacy `br` → `bd`                       | `scripts/posix/migrate-downstream-to-bd.sh`                     | `scripts/windows/migrate-downstream-to-bd.ps1`              |
| Prereq check                                     | `scripts/posix/check-prereqs.sh`                                | `scripts/windows/check-prereqs.ps1`                         |

`bootstrap-new-repo` delegates to `scaffold-repo-files` + `scripts/shared/ensure_stage1_beads.py` (which creates the standalone stage-2 follow-up beads: configure runtime target, specialize `build-and-test`, and — for `game-re` — populate the action catalog). `update-skills` re-runs scaffold on an existing repo.

### Local shell aliases (this machine)

Defined in `~/.zshrc`:

```bash
alias w-bootstrap='bash /home/paolo/www/agent-workflow-template/scripts/posix/bootstrap-new-repo.sh'
alias w-update='bash /home/paolo/www/agent-workflow-template/scripts/posix/update-skills.sh'
alias w-sync='bash /home/paolo/www/agent-workflow-template/scripts/posix/sync-workflow-backup.sh'
```

Usage: `w-bootstrap <repo-path> <prefix> [profile]`, `w-update <repo-path> [profile]`, `w-sync` (run inside a downstream repo).

## Profiles

Two profiles gate optional scaffolding:

- `generic` (default) — base workflow only.
- `game-re` — additionally installs the `game-action-harness` skill and `scripts/shared/harness.py` + `harness_backends/` into the downstream. This profile is for reverse-engineering game repos that need to trigger real user-input code paths through a running game (ADB, SendInput, etc.) and observe via the project's existing hook logs / memory / packets — no OpenCV or OCR.

Profile resolution order in `scaffold-repo-files`: CLI arg → `<repo>/.beads/workflow/profile.json` → `generic`. The effective profile is re-persisted after each run. The list of profile-gated skills lives in `scaffold-repo-files.{sh,ps1}` (`profile_gated_skills`); extend it there, not ad hoc.

## Two-Stage Adoption

- **Stage 1** (bootstrap) — generic `build-and-test` that executes each plan's literal `## Verification` section, and local execution as the default runtime target (`.beads/workflow/runtime-target.json`, seeded from `templates/.beads/workflow/`). `ensure_stage1_beads.py` creates standalone stage-2 follow-up beads exactly once so they survive re-runs.
- **Stage 2** (specialization, done in the downstream) — specialize the downstream's `build-and-test` skill, optionally switch runtime target to SSH via `scripts/shared/target_runtime.py`, and add repo-specific docs. `update-skills` preserves the downstream's customized `build-and-test`.

## Runtime Target Routing

`scripts/shared/target_runtime.py` is the ship-downstream helper that routes build/test/run/deploy commands through local or SSH execution based on `.beads/workflow/runtime-target.json`. When editing it, remember the config schema (`DEFAULT_CONFIG` at the top of the file) is what downstream repos will carry — a breaking change here must include a migration story.

## Managed Snippet Invariants

`AGENTS.snippet.md` and `CLAUDE.snippet.md` are injected into downstream `AGENTS.md` / `CLAUDE.md` between `<!-- BEGIN TEMPLATE BD WORKFLOW -->` and `<!-- END TEMPLATE BD WORKFLOW -->`. `scripts/shared/manage_instructions.py` replaces only the block between those markers — **do not remove or rename the markers** or it will append a duplicate block on the next `update-skills`.

## Verifying Changes

There is no test suite. To verify a change:

1. Run the relevant script (`bootstrap-new-repo.sh` or `update-skills.sh`) against a scratch downstream repo.
2. Inspect what landed in the downstream (especially `.codex/skills/`, `.claude/skills/`, `AGENTS.md` managed block, `.gitignore` managed block).
3. Run `sync-workflow-backup.sh` in that downstream to confirm the backup-mirror round-trip.
4. If the change touches a shared skill, also verify the `.codex/` and `.claude/` copies stayed identical.

## Conventions

- POSIX/Windows script parity: edits to any `scripts/posix/*.sh` almost always require the twin change in `scripts/windows/*.ps1` (and vice versa).
- `.beads/` is git-ignored here as well — this template repo is not itself managed by `bd`.
- Beads is local-only: never add workflow to publish or sync live `.beads/` state across clones.
- When removing a skill from the template, also add explicit `rm -rf`/`Remove-Item` lines for its downstream path in `scaffold-repo-files.{sh,ps1}` so existing downstreams get cleaned up on their next `update-skills`.
