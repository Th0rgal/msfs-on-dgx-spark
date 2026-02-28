#!/usr/bin/env bash
# Dispatch MSFS launch through Steam IPC pipe (more reliable than URI/applaunch in headless Snap sessions).
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-15}"
LAUNCH_URI="${LAUNCH_URI:-steam://rungameid/${MSFS_APPID}}"
PIPE_WRITE_TIMEOUT_SECONDS="${PIPE_WRITE_TIMEOUT_SECONDS:-3}"

STEAM_PIPE="${STEAM_PIPE:-$HOME/snap/steam/common/.steam/steam.pipe}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
CONSOLE_LOG="$STEAM_DIR/logs/console_log.txt"
CONTENT_LOG="$STEAM_DIR/logs/content_log.txt"
COMPAT_LOG="$STEAM_DIR/logs/compat_log.txt"

if [ ! -p "$STEAM_PIPE" ]; then
  echo "ERROR: steam pipe missing: $STEAM_PIPE"
  echo "Hint: ensure Steam is running under snap HOME (/home/*/snap/steam/common)."
  exit 2
fi

if [ ! -f "$CONSOLE_LOG" ]; then
  echo "ERROR: console log missing: $CONSOLE_LOG"
  exit 3
fi

before_ga="$(grep -F -c "GameAction [AppID ${MSFS_APPID}" "$CONSOLE_LOG" || true)"
before_start="$(grep -c "StartSession: appID ${MSFS_APPID}" "$COMPAT_LOG" || true)"

echo "Dispatch via steam pipe"
echo "  AppID: $MSFS_APPID"
echo "  URI:   $LAUNCH_URI"
echo "  Pipe:  $STEAM_PIPE"
echo "  Pipe write timeout: ${PIPE_WRITE_TIMEOUT_SECONDS}s"
echo "  GameAction before: $before_ga"
echo "  StartSession before: $before_start"

if ! timeout "${PIPE_WRITE_TIMEOUT_SECONDS}s" sh -c 'printf "%s\n" "$1" > "$2"' sh "$LAUNCH_URI" "$STEAM_PIPE"; then
  echo "RESULT: failed to write launch URI to steam pipe within timeout."
  echo "Hint: this usually means Steam has no active pipe consumer in the current session."
  pgrep -af "steam|steamwebhelper|steamwebhelper_sniper_wrap|pressure-vessel|pv-bwrap" | sed -n "1,80p" || true
  exit 5
fi

sleep "$WAIT_SECONDS"

after_ga="$(grep -F -c "GameAction [AppID ${MSFS_APPID}" "$CONSOLE_LOG" || true)"
after_start="$(grep -c "StartSession: appID ${MSFS_APPID}" "$COMPAT_LOG" || true)"

echo "  GameAction after:  $after_ga"
echo "  StartSession after: $after_start"

if [ "$after_ga" -gt "$before_ga" ] || [ "$after_start" -gt "$before_start" ]; then
  echo "RESULT: dispatch accepted."
  tail -n 220 "$CONSOLE_LOG" | grep -nE "ExecCommandLine|GameAction \[AppID ${MSFS_APPID}\]|CreatingProcess|ProcessingInstallScript|waitforexitandrun|Game process (added|removed)" | tail -n 80 || true
  tail -n 120 "$CONTENT_LOG" | grep -nE "${MSFS_APPID}|App Running|state changed" | tail -n 40 || true
  tail -n 120 "$COMPAT_LOG" | grep -nE "StartSession: appID ${MSFS_APPID}|Command prefix|Proton - Experimental|GE-Proton" | tail -n 40 || true
  exit 0
fi

echo "RESULT: no launch session accepted via pipe in this attempt."
tail -n 120 "$CONSOLE_LOG" | grep -nE "ExecCommandLine|GameAction \[AppID ${MSFS_APPID}\]" | tail -n 40 || true
exit 4
