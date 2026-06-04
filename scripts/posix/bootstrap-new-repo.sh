#!/usr/bin/env bash
set -euo pipefail

with_screenshots=0
with_codex=0
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-screenshots) with_screenshots=1; shift;;
    --with-codex) with_codex=1; shift;;
    *) positional+=("$1"); shift;;
  esac
done
set -- ${positional[@]+"${positional[@]}"}

if [[ $# -lt 2 ]]; then
  printf 'usage: %s [--with-screenshots] [--with-codex] <repo-path> <prefix>\n' "$0" >&2
  exit 1
fi

repo_path="$1"
prefix="$2"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

scaffold_args=()
if [[ "${with_screenshots}" == "1" ]]; then
  scaffold_args+=(--with-screenshots)
fi
if [[ "${with_codex}" == "1" ]]; then
  scaffold_args+=(--with-codex)
fi

REQUIRE_CODEX="${with_codex}" bash "${script_dir}/check-prereqs.sh"

mkdir -p "${repo_path}"

if ! git -C "${repo_path}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "${repo_path}" init >/dev/null
  printf 'Initialized git repository\n'
fi

printf 'Repo:    %s\n' "${repo_path}"
printf 'Prefix:  %s\n' "${prefix}"
if [[ "${with_codex}" == "1" ]]; then
  printf 'AI:      Claude Code (primary) + Codex\n'
else
  printf 'AI:      Claude Code (primary)\n'
fi

(
  cd "${repo_path}"
  bd init -p "${prefix}" --server --skip-agents --skip-hooks
  # Claude Code is the primary AI and is always set up. Codex is opt-in.
  bd setup claude
  if [[ "${with_codex}" == "1" ]]; then
    bd setup codex
  fi
)

bash "${script_dir}/scaffold-repo-files.sh" ${scaffold_args[@]+"${scaffold_args[@]}"} "${repo_path}" "${prefix}"
python "${script_dir}/../shared/ensure_stage1_beads.py" "${repo_path}"
printf 'Bootstrap complete.\n'
