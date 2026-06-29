'use strict';

// Port of scripts/posix/check-prereqs.sh. Python is no longer required (the
// scaffold logic is native Node now), so it is not checked.

const { which } = require('./which');

function checkPrereqs(options = {}) {
  const requireCodex = Boolean(options.requireCodex);
  const missing = [];

  for (const cmd of ['git', 'bd', 'dolt']) {
    if (!which(cmd)) missing.push(cmd);
  }

  if (requireCodex && !which('codex')) {
    process.stderr.write('warning: codex is not on PATH\n');
  }

  if (missing.length > 0) {
    process.stderr.write(`missing required commands: ${missing.join(' ')}\n`);
    throw new Error(`missing required commands: ${missing.join(' ')}`);
  }

  console.log('Required commands found: git, bd, dolt');
}

module.exports = { checkPrereqs };
