#!/usr/bin/env python3
"""Ensure stage-1 bootstrap follow-up beads exist exactly once."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


def _skill_paths(skill: str, codex: bool) -> str:
    """Render the skill-update instructions, mentioning Codex only when present.

    Claude Code is the primary AI; the Codex copy only exists in repos
    bootstrapped (or updated) with --with-codex, so the stage-2 bead should not
    tell the executor to edit a `.codex/` path that does not exist.
    """
    if codex:
        return (
            f"- update `.claude/skills/{skill}/SKILL.md`\n"
            f"- mirror the same changes in `.codex/skills/{skill}/SKILL.md` (keep the two copies aligned)"
        )
    return f"- update `.claude/skills/{skill}/SKILL.md`"


def screenshots_bead(codex: bool) -> dict:
    align = "\n- keep the Claude and Codex copies aligned" if codex else ""
    both = "both skill copies" if codex else "the skill"
    return {
        "title": "Specialize attach-web-screenshots for this repo",
        "description": f"""Stage-1 bootstrap installed the generic attach-web-screenshots skill.

Create the repo-specific stage-2 specialization as a standalone bead:

## Goal
- fill in the two project-specific gaps left as placeholders in the generic skill:
  1. the command to start the preview server (step 3)
  2. the auth endpoint and User shape for the fetch mock (step 4){align}

## Requirements
- inspect `package.json` (scripts section) and any project README to find the correct preview command, port, and any required env flags (e.g. mock mode). Update step 3 in {both} with the concrete command
- inspect the project's auth API handler and User type to determine the correct endpoint path and response shape. Update step 4's `<auth-endpoint>` placeholder and the mock response object accordingly
- if the project has no auth-protected routes, remove step 4 entirely from {both}
{_skill_paths("attach-web-screenshots", codex)}

## Notes
- keep this bead independent; do not nest it under a feature epic
- do not hard-code credentials or secrets — the fetch mock only needs a valid shape, not real values
""",
    }


def build_and_test_bead(codex: bool) -> dict:
    align = "\n- keep the Claude and Codex build-and-test skills aligned" if codex else ""
    return {
        "title": "Specialize build-and-test for this repo",
        "description": f"""Stage-1 bootstrap installed the generic build-and-test skill.

Create the repo-specific stage-2 specialization as a standalone bead:

## Goal
- replace the generic stage-1 validation flow with project-specific build, run, and smoke-test steps{align}

## Requirements
{_skill_paths("build-and-test", codex)}
- document any stable setup, launch, or verification steps the skill depends on

## Notes
- keep this bead independent; do not nest it under the first feature epic
- later epics may depend on this if stronger verification is needed
""",
    }


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

    # Claude Code is the primary AI; Codex is opt-in. Detect whether this repo
    # has a Codex install so the bead text only references `.codex/` paths that
    # actually exist.
    codex = (repo / ".codex" / "skills").exists() or (repo / ".codex" / "agents").exists()

    beads = [build_and_test_bead(codex)]
    # Only create the screenshot specialization bead if the screenshot skill
    # was opted into during bootstrap (scaffold installs it under either
    # provider dir). This keeps the stage-2 backlog scoped to what's actually
    # installed.
    if (repo / ".codex" / "skills" / "attach-web-screenshots").exists() or \
            (repo / ".claude" / "skills" / "attach-web-screenshots").exists():
        beads.insert(0, screenshots_bead(codex))

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
    for bead in beads:
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
