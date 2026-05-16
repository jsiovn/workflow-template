#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <repo-path> [prefix]\n' "$0" >&2
  exit 1
fi

repo_path="$1"
prefix="${2:-}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
template_root="$(cd "${script_dir}/../.." && pwd)"

python_cmd=""
if command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  python_cmd="python"
else
  printf 'python is required for scaffold-repo-files.sh\n' >&2
  exit 1
fi

mkdir -p "${repo_path}"

cp "${template_root}/templates/BEADS_WORKFLOW.md" "${repo_path}/BEADS_WORKFLOW.md"
printf 'Copied BEADS_WORKFLOW.md\n'

mkdir -p "${repo_path}/.beads"
cp "${template_root}/templates/PRIME.md" "${repo_path}/.beads/PRIME.md"
cp "${template_root}/templates/.beads/.gitignore" "${repo_path}/.beads/.gitignore"
cp "${template_root}/templates/.beads/README.md" "${repo_path}/.beads/README.md"
printf 'Copied .beads/PRIME.md\n'
printf 'Copied .beads/.gitignore\n'
printf 'Copied .beads/README.md\n'

mkdir -p "${repo_path}/.codex/skills"
if [[ ! -d "${repo_path}/.codex/skills/build-and-test" ]]; then
  cp -R "${template_root}/templates/.codex/skills/build-and-test" "${repo_path}/.codex/skills/build-and-test"
  printf 'Copied Codex build-and-test skill\n'
else
  printf 'Preserved existing Codex build-and-test skill\n'
fi
if [[ ! -d "${repo_path}/.codex/skills/attach-web-screenshots" ]]; then
  cp -R "${template_root}/templates/.codex/skills/attach-web-screenshots" "${repo_path}/.codex/skills/attach-web-screenshots"
  printf 'Copied Codex attach-web-screenshots skill\n'
else
  printf 'Preserved existing Codex attach-web-screenshots skill\n'
fi

find "${template_root}/skills" -mindepth 1 -maxdepth 1 -type d | while read -r src; do
  name="$(basename "${src}")"
  dst="${repo_path}/.codex/skills/${name}"
  rm -rf "${dst}"
  cp -R "${src}" "${dst}"
  printf 'Copied Codex skill: %s\n' "${name}"
done
rm -rf "${repo_path}/.codex/skills/plan-debate"
rm -rf "${repo_path}/.codex/skills/plan-critic"
rm -rf "${repo_path}/.codex/skills/start-epic-worktree"
rm -rf "${repo_path}/.codex/skills/game-action-harness"
rm -rf "${repo_path}/.codex/skills/target-runtime-exec"
rm -rf "${repo_path}/.codex/skills/executor-once"
rm -rf "${repo_path}/.codex/skills/executor-loop"
rm -rf "${repo_path}/.codex/skills/executor-loop-epic"
rm -rf "${repo_path}/.codex/skills/swarm-epic"
rm -rf "${repo_path}/.codex/skills/review-epic"
rm -rf "${repo_path}/.codex/skills/execute-bead-worker"
rm -rf "${repo_path}/.codex/skills/test-on-android-device"
if [[ -d "${template_root}/templates/.codex/skills" ]]; then
  find "${template_root}/templates/.codex/skills" -mindepth 1 -maxdepth 1 -type d | while read -r src; do
    name="$(basename "${src}")"
    if [[ "${name}" == "build-and-test" || "${name}" == "attach-web-screenshots" ]]; then
      continue
    fi
    dst="${repo_path}/.codex/skills/${name}"
    rm -rf "${dst}"
    cp -R "${src}" "${dst}"
    printf 'Copied Codex provider skill: %s\n' "${name}"
  done
fi

mkdir -p "${repo_path}/.claude/skills"
if [[ ! -d "${repo_path}/.claude/skills/build-and-test" ]]; then
  cp -R "${template_root}/templates/.codex/skills/build-and-test" "${repo_path}/.claude/skills/build-and-test"
  printf 'Copied Claude build-and-test skill\n'
else
  printf 'Preserved existing Claude build-and-test skill\n'
fi
if [[ ! -d "${repo_path}/.claude/skills/attach-web-screenshots" ]]; then
  cp -R "${template_root}/templates/.codex/skills/attach-web-screenshots" "${repo_path}/.claude/skills/attach-web-screenshots"
  printf 'Copied Claude attach-web-screenshots skill\n'
else
  printf 'Preserved existing Claude attach-web-screenshots skill\n'
fi

find "${template_root}/skills" -mindepth 1 -maxdepth 1 -type d | while read -r src; do
  name="$(basename "${src}")"
  dst="${repo_path}/.claude/skills/${name}"
  rm -rf "${dst}"
  cp -R "${src}" "${dst}"
  printf 'Copied Claude skill: %s\n' "${name}"
done
rm -rf "${repo_path}/.claude/skills/plan-debate"
rm -rf "${repo_path}/.claude/skills/plan-critic"
rm -rf "${repo_path}/.claude/skills/start-epic-worktree"
rm -rf "${repo_path}/.claude/skills/game-action-harness"
rm -rf "${repo_path}/.claude/skills/target-runtime-exec"
rm -rf "${repo_path}/.claude/skills/executor-once"
rm -rf "${repo_path}/.claude/skills/executor-loop"
rm -rf "${repo_path}/.claude/skills/executor-loop-epic"
rm -rf "${repo_path}/.claude/skills/swarm-epic"
rm -rf "${repo_path}/.claude/skills/review-epic"
rm -rf "${repo_path}/.claude/skills/execute-bead-worker"
rm -rf "${repo_path}/.claude/skills/test-on-android-device"
if [[ -d "${template_root}/templates/.claude/skills" ]]; then
  find "${template_root}/templates/.claude/skills" -mindepth 1 -maxdepth 1 -type d | while read -r src; do
    name="$(basename "${src}")"
    if [[ "${name}" == "build-and-test" ]]; then
      continue
    fi
    dst="${repo_path}/.claude/skills/${name}"
    rm -rf "${dst}"
    cp -R "${src}" "${dst}"
    printf 'Copied Claude provider skill: %s\n' "${name}"
  done
fi

# Shared agents — copied to both providers (same pattern as skills/).
if [[ -d "${template_root}/agents" ]]; then
  mkdir -p "${repo_path}/.codex/agents" "${repo_path}/.claude/agents"
  find "${template_root}/agents" -mindepth 1 -maxdepth 1 -type f | while read -r src; do
    name="$(basename "${src}")"
    cp "${src}" "${repo_path}/.codex/agents/${name}"
    cp "${src}" "${repo_path}/.claude/agents/${name}"
    printf 'Copied shared agent: %s\n' "${name}"
  done
fi
# Provider-specific agent overrides (applied after shared, so they win).
if [[ -d "${template_root}/templates/.codex/agents" ]]; then
  mkdir -p "${repo_path}/.codex/agents"
  find "${template_root}/templates/.codex/agents" -mindepth 1 -maxdepth 1 -type f | while read -r src; do
    name="$(basename "${src}")"
    cp "${src}" "${repo_path}/.codex/agents/${name}"
    printf 'Copied Codex agent override: %s\n' "${name}"
  done
fi
if [[ -d "${template_root}/templates/.claude/agents" ]]; then
  mkdir -p "${repo_path}/.claude/agents"
  find "${template_root}/templates/.claude/agents" -mindepth 1 -maxdepth 1 -type f | while read -r src; do
    name="$(basename "${src}")"
    cp "${src}" "${repo_path}/.claude/agents/${name}"
    printf 'Copied Claude agent override: %s\n' "${name}"
  done
fi

mkdir -p "${repo_path}/scripts/windows" "${repo_path}/scripts/posix" "${repo_path}/scripts/shared"
cp "${template_root}/scripts/windows/restore-workflow-backup.ps1" "${repo_path}/scripts/windows/restore-workflow-backup.ps1"
cp "${template_root}/scripts/windows/sync-workflow-backup.ps1" "${repo_path}/scripts/windows/sync-workflow-backup.ps1"
rm -f "${repo_path}/scripts/windows/shared-beads.ps1"
rm -f "${repo_path}/scripts/windows/start-epic-worktree.ps1"
rm -f "${repo_path}/scripts/windows/workflow-status.ps1"
rm -f "${repo_path}/scripts/windows/agent-mail.ps1"
rm -f "${repo_path}/scripts/windows/migrate-downstream-to-bd.ps1"
rm -f "${repo_path}/scripts/windows/migrate-downstream-to-workflow-backup.ps1"
cp "${template_root}/scripts/posix/restore-workflow-backup.sh" "${repo_path}/scripts/posix/restore-workflow-backup.sh"
cp "${template_root}/scripts/posix/sync-workflow-backup.sh" "${repo_path}/scripts/posix/sync-workflow-backup.sh"
rm -f "${repo_path}/scripts/posix/shared-beads.sh"
rm -f "${repo_path}/scripts/posix/start-epic-worktree.sh"
rm -f "${repo_path}/scripts/posix/workflow-status.sh"
rm -f "${repo_path}/scripts/posix/agent-mail.sh"
rm -f "${repo_path}/scripts/posix/migrate-downstream-to-bd.sh"
rm -f "${repo_path}/scripts/posix/migrate-downstream-to-workflow-backup.sh"
chmod +x "${repo_path}/scripts/posix/restore-workflow-backup.sh" "${repo_path}/scripts/posix/sync-workflow-backup.sh"
cp "${template_root}/scripts/shared/manage_instructions.py" "${repo_path}/scripts/shared/manage_instructions.py"
rm -f "${repo_path}/scripts/shared/run_plan_critic.py"
cp "${template_root}/scripts/shared/sync_workflow_backup.py" "${repo_path}/scripts/shared/sync_workflow_backup.py"
cp "${template_root}/scripts/shared/workflow_backup.py" "${repo_path}/scripts/shared/workflow_backup.py"
rm -f "${repo_path}/scripts/shared/shared_beads.py"
rm -f "${repo_path}/scripts/shared/start_epic_worktree.py"
rm -f "${repo_path}/scripts/shared/harness.py"
rm -rf "${repo_path}/scripts/shared/harness_backends"
rm -f "${repo_path}/scripts/shared/target_runtime.py"
rm -f "${repo_path}/scripts/shared/agent_mail.py"
rm -f "${repo_path}/scripts/shared/migrate_br_to_bd.py"
rm -f "${repo_path}/scripts/shared/migrate_downstream_to_workflow_backup.py"
rm -rf "${repo_path}/.beads/workflow"
printf 'Copied script helpers\n'

mkdir -p "${repo_path}/docs"
cp "${template_root}/docs/TROUBLESHOOTING.md" "${repo_path}/docs/TROUBLESHOOTING.md"
printf 'Copied docs/TROUBLESHOOTING.md\n'

mkdir -p "${repo_path}/.github/workflows"
cp "${template_root}/templates/.github/workflows/cleanup-screenshots.yml" "${repo_path}/.github/workflows/cleanup-screenshots.yml"
printf 'Copied .github/workflows/cleanup-screenshots.yml\n'

"${python_cmd}" "${template_root}/scripts/shared/sync_workflow_backup.py" ensure-ignore --repo "${repo_path}"
printf 'Updated .gitignore managed workflow block\n'

"${python_cmd}" "${template_root}/scripts/shared/manage_instructions.py" "${repo_path}/AGENTS.md" "${template_root}/templates/AGENTS.snippet.md"
"${python_cmd}" "${template_root}/scripts/shared/manage_instructions.py" "${repo_path}/CLAUDE.md" "${template_root}/templates/CLAUDE.snippet.md"
printf 'Updated AGENTS.md managed block\n'
printf 'Updated CLAUDE.md managed block\n'
