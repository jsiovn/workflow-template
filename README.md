# Agent Workflow Template

A **scaffold repo** that installs a shared Codex + Claude agent workflow into your other repos. It does not run on its own — its job is to copy a consistent set of skills, agents, docs, and helper scripts into every project you work on, so each one gets the same planner / executor / swarm flow backed by [Beads](https://github.com/steveyegge/beads) for task tracking.

You install it once on your machine, then run one script per project to scaffold (or refresh) the workflow inside that project.

---

## TL;DR

```bash
# 1. One-time, per machine: install bd, dolt, python (see install guides below)

# 2. Per project: bootstrap a downstream repo
bash ./scripts/posix/bootstrap-new-repo.sh /path/to/your-repo myproj

# 3. Inside that repo, plan and execute work using the installed skills
#    (plan-beads → brainstorming → beads-planner → validate-beads → swarm-epic / executor-*)

# 4. Before pushing a PR from the downstream, sync workflow files to the backup mirror
#    (handled automatically by the finishing-a-development-branch skill)
```

To refresh an already-bootstrapped repo with the latest template:

```bash
bash ./scripts/posix/update-skills.sh /path/to/your-repo
```

Windows users: every `.sh` has a `.ps1` twin under `scripts/windows/`.

---

## Mental Model

There are **three** distinct repos to keep straight:

| Repo                        | What lives there                                                                | Tracked by Git?              |
| --------------------------- | ------------------------------------------------------------------------------- | ---------------------------- |
| **This template repo**      | Source of truth for skills, agents, snippets, scripts                           | Yes (this repo's own remote) |
| **Downstream project repo** | Your actual code + a _local-only_ copy of the workflow files scaffolded in      | Code: yes. Workflow: no.     |
| **Workflow backup mirror**  | `agentic-workflows/<project>/` — the remote history for the workflow files only | Yes (separate remote)        |

Why three? The downstream's main remote should only carry product code. The workflow scaffold (`AGENTS.md`, `CLAUDE.md` managed blocks, `.codex/`, `.claude/`, `BEADS_WORKFLOW.md`, `docs/plans/`, helper scripts) lives on disk in the downstream but is `.gitignore`d there — its remote history goes to the sibling backup mirror instead. This keeps PRs in the downstream focused on product changes.

### What gets installed where

Per-machine install (once):

- `bd` (Beads CLI)
- `dolt` (server mode, used by `bd`)
- Python (helpers)

Per-downstream-repo install (via bootstrap script):

- `bd init -p <prefix> --server --skip-agents --skip-hooks` + `bd setup codex`
- `BEADS_WORKFLOW.md`, `.beads/PRIME.md`, `.beads/README.md`
- Managed workflow blocks injected into `AGENTS.md` and `CLAUDE.md`
- `.codex/skills/` and `.claude/skills/` (mirrored copies of `skills/` from this template)
- `.beads/workflow/runtime-target.json` seeded for local execution
- Stage-2 follow-up beads to specialize `build-and-test` and configure runtime target
- Managed `.gitignore` block that hides the workflow surface from the downstream's remote
- `sync-workflow-backup` helper for pushing to the backup mirror

---

## Quick Start

### 1. Bootstrap a new project

POSIX:

```bash
bash ./scripts/posix/bootstrap-new-repo.sh /path/to/repo myproj [profile]
```

Windows:

```powershell
pwsh -File .\scripts\windows\bootstrap-new-repo.ps1 -RepoPath D:\path\to\repo -Prefix myproj
```

Profiles: `generic` (default) or `game-re` (adds the game-action-harness skill for reverse-engineering game projects).

### 2. Plan the first work (in the downstream repo)

Even if the repo is mostly empty, run the planner flow:

1. `plan-beads`
2. `brainstorming`
3. `planner-research` — only when facts still need verification
4. confirm the settled plan
5. `beads-planner` — turns the plan into Beads
6. `validate-beads` — quality-gate the epic before swarm execution

Make `## Verification` sections in execution plans explicit — the stage-1 `build-and-test` skill follows them literally.

### 3. Execute

Pick one:

- `executor-once` — one bead, fresh session
- `executor-loop` — sequential manual execution in a long-lived session
- `swarm-epic <epic-id>` — multi-agent execution scoped to one epic, in branch `epic/<epic-id>`

### 4. Finish

The `finishing-a-development-branch` skill runs `sync-workflow-backup` automatically before branch push / PR creation. Manual sync if needed:

```bash
bash ./scripts/posix/sync-workflow-backup.sh
```

---

## Command Reference

| Purpose                                          | POSIX                                                           | Windows                                                     |
| ------------------------------------------------ | --------------------------------------------------------------- | ----------------------------------------------------------- |
| Bootstrap a new downstream repo                  | `scripts/posix/bootstrap-new-repo.sh <repo> <prefix> [profile]` | `scripts/windows/bootstrap-new-repo.ps1`                    |
| Refresh shared workflow surface                  | `scripts/posix/update-skills.sh <repo> [profile]`               | `scripts/windows/update-skills.ps1`                         |
| Sync downstream → backup mirror                  | `scripts/posix/sync-workflow-backup.sh`                         | `scripts/windows/sync-workflow-backup.ps1`                  |
| Restore backup mirror → downstream               | `scripts/posix/restore-workflow-backup.sh`                      | `scripts/windows/restore-workflow-backup.ps1`               |
| Migrate legacy downstream to backup-mirror model | `scripts/posix/migrate-downstream-to-workflow-backup.sh`        | `scripts/windows/migrate-downstream-to-workflow-backup.ps1` |
| Migrate legacy `br` → `bd`                       | `scripts/posix/migrate-downstream-to-bd.sh`                     | `scripts/windows/migrate-downstream-to-bd.ps1`              |
| Prereq check                                     | `scripts/posix/check-prereqs.sh`                                | `scripts/windows/check-prereqs.ps1`                         |

`update-skills` preserves the downstream's specialized `build-and-test`, refreshes the managed `.gitignore` block, and re-applies the managed AGENTS.md / CLAUDE.md snippets.

---

## Two-Stage Adoption

Downstream repos go through two stages.

### Stage 1 — Generic bootstrap

Run automatically by the bootstrap script. Good enough to start working immediately:

- Generic `build-and-test` skill that executes whatever is under each plan's `## Verification` section.
- `.beads/workflow/runtime-target.json` defaults to **local** execution.
- Two stage-2 follow-up beads created for you, surviving re-runs.

### Stage 2 — Project-specific specialization

Done in the downstream once the project's runtime shape is clear:

- Specialize `build-and-test` for the project's actual stack.
- Optionally switch runtime target to SSH (for cross-machine builds).
- Add repo-specific operational docs.

`update-skills` keeps the shared workflow synced from this template **without** overwriting your specialized `build-and-test` or your runtime-target config.

---

## Workflow Backup Mirror

Why workflow files are _not_ in the downstream's main remote:

- Keeps product PRs free of workflow churn.
- Lets the workflow evolve independently, per-project.
- Still gives you a remote history (the backup mirror).

Layout:

- Downstream: workflow files exist on disk, are `.gitignore`.
- Backup mirror: sibling checkout `../agentic-workflows/<project>/` (override with `AGENTIC_WORKFLOWS_REPO`).
- `finishing-a-development-branch` skill syncs to the mirror before push.
- `sync-workflow-backup` and `restore-workflow-backup` for manual sync / recovery.

To migrate an older downstream that still tracks workflow files in its main remote:

```bash
bash ./scripts/posix/migrate-downstream-to-workflow-backup.sh /path/to/repo
```

This refreshes the scaffold, syncs to the backup, removes tracked workflow files from the downstream Git index (leaving them on disk), and updates `.gitignore`.

---

## Local-Only Beads Model

- `.beads/` runtime state is local to each clone — never commit it, never push it through Dolt remotes.
- Code still flows through normal feature branches and PRs.
- Run **one** top-level epic executor session at a time per clone.
- `swarm-epic` parallelizes ready descendant beads inside one epic, but no longer isolates multiple epics with worktrees.

**Swarm-ready ≠ dependency-free.** It means each bead is _fresh-session-safe_: a new worker can execute it from the bead contract + persisted inputs + local code inspection — without replaying epic chat history.

When a worker blocks: classify the blocker. Local clarifications and env issues stay on the worker; contract or scope problems go back to the coordinator and usually retry in a fresh worker.

---

## Skills & Agents Catalog

Two kinds of building blocks ship with this template:

- **Skills** — runnable workflows. The user types the skill name (e.g. `plan-beads`) and the model executes the workflow end-to-end.
- **Agents** — focused single-purpose roles (PM, architect, reviewer, etc.). Most are invoked by the user on demand for a specific perspective; a few are called internally by skills.

### Skills, grouped by what they do

#### Planning (turn an idea into beads)

| Skill                | What it does                                                                              | When to use                                                                          |
| -------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `plan-beads`         | Full planner-only session: brainstorm → confirm → create beads → stop                     | You have a problem and want to convert it into Beads tasks                           |
| `brainstorming`      | Explores user intent, requirements, and design before any coding                          | Before any creative work — required by `plan-beads` and good as a standalone         |
| `planner-research`   | Resolves factual unknowns after brainstorming                                             | Only when uncertainty would weaken the plan                                          |
| `beads-planner`      | Turns a settled plan into Beads epics + tasks with explicit dependencies                  | After brainstorming/research, when ready to materialize the plan                     |
| `validate-beads`     | Quality-gates an epic for swarm execution (size, contracts, parallel-safety)              | After `beads-planner`, before `swarm-epic`                                           |
| `writing-plans`      | Produces a per-bead execution plan with explicit `## Verification`                        | Inside an executor session, after a bead is claimed — never in a planner session     |
| `audit-backlog-rules` | Audits ready/blocked beads for drift after CLAUDE.md or AGENTS.md rules change            | Right after editing project rules / conventions                                      |

#### Manual execution (one bead at a time)

| Skill                | What it does                                                                       | When to use                                                                        |
| -------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `beads-claim`        | Finds and claims a ready bead at the start of a manual executor session            | Start of a manual executor session                                                 |
| `executor-once`      | Full cycle for one bead: claim → plan → implement → verify → close                 | One-off bead end-to-end                                                            |
| `executor-task`      | Like `executor-once`, but on a fresh `feat/<bead-id>` branch + opens a PR          | One-bead-per-PR delivery rhythm                                                    |
| `executor-loop`      | Repeats executor cycles bead-by-bead until the ready queue is empty                | Sequential autonomous progress, no swarm                                           |
| `executor-loop-epic` | Same loop, scoped to descendants of one epic                                       | Sequential epic progress without swarm coordination                                |
| `beads-close`        | Closes the bead, creates follow-ups, commits `.beads/` state                       | Final step of a manual executor cycle                                              |

#### Swarm execution (multi-agent on one epic)

| Skill                  | What it does                                                                                   | When to use                                                                  |
| ---------------------- | ---------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `swarm-epic <epic-id>` | Coordinates parallel workers across ready descendants of one epic, owns Beads state for them   | After `validate-beads` passes and the epic has independent parallelizable work |
| `execute-bead-worker`  | The per-worker contract used inside a swarm — implements + verifies one bead, no state writes  | Called by `swarm-epic`; not invoked directly                                 |
| `review-epic`          | Epic-level review after swarm/sequential execution, classifies remaining issues P1/P2/P3       | After all child beads complete, to decide close-or-follow-up                 |

#### During implementation (helpers in the executor session)

| Skill                            | What it does                                                                                  | When to use                                                              |
| -------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `systematic-debugging`           | Structured root-cause investigation before proposing a fix                                    | Any bug, test failure, or unexpected behavior                            |
| `target-runtime-exec`            | Routes build/test/run/deploy commands through `scripts/shared/target_runtime.py` (local/SSH)  | When the repo's runtime target is not necessarily the local machine      |
| `verification-before-completion` | Forces real verification commands before claiming "done"                                      | Before committing, opening a PR, or asserting success                    |
| `build-and-test`                 | Runs the literal `## Verification` section of the current execution plan                      | After implementing changes; specialize per repo in stage 2                |
| `game-action-harness`            | Triggers in-game input (ADB / SendInput) and observes via memory/log hooks                    | Reverse-engineering game repos only (`profile=game-re`)                  |

#### Code review & PR delivery

| Skill                            | What it does                                                                          | When to use                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `requesting-code-review`         | Dispatches the `code-reviewer` subagent against the current change                    | After implementing a major task, before merging                              |
| `address-pr-comments`            | Pulls unresolved PR threads → fixes via `pr-comment-fixer` → verifies → push → reply  | When new review comments arrive on the current PR                            |
| `attach-web-screenshots`             | Takes screenshots of a running **web** app (browser-based) and attaches them to the open PR | After implementing a UI feature, before or alongside review            |
| `finishing-a-development-branch` | Pushes the branch and opens a PR; runs `sync-workflow-backup` first                   | When all work on a feature branch is done and verified                       |

#### Project hygiene & workflow infra

| Skill                      | What it does                                                                          | When to use                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `project-auditor`          | Full-repo audit: naming, folder layout, tech-stack consistency, light architecture    | Project health check (not per-PR — use `requesting-code-review` for diffs)   |
| `sync-workflow-backup`     | Pushes the downstream's workflow files to the backup mirror                           | Before pushing a downstream PR (also runs automatically inside finishing skill) |
| `restore-workflow-backup`  | Pulls workflow files *from* the backup mirror back into the downstream                | Fresh clone of an existing downstream repo                                   |

> **`attach-web-screenshots` requires a companion CI workflow.** If you use this skill, run `update-skills` (or `bootstrap-new-repo`) against your downstream repo — it will copy `.github/workflows/cleanup-screenshots.yml` which automatically removes stale screenshot folders for merged branches.

### Agents

#### User-invoked agents (call them directly when you want that perspective)

| Agent                  | What it does                                                                          | When to use                                                      |
| ---------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `product-manager`      | Produces acceptance criteria + done checklist                                         | Early planning, when "done" is fuzzy                             |
| `engineering-manager`  | Critically reviews the PM's spec for feasibility, scope creep, hidden cost            | Right after `product-manager`, before engineering commits        |
| `solution-design`      | High-level solution design — components, contracts, data flow, alternatives           | After acceptance criteria are pinned, before implementation plan |
| `junior-engineer`      | Asks clarifying questions until nothing is ambiguous; returns a numbered list         | Before starting work on cross-cutting / under-specified tasks    |
| `backend-architect`    | Reviews plans + diffs for backend work against opinionated standards                  | Plan touches APIs, services, persistence, queues, jobs           |
| `frontend-architect`   | Reviews plans + diffs for frontend work against opinionated standards                 | Plan touches UI, components, styling, client state               |
| `testing-strategist`   | Produces the test list required to ship a plan/diff with confidence                   | After a plan is settled, before coding — or before opening a PR  |

#### Skill-internal agents (called by a skill, not by you)

| Agent              | What it does                                                                          | Called by                                  |
| ------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------ |
| `code-reviewer`    | Reviews a completed change against its plan/requirements, reports by severity         | `requesting-code-review`                   |
| `project-auditor`  | Full-repo audit (naming, folders, tech stack, architecture hotspots, dead code)       | `project-auditor` skill                    |
| `pr-comment-fixer` | Reads unresolved PR threads, applies fixes, returns reply plan (does not push/post)   | `address-pr-comments`                      |

### Typical flows

**New feature, single bead:**
`plan-beads` → `beads-planner` → `validate-beads` → `executor-task` → PR

**New feature, parallelizable epic:**
`plan-beads` → `beads-planner` → `validate-beads` → `swarm-epic <epic-id>` → `review-epic` → `finishing-a-development-branch`

**Working through a backlog manually:**
`beads-claim` → `writing-plans` → implement → `build-and-test` → `verification-before-completion` → `beads-close` → repeat (or `executor-loop`)

**A PR came back with comments:**
`address-pr-comments` (re-run when more comments arrive)

**Project rules just changed:**
edit CLAUDE.md / AGENTS.md → `audit-backlog-rules` → fix flagged beads

---

## Editing Skills

This template has two skill source locations:

- `skills/<name>/` — shared skills, copied to **both** `.codex/skills/` and `.claude/skills/` in every downstream.
- `templates/.codex/skills/<name>/` and `templates/.claude/skills/<name>/` — provider-specific overrides.

Workflow for editing a shared skill:

1. Edit `skills/<name>/` here.
2. Run `update-skills` against each downstream that uses it.
3. Run `sync-workflow-backup` in the downstream before pushing a PR there.

Same flow for provider-specific skills, but edit under `templates/.codex/skills/` or `templates/.claude/skills/`.

Do **not** hand-edit shared skill copies inside downstream repos unless you intentionally want a repo-specific divergence.

The intended divergences in a downstream are:

- the specialized `build-and-test` skill
- repo-owned runtime wrappers
- the checkout-local `runtime-target.json`

---

## Files In This Repo

- `skills/` — shared workflow skills (mirrored to `.codex/` + `.claude/` downstream)
- `templates/.codex/skills/build-and-test/` — generic stage-1 validator (downstream-specializable)
- `templates/AGENTS.snippet.md`, `templates/CLAUDE.snippet.md` — managed snippets
- `templates/BEADS_WORKFLOW.md`, `templates/PRIME.md` — repo-root scaffolding
- `templates/NEW_REPO_CHECKLIST.md` — human checklist
- `scripts/shared/target_runtime.py` — local/SSH runtime router (ships downstream)
- `scripts/shared/workflow_backup.py` — `.gitignore` + manifest mgmt for the backup mirror
- `scripts/shared/sync_workflow_backup.py` — pushes the downstream surface to the mirror
- `scripts/posix/`, `scripts/windows/` — paired bootstrap, update, sync, migration scripts
- `docs/` — install + troubleshooting guides

---

## Install Guides

- Windows: [docs/INSTALL-WINDOWS.md](docs/INSTALL-WINDOWS.md)
- macOS: [docs/INSTALL-MACOS.md](docs/INSTALL-MACOS.md)
- Ubuntu/Linux: [docs/INSTALL-UBUNTU.md](docs/INSTALL-UBUNTU.md)
- New repo walkthrough: [docs/SETUP-NEW-REPO.md](docs/SETUP-NEW-REPO.md)

---

## Notes & Gotchas

- `bd init` and `bd setup codex` are per repo, not per machine.
- The scaffolding scripts do **not** use Dolt remotes — Beads state stays local.
- Scaffolded workflow files in a downstream are local-only; mirror them via `sync-workflow-backup` before pushing a downstream PR.
- POSIX/Windows scripts are paired twins — keep them in sync when editing.

---

## Attribution

The bundled execution-quality skills are curated copies derived from `obra/superpowers`, adapted to a Beads-native planning/execution flow with selected ideas from GSD and Khuym. See [ATTRIBUTION.md](ATTRIBUTION.md).
