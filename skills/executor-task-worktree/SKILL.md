---
name: executor-task-worktree
description: "Run a full executor cycle for one bead in a fresh git worktree off main: leaves the main working tree completely untouched, creates a sibling worktree at ../<repo>-feat-<bead-id>, executes the bead end-to-end, pushes, opens a PR, then removes the worktree. Use when the main tree has active work that must not be disturbed."
---

# Executor Worktree

Run exactly one full executor cycle for one bead, isolated in a fresh git worktree cut from the latest main, and deliver it as a PR.

This is the preferred path when the main working tree has in-flight changes that must not be touched — no WIP commit, no branch switch, the main tree stays exactly as it is. All bead work happens in a sibling worktree that is created and removed automatically.

## Steps

1. If the current repo is not initialized for Beads, stop and tell the user to run the template bootstrap script or at minimum `bd init --prefix <prefix>` plus the repo scaffolding steps.

2. Determine the target bead **before touching anything**:
   - if the user supplied a bead id in the current request, use that bead
   - if the user supplied freeform selector text, treat it as a selector or hint
   - otherwise inspect `bd ready --json` and choose the best ready bead autonomously
   - preference order: a ready bead clearly related to the current repo context or recent planner discussion, else the highest-priority ready bead
   - if the choice is ambiguous, ask before proceeding
   - record the chosen bead id as `<BEAD_ID>` (e.g. `bd-42`) for the rest of the flow

3. Detect the default branch. Use `git symbolic-ref refs/remotes/origin/HEAD` if present; otherwise fall back to `main` if it exists, else `master`. Record as `<DEFAULT_BRANCH>`.

4. **Do not touch the main working tree at all.** No dirty-state check, no WIP commit, no branch switch. The main tree must remain on whatever branch it is currently on.

5. Determine the worktree path:
   ```
   REPO_NAME=$(basename $(git rev-parse --show-toplevel))
   WORKTREE_PATH="../${REPO_NAME}-feat-${BEAD_ID}"
   ```

6. Fetch the default branch ref so the worktree starts from the latest upstream state:
   ```
   git fetch origin <DEFAULT_BRANCH>
   ```

7. Create the worktree on a new branch off the freshly fetched default:
   ```
   git worktree add <WORKTREE_PATH> -b feat/<BEAD_ID> origin/<DEFAULT_BRANCH>
   ```
   - If `feat/<BEAD_ID>` already exists locally, stop and ask the user whether to reuse, rename, or delete it.
   - If `<WORKTREE_PATH>` already exists on disk, stop and ask the user.

8. Run the executor cycle for `<BEAD_ID>` — **every step in order, operating inside `<WORKTREE_PATH>`**:
   - `beads-claim`
   - `writing-plans`
   - implementation
   - `systematic-debugging` if blocked
   - **`build-and-test`** — REQUIRED after implementation. Read the repo-local skill from the worktree (`.claude/skills/build-and-test/SKILL.md` for Claude sessions or `.codex/skills/build-and-test/SKILL.md` for Codex sessions) and follow it. Do NOT skip this step.
   - `verification-before-completion` (run the verification commands)
   - `requesting-code-review` (dispatch the code-reviewer subagent; required, not optional)
   - `beads-close`

9. If separate work is discovered, create follow-up beads during execution or before close. Keep this worktree scoped to `<BEAD_ID>` only.

10. If a blocker appears, update the current bead, summarize the blocker, and stop — **do not remove the worktree**. Report the worktree path so the user can return to it or clean it up manually:
    ```
    git worktree remove <WORKTREE_PATH>   # to discard
    git worktree prune
    ```

11. If build/test fails and the fix is still in scope, return to implementation and retry.

12. After successful close, finalize the branch from within `<WORKTREE_PATH>` following the **`finishing-a-development-branch`** skill:
    - verify clean tree and commits ahead of `<DEFAULT_BRANCH>`
    - run the workflow-backup sync if the repo uses the local-only workflow mirror model
    - `git push -u origin HEAD`
    - `gh pr create --base <DEFAULT_BRANCH> --title "<conventional-commit title>" --body "..."` — the PR body must include a `Bead: <BEAD_ID>` reference line (e.g. `Bead: lexify-a8m`). The title follows conventional commits format (`type(scope): description`) with no bead id prefix.
    - report the PR URL

13. **Web screenshots** — if the bead touched any UI component or page, run the `attach-web-screenshots` skill from within `<WORKTREE_PATH>` to capture browser screenshots at all Tailwind breakpoints and attach them to the open PR. Skip only when the change is purely non-visual (e.g. utility functions, API handlers, types, tests).

14. **Remove the worktree on success** (after the PR URL is confirmed and screenshots are attached if applicable):
    ```
    git worktree remove <WORKTREE_PATH>
    git worktree prune
    ```

15. Stop with a concise summary: bead id, branch name, PR URL. The main working tree was never touched.

## Checkout Discipline

- Never touch or inspect the main working tree during execution.
- If `bd where` fails inside the worktree, stop and repair with `bd bootstrap --yes` from within the worktree before continuing.
- Never rebase or force-push the default branch.
- The feature branch must be named exactly `feat/<BEAD_ID>` so it is unambiguously tied to the bead.

## Hard Rules

- One bead, one worktree, one PR.
- Never touch the main working tree.
- Do not silently skip verification or code review.
- Do not continue into another bead after the PR is opened.
- If `gh` is unavailable, push the branch and report the branch name for manual PR creation rather than failing the whole flow.
- Remove the worktree only after the PR URL is confirmed and screenshots are attached; keep it on blocker so the user can resume.
