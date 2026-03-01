#!/usr/bin/env bash
# Retry MSFS launch evidence cycles until stable runtime is observed.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-lock.sh"
MSFS_APPID="${MSFS_APPID:-2537590}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-20}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-5}"
ATTEMPT_PAUSE_SECONDS="${ATTEMPT_PAUSE_SECONDS:-12}"
WAIT_SECONDS="${WAIT_SECONDS:-240}"
RECOVER_BETWEEN_ATTEMPTS="${RECOVER_BETWEEN_ATTEMPTS:-0}"
RECOVER_ON_EXIT_CODES="${RECOVER_ON_EXIT_CODES:-2,3,4}"
FATAL_EXIT_CODES="${FATAL_EXIT_CODES-7}"
AUTO_REAUTH_ON_AUTH_FAILURE="${AUTO_REAUTH_ON_AUTH_FAILURE:-0}"
REAUTH_LOGIN_WAIT_SECONDS="${REAUTH_LOGIN_WAIT_SECONDS:-300}"
AUTH_AUTO_FILL="${AUTH_AUTO_FILL:-1}"
AUTH_SUBMIT_LOGIN="${AUTH_SUBMIT_LOGIN:-1}"
AUTH_USE_STEAM_LOGIN_CLI="${AUTH_USE_STEAM_LOGIN_CLI:-1}"
ALLOW_UI_AUTH_FALLBACK="${ALLOW_UI_AUTH_FALLBACK:-0}"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"
ENABLE_SCRIPT_LOCKS="${ENABLE_SCRIPT_LOCKS:-1}"
MSFS_STABLE_RUN_LOCK_WAIT_SECONDS="${MSFS_STABLE_RUN_LOCK_WAIT_SECONDS:-0}"

mkdir -p "$OUT_DIR"

if [ "$ENABLE_SCRIPT_LOCKS" = "1" ]; then
  acquire_script_lock "stable-runner-${MSFS_APPID}" "$MSFS_STABLE_RUN_LOCK_WAIT_SECONDS"
  trap 'release_script_lock' EXIT
fi

if ! [[ "$MAX_ATTEMPTS" =~ ^[0-9]+$ ]] || [ "$MAX_ATTEMPTS" -lt 1 ]; then
  echo "ERROR: MAX_ATTEMPTS must be a positive integer (got: $MAX_ATTEMPTS)"
  exit 1
fi

echo "MSFS retry-to-stable runner"
echo "  AppID: $MSFS_APPID"
echo "  Target stable window: ${MIN_STABLE_SECONDS}s"
echo "  Max attempts: $MAX_ATTEMPTS"
echo "  Retry recovery: ${RECOVER_BETWEEN_ATTEMPTS} (on exit codes: ${RECOVER_ON_EXIT_CODES})"
echo "  Fatal exit codes: ${FATAL_EXIT_CODES}"
echo "  Auto re-auth on auth failure: ${AUTO_REAUTH_ON_AUTH_FAILURE}"

should_recover() {
  local rc="$1"
  [[ ",${RECOVER_ON_EXIT_CODES}," == *",${rc},"* ]]
}

is_fatal() {
  local rc="$1"
  [[ ",${FATAL_EXIT_CODES}," == *",${rc},"* ]]
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

  if is_fatal "$rc"; then
    if [ "$rc" -eq 7 ] && [ "$AUTO_REAUTH_ON_AUTH_FAILURE" = "1" ] && [ "$a" -lt "$MAX_ATTEMPTS" ]; then
      reauth_log="$OUT_DIR/re-auth-between-attempts-${MSFS_APPID}-${stamp}-a${a}.log"
      echo "  auth failure detected; attempting Steam re-auth before retry"
      set +e
      LOGIN_WAIT_SECONDS="$REAUTH_LOGIN_WAIT_SECONDS" \
      AUTH_AUTO_FILL="$AUTH_AUTO_FILL" \
      AUTH_SUBMIT_LOGIN="$AUTH_SUBMIT_LOGIN" \
      AUTH_USE_STEAM_LOGIN_CLI="$AUTH_USE_STEAM_LOGIN_CLI" \
      ALLOW_UI_AUTH_FALLBACK="$ALLOW_UI_AUTH_FALLBACK" \
      "$SCRIPT_DIR/58-ensure-steam-auth.sh" 2>&1 | tee "$reauth_log"
      reauth_rc=${PIPESTATUS[0]}
      set -e
      echo "  re-auth exit code: $reauth_rc"
      echo "  re-auth log: $reauth_log"
      if [ "$reauth_rc" -eq 0 ]; then
        echo "  waiting ${ATTEMPT_PAUSE_SECONDS}s before retry"
        sleep "$ATTEMPT_PAUSE_SECONDS"
        a=$((a + 1))
        continue
      fi
    fi
    echo "RESULT: non-retryable failure encountered (exit code $rc)"
    auth_log="$(ls -1t "$OUT_DIR"/auth-state-${MSFS_APPID}-*.log 2>/dev/null | head -n 1 || true)"
    if [ -n "$auth_log" ] && [ -f "$auth_log" ]; then
      echo "  auth log: $auth_log"
    fi
    exit "$rc"
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
