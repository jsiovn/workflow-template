'use strict';

const fs = require('fs');
const path = require('path');

// `mkdir -p`
function mkdirp(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

// `rm -rf` — `force` swallows ENOENT, matching `rm -rf` on an absent path.
function rmrf(target) {
  fs.rmSync(target, { recursive: true, force: true });
}

// Non-recursive `rmdir`: remove the directory only if it is empty. Swallows
// ENOTEMPTY/ENOENT so it is a no-op on a populated or missing dir — this mirrors
// the `rmdir ... 2>/dev/null || true` prune of now-empty template script dirs.
function rmdirIfEmpty(dir) {
  try {
    fs.rmdirSync(dir);
  } catch (err) {
    if (err.code !== 'ENOTEMPTY' && err.code !== 'ENOENT' && err.code !== 'EEXIST') {
      throw err;
    }
  }
}

// `cp -R src dst` for a single file, preserving the source mode. `copyFileSync`
// does NOT preserve the executable bit, so we chmod afterwards — otherwise
// payload scripts (e.g. skills/*/scripts/*.sh) land non-executable downstream.
function copyFile(src, dst) {
  fs.copyFileSync(src, dst);
  fs.chmodSync(dst, fs.statSync(src).mode);
}

// `cp -R src dst` for a file or directory tree, preserving modes. Hand-rolled
// rather than `fs.cpSync` to preserve the exec bit on all Node >=18 without the
// experimental-warning noise `fs.cpSync` emits on 18–20.
function recursiveCopy(src, dst) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    mkdirp(dst);
    fs.chmodSync(dst, stat.mode);
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
      recursiveCopy(path.join(src, entry.name), path.join(dst, entry.name));
    }
  } else if (stat.isSymbolicLink()) {
    const link = fs.readlinkSync(src);
    rmrf(dst);
    fs.symlinkSync(link, dst);
  } else {
    copyFile(src, dst);
  }
}

// List immediate subdirectory names of `dir` (sorted), or [] if `dir` is absent.
function listDirs(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .sort();
}

// List immediate file names of `dir` (sorted), or [] if `dir` is absent.
function listFiles(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile())
    .map((e) => e.name)
    .sort();
}

module.exports = {
  mkdirp,
  rmrf,
  rmdirIfEmpty,
  copyFile,
  recursiveCopy,
  listDirs,
  listFiles,
};
