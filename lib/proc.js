'use strict';

const { spawnSync } = require('child_process');
const { which } = require('./which');

// Run a command by resolving its full path first (so Windows `.cmd`/`.exe`
// resolve under shell:false) and invoking with an argv array — never a shell —
// so multi-line arguments (e.g. `bd create --description <body>`) survive intact.
//
// Returns { status, stdout, stderr }. When the executable is not found, returns
// a synthetic status 127 instead of throwing, so callers that tolerate failure
// (e.g. git toplevel detection) can branch on it.
function runCapture(cmd, args, opts = {}) {
  const exe = which(cmd);
  if (!exe) {
    return { status: 127, stdout: '', stderr: `${cmd}: command not found\n` };
  }
  const res = spawnSync(exe, args, {
    cwd: opts.cwd,
    encoding: 'utf8',
    shell: false,
  });
  if (res.error) {
    return { status: res.status == null ? 1 : res.status, stdout: '', stderr: String(res.error) };
  }
  return {
    status: res.status == null ? 1 : res.status,
    stdout: res.stdout || '',
    stderr: res.stderr || '',
  };
}

// Run a command with inherited stdio (streams to the user's terminal). Throws
// if the command is missing or exits non-zero, mirroring `set -e`.
function runInherit(cmd, args, opts = {}) {
  const exe = which(cmd);
  if (!exe) {
    throw new Error(`${cmd} is required but was not found on PATH`);
  }
  const res = spawnSync(exe, args, {
    cwd: opts.cwd,
    stdio: 'inherit',
    shell: false,
  });
  if (res.error) {
    throw res.error;
  }
  if (res.status !== 0) {
    throw new Error(`${cmd} ${args.join(' ')} exited with status ${res.status}`);
  }
  return res.status;
}

module.exports = { runCapture, runInherit };
