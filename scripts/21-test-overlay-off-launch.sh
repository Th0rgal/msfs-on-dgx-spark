#!/usr/bin/env bash
# Disable Steam overlay for MSFS in sharedconfig and run one launch cycle via steam.pipe.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-75}"
OUTDIR="${OUTDIR:-$HOME/msfs-on-dgx-spark/output}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUTDIR"

find_steam_dir() {
  local paths=(
    "$HOME/snap/steam/common/.local/share/Steam"
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
  )
  local p
  for p in "${paths[@]}"; do
    [ -d "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

STEAM_DIR="$(find_steam_dir)"
USERDATA_DIR="$(find "$STEAM_DIR/userdata" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
SHAREDCONFIG="$USERDATA_DIR/7/remote/sharedconfig.vdf"
cp -f "$SHAREDCONFIG" "$SHAREDCONFIG.bak.$TS"

awk -v appid="$MSFS_APPID" '
  BEGIN { in_target=0 }
  {
    if ($0 ~ "\"" appid "\"[[:space:]]*$") {
      in_target=1
      print
      next
    }
    if (in_target == 1) {
      if ($0 ~ /"OverlayAppEnable"[[:space:]]*"/) {
        print "\t\t\t\t\t\t\"OverlayAppEnable\"\t\t\"0\""
        next
      }
      if ($0 ~ /^[[:space:]]*}[[:space:]]*$/) {
        print "\t\t\t\t\t\t\"OverlayAppEnable\"\t\t\"0\""
        print
        in_target=0
        next
      }
    }
    print
  }
  END {
    if (in_target == 1) { exit 12 }
  }
' "$SHAREDCONFIG" > "$SHAREDCONFIG.tmp"
mv -f "$SHAREDCONFIG.tmp" "$SHAREDCONFIG"

echo "[1/5] Overlay flag now:"
grep -n "\"$MSFS_APPID\"\|OverlayAppEnable\|LaunchOptions" "$SHAREDCONFIG" | head -n 30 | tee "$OUTDIR/overlay-off-sharedconfig-${TS}.log"

echo "[2/5] Setting minimal launch options"
LAUNCH_OPTIONS='PROTON_LOG=1 PROTON_LOG_DIR=/home/th0rgal/msfs-on-dgx-spark/output %command%' MSFS_APPID="$MSFS_APPID" "$(dirname "$0")/12-set-msfs-launch-options.sh" | tee "$OUTDIR/overlay-off-setopts-${TS}.log"

echo "[3/5] Dispatching launch"
MSFS_APPID="$MSFS_APPID" WAIT_SECONDS=15 "$(dirname "$0")/19-dispatch-via-steam-pipe.sh" | tee "$OUTDIR/overlay-off-dispatch-${TS}.log" || true

echo "[4/5] Runtime watch"
{
  echo "UTC_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for i in $(seq 1 "$WAIT_SECONDS"); do
    ps -ef | grep -E "FlightSimulator2024\\.exe|steam-launch-wrapper|waitforexitandrun" | grep -v grep || true
    sleep 1
  done
  echo "UTC_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUTDIR/overlay-off-runtime-${TS}.log"

echo "[5/5] Crash snapshot"
CRASH_SRC="$HOME/snap/steam/common/.local/share/Steam/steamapps/compatdata/${MSFS_APPID}/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"
if [ -f "$CRASH_SRC" ]; then
  cp -f "$CRASH_SRC" "$OUTDIR/AsoboReport-Crash-${MSFS_APPID}-overlayoff-${TS}.txt"
  grep -E "Code=|TimeUTC=|EnableD3D12=|VideoMemoryBudget=|LastStates=|NumRegisteredPackages=" "$OUTDIR/AsoboReport-Crash-${MSFS_APPID}-overlayoff-${TS}.txt" || true
fi

echo "Done: $TS"
