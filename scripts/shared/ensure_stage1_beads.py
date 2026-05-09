#!/usr/bin/env python3
"""Ensure stage-1 bootstrap follow-up beads exist exactly once."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


BEADS = [
    {
        "title": "Specialize attach-web-screenshots for this repo",
        "description": """Stage-1 bootstrap installed the generic attach-web-screenshots skill.

Create the repo-specific stage-2 specialization as a standalone bead:

## Goal
- fill in the two project-specific gaps left as placeholders in the generic skill:
  1. the command to start the preview server (step 3)
  2. the auth endpoint and User shape for the fetch mock (step 4)
- keep the Codex and Claude copies aligned

## Requirements
- inspect `package.json` (scripts section) and any project README to find the correct preview command, port, and any required env flags (e.g. mock mode). Update step 3 in both skill copies with the concrete command
- inspect the project's auth API handler and User type to determine the correct endpoint path and response shape. Update step 4's `<auth-endpoint>` placeholder and the mock response object accordingly
- if the project has no auth-protected routes, remove step 4 entirely from both skill copies
- update `.codex/skills/attach-web-screenshots/SKILL.md`
- mirror the same changes in `.claude/skills/attach-web-screenshots/SKILL.md`

## Notes
- keep this bead independent; do not nest it under a feature epic
- do not hard-code credentials or secrets — the fetch mock only needs a valid shape, not real values
""",
    },
    {
        "title": "Specialize build-and-test for this repo",
        "description": """Stage-1 bootstrap installed the generic build-and-test skill.

Create the repo-specific stage-2 specialization as a standalone bead:

## Goal
- replace the generic stage-1 validation flow with project-specific build, run, and smoke-test steps
- keep the Codex and Claude build-and-test skills aligned

## Requirements
- update `.codex/skills/build-and-test/SKILL.md`
- mirror the same behavior in `.claude/skills/build-and-test/SKILL.md`
- document any stable setup, launch, or verification steps the skill depends on

## Notes
- keep this bead independent; do not nest it under the first feature epic
- later epics may depend on this if stronger verification is needed
""",
    },
]


def run(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Ensure stage-1 bootstrap follow-up beads exist")
    parser.add_argument("repo", nargs="?", default=".", help="Repo root")
    args = parser.parse_args()

    repo = Path(args.repo).resolve()

    # Include closed beads AND override the default --limit=50 so a completed
    # stage-1 bead does not get re-created as a duplicate on every update-skills
    # run. Without --limit=0 any repo with >50 issues silently loses older beads
    # from the existing-title set.
    list_result = run(repo, "bd", "list", "--all", "--limit", "0", "--json")
    if list_result.returncode != 0:
        sys.stderr.write(list_result.stderr)
        return list_result.returncode

    try:
        issues = json.loads(list_result.stdout or "[]")
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Failed to parse `bd list --json`: {exc}\n")
        return 1

    existing_titles = {
        issue.get("title"): issue.get("id")
        for issue in issues
        if isinstance(issue, dict) and issue.get("title")
    }

    created_any = False
    for bead in BEADS:
        title = bead["title"]
        if title in existing_titles:
            print(f"Stage-1 follow-up bead already exists: {existing_titles[title]}")
            continue

        create_result = run(
            repo,
            "bd",
            "create",
            "--type",
            "chore",
            "--priority",
            "2",
            "--labels",
            "bootstrap,stage-2",
            "--title",
            title,
            "--description",
            bead["description"],
        )
        if create_result.returncode != 0:
            sys.stderr.write(create_result.stderr)
            return create_result.returncode

        created_any = True
        sys.stdout.write(create_result.stdout)

    if not created_any:
        print("All stage-1 follow-up beads already exist.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
