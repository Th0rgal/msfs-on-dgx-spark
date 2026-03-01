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

echo "Lock helper self-test passed."
