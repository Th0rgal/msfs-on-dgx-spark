#!/usr/bin/env bash
# Ensure MSFS launch state is clean: do not relaunch if already running; clear stale launcher wrappers when needed.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_FOR_EXISTING_SECONDS="${WAIT_FOR_EXISTING_SECONDS:-40}"
POLL_SECONDS="${POLL_SECONDS:-4}"
KILL_STALE_WRAPPERS="${KILL_STALE_WRAPPERS:-1}"
RECOVER_STEAM_RUNTIME_ON_STALE="${RECOVER_STEAM_RUNTIME_ON_STALE:-1}"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"

mkdir -p "$OUT_DIR"

strong_runtime_lines() {
  ps -eo pid=,args= \
    | awk -v self_pid="$$" '
      BEGIN { IGNORECASE = 1 }
      $1 != self_pid &&
      $0 ~ /(FlightSimulator2024|FlightSimulator\.exe|KittyHawkx64|gamelaunchhelper\.exe|MSFS2024\/FlightSimulator2024\.exe|Z:\\.*FlightSimulator)/ &&
      $0 !~ /(codex exec|62-ensure-msfs-launchable-state\.sh)/ {
        print
      }
    ' || true
}

appid_wrapper_lines() {
  ps -eo pid=,args= \
    | awk -v self_pid="$$" -v appid="$MSFS_APPID" '
      BEGIN { IGNORECASE = 1 }
      $1 != self_pid &&
      $0 ~ ("AppId=" appid "|rungameid/" appid "|waitforexitandrun|steam-launch-wrapper|steamsteam|proton waitforexitandrun") &&
      $0 !~ /(codex exec|62-ensure-msfs-launchable-state\.sh)/ {
        print
      }
    ' || true
}

kill_stale_wrappers() {
  pkill -f "AppId=${MSFS_APPID}" >/dev/null 2>&1 || true
  pkill -f "rungameid/${MSFS_APPID}" >/dev/null 2>&1 || true
  pkill -f "proton waitforexitandrun" >/dev/null 2>&1 || true
  pkill -f "steam-launch-wrapper" >/dev/null 2>&1 || true
  pkill -f "steamsteam" >/dev/null 2>&1 || true
}

echo "MSFS launchability guard"
echo "  AppID: $MSFS_APPID"
echo "  Wait for existing session: ${WAIT_FOR_EXISTING_SECONDS}s"
echo "  Kill stale wrappers: $KILL_STALE_WRAPPERS"
echo "  Recover Steam runtime on stale: $RECOVER_STEAM_RUNTIME_ON_STALE"

if ! [[ "$WAIT_FOR_EXISTING_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: WAIT_FOR_EXISTING_SECONDS must be >=0 integer (got: $WAIT_FOR_EXISTING_SECONDS)"
  exit 2
fi
if ! [[ "$POLL_SECONDS" =~ ^[0-9]+$ ]] || [ "$POLL_SECONDS" -lt 1 ]; then
  echo "ERROR: POLL_SECONDS must be >=1 integer (got: $POLL_SECONDS)"
  exit 2
fi
if ! [[ "$KILL_STALE_WRAPPERS" =~ ^[01]$ ]]; then
  echo "ERROR: KILL_STALE_WRAPPERS must be 0 or 1 (got: $KILL_STALE_WRAPPERS)"
  exit 2
fi
if ! [[ "$RECOVER_STEAM_RUNTIME_ON_STALE" =~ ^[01]$ ]]; then
  echo "ERROR: RECOVER_STEAM_RUNTIME_ON_STALE must be 0 or 1 (got: $RECOVER_STEAM_RUNTIME_ON_STALE)"
  exit 2
fi

strong="$(strong_runtime_lines)"
if [ -n "$strong" ]; then
  echo "RESULT: MSFS strong runtime already active; skip new launch."
  printf "%s\n" "$strong"
  exit 10
fi

wrappers="$(appid_wrapper_lines)"
if [ -z "$wrappers" ]; then
  echo "RESULT: no stale launch wrappers detected; launch is allowed."
  exit 0
fi

echo "Detected existing AppID/wrapper processes; waiting for natural exit..."
printf "%s\n" "$wrappers"
start_ts="$(date +%s)"
while true; do
  strong="$(strong_runtime_lines)"
  if [ -n "$strong" ]; then
    echo "RESULT: MSFS runtime became active while waiting; skip new launch."
    printf "%s\n" "$strong"
    exit 10
  fi

  wrappers="$(appid_wrapper_lines)"
  if [ -z "$wrappers" ]; then
    echo "RESULT: stale wrappers cleared naturally; launch is allowed."
    exit 0
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  if [ "$elapsed" -ge "$WAIT_FOR_EXISTING_SECONDS" ]; then
    break
  fi
  sleep "$POLL_SECONDS"
done

if [ "$KILL_STALE_WRAPPERS" = "0" ]; then
  echo "RESULT: wrapper processes still present after wait; cleanup disabled."
  exit 3
fi

echo "Stale wrappers persisted; performing targeted cleanup..."
kill_stale_wrappers
sleep 3

if [ "$RECOVER_STEAM_RUNTIME_ON_STALE" = "1" ] && [ -x "$SCRIPT_DIR/57-recover-steam-runtime.sh" ]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  recover_log="$OUT_DIR/already-running-recover-${MSFS_APPID}-${stamp}.log"
  set +e
  OUT_DIR="$OUT_DIR" "$SCRIPT_DIR/57-recover-steam-runtime.sh" >"$recover_log" 2>&1
  recover_rc=$?
  set -e
  echo "Steam runtime recovery exit code: $recover_rc"
  echo "Recovery log: $recover_log"
fi

strong="$(strong_runtime_lines)"
if [ -n "$strong" ]; then
  echo "RESULT: MSFS runtime active after cleanup; skip new launch."
  printf "%s\n" "$strong"
  exit 10
fi

wrappers="$(appid_wrapper_lines)"
if [ -n "$wrappers" ]; then
  echo "RESULT: stale wrappers still present after cleanup."
  printf "%s\n" "$wrappers"
  exit 5
fi

echo "RESULT: stale wrappers cleared; launch is allowed."
exit 0
