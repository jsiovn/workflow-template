<!-- BEGIN TEMPLATE BD WORKFLOW -->

### PR review replies

Only append `@claude review` when posting a reply to a **conversation comment authored by `claude[bot]`**. This triggers the bot to re-run its review.

Do **not** include `@claude review` in replies to human reviewer inline thread comments or in any other conversation comments.

## Issue tracking

This repo uses `bd` for issue tracking. Use `bd`, not markdown TODO files or alternate trackers.

Live `.beads` state is local-only and should not be committed. Use one top-level executor session at a time per branch.

Preferred workflow entry points are `plan-beads`, `executor-task`, and `executor-task-worktree`. When the bead is part of an epic that should land in main as a single merge, use `executor-epic-task` (or `executor-epic-task-worktree` for parallel work) — these branch off and PR into `epic/<epic-bead-id>-<slug>` instead of main. When a bead was already executed and a PR is open but the task turned out to be wrong, reopen the bead, edit its requirements, then run `executor-rework-in-place <bead-id>` to amend the existing PR in the current working tree (no new branch, no new PR). Use `planner-research` only inside planner sessions and keep `writing-plans` executor-only.

Each bead must be fresh-session-safe: a new executor session should be able to execute from the bead contract, persisted inputs, and local code inspection without replaying prior chat.

Workflow scaffold files such as `CLAUDE.md`, `BEADS_WORKFLOW.md`, repo-local skills under `.claude/skills/`, and repo-local subagents under `.claude/agents/` are committed to this repo's git — and `AGENTS.md` plus the `.codex/skills/` and `.codex/agents/` surfaces are committed too when Codex is set up — so they travel with feature branches and `git worktree` checkouts. Refresh them from the template with `update-skills`. Plan files under `docs/plans/` are the exception: they are git-ignored local scratch, written fresh per bead — not committed and not pushed. When a bead needs to reference its plan across machines, inline the plan into the bead's `notes` (Dolt-synced), not the `docs/plans/` path.

Keep repo exploration local. Verify the actual environment before running build, test, run, deploy, or migration commands; do not assume local execution.

Useful commands:

```bash
bd ready --json
bd show <id> --json
bd update <id> --status=in_progress
bd close <id> --reason="Completed"
bd dep add <child-id> <parent-id>
```

<!-- END TEMPLATE BD WORKFLOW -->
