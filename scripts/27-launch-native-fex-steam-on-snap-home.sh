#!/usr/bin/env bash
# Launch native Steam (under FEX) using Snap Steam HOME/state, outside Snap confinement.
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:3}"
RESOLUTION="${RESOLUTION:-1920x1080x24}"
SNAP_HOME="${SNAP_HOME:-$HOME/snap/steam/common}"
STEAM_LAUNCHER_DIR="${STEAM_LAUNCHER_DIR:-$HOME/fex-steam-native/steam-launcher}"

if [ ! -d "$STEAM_LAUNCHER_DIR" ]; then
  echo "ERROR: Missing Steam launcher dir: $STEAM_LAUNCHER_DIR"
  exit 2
fi

if [ ! -d "$SNAP_HOME/.local/share/Steam" ]; then
  echo "ERROR: Missing Snap Steam data dir under: $SNAP_HOME"
  exit 3
fi

pkill -x steamwebhelper >/dev/null 2>&1 || true
pkill -x steam >/dev/null 2>&1 || true

if ! pgrep -f "Xvfb ${DISPLAY_NUM}" >/dev/null; then
  Xvfb "$DISPLAY_NUM" -ac -screen 0 "$RESOLUTION" >/tmp/xvfb-native-steam.log 2>&1 &
  sleep 1
fi

if ! pgrep -x openbox >/dev/null; then
  DISPLAY="$DISPLAY_NUM" openbox >/tmp/openbox-native-steam.log 2>&1 &
  sleep 1
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$HOME/msfs-on-dgx-spark/output/native-fex-snaphome-$TS.log"
nohup env HOME="$SNAP_HOME" DISPLAY="$DISPLAY_NUM" XDG_RUNTIME_DIR="/run/user/$(id -u)" \
  dbus-run-session -- bash -lc "cd '$STEAM_LAUNCHER_DIR' && FEXBash -c ./steam -silent" >"$LOG" 2>&1 &

echo "Launched native Steam with Snap HOME."
echo "  DISPLAY=$DISPLAY_NUM"
echo "  LOG=$LOG"
