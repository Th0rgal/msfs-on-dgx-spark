#!/usr/bin/env bash
# Write or update Steam launch options for MSFS in sharedconfig.vdf.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
LAUNCH_OPTIONS="${LAUNCH_OPTIONS:-PROTON_LOG=1 PROTON_USE_WINED3D=1 PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 %command% -dx11 -FastLaunch}"

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

USERDATA_DIR="$(find "$STEAM_DIR/userdata" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
if [ -z "$USERDATA_DIR" ]; then
  echo "ERROR: No Steam userdata directory found under $STEAM_DIR/userdata"
  exit 2
fi

SHAREDCONFIG="$USERDATA_DIR/7/remote/sharedconfig.vdf"
if [ ! -f "$SHAREDCONFIG" ]; then
  echo "ERROR: sharedconfig.vdf missing: $SHAREDCONFIG"
  exit 3
fi

cp -f "$SHAREDCONFIG" "$SHAREDCONFIG.bak.$(date +%Y%m%d%H%M%S)"

awk -v appid="$MSFS_APPID" -v launch="$LAUNCH_OPTIONS" '
  BEGIN { in_target=0; seen_target=0; wrote_launch=0 }
  {
    if ($0 ~ "\"" appid "\"[[:space:]]*$") {
      in_target=1
      seen_target=1
      wrote_launch=0
      print
      next
    }

    if (in_target == 1) {
      if ($0 ~ /"LaunchOptions"[[:space:]]*"/) {
        next
      }
      if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) {
        print "\t\t\t\t\t\t\"LaunchOptions\"\t\t\"" launch "\""
        wrote_launch=1
        print
        in_target=0
        next
      }
    }

    print
  }
  END {
    if (seen_target == 0) {
      exit 11
    }
    if (wrote_launch == 0) {
      exit 12
    }
  }
' "$SHAREDCONFIG" > "$SHAREDCONFIG.tmp" || {
  rc=$?
  rm -f "$SHAREDCONFIG.tmp"
  if [ "$rc" -eq 11 ]; then
    echo "ERROR: AppID $MSFS_APPID block not found in $SHAREDCONFIG"
  elif [ "$rc" -eq 12 ]; then
    echo "ERROR: Could not write LaunchOptions for AppID $MSFS_APPID"
  else
    echo "ERROR: Failed to patch $SHAREDCONFIG (rc=$rc)"
  fi
  exit "$rc"
}

mv -f "$SHAREDCONFIG.tmp" "$SHAREDCONFIG"

echo "Updated launch options for AppID $MSFS_APPID in:"
echo "  $SHAREDCONFIG"
grep -n "\"$MSFS_APPID\"\\|LaunchOptions" "$SHAREDCONFIG" | sed -n '1,20p'
