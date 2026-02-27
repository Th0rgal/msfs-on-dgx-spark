#!/usr/bin/env bash
# Check whether Steam accepted a launch request by watching GameAction deltas.
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
MSFS_APPID="${MSFS_APPID:-2537590}"
MODE="${1:-uri}" # uri|applaunch|pipe
WAIT_SECONDS="${WAIT_SECONDS:-15}"

find_steam_dir() {
  local paths=(
    "$HOME/snap/steam/common/.local/share/Steam"
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
  )
  local p
  for p in "${paths[@]}"; do
    if [ -d "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi

LOG="$STEAM_DIR/logs/console_log.txt"
if [ ! -f "$LOG" ]; then
  echo "ERROR: Steam console log missing: $LOG"
  exit 2
fi

before="$(grep -c "GameAction \\[AppID ${MSFS_APPID}" "$LOG" || true)"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "Debug launch dispatch"
echo "  Time (UTC): $ts"
echo "  Display: $DISPLAY_NUM"
echo "  AppID: $MSFS_APPID"
echo "  Mode: $MODE"
echo "  GameAction count before: $before"

case "$MODE" in
  uri)
    DISPLAY="$DISPLAY_NUM" steam "steam://rungameid/${MSFS_APPID}" >/tmp/msfs-debug-uri.log 2>&1 || true
    ;;
  applaunch)
    DISPLAY="$DISPLAY_NUM" steam -applaunch "${MSFS_APPID}" -dx11 -FastLaunch >/tmp/msfs-debug-applaunch.log 2>&1 || true
    ;;
  pipe)
    MSFS_APPID="$MSFS_APPID" WAIT_SECONDS="$WAIT_SECONDS" "$(dirname "$0")/19-dispatch-via-steam-pipe.sh"
    ;;
  *)
    echo "ERROR: unsupported mode  (use: uri|applaunch|pipe)"
    exit 3
    ;;
esac

if [ "$MODE" = "pipe" ]; then
  exit 0
fi

sleep "$WAIT_SECONDS"

after="$(grep -c "GameAction \\[AppID ${MSFS_APPID}" "$LOG" || true)"
echo "  GameAction count after:  $after"
if [ "$after" -gt "$before" ]; then
  echo "RESULT: dispatch accepted by Steam (new GameAction entry detected)."
  grep -n "AppID ${MSFS_APPID}\\|GameAction" "$LOG" | tail -n 25
  exit 0
fi

echo "RESULT: no new GameAction entries; launch request not accepted by current client state."
grep -n "AppID ${MSFS_APPID}\\|GameAction\\|ExecCommandLine" "$LOG" | tail -n 40
exit 4
