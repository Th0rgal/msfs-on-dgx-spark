#!/usr/bin/env bash
# Shared lock helpers for serializing critical MSFS orchestration scripts.
set -euo pipefail

lock_holder_pid_from_file() {
  local pid_file="${1:?pid file required}"
  local holder_pid=""
  if [ -f "$pid_file" ]; then
    holder_pid="$(head -n 1 "$pid_file" 2>/dev/null | tr -d '[:space:]')"
  fi
  if [[ "$holder_pid" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$holder_pid"
    return 0
  fi
  return 1
}

lock_pid_is_running() {
  local holder_pid="${1:?pid required}"
  ps -p "$holder_pid" >/dev/null 2>&1
}

lock_busy_holder_note() {
  local pid_file="${1:?pid file required}"
  local holder_pid=""
  holder_pid="$(lock_holder_pid_from_file "$pid_file" 2>/dev/null || true)"
  if [ -z "$holder_pid" ]; then
    return 0
  fi
  if lock_pid_is_running "$holder_pid"; then
    printf '(holder pid: %s)' "$holder_pid"
  else
    printf '(stale pid file: %s not running)' "$holder_pid"
  fi
}

try_reclaim_stale_lockdir() {
  local lock_dir="${1:?lock dir required}"
  local pid_file="$lock_dir/pid"
  local holder_pid=""

  [ -d "$lock_dir" ] || return 1
  holder_pid="$(lock_holder_pid_from_file "$pid_file" 2>/dev/null || true)"
  [ -n "$holder_pid" ] || return 1

  if lock_pid_is_running "$holder_pid"; then
    return 1
  fi

  if rm -rf "$lock_dir" 2>/dev/null; then
    echo "INFO: reclaimed stale lock: $lock_dir (pid $holder_pid not running)." >&2
    return 0
  fi
  return 1
}

acquire_script_lock() {
  local lock_name="${1:?lock name required}"
  local lock_wait_seconds="${2:-0}"
  local locks_dir="${3:-${MSFS_LOCKS_DIR:-${XDG_RUNTIME_DIR:-/tmp}/msfs-on-dgx-spark-locks}}"
  local lock_reclaim_stale="${MSFS_LOCK_RECLAIM_STALE:-1}"
  local force_mkdir_lock="${MSFS_FORCE_MKDIR_LOCK:-0}"
  local holder_note=""
  mkdir -p "$locks_dir"

  if [[ "$force_mkdir_lock" != "0" && "$force_mkdir_lock" != "1" ]]; then
    echo "ERROR: MSFS_FORCE_MKDIR_LOCK must be 0 or 1 (got: $force_mkdir_lock)"
    return 1
  fi
  if [[ "$lock_reclaim_stale" != "0" && "$lock_reclaim_stale" != "1" ]]; then
    echo "ERROR: MSFS_LOCK_RECLAIM_STALE must be 0 or 1 (got: $lock_reclaim_stale)"
    return 1
  fi

  if [[ "$force_mkdir_lock" != "1" ]] && command -v flock >/dev/null 2>&1; then
    MSFS_LOCK_FILE="$locks_dir/${lock_name}.lock"
    exec {MSFS_LOCK_FD}> "$MSFS_LOCK_FILE"
    if ! [[ "$lock_wait_seconds" =~ ^[0-9]+$ ]]; then
      echo "ERROR: lock wait must be a non-negative integer (got: $lock_wait_seconds)"
      return 1
    fi
    if [ "$lock_wait_seconds" -gt 0 ]; then
      flock -w "$lock_wait_seconds" "$MSFS_LOCK_FD" || {
        holder_note="$(lock_busy_holder_note "${MSFS_LOCK_FILE}.pid" || true)"
        echo "ERROR: lock busy: $lock_name (waited ${lock_wait_seconds}s). ${holder_note}"
        return 1
      }
    else
      flock -n "$MSFS_LOCK_FD" || {
        holder_note="$(lock_busy_holder_note "${MSFS_LOCK_FILE}.pid" || true)"
        echo "ERROR: lock busy: $lock_name (set a *_LOCK_WAIT_SECONDS override to wait). ${holder_note}"
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
    if [ "$lock_reclaim_stale" = "1" ] && try_reclaim_stale_lockdir "$MSFS_LOCK_DIR"; then
      continue
    fi
    if [ "$lock_wait_seconds" -eq 0 ] || [ "$elapsed" -ge "$lock_wait_seconds" ]; then
      holder_note="$(lock_busy_holder_note "${MSFS_LOCK_DIR}/pid" || true)"
      echo "ERROR: lock busy: $lock_name (mkdir fallback lock). ${holder_note}"
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
