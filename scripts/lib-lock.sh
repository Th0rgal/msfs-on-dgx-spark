#!/usr/bin/env bash
# Shared lock helpers for serializing critical MSFS orchestration scripts.
set -euo pipefail

acquire_script_lock() {
  local lock_name="${1:?lock name required}"
  local lock_wait_seconds="${2:-0}"
  local locks_dir="${3:-${MSFS_LOCKS_DIR:-${XDG_RUNTIME_DIR:-/tmp}/msfs-on-dgx-spark-locks}}"
  mkdir -p "$locks_dir"

  if command -v flock >/dev/null 2>&1; then
    MSFS_LOCK_FILE="$locks_dir/${lock_name}.lock"
    exec {MSFS_LOCK_FD}> "$MSFS_LOCK_FILE"
    if ! [[ "$lock_wait_seconds" =~ ^[0-9]+$ ]]; then
      echo "ERROR: lock wait must be a non-negative integer (got: $lock_wait_seconds)"
      return 1
    fi
    if [ "$lock_wait_seconds" -gt 0 ]; then
      flock -w "$lock_wait_seconds" "$MSFS_LOCK_FD" || {
        echo "ERROR: lock busy: $lock_name (waited ${lock_wait_seconds}s)."
        return 1
      }
    else
      flock -n "$MSFS_LOCK_FD" || {
        echo "ERROR: lock busy: $lock_name (set a *_LOCK_WAIT_SECONDS override to wait)."
        return 1
      }
    fi
    printf '%s\n' "$$" > "${MSFS_LOCK_FILE}.pid" || true
    return 0
  fi

  if ! [[ "$lock_wait_seconds" =~ ^[0-9]+$ ]]; then
    echo "ERROR: lock wait must be a non-negative integer (got: $lock_wait_seconds)"
    return 1
  fi
  MSFS_LOCK_DIR="$locks_dir/${lock_name}.lockdir"
  local elapsed=0
  while ! mkdir "$MSFS_LOCK_DIR" 2>/dev/null; do
    if [ "$lock_wait_seconds" -eq 0 ] || [ "$elapsed" -ge "$lock_wait_seconds" ]; then
      echo "ERROR: lock busy: $lock_name (mkdir fallback lock)."
      return 1
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  printf '%s\n' "$$" > "${MSFS_LOCK_DIR}/pid" || true
  return 0
}

release_script_lock() {
  if [ -n "${MSFS_LOCK_FILE:-}" ]; then
    rm -f "${MSFS_LOCK_FILE}.pid" 2>/dev/null || true
  fi
  if [ -n "${MSFS_LOCK_FD:-}" ]; then
    flock -u "$MSFS_LOCK_FD" 2>/dev/null || true
    eval "exec ${MSFS_LOCK_FD}>&-"
  fi
  if [ -n "${MSFS_LOCK_DIR:-}" ]; then
    rm -f "${MSFS_LOCK_DIR}/pid" 2>/dev/null || true
    rmdir "${MSFS_LOCK_DIR}" 2>/dev/null || true
  fi
}
