#!/usr/bin/env bash
# Print the best display for MSFS runs, preferring NVIDIA-backed X displays.
set -euo pipefail

if [ -n "${DISPLAY_NUM:-}" ]; then
  printf '%s\n' "$DISPLAY_NUM"
  exit 0
fi

has_display() {
  local d="$1"
  DISPLAY="$d" xset q >/dev/null 2>&1
}

is_nvidia_gl() {
  local d="$1"
  DISPLAY="$d" glxinfo -B 2>/dev/null | grep -Eq 'OpenGL renderer string:.*NVIDIA|OpenGL vendor string: NVIDIA'
}

# Prefer known DGX GPU-backed display slots first.
for d in :2 :0 :4 :5; do
  if has_display "$d" && is_nvidia_gl "$d"; then
    printf '%s\n' "$d"
    exit 0
  fi
done

# Fallback to any live display before resorting to :1 bootstrap.
for d in :1 :3; do
  if has_display "$d"; then
    printf '%s\n' "$d"
    exit 0
  fi
done

printf '%s\n' ':1'
