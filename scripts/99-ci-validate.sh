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

echo "CI validation passed."
