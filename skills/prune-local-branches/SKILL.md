---
name: prune-local-branches
description: "Delete local git branches whose upstream has been removed from origin. Use when the user asks to clean up stale, pruned, or deleted remote branches locally."
---

# Prune Local Branches

Remove local branches that no longer have a corresponding branch on origin.

## Steps

### 1. Fetch and prune remote-tracking refs

```bash
git fetch --prune
```

This updates remote-tracking refs and removes any that no longer exist on origin.

### 2. List local branches with a gone upstream

```bash
git branch -vv | grep ': gone]'
```

Each line shows a local branch whose upstream has been deleted on origin. If the output is empty, report "No stale local branches found" and stop.

### 3. Confirm before deleting

Show the user the list of branches to be deleted and ask for confirmation before proceeding. Do not delete without explicit approval.

### 4. Delete the stale branches

For each branch in the list (extract just the branch name — the first word of each line, stripping any leading `*`):

```bash
git branch -D <branch>
```

Always use `-D` (force-delete). Branches in this list already had their upstream deleted on origin, so "not fully merged" warnings are expected — they arise from squash or rebase merges on the remote where the commit SHAs differ even though the code is already on the default branch (e.g. `main`).

### 5. Report results

List every branch that was deleted and every branch that was skipped (with the reason).

## Hard Rules

- Always run `git fetch --prune` first — local remote-tracking state may be stale.
- Never delete the currently checked-out branch.
- Always use `-D` for branches in the gone list — squash/rebase merges mean `-d` will falsely refuse them.
- Never delete branches that still have a live upstream (not `: gone]` in `git branch -vv`).
