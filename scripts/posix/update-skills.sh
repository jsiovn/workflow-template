#!/usr/bin/env bash
set -euo pipefail

with_screenshots=0
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-screenshots) with_screenshots=1; shift;;
    *) positional+=("$1"); shift;;
  esac
done
set -- ${positional[@]+"${positional[@]}"}

if [[ $# -lt 1 ]]; then
  printf 'usage: %s [--with-screenshots] <repo-path>\n' "$0" >&2
  exit 1
fi

repo_path="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

scaffold_args=()
if [[ "${with_screenshots}" == "1" ]]; then
  scaffold_args+=(--with-screenshots)
fi

bash "${script_dir}/check-prereqs.sh"
bash "${script_dir}/scaffold-repo-files.sh" ${scaffold_args[@]+"${scaffold_args[@]}"} "${repo_path}" ""

python "${script_dir}/../shared/ensure_stage1_beads.py" "${repo_path}"

printf 'Skills synced to %s\n' "${repo_path}"
