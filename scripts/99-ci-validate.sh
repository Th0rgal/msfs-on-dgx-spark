#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

if command -v rg >/dev/null 2>&1; then
  have_rg=1
else
  have_rg=0
fi

echo "==> Bash syntax checks"
while IFS= read -r script_path; do
  bash -n "${script_path}"
done < <(find scripts -maxdepth 1 -type f -name '*.sh' | sort)

echo "==> Shebang guardrails"
while IFS= read -r script_path; do
  shebang_line="$(head -n 1 "${script_path}")"
  if [[ "${shebang_line}" != "#!/usr/bin/env bash" ]]; then
    echo "ERROR: expected '#!/usr/bin/env bash' in ${script_path}" >&2
    exit 1
  fi
done < <(find scripts -maxdepth 1 -type f -name '*.sh' | sort)

echo "==> Executable bit checks"
while IFS= read -r script_path; do
  if [[ ! -x "${script_path}" ]]; then
    echo "ERROR: expected executable script: ${script_path}" >&2
    exit 1
  fi
done < <(find scripts -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort)

echo "==> Unique numbered-script prefix checks"
if duplicate_prefixes="$(
  find scripts -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' -printf '%f\n' \
    | sed -E 's/^([0-9][0-9])-.*/\1/' \
    | sort \
    | uniq -d
)"; then
  if [[ -n "${duplicate_prefixes}" ]]; then
    echo "ERROR: duplicate two-digit script prefixes detected:" >&2
    while IFS= read -r prefix; do
      [[ -n "${prefix}" ]] || continue
      echo "  - ${prefix}" >&2
      find scripts -maxdepth 1 -type f -name "${prefix}-*.sh" -printf '    %f\n' | sort >&2
    done <<< "${duplicate_prefixes}"
    exit 1
  fi
fi

echo "==> Docs script-reference checks"
mapfile -t markdown_files < <(git ls-files '*.md')
if [[ "${#markdown_files[@]}" -eq 0 ]]; then
  echo "WARN: no tracked markdown files found; skipping docs script-reference checks."
fi

list_doc_script_refs() {
  if [[ "${#markdown_files[@]}" -eq 0 ]]; then
    return 0
  fi
  if [[ "${have_rg}" -eq 1 ]]; then
    rg --no-filename -o 'scripts/[0-9][0-9]-[A-Za-z0-9_.-]+\.sh' \
      "${markdown_files[@]}" || true
  else
    grep -Eho 'scripts/[0-9][0-9]-[A-Za-z0-9_.-]+\.sh' \
      "${markdown_files[@]}" || true
  fi
}

while IFS= read -r referenced_script; do
  if [[ ! -f "${referenced_script}" ]]; then
    echo "ERROR: docs reference missing script: ${referenced_script}" >&2
    exit 1
  fi
done < <(
  list_doc_script_refs | sort -u
)

echo "==> Strict-mode guardrails (critical orchestrators)"
critical_strict_scripts=(
  "scripts/53-preflight-runtime-repair.sh"
  "scripts/54-launch-and-capture-evidence.sh"
  "scripts/55-run-until-stable-runtime.sh"
  "scripts/56-run-staged-stability-check.sh"
  "scripts/57-recover-steam-runtime.sh"
  "scripts/58-ensure-steam-auth.sh"
  "scripts/90-remote-dgx-stable-check.sh"
)
for script_path in "${critical_strict_scripts[@]}"; do
  if ! grep -qx 'set -euo pipefail' "${script_path}"; then
    echo "ERROR: missing strict mode header in ${script_path}" >&2
    exit 1
  fi
done

echo "==> Hardcoded sudo password guardrails"
hardcoded_sudo_pattern="echo[[:space:]]+[\"'][^\"']+[\"'][[:space:]]*\\|[[:space:]]*sudo[[:space:]]+-S"
if grep -RInE "${hardcoded_sudo_pattern}" scripts/*.sh >/dev/null; then
  echo "ERROR: found disallowed hardcoded password pipe into sudo -S." >&2
  echo "Use root, sudo -n, or environment-driven secure injection instead." >&2
  grep -RInE "${hardcoded_sudo_pattern}" scripts/*.sh >&2 || true
  exit 1
fi

echo "==> ShellCheck error-level guardrails"
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "ERROR: shellcheck is required but was not found in PATH." >&2
  echo "Install shellcheck locally or run in CI where it is provisioned." >&2
  exit 1
fi
shellcheck -S error scripts/*.sh

echo "==> Lock helper behavioral self-test"
./scripts/98-test-lock-lib.sh

echo "CI validation passed."
