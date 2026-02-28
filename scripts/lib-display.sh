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
