'use strict';

// Port of scripts/posix/bootstrap-new-repo.sh — initialize a new downstream repo:
// prereq check, git init, `bd` setup, scaffold, and stage-1 follow-up beads.

const path = require('path');

const { checkPrereqs } = require('../prereqs');
const { mkdirp } = require('../fsx');
const { runCapture, runInherit } = require('../proc');
const { scaffold } = require('../scaffold');
const { ensureStage1Beads } = require('../ensureStage1Beads');

function bootstrap(repoPath, prefix, options = {}) {
  const repo = path.resolve(repoPath);
  const withScreenshots = Boolean(options.withScreenshots);
  const withCodex = Boolean(options.withCodex);

  checkPrereqs({ requireCodex: withCodex });

  mkdirp(repo);

  const insideWorktree = runCapture('git', ['-C', repo, 'rev-parse', '--is-inside-work-tree']);
  if (insideWorktree.status !== 0) {
    runInherit('git', ['-C', repo, 'init']);
    console.log('Initialized git repository');
  }

  console.log(`Repo:    ${repo}`);
  console.log(`Prefix:  ${prefix}`);
  console.log(`AI:      ${withCodex ? 'Claude Code (primary) + Codex' : 'Claude Code (primary)'}`);

  runInherit('bd', ['init', '-p', prefix, '--server', '--skip-agents', '--skip-hooks'], {
    cwd: repo,
  });
  // Claude Code is the primary AI and is always set up. Codex is opt-in.
  runInherit('bd', ['setup', 'claude'], { cwd: repo });
  if (withCodex) {
    runInherit('bd', ['setup', 'codex'], { cwd: repo });
  }

  scaffold(repo, { withScreenshots, withCodex });
  ensureStage1Beads(repo);
  console.log('Bootstrap complete.');
}

module.exports = { bootstrap };
