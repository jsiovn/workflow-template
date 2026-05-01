---
name: executor-task
description: "Run a full executor cycle for one bead on a fresh feature branch off main: stash any in-flight work, switch to main, pull, create feat/<bead-id>, execute the bead end-to-end, then push and open a PR. Use when the user wants a single bead delivered as its own PR."
---

# Executor Task

Run exactly one full executor cycle for one bead, isolated on a fresh feature branch cut from the latest main, and deliver it as a PR.

This is the preferred manual path when each bead should ship as its own pull request and the working tree may have unrelated in-flight changes that should be preserved, not lost.

## Steps

1. If the current repo is not initialized for Beads, stop and tell the user to run the template bootstrap script or at minimum `bd init --prefix <prefix>` plus the repo scaffolding steps.

2. Determine the target bead **before touching the working tree**:
   - if the user supplied a bead id in the current request, use that bead
   - if the user supplied freeform selector text, treat it as a selector or hint
   - otherwise inspect `bd ready --json` and choose the best ready bead autonomously
   - preference order: a ready bead clearly related to the current repo context or recent planner discussion, else the highest-priority ready bead
   - if the choice is ambiguous, ask before claiming
   - record the chosen bead id as `<BEAD_ID>` (e.g. `bd-42`) for the rest of the flow

3. Detect the default branch. Use `git symbolic-ref refs/remotes/origin/HEAD` if present; otherwise fall back to `main` if it exists, else `master`. Record as `<DEFAULT_BRANCH>`.

4. Preserve any in-flight changes on the current branch:
   - run `git status --porcelain` to detect dirty state (tracked changes, untracked files, staged or unstaged)
   - record the current branch name as `<PREV_BRANCH>` via `git rev-parse --abbrev-ref HEAD`
   - if dirty:
     - if `<PREV_BRANCH>` equals `<DEFAULT_BRANCH>`, stop and ask the user how to proceed — do not auto-commit on the default branch
     - otherwise, stage everything and commit on `<PREV_BRANCH>` with message:
       ```
       wip(<PREV_BRANCH>): switching to <BEAD_ID> — <short reason>
       ```
       where `<short reason>` is "start <BEAD_ID>" plus the bead title if known. Use `git add -A` then `git commit -m "..."`.
     - Do **not** use `git stash` — a real WIP commit on the source branch is easier to recover and survives `git checkout`.
   - if clean, no action needed

5. Switch to the default branch and update it:
   ```
   git checkout <DEFAULT_BRANCH>
   git pull --ff-only
   ```
   If `pull --ff-only` fails (local divergence on the default branch), stop and ask the user — do not force or rebase silently.

6. Create the feature branch off the freshly pulled default:
   ```
   git checkout -b feat/<BEAD_ID>
   ```
   If `feat/<BEAD_ID>` already exists locally, stop and ask the user whether to reuse, rename, or delete it.

7. Run the executor cycle for `<BEAD_ID>` — **every step in order**:
   - `beads-claim`
   - `writing-plans`
   - implementation
   - `systematic-debugging` if blocked
   - **`build-and-test`** — REQUIRED after implementation. Read the repo-local skill (`.claude/skills/build-and-test/SKILL.md` for Claude sessions or `.codex/skills/build-and-test/SKILL.md` for Codex sessions — both are kept in sync) and follow it. Do NOT skip this step.
   - `verification-before-completion` (run the verification commands)
   - `requesting-code-review` (dispatch the code-reviewer subagent; required, not optional)
   - `beads-close`

8. If separate work is discovered, create follow-up beads during execution or before close. Keep this branch scoped to `<BEAD_ID>` only.

9. If a blocker appears, update the current bead, summarize the blocker, and stop **on the feature branch** — do not push or open a PR. The earlier WIP commit on `<PREV_BRANCH>` is intact and can be returned to with `git checkout <PREV_BRANCH>`.

10. If build/test fails and the fix is still in scope, return to implementation and retry.

11. After successful close, finalize the branch by following the **`finishing-a-development-branch`** skill:
    - verify clean tree and commits ahead of `<DEFAULT_BRANCH>`
    - run the workflow-backup sync if the repo uses the local-only workflow mirror model
    - `git push -u origin HEAD`
    - `gh pr create --base <DEFAULT_BRANCH> --fill` (or with `--title`/`--body` if the user supplied them)
    - report the PR URL

12. Stop with a concise summary: bead id, branch name, PR URL, and a one-line note if a WIP commit was left on `<PREV_BRANCH>` so the user knows where to return.

## Checkout Discipline

- If `bd where` fails in the current checkout, stop and repair the repo with `bd bootstrap --yes` before continuing.
- Never rebase or force-push the default branch.
- The feature branch must be named exactly `feat/<BEAD_ID>` so it is unambiguously tied to the bead.

## Hard Rules

- One bead, one branch, one PR.
- Never lose uncommitted work — always make a WIP commit on the previous branch before switching, never stash silently, and never operate from a dirty default branch.
- Do not silently skip verification or code review.
- Do not continue into another bead after the PR is opened.
- If `gh` is unavailable, push the branch and report the branch name for manual PR creation rather than failing the whole flow.
