#!/usr/bin/env bash
# Set per-app Steam LaunchOptions in localconfig.vdf (effective for Steam game launches).
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
LAUNCH_OPTIONS="${LAUNCH_OPTIONS:-PROTON_LOG=1 PROTON_LOG_DIR=/home/th0rgal/msfs-on-dgx-spark/output STEAM_LINUX_RUNTIME_LOG=1 %command% -dx11 -FastLaunch}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"

USERDATA_DIR="$(find "$STEAM_DIR/userdata" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
if [ -z "$USERDATA_DIR" ]; then
  echo "ERROR: No Steam userdata directory found under $STEAM_DIR/userdata"
  exit 2
fi

LOCALCONFIG="$USERDATA_DIR/config/localconfig.vdf"
if [ ! -f "$LOCALCONFIG" ]; then
  echo "ERROR: localconfig.vdf missing: $LOCALCONFIG"
  exit 3
fi

cp -f "$LOCALCONFIG" "$LOCALCONFIG.bak.$(date +%Y%m%d%H%M%S)"

awk -v appid="$MSFS_APPID" -v launch="$LAUNCH_OPTIONS" '
  BEGIN { in_target=0; seen_target=0; wrote=0 }
  {
    if ($0 ~ "\"" appid "\"[[:space:]]*$") {
      in_target=1
      seen_target=1
      wrote=0
      print
      next
    }

    if (in_target == 1) {
      if ($0 ~ /"LaunchOptions"[[:space:]]*"/) {
        next
      }
      if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) {
        print "\t\t\t\t\t\t\t\t\"LaunchOptions\"\t\t\"" launch "\""
        wrote=1
        print
        in_target=0
        next
      }
    }

    print
  }
  END {
    if (seen_target == 0) exit 11
    if (wrote == 0) exit 12
  }
' "$LOCALCONFIG" > "$LOCALCONFIG.tmp" || {
  rc=$?
  rm -f "$LOCALCONFIG.tmp"
  echo "ERROR: Failed to patch localconfig.vdf (rc=$rc)"
  exit "$rc"
}

mv -f "$LOCALCONFIG.tmp" "$LOCALCONFIG"

echo "Updated localconfig launch options:"
echo "  file=$LOCALCONFIG"
grep -nE "2537590|LaunchOptions" "$LOCALCONFIG" | sed -n "1,40p"
