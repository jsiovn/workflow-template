'use strict';

// Port of scripts/shared/manage_instructions.py — manage template-owned
// AGENTS/CLAUDE instruction blocks. The legacy block/snippet definitions and the
// strip/upsert semantics are reproduced verbatim so that already-scaffolded
// downstreams have their stale blocks scrubbed on the next `update`.

const fs = require('fs');

const LEGACY_BLOCKS = [
  ['<!-- BEGIN BEADS INTEGRATION -->', '<!-- END BEADS INTEGRATION -->'],
  ['<!-- BEGIN BEADS INTEGRATION v:', '<!-- END BEADS INTEGRATION -->'],
  ['<!-- br-agent-instructions-v', '<!-- end-br-agent-instructions -->'],
  ['<!-- bv-agent-instructions-v', '<!-- end-bv-agent-instructions -->'],
  ['<!-- BEGIN TEMPLATE BR WORKFLOW -->', '<!-- END TEMPLATE BR WORKFLOW -->'],
];

// Build a "## Workflow Guide" legacy snippet. The four historical variants differ
// only by whether the planner-research and/or plan-debate lines are present.
function workflowGuide({ plannerResearch, planDebate }) {
  const lines = [
    '## Workflow Guide',
    '',
    'Use `BEADS_WORKFLOW.md` for the current planner, manual executor, and swarm executor flow.',
    'All workflow skills are repo-local: Codex skills live under `.codex/skills/`, Claude skills under `.claude/skills/`.',
    'Preferred entry points are `plan-beads`, `validate-beads`, `start-epic-worktree`, `swarm-epic`, and `executor-once`.',
  ];
  if (plannerResearch) {
    lines.push(
      'Use `planner-research` only inside a planner session when `brainstorming` still leaves material factual uncertainty.',
    );
  }
  if (planDebate) {
    lines.push(
      'Use `plan-debate` before `beads-planner` when the user asks for extra scrutiny or the plan is risky.',
    );
  }
  lines.push(
    'Use `executor-loop` or `executor-loop-epic` for sequential autonomy when swarm coordination is not needed.',
    'The executor test skill lives at `.codex/skills/build-and-test/SKILL.md`; use it between implementation and final verification.',
    'Use `scripts/windows/start-epic-worktree.ps1` or `scripts/posix/start-epic-worktree.sh` to prepare epic worktrees.',
    'Use `scripts/windows/workflow-status.ps1` or `scripts/posix/workflow-status.sh` to inspect `.beads/workflow/` plus the shared control plane.',
    'Use `scripts/windows/agent-mail.ps1` or `scripts/posix/agent-mail.sh` for shared epic locks, reservations, and mailbox inspection.',
    '',
    'Important:',
    '',
    '- keep this section outside the Beads-managed `AGENTS.md` block',
    '- do not edit inside `<!-- BEGIN BEADS INTEGRATION --> ... <!-- END BEADS INTEGRATION -->`',
  );
  return lines.join('\n') + '\n';
}

const LEGACY_SNIPPETS = [
  '## Issue Tracking\n\nUses `bd` (beads/Dolt). See `AGENTS.md` for repo rules and `BEADS_WORKFLOW.md` for the planner/executor workflow. Never use markdown TODOs or alternate task trackers.\n',
  workflowGuide({ plannerResearch: false, planDebate: true }),
  workflowGuide({ plannerResearch: true, planDebate: true }),
  workflowGuide({ plannerResearch: false, planDebate: false }),
  workflowGuide({ plannerResearch: true, planDebate: false }),
];

function stripBlock(content, startMarker, endMarker) {
  for (;;) {
    const start = content.indexOf(startMarker);
    if (start === -1) return content;
    const endIdx = content.indexOf(endMarker, start);
    if (endIdx === -1) return content;
    const end = endIdx + endMarker.length;
    const before = content.slice(0, start).replace(/[\r\n]+$/, '');
    const after = content.slice(end).replace(/^[\r\n]+/, '');
    if (before && after) {
      content = before + '\n\n' + after;
    } else {
      content = before || after;
    }
  }
}

function normalizeLegacy(content) {
  for (const [start, end] of LEGACY_BLOCKS) {
    content = stripBlock(content, start, end);
  }
  for (const snippet of LEGACY_SNIPPETS) {
    content = content.split(snippet).join('');
  }
  return content.trim();
}

function parseMarkers(snippet) {
  const lines = snippet.split(/\r?\n/).filter((line) => line.trim());
  const start = lines.find((line) => line.startsWith('<!-- BEGIN '));
  const end = lines.find((line) => line.startsWith('<!-- END '));
  if (!start || !end) {
    throw new Error('snippet must contain <!-- BEGIN ... --> and <!-- END ... --> markers');
  }
  return [start, end];
}

function upsert(targetPath, snippetPath) {
  const snippet = fs.readFileSync(snippetPath, 'utf8').trim();
  const [startMarker, endMarker] = parseMarkers(snippet);
  let merged;
  if (fs.existsSync(targetPath)) {
    let content = normalizeLegacy(fs.readFileSync(targetPath, 'utf8'));
    content = stripBlock(content, startMarker, endMarker).trim();
    merged = content ? `${content}\n\n${snippet}` : snippet;
  } else {
    merged = snippet;
  }
  fs.writeFileSync(targetPath, merged.replace(/\s+$/, '') + '\n', 'utf8');
}

module.exports = { upsert, stripBlock, normalizeLegacy, parseMarkers, LEGACY_SNIPPETS };
