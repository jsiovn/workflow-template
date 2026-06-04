---
name: rebase-and-push
description: Use when the user wants to rebase the current feature branch onto its up-to-date base and force-push with lease — e.g. "rebase this branch", "rebase and push", "bring my branch up to date with the epic". Detects whether the branch was cut from its parent epic branch (epic/<epic-bead-id>) or the default branch (main/master), rebases onto the matching origin ref, resolves conflicts, runs verification-before-completion, then pushes with --force-with-lease. Maintenance op; refuses to run on the default branch or an epic branch.
---

# Rebase and Push

Rebase the **current feature branch** onto its up-to-date base, resolve any conflicts, prove the result still passes via `verification-before-completion`, then push with `--force-with-lease`.

**Announce at start:** "I'm using the rebase-and-push skill to rebase the current branch onto its base and push with lease."

This is a maintenance op, user-invoked. It rewrites history and force-pushes — so it only ever touches a feature branch, never the default branch or an epic branch.

## The base it rebases onto

The base is the branch this feature branch was cut from:

- Cut from an **epic** → rebase onto `origin/epic/<epic-bead-id>`.
- Cut from the **default branch** → rebase onto `origin/<default-branch>` (`main`, else `master`).

The skill always rebases onto the **`origin/` ref** (the freshly fetched remote tip), never a stale local copy.

## Steps

### 1. Capture starting state — BEFORE any fetch

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
ORIG_HEAD_SHA=$(git rev-parse HEAD)
git branch "backup/${CURRENT_BRANCH}-pre-rebase" "$ORIG_HEAD_SHA" 2>/dev/null || true  # durable recovery point

# The branch's real upstream — it may be named differently from the local branch
# (fork / PR checkouts), and it is what we must lease against and push to.
UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)  # e.g. origin/feature/foo

# The remote tip of OUR branch right now = the lease value. Capture it BEFORE any fetch
# (step 8) or the lease check becomes meaningless.
EXPECTED_REMOTE=$(git rev-parse --verify --quiet "${UPSTREAM:-refs/remotes/origin/$CURRENT_BRANCH}" || true)
```

Refuse to run — stop and report — if any of these hold:

- `CURRENT_BRANCH` is `HEAD` (detached).
- `CURRENT_BRANCH` is the default branch (`main`/`master`).
- `CURRENT_BRANCH` matches `epic/*`.

**Resolve the remote-side branch name** (`REMOTE_BRANCH`) — what we fetch and push in step 8:

- If `UPSTREAM` is empty → the branch was never pushed; `REMOTE_BRANCH` = `$CURRENT_BRANCH`, `EXPECTED_REMOTE` is empty.
- If `UPSTREAM` is `origin/<name>` → `REMOTE_BRANCH` = `<name>` (strip the `origin/` prefix). This is **not** assumed equal to `$CURRENT_BRANCH`.
- If `UPSTREAM` points at a remote other than `origin` → stop and ask; this skill assumes `origin`.

Never push to a fresh `origin/$CURRENT_BRANCH` when an upstream with a different name already exists — that silently splits your rebased work onto a phantom branch the PR isn't watching.

**Recovery point.** The durable handle is the recorded `$ORIG_HEAD_SHA` (and the `backup/<branch>-pre-rebase` branch). After a rebase, `git reset --hard "$ORIG_HEAD_SHA"` restores the pre-rebase branch. Do **not** rely on the bare `ORIG_HEAD` ref for recovery — any later history-moving op (a second rebase, a `git reset`, `merge`, `pull`) overwrites it.

### 2. Require a clean working tree

```bash
git status --porcelain
```

If there is **any** output (tracked changes, staged, or untracked), stop and ask the user to commit or stash. **Never** auto-stash or `git add -A` on their behalf — a silent stash is easy to lose across a conflicted rebase.

### 3. Determine the base branch

Resolve `<BASE>` in this order; stop at the first that yields a confident answer:

**(a) Explicit override.** If the user named a base in the request, use it. Normalise a bare epic bead id `X` to `epic/X`; treat `main`/`master`/"default" as the default branch.

**(b) Beads parent epic** (authoritative when Beads is set up and the branch is `feat/<bead-id>...`):

- If `bd where` succeeds and `CURRENT_BRANCH` looks like `feat/<bead-id>-...`, extract `<BEAD_ID>` as the first two `-`-delimited tokens after `feat/` (e.g. `feat/lexify-wyk-t9-root-wiring` → `lexify-wyk`). Confirm with `bd show <BEAD_ID> --json`; if that fails, try the first token alone; if still invalid, fall through to (c).
- Inspect parent deps (`bd show <BEAD_ID> --json`, `bd dep list <BEAD_ID>`) for a parent whose target bead is `--type epic`.
  - Parent epic `<EPIC_BEAD_ID>` exists → `<BASE>` = `epic/<EPIC_BEAD_ID>`.
  - No epic parent → `<BASE>` = the default branch.
- If multiple epic parents exist, stop and ask which one.

**(c) Git topology** (general fallback when Beads is unavailable or the branch name carries no bead id). After the fetch in step 4, pick the candidate base whose **merge-base with HEAD is the deepest** — the base you were actually cut from has the fork point that is a descendant of every other candidate's fork point. Rank by **topology, not commit timestamp**: timestamps can be backdated or rewritten and do not track depth.

```bash
DEFAULT_BRANCH=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH=$(git rev-parse --verify --quiet origin/main >/dev/null && echo main || echo master)

BASE=""; BASE_MB=""
for c in "$DEFAULT_BRANCH" $(git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/epic); do
  mb=$(git merge-base HEAD "origin/$c" 2>/dev/null) || continue
  if [ -z "$BASE" ]; then
    BASE="$c"; BASE_MB="$mb"
  elif [ "$mb" = "$BASE_MB" ]; then
    [ "$c" = "$DEFAULT_BRANCH" ] && BASE="$c"          # genuine tie on the fork point → prefer default
  elif git merge-base --is-ancestor "$BASE_MB" "$mb"; then
    BASE="$c"; BASE_MB="$mb"                            # c's fork point is deeper → it's the closer base
  fi                                                     # else $mb is shallower (or equal) → keep current best
done
echo "$BASE"
```

Sanity-check the winner: its fork point (`BASE_MB`) must contain every other candidate's fork point (`git merge-base --is-ancestor <other_mb> "$BASE_MB"` is true for each). If two fork points are **unordered** — neither contains the other — the base is genuinely ambiguous; stop and ask.

**Cross-check and confirm.** Print the resolved base, the base ref (`origin/<BASE>`), and how far behind/ahead the branch is. If (b) and (c) are both available and **disagree**, or the base is otherwise ambiguous, stop and ask before doing anything destructive. Otherwise state the resolved base and proceed.

### 4. Fetch and validate the base

```bash
git fetch origin --prune
git rev-parse --verify "origin/$BASE"   # must succeed
```

If `origin/<BASE>` does not exist (e.g. an epic branch that was never pushed), **stop and report**. Do **not** create the base branch — creating epic branches is the executor skills' job, not this one.

### 5. Skip the rebase if the base tip is already contained

```bash
git merge-base --is-ancestor "origin/$BASE" HEAD && echo "BASE_CONTAINED"
```

- **Base tip contained AND tip already matches the remote** (`[ -n "$EXPECTED_REMOTE" ] && [ "$(git rev-parse HEAD)" = "$EXPECTED_REMOTE" ]`) → nothing to do. Report "already up to date with `<BASE>`" and stop.
- **Base tip contained but there are unpushed commits** (`HEAD` ≠ `EXPECTED_REMOTE`, or the branch was never pushed) → skip the rebase (it would be a no-op) but **continue to steps 7–8** to verify and push the unpushed work. Do not report "up to date" — there is work to publish.
- **Base tip not contained** → continue to step 6 (a real rebase).

### 6. Rebase and resolve conflicts

```bash
git rebase "origin/$BASE"
```

- **No conflicts** → go to step 7.
- **Conflicts** → resolve them:
  - **`ours`/`theirs` are inverted during rebase.** `ours` = the base you are replaying onto (`origin/<BASE>`); `theirs` = your own commit being applied. This is the reverse of a merge — keep it straight while resolving.
  - For each conflicted file (`git diff --name-only --diff-filter=U`): read it, understand both sides, and resolve to preserve the intent of **both** the base's change and your commit's change. Do not blindly take one side.
  - `git add <file>` each resolved file, then `git rebase --continue`. Repeat per replayed commit.
  - **Never `git rebase --skip`** without explicit user approval — it silently drops one of your commits.
  - If a conflict is genuinely ambiguous and you cannot determine the correct resolution, **stop and ask**. Leave the rebase in progress; `git rebase --abort` restores the branch to its pre-rebase state.

### 7. Verify — run `verification-before-completion` (REQUIRED before push)

Invoke the **`verification-before-completion`** skill: run the repo's `build-and-test` / verification commands, read the full output, confirm exit 0 / 0 failures.

```
NO PUSH WITHOUT FRESH VERIFICATION EVIDENCE.
```

If verification fails, **do not push**. Stop and report the failures. The rebased commits are local only — the user can fix forward or `git reset --hard "$ORIG_HEAD_SHA"`.

### 8. Push with lease

**Never-pushed branch** (`EXPECTED_REMOTE` is empty) → plain push, no force, no concurrent-push check needed:

```bash
git push -u origin HEAD
```

**Already on origin** (`EXPECTED_REMOTE` is non-empty) → detect a concurrent push first, then force-push with an explicit lease tied to the value captured in step 1. The rebase rewrote history, so a blind force would clobber anyone who pushed since we started:

```bash
git fetch origin "$REMOTE_BRANCH"
REMOTE_NOW=$(git rev-parse --verify --quiet "refs/remotes/origin/$REMOTE_BRANCH" || true)

if [ "$REMOTE_NOW" != "$EXPECTED_REMOTE" ]; then
  : # someone pushed to this branch since we started — STOP and ask; do not clobber their work
else
  git push --force-with-lease="$REMOTE_BRANCH:$EXPECTED_REMOTE" origin "HEAD:$REMOTE_BRANCH"
fi
```

If the push is still rejected by the lease, a concurrent push beat us — **stop**. Do **not** retry with a bare `--force`.

### 9. Report

```
Branch:   <CURRENT_BRANCH>  (→ origin/<REMOTE_BRANCH>)
Base:     origin/<BASE>   (<n> commits rebased; <m> conflicts resolved in: <files>)
Verify:   <command> → <evidence, e.g. exit 0, 42/42 pass>
Pushed:   <short-sha>  (--force-with-lease)
Recover:  git reset --hard <ORIG_HEAD_SHA>   # or: git reset --hard backup/<CURRENT_BRANCH>-pre-rebase
```

## Hard Rules

- **Feature branches only.** Refuse on the default branch, any `epic/*` branch, or detached HEAD. Never rebase or force-push the default or an epic branch.
- **Verification gates the push.** No push without fresh `verification-before-completion` evidence. A verification failure means no push, full stop.
- **Lease, never bare force.** Always `--force-with-lease=<remote-branch>:<expected>`; capture `<expected>` from the branch's upstream BEFORE any fetch. If the lease is rejected, stop — never escalate to `--force`.
- **Push to the real upstream.** Resolve the remote branch name from `@{u}`; never create a new `origin/<local-name>` when the upstream is named differently.
- **Clean tree required.** Never silently stash or stage the user's uncommitted work.
- **Never `git rebase --skip`** without explicit approval — it drops a commit.
- **Don't create a missing base branch.** If `origin/<BASE>` doesn't exist, stop and report.
- **Stop on ambiguity** — ambiguous base detection (unordered fork points, or signals that disagree) or ambiguous conflict resolution means ask, not guess.

## Quick Reference

| Situation | Action |
|-----------|--------|
| On `main`/`master` or `epic/*` | Refuse — only feature branches |
| Detached HEAD | Refuse — stop |
| Dirty working tree | Stop, ask user to commit or stash |
| Beads parent epic resolves | Base = `epic/<epic-bead-id>` |
| No epic parent / no Beads | Base = default branch (topology cross-check) |
| Topology fork points unordered / signals disagree | Stop, ask |
| `origin/<BASE>` missing | Stop, report — do not create it |
| Base contained AND tip == remote | Report "up to date", stop |
| Base contained but commits unpushed | Skip rebase, still verify + push |
| Rebase conflict | Resolve (`ours`=base, `theirs`=your commit); `--continue` |
| Conflict ambiguous | Stop and ask; `git rebase --abort` to restore |
| Verification fails | Do NOT push; stop, report |
| Branch never pushed (`EXPECTED_REMOTE` empty) | `git push -u origin HEAD` (no force) |
| Upstream name ≠ local name | Push `HEAD:<remote-branch>` from `@{u}`; never a new `origin/<local-name>` |
| Remote tip moved since start | Stop, ask — do not clobber |
| Lease rejected | Stop — never bare `--force` |

## Integration

**Pairs with:**

- **`verification-before-completion`** — the required gate before the force-push. Same Iron Law: evidence before the push, always.

**Complements:**

- **`executor-epic-task`** / **`executor-epic-task-worktree`** — they create `epic/<epic-bead-id>` and cut `feat/<bead-id>` branches off it; this skill refreshes such a feature branch against its parent epic later, when the epic has moved on.
- **`prune-local-branches`** — sibling maintenance op for cleaning up branches whose upstream is gone.

**Called by:** the user, manually, whenever a feature branch needs to catch up to its base before review or merge.
