<!-- BEGIN TEMPLATE BD WORKFLOW -->
## Workflow Guide

Use `BEADS_WORKFLOW.md` for the current planner and executor flow. All workflow skills are repo-local: Codex skills live under `.codex/skills/`, Claude skills under `.claude/skills/`. Subagents dispatched by skills (e.g. `code-reviewer`) live under `.codex/agents/` and `.claude/agents/`.

Preferred entry points are `plan-beads`, `executor-task`, and `executor-task-worktree`. When the bead is part of an epic that should land in main as a single merge, use `executor-epic-task` (or `executor-epic-task-worktree` for parallel work) — these branch off and PR into `epic/<epic-bead-id>-<slug>` instead of main. When a bead was already executed and a PR is open but the task turned out to be wrong, reopen the bead, edit its requirements, then run `executor-rework-in-place <bead-id>` to amend the existing PR in the current working tree (no new branch, no new PR). Use `planner-research` only inside a planner session when `brainstorming` still leaves material factual uncertainty.

The executor test skill is installed under both `.claude/skills/build-and-test/SKILL.md` and `.codex/skills/build-and-test/SKILL.md` (kept in sync); read whichever matches your session and use it between implementation and final verification.

Use `scripts/windows/workflow-status.ps1` or `scripts/posix/workflow-status.sh` to inspect `.beads/workflow/`, the shared control plane, and Beads backend state. Use `scripts/windows/agent-mail.ps1` or `scripts/posix/agent-mail.sh` for shared locks, reservations, and mailbox inspection.
Workflow scaffold files such as `AGENTS.md`, `CLAUDE.md`, `BEADS_WORKFLOW.md`, `docs/plans/`, and `.codex/.claude` skills stay local-only in downstream Git. Mirror them to the backup repo with `scripts/windows/sync-workflow-backup.ps1` or `scripts/posix/sync-workflow-backup.sh` before opening a PR.

Keep repo exploration local. Verify the actual environment before running build, test, run, deploy, or migration commands; do not assume local execution.

## Issue Tracking With `bd`

- Use `bd` for all issue tracking
- Do not use markdown TODO files, TodoWrite, or alternate trackers
- Live `.beads` state is local-only and should not be committed
- Run one top-level executor session at a time per branch

## Essential Commands

```bash
bd ready --json
bd show <id> --json
bd create --title="Summary" --description="Details" --type=task|bug|feature|epic --priority=2
bd update <id> --status=in_progress
bd close <id> --reason="Completed"
bd dep add <child-id> <parent-id>
git checkout -b feat/<bead-id>
```

## Notes

- Epics must use `--type=epic`
- Check `bd ready` before asking what to work on next
- Each bead must be fresh-session-safe: a new executor session should be able to execute from the bead contract, persisted inputs, and local code inspection without replaying prior chat
- If the current checkout cannot open the Beads database, inspect `bd where` and run `bd bootstrap --yes` before continuing
<!-- END TEMPLATE BD WORKFLOW -->
