'use strict';

const { bootstrap } = require('./commands/bootstrap');
const { update } = require('./commands/update');
const { checkPrereqs } = require('./prereqs');

const pkg = require('../package.json');

const USAGE = `agent-workflow-beads — scaffold the Beads-backed planner → executor workflow into any repo

Usage:
  agent-workflow-beads bootstrap <repo> <prefix> [options]   Initialize a downstream repo
  agent-workflow-beads update <repo> [options]               Refresh the workflow surface
  agent-workflow-beads check [--with-codex]                  Verify required tools are installed

Options:
  --with-codex          Also scaffold the Codex surface (.codex/ skills + agents, AGENTS.md)
  --with-screenshots    Also install the attach-web-screenshots skill + cleanup CI workflow
  -h, --help            Show this help
  -v, --version         Show the installed version

Prerequisites on PATH: git, bd, dolt`;

// Split argv into flags and positionals, mirroring the case-loop in the old
// shell scripts (anything not a recognized flag is positional).
function parseArgs(argv) {
  const positional = [];
  const flags = { withScreenshots: false, withCodex: false, help: false, version: false };
  for (const arg of argv) {
    switch (arg) {
      case '--with-screenshots':
        flags.withScreenshots = true;
        break;
      case '--with-codex':
        flags.withCodex = true;
        break;
      case '-h':
      case '--help':
        flags.help = true;
        break;
      case '-v':
      case '--version':
        flags.version = true;
        break;
      default:
        positional.push(arg);
    }
  }
  return { positional, flags };
}

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}

function main(argv) {
  // Never let `bd` block on an interactive prompt when driven by this CLI — e.g.
  // init's "Contributing to someone else's repo?" (defaults to maintainer / "N")
  // and "Enable auto-export?" (bootstrap disables auto-export explicitly).
  process.env.BD_NON_INTERACTIVE = '1';

  const { positional, flags } = parseArgs(argv);

  if (flags.version) {
    console.log(pkg.version);
    return;
  }
  if (flags.help || positional.length === 0) {
    console.log(USAGE);
    if (positional.length === 0 && !flags.help) process.exitCode = 1;
    return;
  }

  const [command, ...rest] = positional;
  const opts = { withScreenshots: flags.withScreenshots, withCodex: flags.withCodex };

  try {
    switch (command) {
      case 'bootstrap': {
        if (rest.length < 2) {
          return fail(
            'usage: agent-workflow-beads bootstrap [--with-screenshots] [--with-codex] <repo-path> <prefix>',
          );
        }
        bootstrap(rest[0], rest[1], opts);
        break;
      }
      case 'update': {
        if (rest.length < 1) {
          return fail(
            'usage: agent-workflow-beads update [--with-screenshots] [--with-codex] <repo-path>',
          );
        }
        update(rest[0], opts);
        break;
      }
      case 'check': {
        checkPrereqs({ requireCodex: flags.withCodex });
        break;
      }
      default:
        return fail(`unknown command: ${command}\n\n${USAGE}`);
    }
  } catch (err) {
    fail(err && err.message ? err.message : String(err));
  }
}

module.exports = { main, parseArgs };
