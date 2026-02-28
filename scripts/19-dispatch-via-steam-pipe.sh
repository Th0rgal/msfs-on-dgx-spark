#!/usr/bin/env bash
# Dispatch MSFS launch through Steam IPC pipe (more reliable than URI/applaunch in headless Snap sessions).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib-display.sh"
MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-15}"
LAUNCH_URI="${1:-${LAUNCH_URI:-steam://rungameid/${MSFS_APPID}}}"
PIPE_WRITE_TIMEOUT_SECONDS="${PIPE_WRITE_TIMEOUT_SECONDS:-3}"
PIPE_WRITE_RETRIES="${PIPE_WRITE_RETRIES:-2}"
PIPE_WRITE_RETRY_DELAY_SECONDS="${PIPE_WRITE_RETRY_DELAY_SECONDS:-5}"
PIPE_WRITE_RECOVER_ON_TIMEOUT="${PIPE_WRITE_RECOVER_ON_TIMEOUT:-1}"
URI_FALLBACK_ON_PIPE_FAILURE="${URI_FALLBACK_ON_PIPE_FAILURE:-1}"
URI_FALLBACK_TIMEOUT_SECONDS="${URI_FALLBACK_TIMEOUT_SECONDS:-15}"
RECOVER_SCRIPT="${RECOVER_SCRIPT:-$SCRIPT_DIR/57-recover-steam-runtime.sh}"
RECOVER_OUT_DIR="${RECOVER_OUT_DIR:-$REPO_ROOT/output}"
DISPLAY_NUM="${DISPLAY_NUM:-$(resolve_display_num "$SCRIPT_DIR")}"

STEAM_PIPE="${STEAM_PIPE:-$HOME/snap/steam/common/.steam/steam.pipe}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
LOG_DIR="$STEAM_DIR/logs"
CONSOLE_LOG=""
CONTENT_LOG="$STEAM_DIR/logs/content_log.txt"
COMPAT_LOG="$STEAM_DIR/logs/compat_log.txt"

pick_latest_log() {
  local best=""
  local best_ts=0
  local f ts
  for f in "$@"; do
    [ -f "$f" ] || continue
    ts="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    if [ "${ts:-0}" -gt "$best_ts" ]; then
      best="$f"
      best_ts="$ts"
    fi
  done
  [ -n "$best" ] && echo "$best"
}

if [ ! -p "$STEAM_PIPE" ]; then
  echo "ERROR: steam pipe missing: $STEAM_PIPE"
  echo "Hint: ensure Steam is running under snap HOME (/home/*/snap/steam/common)."
  exit 2
fi

CONSOLE_LOG="$(pick_latest_log "$LOG_DIR/console-linux.txt" "$LOG_DIR/console_log.txt")"

if [ -z "$CONSOLE_LOG" ]; then
  echo "WARN: no console log found in $LOG_DIR (continuing with compat_log-only checks)."
fi

if [ ! -f "$COMPAT_LOG" ]; then
  echo "ERROR: compat log missing: $COMPAT_LOG"
  exit 3
fi

before_ga=0
if [ -n "$CONSOLE_LOG" ]; then
  before_ga="$(grep -F -c "GameAction [AppID ${MSFS_APPID}" "$CONSOLE_LOG" || true)"
fi
before_start="$(grep -c "StartSession: appID ${MSFS_APPID}" "$COMPAT_LOG" || true)"

echo "Dispatch via steam pipe"
echo "  AppID: $MSFS_APPID"
echo "  URI:   $LAUNCH_URI"
echo "  Pipe:  $STEAM_PIPE"
if [ -n "$CONSOLE_LOG" ]; then
  echo "  Console log: $CONSOLE_LOG"
fi
echo "  Compat log:  $COMPAT_LOG"
echo "  Pipe write timeout: ${PIPE_WRITE_TIMEOUT_SECONDS}s"
echo "  Pipe write retries: ${PIPE_WRITE_RETRIES}"
echo "  Pipe timeout recovery: ${PIPE_WRITE_RECOVER_ON_TIMEOUT}"
echo "  URI fallback on pipe failure: ${URI_FALLBACK_ON_PIPE_FAILURE}"
echo "  DISPLAY: $DISPLAY_NUM"
echo "  GameAction before: $before_ga"
echo "  StartSession before: $before_start"

if ! [[ "$PIPE_WRITE_RETRIES" =~ ^[0-9]+$ ]] || [ "$PIPE_WRITE_RETRIES" -lt 1 ]; then
  echo "ERROR: PIPE_WRITE_RETRIES must be a positive integer (got: $PIPE_WRITE_RETRIES)"
  exit 6
fi

pipe_write_ok=0
attempt=1
while [ "$attempt" -le "$PIPE_WRITE_RETRIES" ]; do
  if timeout "${PIPE_WRITE_TIMEOUT_SECONDS}s" sh -c 'printf "%s\n" "$1" > "$2"' sh "$LAUNCH_URI" "$STEAM_PIPE"; then
    pipe_write_ok=1
    echo "  Pipe write: success on attempt ${attempt}/${PIPE_WRITE_RETRIES}"
    break
  fi

  echo "  Pipe write: timeout on attempt ${attempt}/${PIPE_WRITE_RETRIES}"
  if [ "$attempt" -lt "$PIPE_WRITE_RETRIES" ]; then
    if [ "$PIPE_WRITE_RECOVER_ON_TIMEOUT" = "1" ] && [ -x "$RECOVER_SCRIPT" ]; then
      echo "  Running runtime recovery before retry..."
      OUT_DIR="$RECOVER_OUT_DIR" "$RECOVER_SCRIPT" >/dev/null 2>&1 || true
    fi
    sleep "$PIPE_WRITE_RETRY_DELAY_SECONDS"
  fi
  attempt=$((attempt + 1))
done

if [ "$pipe_write_ok" -ne 1 ]; then
  if [ "$URI_FALLBACK_ON_PIPE_FAILURE" = "1" ]; then
    echo "  Pipe write exhausted; falling back to Steam URI dispatch on DISPLAY=$DISPLAY_NUM"
    timeout "${URI_FALLBACK_TIMEOUT_SECONDS}s" env DISPLAY="$DISPLAY_NUM" steam "$LAUNCH_URI" >/dev/null 2>&1 || true
  else
    echo "RESULT: failed to write launch URI to steam pipe within timeout."
    echo "Hint: this usually means Steam has no active pipe consumer in the current session."
    pgrep -af "steam|steamwebhelper|steamwebhelper_sniper_wrap|pressure-vessel|pv-bwrap" | sed -n "1,80p" || true
    exit 5
  fi
fi

sleep "$WAIT_SECONDS"

after_ga="$before_ga"
if [ -n "$CONSOLE_LOG" ]; then
  after_ga="$(grep -F -c "GameAction [AppID ${MSFS_APPID}" "$CONSOLE_LOG" || true)"
fi
after_start="$(grep -c "StartSession: appID ${MSFS_APPID}" "$COMPAT_LOG" || true)"

echo "  GameAction after:  $after_ga"
echo "  StartSession after: $after_start"

if [ "$after_ga" -gt "$before_ga" ] || [ "$after_start" -gt "$before_start" ]; then
  echo "RESULT: dispatch accepted."
  if [ -n "$CONSOLE_LOG" ]; then
    tail -n 220 "$CONSOLE_LOG" | grep -nE "ExecCommandLine|GameAction \[AppID ${MSFS_APPID}\]|CreatingProcess|ProcessingInstallScript|waitforexitandrun|Game process (added|removed)" | tail -n 80 || true
  fi
  tail -n 120 "$CONTENT_LOG" | grep -nE "${MSFS_APPID}|App Running|state changed" | tail -n 40 || true
  tail -n 120 "$COMPAT_LOG" | grep -nE "StartSession: appID ${MSFS_APPID}|Command prefix|Proton - Experimental|GE-Proton" | tail -n 40 || true
  exit 0
fi

echo "RESULT: no launch session accepted via pipe in this attempt."
if [ -n "$CONSOLE_LOG" ]; then
  tail -n 120 "$CONSOLE_LOG" | grep -nE "ExecCommandLine|GameAction \[AppID ${MSFS_APPID}\]" | tail -n 40 || true
fi
exit 4
