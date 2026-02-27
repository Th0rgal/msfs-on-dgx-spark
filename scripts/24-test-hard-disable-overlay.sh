#!/usr/bin/env bash
set -euo pipefail

APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OVER32="$STEAM_DIR/ubuntu12_32/gameoverlayrenderer.so"
OVER64="$STEAM_DIR/ubuntu12_64/gameoverlayrenderer.so"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/msfs-on-dgx-spark/output/overlay-hardoff-cycle-${TS}.log"
CRASH_OUT="$HOME/msfs-on-dgx-spark/output/AsoboReport-Crash-2537590-hardoverlayoff-${TS}.txt"
CRASH_SRC="$STEAM_DIR/steamapps/compatdata/${APPID}/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"

B32="${OVER32}.bak.${TS}"
B64="${OVER64}.bak.${TS}"

restore_overlay() {
  [ -f "$B32" ] && mv -f "$B32" "$OVER32" || true
  [ -f "$B64" ] && mv -f "$B64" "$OVER64" || true
}
trap restore_overlay EXIT

{
  echo "== hard overlay-off cycle =="
  date -u +%FT%TZ
  echo "AppID=$APPID"
  echo "overlay32=$OVER32"
  echo "overlay64=$OVER64"

  [ -f "$OVER32" ] && mv -f "$OVER32" "$B32"
  [ -f "$OVER64" ] && mv -f "$OVER64" "$B64"
  echo "overlay moved to backups"

  "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" "steam://rungameid/${APPID}"

  sleep 55
  echo "-- process snapshot --"
  ps -ef | grep -E "FlightSimulator2024|steam-launch-wrapper.*${APPID}|proton waitforexitandrun" | grep -v grep || true

  echo "-- recent console lines --"
  tail -n 80 "$STEAM_DIR/logs/console_log.txt" | grep -E "${APPID}|overlay|preload|error|failed|crash|Game process" || true

  if [ -f "$CRASH_SRC" ]; then
    cp -f "$CRASH_SRC" "$CRASH_OUT"
    echo "-- crash summary --"
    grep -E "Code=|TimeUTC=|LastStates|NumRegisteredPackages|EnableD3D12" "$CRASH_SRC" || true
  else
    echo "-- crash summary --"
    echo "No AsoboReport-Crash.txt found at expected path"
  fi
} | tee "$OUT"

echo "$OUT"
