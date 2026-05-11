# Beads Workflow

This repo uses **`bd`** for task state and selected execution-quality skills for planning and delivery. Beads remains the source of truth for `epic`, `task`, `bug`, and `chore` state.

## Local-Only Beads Model

- The current checkout owns the live `.beads/` database.
- Live Beads state is local to this clone and is not shared through Git.
- Run one top-level executor session at a time per branch to avoid Git conflicts.

## Workflow Skills

Codex and Claude Code can enter the workflow through repo-local skills installed under `.codex/skills/` and `.claude/skills/`:

- `plan-beads`
- `executor-task`
- `executor-task-worktree`
- `executor-epic-task`
- `executor-epic-task-worktree`

When an executor skill stops on a blocker, continue in normal chat by telling the agent to resume the blocked bead.

## Planner Session

Turns a fuzzy idea into structured, claimable beads. No code is written.

1. `brainstorming` - clarify scope, options, and design direction
2. `planner-research` - only if material factual uncertainty remains
3. brief the settled recommendation and confirm Beads creation
4. `beads-planner` - translate the design into Beads epics, tasks, and dependencies
5. `validate-beads` - confirm the epic is fresh-session-safe

Entry: a feature idea, bug report, or project change.
Exit: beads created with dependencies, ready for `bd ready`.

Fresh-session-safe means each bead carries enough persisted context that a new executor session can execute it without replaying the prior planner chat.

## Executor Session

Claims one bead and delivers it.

1. `beads-claim`
2. `writing-plans`
3. implement
4. `systematic-debugging` if blocked
5. repo-local `build-and-test`
6. `verification-before-completion`
7. `requesting-code-review`
8. `beads-close`

Entry: a ready bead from `bd ready`.
Exit: bead closed, code committed, follow-up beads created if needed.

Pick the executor variant by base branch and isolation:

- **PR base = main, current checkout:** `executor-task`
- **PR base = main, isolated worktree (parallel-safe):** `executor-task-worktree`
- **PR base = the bead's parent epic branch (`epic/<epic-bead-id>-<slug>`), current checkout:** `executor-epic-task`
- **PR base = epic branch, isolated worktree:** `executor-epic-task-worktree`

Use the `epic-*` variants when the whole epic should land in main as one merge and each child bead ships as its own PR into that epic branch. The epic variants resolve `<epic-bead-id>` from the task bead's parent epic; if the epic branch doesn't exist yet, they create it from the latest default branch.

## Session Boundaries

- Planner sessions do not write code.
- Executor sessions do not re-plan the whole project.
- Do not run multiple top-level code-writing executor sessions on the same branch at the same time.

## Branch and PR Workflow

- Do code work on feature branches.
- Open pull requests instead of merging locally.
- Beads state itself is local-only; code moves through Git, not Beads exports.
- Workflow scaffold files stay local-only in downstream Git and are mirrored to the backup repo with `scripts/posix/sync-workflow-backup.sh` or `scripts/windows/sync-workflow-backup.ps1`.
- `finishing-a-development-branch` handles workflow-backup sync, branch push, and PR creation.

## Operational Notes

- Run `scripts/windows/workflow-status.ps1` or `scripts/posix/workflow-status.sh` to inspect checkout runtime plus Agent Mail state.
- Run `scripts/windows/sync-workflow-backup.ps1` or `scripts/posix/sync-workflow-backup.sh` before a PR when you need to sync workflow docs, skills, or helper scripts outside the normal branch-finish flow.
- If `bd where` or `bd context` fails in the current checkout, repair the repo with `bd bootstrap --yes` before continuing.
- Use `bd ready` before asking what to work on next.
