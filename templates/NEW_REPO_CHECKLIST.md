# New Repo Checklist

## Stage 1: General Workflow Bootstrap

1. Install `bd`, `dolt`, and Python on the machine.
2. Bootstrap the repo with the template script. If the target path is empty, the script initializes git first.
   - macOS/Linux: `bash ./scripts/posix/bootstrap-new-repo.sh /path/to/repo <prefix>`
   - Windows: `pwsh -File .\scripts\windows\bootstrap-new-repo.ps1 -RepoPath D:\path\to\repo -Prefix <prefix>`
3. Verify:
   - `bd version`
   - `bd ready --json`
   - `bd where`
   - `scripts/windows/workflow-status.ps1` or `scripts/posix/workflow-status.sh`
4. Confirm the standalone bootstrap beads exist:
   - `Specialize build-and-test for this repo`
   - `Specialize attach-web-screenshots for this repo`
5. Use the general planner flow immediately, even in an empty repo:
   - `plan-beads`
   - `brainstorming`
   - `planner-research` if needed
   - `beads-planner`
   - `validate-beads`
6. Ensure beads include `Read:`, `Inputs:`, `Files:`, and `Verify:` so a new executor session can execute them without replaying planner chat.
7. Keep the bootstrap-created build-and-test bead independent; do not nest it under the first feature epic.
8. Ensure the first execution plans include an exact `## Verification` section because the stage-1 `build-and-test` skill is generic and follows the plan literally.

## Stage 2: Project-Specific Specialization

1. Customize the repo-local `build-and-test` skill once the repeated verification flow is clear.
2. Customize the repo-local `attach-web-screenshots` skill with the project's preview command and auth shape.
3. Add repo-specific setup docs only when there is stable runtime, build, serve, deploy, or smoke-test behavior worth documenting.
4. Keep the general workflow skills synced from this template; only the repo-local specializations should diverge.
5. Run one top-level executor session at a time per branch. Use `executor-task-worktree` to parallelize across worktrees.
