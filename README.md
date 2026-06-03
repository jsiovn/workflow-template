# Agent Workflow Template

A scaffold that drops a consistent **planner → executor** agent workflow into any repo you work on. It installs a shared set of skills, agents, helper scripts, and [Beads](https://github.com/steveyegge/beads)-backed task tracking so that **Claude Code** and **Codex** follow the same playbook in every project — you plan once, execute one bead per PR, and ship.

This repo doesn't run anything itself. You install it once on your machine, then run one script per project to scaffold (or refresh) the workflow inside that project.

---

## Preinstall

You need three machine-wide tools before bootstrapping any project:

| Tool      | What for                          | Verify                  |
| --------- | --------------------------------- | ----------------------- |
| `bd`      | Beads CLI (issue tracking)        | `bd version`            |
| `dolt`    | Storage backend used by `bd`      | `dolt version`          |
| `python3` | Helper scripts in `scripts/`      | `python3 --version`     |

Per-OS install instructions:

- macOS — [docs/INSTALL-MACOS.md](docs/INSTALL-MACOS.md)
- Ubuntu / Linux — [docs/INSTALL-UBUNTU.md](docs/INSTALL-UBUNTU.md)
- Windows — [docs/INSTALL-WINDOWS.md](docs/INSTALL-WINDOWS.md)

To verify everything is in place in one shot:

```bash
bash ./scripts/posix/check-prereqs.sh
# Windows:
pwsh -File .\scripts\windows\check-prereqs.ps1
```

---

## How to install

### 1. Clone this template to a stable path on your machine

```bash
git clone https://github.com/jsiovn/workflow-template.git ~/www/workflow-template
```

Pick any path you like — just keep it stable, because your shell aliases (next section) and downstream `update-skills` invocations will point at it.

### 2. Bootstrap a project

Run this once per repo you want to use the workflow in:

```bash
bash ~/www/workflow-template/scripts/posix/bootstrap-new-repo.sh /path/to/your-repo myprefix
```

Windows:

```powershell
pwsh -File "$HOME\www\workflow-template\scripts\windows\bootstrap-new-repo.ps1" -RepoPath D:\path\to\repo -Prefix myprefix
```

`myprefix` is the short tag Beads uses for issue IDs in that repo (e.g. `acme` → `acme-1`, `acme-2`). The bootstrap script initializes git if needed, runs `bd init` and `bd setup codex`, and copies the shared skills, agents, and helper scripts into the project.

For web/UI projects, add `--with-screenshots` (POSIX) or `-WithScreenshots` (PowerShell) to also install the `attach-web-screenshots` skill and its companion `.github/workflows/cleanup-screenshots.yml`. Omit for backend, CLI, or library repos. The flag is also accepted by `update-skills` if you adopt screenshots later.

### 3. Refresh later

When this template gets updates, refresh any downstream repo with:

```bash
bash ~/www/workflow-template/scripts/posix/update-skills.sh /path/to/your-repo
```

For a guided walkthrough of a brand-new project, see [docs/SETUP-NEW-REPO.md](docs/SETUP-NEW-REPO.md).

---

## How to setup aliases

Typing the full path every time is annoying. Add aliases to your shell:

**bash / zsh** (`~/.bashrc` or `~/.zshrc`):

```bash
alias w-bootstrap='bash ~/www/workflow-template/scripts/posix/bootstrap-new-repo.sh'
alias w-update='bash ~/www/workflow-template/scripts/posix/update-skills.sh'
```

**PowerShell** (`$PROFILE`):

```powershell
function w-bootstrap { pwsh -File "$HOME\www\workflow-template\scripts\windows\bootstrap-new-repo.ps1" @args }
function w-update    { pwsh -File "$HOME\www\workflow-template\scripts\windows\update-skills.ps1" @args }
```

Reload the shell, then:

```bash
w-bootstrap /path/to/your-repo myprefix
w-update    /path/to/your-repo
```

---

## How to use skills and agents

Once a repo is bootstrapped, your AI tool (Claude Code or Codex) sees two kinds of building blocks:

- **Skills** — runnable workflows. You invoke a skill by name (e.g. `plan-beads`, `executor-task`) and the model executes the whole workflow end-to-end.
- **Agents** — focused single-purpose roles (PM, architect, reviewer, …). You invoke an agent when you want that specific perspective on the current work.

### The two flows you'll run most often

**Planning** — turn an idea into Beads tasks:

```
plan-beads → brainstorming → (planner-research, optional) → beads-planner → validate-beads
```

**Execution** — pick up one bead, ship one PR:

```
executor-task                # default: PR into main
executor-task-worktree       # same, in an isolated worktree (parallel-safe)
executor-epic-task           # bead belongs to an epic — PR into the epic branch
executor-rework-in-place <bead-id>   # bead was reopened, amend the existing PR
```

Other useful skills you'll reach for:

- `address-pr-comments` — when a reviewer left comments on your PR
- `finishing-a-development-branch` — push and open the PR
- `audit-backlog-rules` — re-check the backlog after editing project rules
- `requesting-code-review` — get a review of the current change before merging

### Full skills catalog

<details>
<summary><b>Planning skills</b> — turn an idea into beads</summary>

| Skill                | What it does                                                                              | When to use                                                                          |
| -------------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `plan-beads`         | Full planner-only session: brainstorm → confirm → create beads → stop                     | You have a problem and want to convert it into Beads tasks                           |
| `brainstorming`      | Explores user intent, requirements, and design before any coding                          | Before any creative work — required by `plan-beads` and good as a standalone         |
| `planner-research`   | Resolves factual unknowns after brainstorming                                             | Only when uncertainty would weaken the plan                                          |
| `beads-planner`      | Turns a settled plan into Beads epics + tasks with explicit dependencies                  | After brainstorming/research, when ready to materialize the plan                     |
| `validate-beads`     | Quality-gates an epic (size, contracts, fresh-session safety)                             | After `beads-planner`, before claiming any of its beads for execution                |
| `writing-plans`      | Produces a per-bead execution plan with explicit `## Verification`                        | Inside an executor session, after a bead is claimed — never in a planner session     |
| `audit-backlog-rules`| Audits ready/blocked beads for drift after CLAUDE.md or AGENTS.md rules change            | Right after editing project rules / conventions                                      |

</details>

<details>
<summary><b>Execution skills</b> — one bead end-to-end</summary>

| Skill                           | What it does                                                                               | When to use                                                                            |
| ------------------------------- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| `beads-claim`                   | Finds and claims a ready bead at the start of an executor session                          | Start of an executor session                                                           |
| `executor-task`                 | Full cycle for one bead on a fresh `feat/<bead-id>` branch off main + opens a PR into main | One-bead-per-PR delivery rhythm                                                        |
| `executor-task-worktree`        | Same as `executor-task` but runs in an isolated git worktree                               | When you need to run multiple beads in parallel without branch interference            |
| `executor-epic-task`            | Same as `executor-task` but branches off (and PRs into) the bead's parent epic branch      | Epic delivered as one merge to main; each child bead ships as its own PR into the epic |
| `executor-epic-task-worktree`   | Same as `executor-epic-task` but runs in an isolated git worktree                          | Epic flow + parallel beads + main tree must stay untouched                             |
| `executor-rework-in-place`      | Re-execute a reopened bead on the current feature branch; push commits into the existing open PR (no new branch, no new PR); requires `bead_id` | Bead was already executed but the task was wrong — user reopened the bead, updated its requirements, and wants to amend the existing PR |
| `beads-close`                   | Closes the bead, creates follow-ups, commits `.beads/` state                               | Final step of an executor cycle                                                        |

</details>

<details>
<summary><b>Helpers used during implementation</b></summary>

| Skill                            | What it does                                                                                  | When to use                                                              |
| -------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `systematic-debugging`           | Structured root-cause investigation before proposing a fix                                    | Any bug, test failure, or unexpected behavior                            |
| `verification-before-completion` | Forces real verification commands before claiming "done"                                      | Before committing, opening a PR, or asserting success                    |
| `build-and-test`                 | Runs the literal `## Verification` section of the current execution plan                      | After implementing changes; specialize per repo in stage 2               |

</details>

<details>
<summary><b>Code review & PR delivery</b></summary>

| Skill                            | What it does                                                                          | When to use                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `requesting-code-review`         | Dispatches the `code-reviewer` subagent against the current change                    | After implementing a major task, before merging                              |
| `address-pr-comments`            | Pulls unresolved PR threads → fixes via `pr-comment-fixer` → verifies → push → reply  | When new review comments arrive on the current PR                            |
| `attach-web-screenshots`         | Takes screenshots of a running web app and attaches them to the open PR               | After implementing a UI feature, before or alongside review                  |
| `finishing-a-development-branch` | Pushes the branch and opens a PR                                                      | When all work on a feature branch is done and verified                       |

> `attach-web-screenshots` is opt-in — pass `--with-screenshots` to `bootstrap-new-repo` (or `update-skills` to adopt later). It ships a companion CI workflow (`.github/workflows/cleanup-screenshots.yml`) that prunes stale screenshot folders for merged branches.

</details>

<details>
<summary><b>Project hygiene & workflow infra</b></summary>

| Skill                      | What it does                                                                          | When to use                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `project-auditor`          | Full-repo audit: naming, folder layout, tech-stack consistency, light architecture    | Project health check (not per-PR — use `requesting-code-review` for diffs)   |
| `prune-local-branches`     | Removes stale local branches whose PRs are merged or closed                           | Periodic cleanup                                                             |

</details>

<details>
<summary><b>Agents — call them directly when you want that perspective</b></summary>

| Agent                  | What it does                                                                          | When to use                                                      |
| ---------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `product-manager`      | Produces acceptance criteria + done checklist                                         | Early planning, when "done" is fuzzy                             |
| `engineering-manager`  | Critically reviews the PM's spec for feasibility, scope creep, hidden cost            | Right after `product-manager`, before engineering commits        |
| `solution-design`      | High-level solution design — components, contracts, data flow, alternatives           | After acceptance criteria are pinned, before implementation plan |
| `junior-engineer`      | Asks clarifying questions until nothing is ambiguous; returns a numbered list         | Before starting work on cross-cutting / under-specified tasks    |
| `backend-architect`    | Reviews plans + diffs for backend work against opinionated standards                  | Plan touches APIs, services, persistence, queues, jobs           |
| `frontend-architect`   | Reviews plans + diffs for frontend work against opinionated standards                 | Plan touches UI, components, styling, client state               |
| `testing-strategist`   | Produces the test list required to ship a plan/diff with confidence                   | After a plan is settled, before coding — or before opening a PR  |

</details>

<details>
<summary><b>Skill-internal agents</b> (called by a skill, not by you)</summary>

| Agent              | What it does                                                                          | Called by                                  |
| ------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------ |
| `code-reviewer`    | Reviews a completed change against its plan/requirements, reports by severity         | `requesting-code-review`                   |
| `project-auditor`  | Full-repo audit (naming, folders, tech stack, architecture hotspots, dead code)       | `project-auditor` skill                    |
| `pr-comment-fixer` | Reads unresolved PR threads, applies fixes, returns reply plan (does not push/post)   | `address-pr-comments`                      |

</details>

For the internal "who calls whom" graph view of the skills, see [docs/SKILLS_RELATIONSHIPS.md](docs/SKILLS_RELATIONSHIPS.md).

---

## Browse beads visually with bdtui

![bdtui screenshot](https://raw.githubusercontent.com/jsiovn/bdtui/master/docs/images/bdtui.png)

[`bdtui`](https://www.npmjs.com/package/bdtui) is a terminal UI for browsing the Beads backlog — ready vs. blocked beads, dependencies, status, the lot. Install once:

```bash
npm install -g bdtui
```

Then run `bdtui` from inside any bootstrapped repo.

---

## Command reference

| Purpose                                          | POSIX                                                           | Windows                                                     |
| ------------------------------------------------ | --------------------------------------------------------------- | ----------------------------------------------------------- |
| Bootstrap a new downstream repo                  | `scripts/posix/bootstrap-new-repo.sh <repo> <prefix>`           | `scripts/windows/bootstrap-new-repo.ps1`                    |
| Refresh shared workflow surface                  | `scripts/posix/update-skills.sh <repo>`                         | `scripts/windows/update-skills.ps1`                         |
| Prerequisite check                               | `scripts/posix/check-prereqs.sh`                                | `scripts/windows/check-prereqs.ps1`                         |

---

## More docs

- [docs/INSTALL-MACOS.md](docs/INSTALL-MACOS.md) — macOS install
- [docs/INSTALL-UBUNTU.md](docs/INSTALL-UBUNTU.md) — Ubuntu / Linux install
- [docs/INSTALL-WINDOWS.md](docs/INSTALL-WINDOWS.md) — Windows install
- [docs/SETUP-NEW-REPO.md](docs/SETUP-NEW-REPO.md) — guided new-repo walkthrough
- [docs/SKILLS_RELATIONSHIPS.md](docs/SKILLS_RELATIONSHIPS.md) — internal skill graph
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — common issues

---

## Attribution

The bundled execution-quality skills are curated copies derived from `obra/superpowers`, adapted to a Beads-native planning/execution flow with selected ideas from GSD and Khuym. See [ATTRIBUTION.md](ATTRIBUTION.md).
