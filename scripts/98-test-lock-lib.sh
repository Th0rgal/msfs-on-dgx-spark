#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib-lock.sh
source "$SCRIPT_DIR/lib-lock.sh"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "[lock-test] contention emits busy diagnostics"
(
  MSFS_LOCKS_DIR="$tmp_dir" acquire_script_lock "ci-lock-contention" 0
  sleep 3
  release_script_lock
) &
holder_job_pid=$!

lock_pid_file="$tmp_dir/ci-lock-contention.lock.pid"
for _ in $(seq 1 40); do
  [ -f "$lock_pid_file" ] && break
  sleep 0.1
done
if [ ! -f "$lock_pid_file" ]; then
  echo "ERROR: lock holder pid file was not created in time." >&2
  wait "$holder_job_pid" || true
  exit 1
fi

set +e
contention_output="$(
  MSFS_LOCKS_DIR="$tmp_dir" bash -c "source \"$SCRIPT_DIR/lib-lock.sh\"; acquire_script_lock 'ci-lock-contention' 0" 2>&1
)"
contention_rc=$?
set -e

wait "$holder_job_pid"

if [ "$contention_rc" -eq 0 ]; then
  echo "ERROR: contention test unexpectedly acquired lock." >&2
  exit 1
fi
if ! grep -q "ERROR: lock busy: ci-lock-contention" <<<"$contention_output"; then
  echo "ERROR: contention output missing lock-busy diagnostic." >&2
  echo "$contention_output" >&2
  exit 1
fi
if ! grep -q "holder pid:" <<<"$contention_output"; then
  echo "ERROR: contention output missing holder pid context." >&2
  echo "$contention_output" >&2
  exit 1
fi

echo "[lock-test] stale lockdir reclaim removes non-running holder lock"
stale_lock_dir="$tmp_dir/stale.lockdir"
mkdir -p "$stale_lock_dir"
printf '%s\n' 999999 > "$stale_lock_dir/pid"
if ! try_reclaim_stale_lockdir "$stale_lock_dir" >/dev/null; then
  echo "ERROR: stale lockdir reclaim should have succeeded." >&2
  exit 1
fi
if [ -d "$stale_lock_dir" ]; then
  echo "ERROR: stale lockdir still exists after reclaim." >&2
  exit 1
fi

echo "[lock-test] stale reclaim preserves lockdir for running holder pid"
active_lock_dir="$tmp_dir/active.lockdir"
mkdir -p "$active_lock_dir"
printf '%s\n' "$$" > "$active_lock_dir/pid"
if try_reclaim_stale_lockdir "$active_lock_dir" >/dev/null; then
  echo "ERROR: lockdir with running holder pid must not be reclaimed." >&2
  exit 1
fi
if [ ! -d "$active_lock_dir" ]; then
  echo "ERROR: active lockdir was unexpectedly removed." >&2
  exit 1
fi

echo "[lock-test] mkdir fallback contention emits busy diagnostics"
(
  MSFS_LOCKS_DIR="$tmp_dir" MSFS_FORCE_MKDIR_LOCK=1 acquire_script_lock "ci-mkdir-contention" 0
  sleep 3
  release_script_lock
) &
mkdir_holder_job_pid=$!

mkdir_lock_pid_file="$tmp_dir/ci-mkdir-contention.lockdir/pid"
for _ in $(seq 1 40); do
  [ -f "$mkdir_lock_pid_file" ] && break
  sleep 0.1
done
if [ ! -f "$mkdir_lock_pid_file" ]; then
  echo "ERROR: mkdir fallback holder pid file was not created in time." >&2
  wait "$mkdir_holder_job_pid" || true
  exit 1
fi

set +e
mkdir_contention_output="$(
  MSFS_LOCKS_DIR="$tmp_dir" MSFS_FORCE_MKDIR_LOCK=1 bash -c "source \"$SCRIPT_DIR/lib-lock.sh\"; acquire_script_lock 'ci-mkdir-contention' 0" 2>&1
)"
mkdir_contention_rc=$?
set -e

wait "$mkdir_holder_job_pid"

if [ "$mkdir_contention_rc" -eq 0 ]; then
  echo "ERROR: mkdir contention test unexpectedly acquired lock." >&2
  exit 1
fi
if ! grep -q "ERROR: lock busy: ci-mkdir-contention" <<<"$mkdir_contention_output"; then
  echo "ERROR: mkdir contention output missing lock-busy diagnostic." >&2
  echo "$mkdir_contention_output" >&2
  exit 1
fi
if ! grep -q "holder pid:" <<<"$mkdir_contention_output"; then
  echo "ERROR: mkdir contention output missing holder pid context." >&2
  echo "$mkdir_contention_output" >&2
  exit 1
fi

echo "[lock-test] mkdir fallback auto-reclaims stale lockdir during acquire"
mkdir -p "$tmp_dir/ci-mkdir-stale.lockdir"
printf '%s\n' 999999 > "$tmp_dir/ci-mkdir-stale.lockdir/pid"
MSFS_LOCKS_DIR="$tmp_dir" MSFS_FORCE_MKDIR_LOCK=1 acquire_script_lock "ci-mkdir-stale" 0
if [ ! -f "$tmp_dir/ci-mkdir-stale.lockdir/pid" ]; then
  echo "ERROR: expected lock pid file after stale lockdir reclaim acquire." >&2
  release_script_lock
  exit 1
fi
release_script_lock

echo "[lock-test] mkdir fallback honors MSFS_LOCK_RECLAIM_STALE=0"
mkdir -p "$tmp_dir/ci-mkdir-no-reclaim.lockdir"
printf '%s\n' 999999 > "$tmp_dir/ci-mkdir-no-reclaim.lockdir/pid"
set +e
no_reclaim_output="$(
  MSFS_LOCKS_DIR="$tmp_dir" MSFS_FORCE_MKDIR_LOCK=1 MSFS_LOCK_RECLAIM_STALE=0 bash -c "source \"$SCRIPT_DIR/lib-lock.sh\"; acquire_script_lock 'ci-mkdir-no-reclaim' 0" 2>&1
)"
no_reclaim_rc=$?
set -e
if [ "$no_reclaim_rc" -eq 0 ]; then
  echo "ERROR: expected stale lockdir to block acquire when reclaim is disabled." >&2
  exit 1
fi
if ! grep -q "ERROR: lock busy: ci-mkdir-no-reclaim" <<<"$no_reclaim_output"; then
  echo "ERROR: missing lock-busy diagnostic when stale reclaim is disabled." >&2
  echo "$no_reclaim_output" >&2
  exit 1
fi

echo "Lock helper self-test passed."
