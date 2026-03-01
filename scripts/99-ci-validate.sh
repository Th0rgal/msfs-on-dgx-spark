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

echo "==> Local markdown-link integrity checks"
extract_markdown_inline_links() {
  local md_file="$1"
  if [[ "${have_rg}" -eq 1 ]]; then
    rg --no-filename -o '!?\[[^]]+\]\([^)]+\)' "${md_file}" || true
  else
    grep -Eo '!?\[[^]]+\]\([^)]+\)' "${md_file}" || true
  fi
}

normalize_markdown_link_target() {
  local raw_link="$1"
  local target="${raw_link#*](}"
  target="${target%)}"
  target="${target#"${target%%[![:space:]]*}"}"
  target="${target%"${target##*[![:space:]]}"}"
  target="${target#<}"
  target="${target%>}"

  if [[ "${target}" == *" \""* ]] || [[ "${target}" == *" '"* ]]; then
    target="${target%% *}"
  fi

  target="${target%%#*}"
  target="${target%%\?*}"
  printf '%s\n' "${target}"
}

if [[ "${#markdown_files[@]}" -gt 0 ]]; then
  while IFS= read -r md_file; do
    md_dir="$(dirname "${md_file}")"
    while IFS= read -r raw_link; do
      target="$(normalize_markdown_link_target "${raw_link}")"
      [[ -n "${target}" ]] || continue

      if [[ "${target}" =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]]; then
        continue
      fi
      if [[ "${target}" == \#* ]]; then
        continue
      fi

      if [[ "${target}" == /* ]]; then
        resolved_target="${target}"
      else
        resolved_target="${md_dir}/${target}"
      fi

      if [[ "${target}" == */ ]]; then
        if [[ ! -d "${resolved_target}" ]]; then
          echo "ERROR: broken local markdown link in ${md_file}: ${target}" >&2
          exit 1
        fi
      elif [[ ! -e "${resolved_target}" ]]; then
        echo "ERROR: broken local markdown link in ${md_file}: ${target}" >&2
        exit 1
      fi
    done < <(extract_markdown_inline_links "${md_file}")
  done < <(printf '%s\n' "${markdown_files[@]}")
fi

echo "==> Text file encoding/line-ending guardrails"
mapfile -t text_guardrail_files < <(
  git ls-files 'scripts/*.sh' '*.md' '.github/workflows/*.yml'
)
for file_path in "${text_guardrail_files[@]}"; do
  if LC_ALL=C grep -q $'\r' "${file_path}"; then
    echo "ERROR: CRLF line endings detected in ${file_path}" >&2
    exit 1
  fi

  bom_hex="$(head -c 3 "${file_path}" | od -An -t x1 | tr -d '[:space:]')"
  if [[ "${bom_hex}" == "efbbbf" ]]; then
    echo "ERROR: UTF-8 BOM detected in ${file_path}" >&2
    exit 1
  fi
done

echo "==> Strict-mode guardrails (numbered scripts)"
while IFS= read -r script_path; do
  if ! grep -qx 'set -euo pipefail' "${script_path}"; then
    echo "ERROR: missing strict mode header in ${script_path}" >&2
    exit 1
  fi
done < <(find scripts -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' | sort)

echo "==> Hardcoded sudo password guardrails"
hardcoded_sudo_pattern="echo[[:space:]]+[\"'][^\"']+[\"'][[:space:]]*\\|[[:space:]]*sudo[[:space:]]+-S"
if grep -RInE "${hardcoded_sudo_pattern}" scripts/*.sh >/dev/null; then
  echo "ERROR: found disallowed hardcoded password pipe into sudo -S." >&2
  echo "Use root, sudo -n, or environment-driven secure injection instead." >&2
  grep -RInE "${hardcoded_sudo_pattern}" scripts/*.sh >&2 || true
  exit 1
fi

echo "==> Merge-conflict marker guardrails"
if git grep -nE '^(<<<<<<< |=======|>>>>>>> )' -- . >/dev/null; then
  echo "ERROR: unresolved merge-conflict markers detected in tracked files." >&2
  git grep -nE '^(<<<<<<< |=======|>>>>>>> )' -- . >&2 || true
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
