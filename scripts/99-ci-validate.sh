#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

echo "==> Bash syntax checks"
while IFS= read -r script_path; do
  bash -n "${script_path}"
done < <(find scripts -maxdepth 1 -type f -name '*.sh' | sort)

echo "==> Executable bit checks"
while IFS= read -r script_path; do
  if [[ ! -x "${script_path}" ]]; then
    echo "ERROR: expected executable script: ${script_path}" >&2
    exit 1
  fi
done < <(find scripts -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort)

echo "==> Docs script-reference checks"
while IFS= read -r referenced_script; do
  if [[ ! -f "${referenced_script}" ]]; then
    echo "ERROR: docs reference missing script: ${referenced_script}" >&2
    exit 1
  fi
done < <(
  {
    rg --no-filename -o 'scripts/[0-9][0-9]-[A-Za-z0-9_.-]+\.sh' \
      README.md \
      docs/setup-guide.md \
      docs/troubleshooting.md || true
  } | sort -u
)

echo "==> Strict-mode guardrails (critical orchestrators)"
critical_strict_scripts=(
  "scripts/54-launch-and-capture-evidence.sh"
  "scripts/55-run-until-stable-runtime.sh"
  "scripts/90-remote-dgx-stable-check.sh"
)
for script_path in "${critical_strict_scripts[@]}"; do
  if ! rg -q '^set -euo pipefail$' "${script_path}"; then
    echo "ERROR: missing strict mode header in ${script_path}" >&2
    exit 1
  fi
done

echo "CI validation passed."
