#!/usr/bin/env bash
# Retry MSFS launch evidence cycles until stable runtime is observed.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MSFS_APPID="${MSFS_APPID:-2537590}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-20}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
ATTEMPT_PAUSE_SECONDS="${ATTEMPT_PAUSE_SECONDS:-12}"
WAIT_SECONDS="${WAIT_SECONDS:-240}"
RECOVER_BETWEEN_ATTEMPTS="${RECOVER_BETWEEN_ATTEMPTS:-0}"
RECOVER_ON_EXIT_CODES="${RECOVER_ON_EXIT_CODES:-2,3,4}"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"

mkdir -p "$OUT_DIR"

if ! [[ "$MAX_ATTEMPTS" =~ ^[0-9]+$ ]] || [ "$MAX_ATTEMPTS" -lt 1 ]; then
  echo "ERROR: MAX_ATTEMPTS must be a positive integer (got: $MAX_ATTEMPTS)"
  exit 1
fi

echo "MSFS retry-to-stable runner"
echo "  AppID: $MSFS_APPID"
echo "  Target stable window: ${MIN_STABLE_SECONDS}s"
echo "  Max attempts: $MAX_ATTEMPTS"
echo "  Retry recovery: ${RECOVER_BETWEEN_ATTEMPTS} (on exit codes: ${RECOVER_ON_EXIT_CODES})"

should_recover() {
  local rc="$1"
  [[ ",${RECOVER_ON_EXIT_CODES}," == *",${rc},"* ]]
}

a=1
while [ "$a" -le "$MAX_ATTEMPTS" ]; do
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  attempt_log="$OUT_DIR/retry-attempt-${MSFS_APPID}-${stamp}-a${a}.log"

  echo
  echo "[attempt $a/$MAX_ATTEMPTS] launching capture cycle"
  set +e
  MSFS_APPID="$MSFS_APPID" MIN_STABLE_SECONDS="$MIN_STABLE_SECONDS" WAIT_SECONDS="$WAIT_SECONDS" \
    "$SCRIPT_DIR/54-launch-and-capture-evidence.sh" 2>&1 | tee "$attempt_log"
  rc=${PIPESTATUS[0]}
  set -e

  if [ "$rc" -eq 0 ]; then
    echo
    echo "RESULT: stable runtime achieved on attempt $a"
    echo "  Attempt log: $attempt_log"
    exit 0
  fi

  echo "  attempt exit code: $rc"
  last_verify="$(ls -1t "$OUT_DIR"/verify-launch-${MSFS_APPID}-*.log 2>/dev/null | head -n 1 || true)"
  if [ -n "$last_verify" ] && [ -f "$last_verify" ]; then
    lifetime_line="$(grep -E 'Strong runtime lifetime|Wrapper-only lifetime|RESULT:' "$last_verify" | tail -n 3 | tr '\n' ' ' || true)"
    echo "  latest verifier summary: ${lifetime_line:-n/a}"
    echo "  verify log: $last_verify"
  fi

  if [ "$a" -lt "$MAX_ATTEMPTS" ]; then
    if [ "$RECOVER_BETWEEN_ATTEMPTS" = "1" ] && should_recover "$rc"; then
      recover_log="$OUT_DIR/recover-between-attempts-${MSFS_APPID}-${stamp}-a${a}.log"
      echo "  running Steam runtime recovery before retry"
      set +e
      OUT_DIR="$OUT_DIR" "$SCRIPT_DIR/57-recover-steam-runtime.sh" 2>&1 | tee "$recover_log"
      recover_rc=${PIPESTATUS[0]}
      set -e
      echo "  recovery exit code: $recover_rc"
      echo "  recovery log: $recover_log"
    fi
    echo "  waiting ${ATTEMPT_PAUSE_SECONDS}s before retry"
    sleep "$ATTEMPT_PAUSE_SECONDS"
  fi

  a=$((a + 1))
done

echo
echo "RESULT: did not reach stable runtime after $MAX_ATTEMPTS attempts"
exit 1
