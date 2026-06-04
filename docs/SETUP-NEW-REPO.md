# New Repo Setup Guide

Use this guide when starting a downstream repo from scratch or when a repo is still too empty to support project-specific workflow customization.

## Stage 1: General Bootstrap

1. Ensure machine prerequisites exist:
   - `bd`
   - `dolt`
   - Python
2. Bootstrap the repo from this template:
   - macOS/Linux: `bash ./scripts/posix/bootstrap-new-repo.sh [--with-screenshots] /path/to/repo <prefix>`
   - Windows: `pwsh -File .\scripts\windows\bootstrap-new-repo.ps1 -RepoPath D:\path\to\repo -Prefix <prefix> [-WithScreenshots]`
   - Pass `--with-screenshots` / `-WithScreenshots` only for web/UI projects that want the `attach-web-screenshots` skill plus its companion `.github/workflows/cleanup-screenshots.yml`. Omit for backend, CLI, or library repos.
3. The bootstrap script:
   - initializes git if the target path is not already a repo
   - runs `bd init -p <prefix> --server --skip-agents --skip-hooks`
   - runs `bd setup codex`
   - scaffolds the shared workflow docs, skills, and helper scripts
   - installs the managed root `.gitignore` block for local runtime artifacts (Beads/Dolt state, `*.db`, `__pycache__`, etc.) plus `docs/plans/` (per-session plan scratch that stays local — see `writing-plans`)
   - creates a standalone stage-2 bead for specializing `build-and-test`, plus a matching bead for `attach-web-screenshots` only when that opt-in skill was installed
4. Verify the repo is ready:
   - `bd where`
   - `bd ready --json`

## First Work In An Empty Repo

You do not need project-specific skills yet.

1. Run a planner session:
   - `plan-beads`
   - `brainstorming`
   - `planner-research` only if facts still matter
   - confirm the settled plan for Beads creation
   - `beads-planner`
   - `validate-beads`
2. Let the first planning pass define the runtime shape, likely files, verification needs, and the persisted inputs later beads should rely on.
3. Make sure the bead contract includes `Read:`, `Inputs:`, `Files:`, and `Verify:` so a fresh executor session can execute without replaying planner chat.
4. Make sure early execution plans include a precise `## Verification` section with exact commands and expected evidence. The stage-1 `build-and-test` skill depends on that section and will not guess.
5. Keep the bootstrap-created `Specialize build-and-test for this repo` bead independent (and `Specialize attach-web-screenshots for this repo` if you opted into screenshots). Do not make them children of the first feature epic.

## Stage 2: Project-Specific Customization

Customize the repo only after the real workflow becomes obvious from the first plan, first beads, or first implementation cycle.

Typical stage-2 changes:

- specialize `.codex/skills/build-and-test/SKILL.md`
- mirror the same specialization to `.claude/skills/build-and-test/SKILL.md`
- (if installed) specialize `.codex/skills/attach-web-screenshots/SKILL.md` and the `.claude/` mirror
- add runtime-specific setup or operational notes
- add repo-specific guidance outside the managed blocks in `AGENTS.md` or `CLAUDE.md`
- run `update-skills` to refresh shared workflow docs and skills from the template — they are committed to the downstream's own git and travel with feature branches

Examples:

- web app: `npm run build`, `npm run preview`, HTTP smoke checks, browser inspection
- backend service: package build, process launch, API health checks
- device viewer: serve the app, connect to a live device or image, confirm the UI renders the session correctly

## Ongoing Maintenance

- edit shared workflow skills in this template repo, then run `update-skills` for downstream repos
- the scaffolded workflow docs, skills, and helper scripts are committed to the downstream repo's own git (no backup mirror)
- keep repo-specific `build-and-test` customizations local to the downstream repo
- if template changes should not overwrite a downstream specialization, rely on the existing scaffold behavior that preserves `build-and-test`
