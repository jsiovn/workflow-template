'use strict';

const fs = require('fs');
const path = require('path');

const isWindows = process.platform === 'win32';

function isExecutableFile(p) {
  try {
    const stat = fs.statSync(p);
    if (!stat.isFile()) return false;
    if (isWindows) return true; // PATHEXT governs executability on Windows
    return (stat.mode & 0o111) !== 0;
  } catch {
    return false;
  }
}

// Resolve an executable to its full path by scanning PATH (honoring PATHEXT on
// Windows so bare `bd` matches `bd.cmd`/`bd.exe`). Returns the absolute path or
// null. Passing the resolved path to spawnSync({ shell: false }) is what keeps
// `.cmd` resolution working on Windows AND keeps argv free of shell quoting.
function which(cmd) {
  // An explicit path (contains a separator) is used as-is if executable.
  if (cmd.includes('/') || cmd.includes('\\')) {
    return isExecutableFile(cmd) ? path.resolve(cmd) : null;
  }

  const pathEntries = (process.env.PATH || '').split(path.delimiter).filter(Boolean);
  const exts = isWindows
    ? (process.env.PATHEXT || '.COM;.EXE;.BAT;.CMD').split(';').filter(Boolean)
    : [''];

  for (const dir of pathEntries) {
    for (const ext of exts) {
      const candidate = path.join(dir, cmd + ext);
      if (isExecutableFile(candidate)) {
        return candidate;
      }
    }
  }
  return null;
}

module.exports = { which, isWindows };
