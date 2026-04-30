---
name: address-pr-comments
description: Use to iteratively address unresolved review comments on the current PR. Fetches unresolved threads, dispatches the pr-comment-fixer subagent to apply fixes, then verifies, commits, pushes, and posts replies. The reviewer resolves threads on their side; rerun the skill when new comments arrive.
---

# Addressing PR Review Comments

**Announce at start:** "I'm using the address-pr-comments skill to fetch unresolved review comments and dispatch the pr-comment-fixer subagent."

This skill is a thin driver. The heavy work — reading files and applying fixes — happens in the `pr-comment-fixer` subagent so the main session stays clean across iterative review cycles. Resolution status is the tracking mechanism: every rerun queries `isResolved: false`, so threads the reviewer has accepted drop out automatically. **You never resolve threads.**

## Where the subagent lives

- `.claude/agents/pr-comment-fixer.md` (Claude)
- `.codex/agents/pr-comment-fixer.md` (Codex)

If neither exists, run `update-skills` against the repo to install them.

## Prerequisites

- Working directory is the downstream repo with the PR's feature branch checked out.
- `gh` CLI is installed and authenticated (`gh auth status`).
- Working tree is clean (or any uncommitted changes are intentional).
- `gh pr view` succeeds — the branch has an open PR.

If any prerequisite fails, stop and report.

## Steps

### 1. Identify the PR, repo, and "us"

```bash
gh pr view --json number,headRefName,url,state,author -q '{number, branch: .headRefName, url, state, author: .author.login}'
gh repo view --json owner,name -q '{owner: .owner.login, name}'
```

Capture `OWNER`, `REPO`, `PR_NUMBER`, and `AUTHOR_LOGIN` (the PR author — this is "us" for the purpose of detecting our own replies). If `state != OPEN`, stop.

### 2. Fetch unresolved review threads

REST does not expose thread resolution state — use GraphQL:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            comments(first: 50) {
              nodes {
                databaseId
                author { login }
                body
                path
                line
                diffHunk
                url
                createdAt
                reactions(first: 20, content: EYES) {
                  nodes { user { login } }
                }
              }
            }
          }
        }
      }
    }
  }' -F owner="$OWNER" -F repo="$REPO" -F pr="$PR_NUMBER"
```

Filter the threads with **two** conditions, both must hold:

1. `isResolved == false` (reviewer has not accepted the fix yet)
2. **The latest reviewer comment (i.e. latest comment whose `author.login != AUTHOR_LOGIN`) does NOT have a 👀 reaction from `AUTHOR_LOGIN`**

The 👀 reaction is the "we addressed this" marker. After we reply on a thread (step 7), we also 👀 the latest reviewer comment in that thread (step 7b). On reruns:

- Thread reviewer never followed up → their last comment still has our 👀 → not actionable.
- Reviewer added a follow-up after our reply → new latest-reviewer-comment has no 👀 → actionable again.
- Reviewer resolved → drops out via `isResolved` regardless of reactions.

This works for both human reviewers (who usually resolve) and bot reviewers (`claude[bot]`, `coderabbit[bot]`, `ultrareview`) who often do not. The 👀 is also visible in the GitHub UI as a soft signal that the comment was acknowledged.

Keep `isOutdated` threads if they pass the two filters above (outdated ≠ resolved).

If zero threads remain after filtering, report "No actionable unresolved threads (all already 👀'd or resolved)" and stop.

### 3. Build the brief and dispatch the subagent

Transform the GraphQL response into the brief schema the subagent expects (see `pr-comment-fixer.md`'s "Reading the brief" section). For each actionable thread, include:

- `thread_id` — the GraphQL `id`
- `root_comment_id` — `comments.nodes[0].databaseId` (used to post the reply)
- `latest_reviewer_comment_id` — `databaseId` of the most recent comment whose `author.login != AUTHOR_LOGIN` (used to post the 👀)
- `path`, `line`, `is_outdated`
- `comments[]` — all comments oldest-first, each with `author.login` and `body`
- `diff_hunk`, `url`

Dispatch the `pr-comment-fixer` subagent:

- **Claude session:** Task tool with `subagent_type: pr-comment-fixer`, prompt = the JSON brief plus a one-line preamble: `Address these unresolved review threads on PR #<num>. Brief follows.`
- **Codex session:** equivalent subagent dispatch with the same prompt.

The subagent edits files and returns a JSON summary (schema in its definition). It does **not** commit, push, or call any GitHub API.

### 4. Verify

Run the repo's `build-and-test` skill (or the project's standard verification command). If verification fails, fix the regression — do not push broken fixes. If you cannot reconcile what the subagent did with the test failure, surface the diff to the user before continuing.

### 5. Commit

Single commit per skill run. Default message:

```bash
git add -A
git commit -m "fixup: address review comments on PR #$PR_NUMBER"
```

If the project preserves history on merge (no squash), prefer `git commit --fixup=<sha>` against the original feature commit so an autosquash rebase is clean. Ask the user which the project uses if it is not obvious from existing branch history.

### 6. Push

```bash
git push
```

If push fails (diverged history, etc.), stop and ask. **Never force-push** without explicit permission.

### 7. Post replies

For each thread in the subagent's output, replace the literal token `<sha>` in `reply_body` with the short SHA of the commit just pushed (`git rev-parse --short HEAD`), then post:

```bash
gh api -X POST \
  "repos/$OWNER/$REPO/pulls/$PR_NUMBER/comments/$ROOT_COMMENT_ID/replies" \
  -f body="$REPLY_BODY"
```

Where `$ROOT_COMMENT_ID` is `root_comment_id` from the subagent's output for that thread.

### 7b. 👀 the latest reviewer comment

For each thread, after the reply posts successfully, react with 👀 on the latest reviewer comment so the next run knows we addressed it. We use 👀 (eyes / "seen") rather than 👍 (thumbs up / "agree") because the reaction marks "processed," not "agreed" — actions like Pushback or Clarify mean we processed the comment without agreeing with it.

```bash
gh api -X POST \
  "repos/$OWNER/$REPO/pulls/comments/$LATEST_REVIEWER_COMMENT_ID/reactions" \
  -f content="eyes"
```

`$LATEST_REVIEWER_COMMENT_ID` is `latest_reviewer_comment_id` from the brief you built in step 3 (carry it through; the subagent does not modify it).

If the reaction call fails (e.g., the reaction already exists, network blip), log it and continue — the worst case is the next run sees the thread as actionable and the subagent will likely return `already-fixed`. Do **not** abort the run for a failed reaction.

**Do not resolve threads.** Resolution is the reviewer's signal that they accept the fix.

### 8. Report

Print a summary using the subagent's `summary` field plus a per-thread breakdown:

```
Addressed N unresolved threads on PR #<num>:
  - <file:line> — Fixed (<change_summary>)
  - <file:line> — Pushback (<reason>)
  - <file:line> — Clarify (<question>)
  - <file:line> — Already-fixed (<mechanism>)

Pushed: <branch> (<short_sha>)
PR: <url>
```

Include the subagent's `notes` field if non-empty.

## Hard Rules

- **Never resolve threads yourself.** Resolution status is the reviewer's tracking mechanism across reruns. If the user explicitly asks you to resolve, do it via the `resolveReviewThread` GraphQL mutation, but warn first that this short-circuits the reviewer's verification.
- **Never force-push** unless the user explicitly asks.
- **Never invent a reply.** Replies come from the subagent's `reply_body`, with only `<sha>` substitution.
- **Never skip verification.** A reply that says "fixed in abc123" pointing at a broken commit destroys reviewer trust.
- **Never trust `already-fixed` blind.** If the subagent claims a thread is already-fixed, spot-check by reading the cited file:line before accepting.

## Iteration Pattern

This skill is built to run repeatedly. A thread is **actionable** when both:

- `isResolved == false`, AND
- the latest reviewer comment lacks a 👀 reaction from us

State transitions per thread:

| Event | Effect on actionability |
|---|---|
| Reviewer (human or bot) posts initial comment | Actionable (no 👀 yet) |
| Skill replies + 👀's the latest reviewer comment | Not actionable (👀 marker present) |
| Reviewer posts a follow-up | Actionable again (new latest reviewer comment, no 👀 on it) |
| Reviewer resolves (human only — bots usually do not) | Not actionable forever |

Iteration loop:

1. You run the skill → subagent fixes + you verify, commit, push, reply. All addressed threads become non-actionable because we are now the latest author.
2. Reviewer reads replies, verifies the SHA. Human reviewers resolve; bot reviewers usually do not — but either way the skill stops acting on threads we already replied to.
3. Reviewer adds new comments on anything still wrong, or in a new place.
4. You rerun the skill → it picks up only actionable threads (newly opened, or follow-ups after our reply).
5. Repeat until the PR is approved.

Each iteration is one small fixup commit. Do not amend or force-push between iterations — the reviewer needs linear history to trust that "fixed in `<sha>`" still points at a real change.

## Edge Cases

| Situation | Action |
|---|---|
| Reviewer's comment is on the PR conversation (not inline) | This skill only handles inline review threads. Handle conversation comments manually with `gh pr comment`. |
| Reviewer is a bot (`claude[bot]`, `coderabbit[bot]`, etc.) that never resolves threads | The 👀 marker handles this — once we 👀 the bot's comment in step 7b, it drops out of the actionable filter. If the bot posts a *new* comment in the thread later, that new comment has no 👀 → actionable again next run. |
| Reviewer responds to our reply with a follow-up comment | Their new comment becomes the latest reviewer comment with no 👀 → actionable again next run. The subagent gets the full thread history and addresses the latest ask. |
| User wants to clear our 👀 to re-process a thread | They remove the 👀 reaction in the GitHub UI; next run picks it up. |
| The reviewer pushes commits while you are working | `git push` will fail; pull/rebase first, re-verify, then push. Do not silently force-push over their work. |
| CODEOWNERS re-requests review on every push | Normal — not a problem, just expected churn. |
| Subagent returns `clarify` for everything | The brief was probably underspecified or the comments are genuinely ambiguous; surface the questions to the user before posting them, in case the user can answer them directly. |
| Subagent edits files unrelated to any thread | Reject and re-dispatch with a stricter prompt. The subagent must stay in scope. |

## Integration

**Pairs with:**
- **`requesting-code-review`** — that skill dispatches a fresh review; this one closes the loop on review comments already received.
- **`build-and-test`** — must pass after fixes before pushing.

**Subagent:** `pr-comment-fixer` (definition in `agents/pr-comment-fixer.md`).

**Called by:** the user, manually, whenever new unresolved review comments appear on the active PR.
