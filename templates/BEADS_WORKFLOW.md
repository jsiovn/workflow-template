# Beads Workflow

This repo uses **`bd`** for task state and selected execution-quality skills for planning and delivery. Beads remains the source of truth for `epic`, `task`, `bug`, and `chore` state.

## Local-Only Beads Model

- The current checkout owns the live `.beads/` database.
- Live Beads state is local to this clone and is not shared through Git.
- Run one top-level executor session at a time per branch to avoid Git conflicts.

## Workflow Skills

Claude Code (and Codex, when set up) can enter the workflow through repo-local skills installed under `.claude/skills/` (and `.codex/skills/` when Codex is set up):

- `plan-beads`
- `executor-task`
- `executor-task-worktree`
- `executor-epic-task`
- `executor-epic-task-worktree`
- `executor-rework-in-place`

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

When a bead was already executed but the task itself turned out to be wrong:

- **Rework into the existing PR (no new branch, no new PR):** `executor-rework-in-place`

Use this after `bd reopen <bead-id>` and editing the bead's requirements. It stays on the current feature branch in the current working tree, re-runs the executor chain against the updated bead, pushes new commits into the existing open PR, and posts a top-level fixup comment naming the bead id and the new tip SHA. Requires `bead_id`; refuses to run on the default branch, on a dirty tree, or when the current branch has no open PR.

## Session Boundaries

- Planner sessions do not write code.
- Executor sessions do not re-plan the whole project.
- Do not run multiple top-level code-writing executor sessions on the same branch at the same time.

## Branch and PR Workflow

- Do code work on feature branches.
- Open pull requests instead of merging locally.
- Beads state itself is local-only; code moves through Git, not Beads exports.
- Workflow scaffold files are committed to this repo's git and travel with feature branches and `git worktree` checkouts.
- Plan files under `docs/plans/` are git-ignored local scratch — written fresh per bead, never committed or pushed. To carry a plan across machines, inline it into the bead's `notes` (Dolt-synced), not the `docs/plans/` path.
- `finishing-a-development-branch` handles branch push and PR creation.

## Operational Notes

- Workflow docs and skills are committed and pushed as part of the normal git flow; refresh them from the template with `update-skills` when needed.
- If `bd where` or `bd context` fails in the current checkout, repair the repo with `bd bootstrap --yes` before continuing.
- Use `bd ready` before asking what to work on next.
