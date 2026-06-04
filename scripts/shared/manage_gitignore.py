#!/usr/bin/env python3
"""Maintain the managed ``.gitignore`` block in a downstream repo.

The workflow surface (skills, agents, docs, helper scripts) is committed to each
downstream repo's own git, so it travels with feature branches and
``git worktree`` checkouts. Machine-local runtime artifacts, plus the per-session
plan files under ``docs/plans/`` (local scratch the planner/executor writes per
bead — not part of the committed workflow surface), stay ignored. This module
writes that small managed block between the BEGIN/END markers and is idempotent:
re-running it replaces the previous block in place.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


IGNORE_BLOCK_START = "# BEGIN TEMPLATE AGENT WORKFLOW LOCAL-ONLY"
IGNORE_BLOCK_END = "# END TEMPLATE AGENT WORKFLOW LOCAL-ONLY"
LEGACY_IGNORE_HEADER = "# Local agent workflow assets"

# Paths that must never be committed downstream: machine-local runtime artifacts,
# plus the per-session plan files under docs/plans/ (local scratch the
# planner/executor writes per bead — not part of the committed workflow surface).
# Everything else the template scaffolds is tracked in git. Older template
# versions listed every skill/agent/doc path here; ensure_ignore_block() strips
# the previous block before rewriting, so those stale entries (and any standalone
# docs/plans/ line a downstream added by hand) are folded into this block on the
# next run.
IGNORE_ENTRIES = (
    ".beads-credential-key",
    ".beads/interactions.jsonl",
    ".bv/",
    ".dolt/",
    "*.db",
    "scripts/shared/__pycache__/",
    "docs/plans/",
)


def resolve_repo_root(path: str | Path) -> Path:
    candidate = Path(path).expanduser().resolve()
    try:
        result = subprocess.run(
            ["git", "-C", str(candidate), "rev-parse", "--show-toplevel"],
            check=True,
            text=True,
            capture_output=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return candidate
    return Path(result.stdout.strip()).resolve()


def _strip_ignore_block(content: str) -> str:
    start = content.find(IGNORE_BLOCK_START)
    end = content.find(IGNORE_BLOCK_END)
    if start == -1 or end == -1 or end < start:
        return content
    end += len(IGNORE_BLOCK_END)
    before = content[:start].rstrip("\r\n")
    after = content[end:].lstrip("\r\n")
    if before and after:
        return before + "\n\n" + after
    return before or after


def _squash_blank_runs(lines: list[str]) -> list[str]:
    squashed: list[str] = []
    blank = False
    for line in lines:
        if line.strip():
            squashed.append(line.rstrip())
            blank = False
            continue
        if not blank:
            squashed.append("")
        blank = True
    while squashed and squashed[0] == "":
        squashed.pop(0)
    while squashed and squashed[-1] == "":
        squashed.pop()
    return squashed


def ensure_ignore_block(repo_root: Path) -> bool:
    target = repo_root / ".gitignore"
    content = target.read_text(encoding="utf-8") if target.exists() else ""
    stripped = _strip_ignore_block(content)

    filtered_lines: list[str] = []
    managed = set(IGNORE_ENTRIES)
    for line in stripped.splitlines():
        raw = line.rstrip("\r")
        if raw == LEGACY_IGNORE_HEADER:
            continue
        if raw in managed:
            continue
        filtered_lines.append(raw)
    filtered_lines = _squash_blank_runs(filtered_lines)

    block_lines = [
        IGNORE_BLOCK_START,
        *IGNORE_ENTRIES,
        IGNORE_BLOCK_END,
    ]

    merged = "\n".join(filtered_lines + ([""] if filtered_lines else []) + block_lines) + "\n"
    if merged == content:
        return False
    target.write_text(merged, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage the downstream .gitignore workflow block")
    subparsers = parser.add_subparsers(dest="command", required=True)

    ensure_ignore = subparsers.add_parser(
        "ensure-ignore",
        help="Install or refresh the managed workflow ignore block in the downstream repo .gitignore",
    )
    ensure_ignore.add_argument("--repo", default=".", help="Downstream repo path (default: current directory)")
    ensure_ignore.add_argument("--json", action="store_true")

    args = parser.parse_args()
    if args.command == "ensure-ignore":
        repo_root = resolve_repo_root(args.repo)
        changed = ensure_ignore_block(repo_root)
        if args.json:
            print(json.dumps({"repo_root": str(repo_root), "changed": changed}))
        else:
            state = "updated" if changed else "already current"
            print(f"Managed workflow ignore block {state} in {repo_root / '.gitignore'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
