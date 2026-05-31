---
name: validate-beads
description: "Validate a planned epic before autonomous execution. Use after beads-planner to check dependency quality, bead size, fresh-session-safe bead contracts, verification instructions, and parallel-safety notes."
---

# Validate Beads

Run a pre-execution quality gate for an epic before autonomous execution starts.

## Goal

Catch planning defects before execution starts coding. This is a planner-side validation pass, not an implementation step.

## Steps

1. If the current repo is not initialized for Beads, stop and tell the user to run the template bootstrap script or at minimum `bd init --prefix <prefix>` plus the repo scaffolding steps.
2. Determine the target epic:
   - if the user supplied an epic id, use it
   - otherwise use the most recent planning context and ask only if the target epic is ambiguous
3. Inspect the epic and its child beads. Use `bd show <epic-id> --json` plus the current planning context and `.beads/` state as needed.
4. Validate the epic against this checklist:
   - the target is actually an epic
   - child beads are small enough for one focused executor session
   - dependencies are explicit and coherent
   - no two child beads describe the same work
   - there is a meaningful final integration or `build-and-test` bead when runtime behavior changed
   - every bead includes:
     - `Read:`
     - `Inputs:`
     - `Files:`
     - `Verify:`
     - `Risk:`
     - `Parallel:`
     - `Escalate:`
   - every bead is fresh-session-safe: an executor can run it from the bead contract plus local inspection without replaying prior chat context
   - `Inputs:` references persisted state only, not conversational memory
   - beads marked as parallel do not obviously overlap the same file scope
   - every `Read:` path is portable across machines: a path is portable only if it is committed to git in the current repo. Paths under `$HOME`, `~/.claude/`, `/tmp/`, anywhere outside the repo, OR in-repo paths under a git-ignored directory (verify with `git check-ignore -v <path>`) are blocking. For each, the planner must inline the file's content into the bead notes (so it syncs via Dolt). Only rewrite the `Read:` reference to an in-repo path if that path is actually git-committed; if `docs/plans/` is git-ignored, point executors at the bead's `notes` field instead (`bd show <id>`).
5. Classify findings:
   - blocking: missing execution contract, duplicate work, broken dependency shape, oversized bead, or chat-context-dependent bead
   - non-blocking: wording cleanup, minor note improvements
6. If blocking findings exist:
   - do not approve any bead for execution
   - update beads, notes, or dependencies until the blockers are removed
   - report exactly what still needs to change
7. If the epic passes:
   - report that the epic is validated
   - identify the first ready descendants or likely first wave
   - recommend claiming a bead via an `executor-*` orchestrator skill (use an `executor-epic-task` variant for epic-scoped plans)

## Hard Rules

- Do not claim beads.
- Do not implement code.
- Do not approve any bead while it is missing `Read:`, `Inputs:`, `Files:`, or `Verify:`.
- Fail closed if a bead would require an executor to infer missing product intent from earlier conversation history.
- When in doubt about parallel safety, fail closed and mark the work as sequential.
