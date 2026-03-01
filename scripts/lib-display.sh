#!/usr/bin/env bash
# Shared display selection helpers for DGX MSFS scripts.
set -euo pipefail

display_is_live() {
  local d="$1"
  if command -v xset >/dev/null 2>&1; then
    DISPLAY="$d" xset q >/dev/null 2>&1
    return $?
  fi
  if command -v xdpyinfo >/dev/null 2>&1; then
    DISPLAY="$d" xdpyinfo >/dev/null 2>&1
    return $?
  fi
  return 1
}

display_is_nvidia_gl() {
  local d="$1"
  if ! command -v glxinfo >/dev/null 2>&1; then
    return 1
  fi
  DISPLAY="$d" glxinfo -B 2>/dev/null \
    | grep -Eq 'OpenGL renderer string:.*NVIDIA|OpenGL vendor string: NVIDIA'
}

find_live_nvidia_display() {
  local d candidate

  for d in :2 :0 :4 :5 :1 :3; do
    if display_is_live "$d" && display_is_nvidia_gl "$d"; then
      echo "$d"
      return 0
    fi
  done

  while read -r candidate; do
    [ -n "$candidate" ] || continue
    if display_is_live "$candidate" && display_is_nvidia_gl "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done < <(
    pgrep -af 'X(org|vfb) :[0-9]+' \
      | sed -n 's/.* \(:[0-9]\+\).*/\1/p' \
      | awk '!seen[$0]++'
  )

  return 1
}

resolve_runtime_display_num() {
  local script_dir="$1"
  local require_nvidia="${2:-0}"
  local candidate nvidia_candidate

  candidate="$(resolve_display_num "$script_dir")"
  if [ "$require_nvidia" != "1" ]; then
    echo "$candidate"
    return 0
  fi

  if display_is_live "$candidate" && display_is_nvidia_gl "$candidate"; then
    echo "$candidate"
    return 0
  fi

  nvidia_candidate="$(find_live_nvidia_display || true)"
  if [ -n "$nvidia_candidate" ]; then
    echo "$nvidia_candidate"
    return 0
  fi

  return 1
}

resolve_display_num() {
  local script_dir="$1"
  local helper="${script_dir}/00-select-msfs-display.sh"
  local d candidate

  if [ -n "${DISPLAY_NUM:-}" ]; then
    echo "$DISPLAY_NUM"
    return 0
  fi

  if [ -x "$helper" ]; then
    candidate="$("$helper" 2>/dev/null || true)"
    if [ -n "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  fi

  for d in :2 :1 :0 :3; do
    if display_is_live "$d"; then
      echo "$d"
      return 0
    fi
  done

  candidate="$(pgrep -af 'Xvfb :[0-9]+' \
    | sed -n 's/.*Xvfb \(:[0-9]\+\).*/\1/p' \
    | head -n 1 || true)"
  if [ -n "$candidate" ]; then
    echo "$candidate"
    return 0
  fi

  echo ":1"
}
