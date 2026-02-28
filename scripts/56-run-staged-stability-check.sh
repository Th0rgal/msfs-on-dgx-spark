#!/usr/bin/env bash
# Run a two-stage stability gate:
#  1) baseline "can run locally" window
#  2) stricter stability window
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-240}"
ATTEMPT_PAUSE_SECONDS="${ATTEMPT_PAUSE_SECONDS:-12}"

BASELINE_MIN_STABLE_SECONDS="${BASELINE_MIN_STABLE_SECONDS:-30}"
BASELINE_MAX_ATTEMPTS="${BASELINE_MAX_ATTEMPTS:-2}"

STRICT_MIN_STABLE_SECONDS="${STRICT_MIN_STABLE_SECONDS:-45}"
STRICT_MAX_ATTEMPTS="${STRICT_MAX_ATTEMPTS:-3}"

echo "MSFS staged stability runner"
echo "  AppID: $MSFS_APPID"
echo "  Baseline gate: ${BASELINE_MIN_STABLE_SECONDS}s (max attempts: $BASELINE_MAX_ATTEMPTS)"
echo "  Strict gate: ${STRICT_MIN_STABLE_SECONDS}s (max attempts: $STRICT_MAX_ATTEMPTS)"

echo
echo "[stage 1/2] Baseline local-run gate"
MSFS_APPID="$MSFS_APPID" \
MIN_STABLE_SECONDS="$BASELINE_MIN_STABLE_SECONDS" \
MAX_ATTEMPTS="$BASELINE_MAX_ATTEMPTS" \
WAIT_SECONDS="$WAIT_SECONDS" \
ATTEMPT_PAUSE_SECONDS="$ATTEMPT_PAUSE_SECONDS" \
  "$SCRIPT_DIR/55-run-until-stable-runtime.sh"

echo
echo "[stage 2/2] Strict stability gate"
if MSFS_APPID="$MSFS_APPID" \
  MIN_STABLE_SECONDS="$STRICT_MIN_STABLE_SECONDS" \
  MAX_ATTEMPTS="$STRICT_MAX_ATTEMPTS" \
  WAIT_SECONDS="$WAIT_SECONDS" \
  ATTEMPT_PAUSE_SECONDS="$ATTEMPT_PAUSE_SECONDS" \
  "$SCRIPT_DIR/55-run-until-stable-runtime.sh"; then
  echo
  echo "RESULT: baseline and strict stability gates passed"
  exit 0
fi

echo
echo "RESULT: baseline gate passed, strict gate did not pass in allotted attempts"
exit 3
