---
name: project-auditor
description: "Run a full-repo audit covering naming conventions, folder structure, tech stack consistency, and a light architectural pass. Use when the user asks to audit, review consistency, or get a project health check."
---

# Project Auditor

Dispatch the `project-auditor` subagent against the current repository.

## Steps

1. Dispatch the `project-auditor` agent with the current repo root as context.
2. Wait for the audit report to complete.
3. Present the report to the user as-is — do not summarize or filter findings.

## Hard Rules

- Do not run this on a single file or diff — that is the `code-reviewer` agent's job.
- Do not truncate or editorialize the report. The user asked for the full audit.
