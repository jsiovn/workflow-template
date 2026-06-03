# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is a **template/scaffold repo**, not a deployed application. It produces and updates workflow files _in other (downstream) repos_. There is no build, no test suite, and no runtime service here — the "output" is files copied into downstream checkouts by the scripts in `scripts/`.

Concretely: editing a file under `skills/`, `agents/`, or `templates/` only takes effect after running `update-skills` (or `bootstrap-new-repo` for a fresh repo) against a downstream repo and committing the refreshed files there. Nothing in this repo runs on its own.

## Mental Model: How Changes Propagate

Three surfaces get written into every downstream repo:

1. **Shared workflow skills** — one source in `skills/<name>/`, copied into both `<downstream>/.codex/skills/<name>/` and `<downstream>/.claude/skills/<name>/`.
2. **Shared agents** — one source in `agents/<name>.md`, copied into both `<downstream>/.codex/agents/<name>.md` and `<downstream>/.claude/agents/<name>.md`. Provider-specific overrides can be placed in `templates/.codex/agents/` or `templates/.claude/agents/` and are applied on top.
3. **Bootstrap-only / stage-1 skills** — sources in `templates/skills/<name>/`, copied into both `<downstream>/.codex/skills/<name>/` and `<downstream>/.claude/skills/<name>/`. The generic stage-1 `build-and-test` skill lives here and is the one file `update-skills` _preserves_ in the downstream if it already exists (downstream specialization). `attach-web-screenshots` also lives here but is opt-in — only installed when `bootstrap-new-repo` / `update-skills` is invoked with `--with-screenshots`, or when the skill already exists in the downstream.
4. **Repo-root scaffolding** — `templates/BEADS_WORKFLOW.md`, `templates/PRIME.md`, `templates/.beads/*`, the managed snippets `templates/AGENTS.snippet.md` and `templates/CLAUDE.snippet.md` (merged into the downstream's `AGENTS.md` / `CLAUDE.md` between `<!-- BEGIN/END TEMPLATE BD WORKFLOW -->` markers by `scripts/shared/manage_instructions.py`), plus helper scripts under `scripts/posix/`, `scripts/windows/`, and `scripts/shared/`.

`scripts/posix/scaffold-repo-files.sh` and its `.ps1` twin are the authority on exactly what gets copied and what gets deleted (e.g. removed legacy skills like `plan-debate`, `start-epic-worktree`, `swarm-epic`, `executor-once`). Read that script before adding or renaming anything that ships downstream.

### Downstream Git tracks the workflow surface

The scaffolded workflow files (`AGENTS.md`, `CLAUDE.md`, `BEADS_WORKFLOW.md`, `docs/plans/`, `.codex/`, `.claude/`, scaffolded scripts) are **committed to each downstream repo's own git**, so they travel with feature branches and `git worktree` checkouts (the worktree executor flows depend on this). The downstream's `.gitignore` managed block — written by `scripts/shared/manage_gitignore.py` between the `# BEGIN/END TEMPLATE AGENT WORKFLOW LOCAL-ONLY` markers — now lists only genuinely machine-local runtime artifacts (`.beads-credential-key`, `.beads/interactions.jsonl`, `.bv/`, `.dolt/`, `*.db`, `scripts/shared/__pycache__/`). Any change you make here propagates in one round-trip: edit here → `update-skills` in the downstream → commit the refreshed files there. (There is no longer a sibling backup-mirror repo; that machinery has been retired.)

## Primary Entry Points

All user-facing operations are invoked through these scripts (POSIX `.sh` and Windows `.ps1` are paired twins — keep them in sync when editing):

| Purpose                                          | POSIX                                                           | Windows                                                     |
| ------------------------------------------------ | --------------------------------------------------------------- | ----------------------------------------------------------- |
| New downstream repo                              | `scripts/posix/bootstrap-new-repo.sh <repo> <prefix>`           | `scripts/windows/bootstrap-new-repo.ps1`                    |
| Refresh shared workflow surface                  | `scripts/posix/update-skills.sh <repo>`                         | `scripts/windows/update-skills.ps1`                         |
| Prereq check                                     | `scripts/posix/check-prereqs.sh`                                | `scripts/windows/check-prereqs.ps1`                         |

`bootstrap-new-repo` delegates to `scaffold-repo-files` + `scripts/shared/ensure_stage1_beads.py` (which creates the standalone stage-2 follow-up bead to specialize `build-and-test`, plus a matching bead for `attach-web-screenshots` only when that opt-in skill is installed). `update-skills` re-runs scaffold on an existing repo. Both accept `--with-screenshots` (PowerShell: `-WithScreenshots`) to install the `attach-web-screenshots` skill and its companion `cleanup-screenshots.yml` CI workflow.

### Local shell aliases (this machine)

Defined in `~/.zshrc`:

```bash
alias w-bootstrap='bash /home/paolo/www/workflow-template/scripts/posix/bootstrap-new-repo.sh'
alias w-update='bash /home/paolo/www/workflow-template/scripts/posix/update-skills.sh'
```

Usage: `w-bootstrap <repo-path> <prefix>`, `w-update <repo-path>`.

## Two-Stage Adoption

- **Stage 1** (bootstrap) — generic `build-and-test` that executes each plan's literal `## Verification` section. `ensure_stage1_beads.py` creates standalone stage-2 follow-up beads exactly once so they survive re-runs.
- **Stage 2** (specialization, done in the downstream) — specialize the downstream's `build-and-test` skill and add repo-specific docs. `update-skills` preserves the downstream's customized `build-and-test`.

## Managed Snippet Invariants

`AGENTS.snippet.md` and `CLAUDE.snippet.md` are injected into downstream `AGENTS.md` / `CLAUDE.md` between `<!-- BEGIN TEMPLATE BD WORKFLOW -->` and `<!-- END TEMPLATE BD WORKFLOW -->`. `scripts/shared/manage_instructions.py` replaces only the block between those markers — **do not remove or rename the markers** or it will append a duplicate block on the next `update-skills`.

## Verifying Changes

When adding or editing a skill, follow `docs/AUTHORING-SKILLS.md` — it covers the SKILL.md conventions, the subagent pressure-test, and the propagation checks before the round-trip below.

There is no test suite. To verify a change:

1. Run the relevant script (`bootstrap-new-repo.sh` or `update-skills.sh`) against a scratch downstream repo.
2. Inspect what landed in the downstream (especially `.codex/skills/`, `.claude/skills/`, `AGENTS.md` managed block, `.gitignore` managed block — it should list only the runtime artifacts, not the skill/agent paths).
3. Confirm the refreshed workflow files show up as ordinary tracked files in `git status` (they are committed, not gitignored).
4. If the change touches a shared skill, also verify the `.codex/` and `.claude/` copies stayed identical.

Because the workflow surface is committed to the downstream's own git, a fresh clone already carries it; run `update-skills` against the clone to pull the latest template versions.

## Conventions

- POSIX/Windows script parity: edits to any `scripts/posix/*.sh` almost always require the twin change in `scripts/windows/*.ps1` (and vice versa).
- `.beads/` is git-ignored here as well — this template repo is not itself managed by `bd`.
- Beads is local-only: never add workflow to publish or sync live `.beads/` state across clones.
- When removing a skill from the template, also add its name to the `legacy_skills`/`$legacySkills` prune list in `scaffold-repo-files.{sh,ps1}` (or an explicit `rm -rf`/`Remove-Item` line) so existing downstreams get it deleted on their next `update-skills` — the copy loop only iterates skills that still exist in the template, so a deleted source is never cleaned up otherwise.
- When adding a new skill under `skills/`, the scaffold scripts pick it up automatically via `find` and copy it into both `.codex/skills/` and `.claude/skills/`. No `.gitignore` bookkeeping is needed: the workflow surface is committed downstream, and `scripts/shared/manage_gitignore.py` only ignores machine-local runtime artifacts.
