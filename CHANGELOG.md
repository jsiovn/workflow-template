# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-29

First npm release. The scaffolder is now a single cross-platform Node CLI —
`agent-workflow-beads` — installed with `npm install -g`. No more cloning the
template to a stable path, maintaining shell aliases, or running per-OS scripts.

### Added

- `agent-workflow-beads` CLI with `bootstrap`, `update`, and `check` subcommands
  (`bin/cli.js`, `lib/`). Same command on macOS, Linux, and Windows.
- `npm install -g agent-workflow-beads` as the single install path. Bundled assets
  (`skills/`, `agents/`, `templates/`) ship via the `package.json` `files` allowlist
  and resolve relative to the install location, independent of the working directory.
- Consolidated `docs/INSTALL.md` covering Node.js, `bd`, `dolt`, and the CLI.

### Changed

- Ported all scaffolding logic from the POSIX/PowerShell scripts and Python helpers
  to pure Node with **zero runtime dependencies** (`lib/scaffold.js`,
  `lib/manageInstructions.js`, `lib/manageGitignore.js`, `lib/ensureStage1Beads.js`,
  `lib/prereqs.js`, `lib/proc.js`, `lib/which.js`, `lib/fsx.js`). Behavior toward
  downstream repos is unchanged — managed-block, `.gitignore`, and bead semantics are
  byte-for-byte identical to the previous implementation.
- `templates/.beads/.gitignore` is stored in-package as `templates/.beads/beads.gitignore`
  (npm refuses to pack a file basenamed `.gitignore`) and written to the dotted name on scaffold.
- Rewrote `README.md` and the docs for the npm install flow; dropped the
  clone/alias/Python instructions.

### Removed

- `scripts/posix/`, `scripts/windows/`, `scripts/shared/` — logic now lives in `lib/`.
- Per-OS install guides `docs/INSTALL-MACOS.md`, `docs/INSTALL-UBUNTU.md`,
  `docs/INSTALL-WINDOWS.md` (collapsed into `docs/INSTALL.md`).
- The `python3` prerequisite.

### Requirements

- Node.js >= 18; `git`, `bd`, and `dolt` on `PATH`.

[1.0.0]: https://github.com/jsiovn/workflow-template/releases/tag/v1.0.0
