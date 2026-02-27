#!/usr/bin/env bash
# Mirror installed MSFS package tree into C: path, reset prefix, then retest with GE-Proton.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
COMPAT_ROOT="${COMPAT_ROOT:-$HOME/snap/steam/common/.steam/steam/steamapps/compatdata}"
COMPAT_DATA_PATH="$COMPAT_ROOT/$MSFS_APPID"
PFX="$COMPAT_DATA_PATH/pfx"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/msfs-on-dgx-spark/output}"
CFG_VDF="$STEAM_DIR/userdata/391443739/7/remote/sharedconfig.vdf"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUTPUT_DIR/cleanprefix-cpath-ge-$TS.log"

exec > >(tee -a "$LOG") 2>&1

SRC_PACKAGES="$STEAM_DIR/steamapps/common/MSFS2024/Packages"
DST_PACKAGES="$PFX/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/Packages"

echo "== cleanprefix + C: package mirror + GE retest =="
echo "ts=$TS"
echo "appid=$MSFS_APPID"

if [ ! -d "$SRC_PACKAGES" ]; then
  echo "ERROR: source package tree missing: $SRC_PACKAGES"
  exit 2
fi

pkill -f "snap/steam/.*/steam" || true
sleep 2

if [ -d "$COMPAT_DATA_PATH" ]; then
  mv "$COMPAT_DATA_PATH" "${COMPAT_DATA_PATH}.bak.$TS"
fi
mkdir -p "$DST_PACKAGES"

# Hardlink mirror avoids giant copy while preserving normal directory semantics for Wine.
cp -al "$SRC_PACKAGES"/. "$DST_PACKAGES"/
echo "cpath_top_dirs=$(find "$DST_PACKAGES" -mindepth 1 -maxdepth 1 -type d | wc -l)"

for cfg in \
  "$PFX/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/UserCfg.opt" \
  "$PFX/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator/UserCfg.opt"; do
  mkdir -p "$(dirname "$cfg")"
  cat > "$cfg" <<'EOF'
InstalledPackagesPath "C:\users\steamuser\AppData\Roaming\Microsoft Flight Simulator 2024\Packages"
PreferD3D12 0
EOF
done

"$HOME/msfs-on-dgx-spark/scripts/15-remap-proton-experimental-to-ge.sh"

if [ -f "$CFG_VDF" ]; then
  perl -0777 -i -pe 's/"LaunchOptions"\s+"[^"]*"/"LaunchOptions"\t\t"PROTON_LOG=1 PROTON_LOG_DIR=\/home\/th0rgal\/msfs-on-dgx-spark\/output STEAM_LINUX_RUNTIME_LOG=1 %command% -FastLaunch"/g' "$CFG_VDF"
fi

DISPLAY=:1 nohup steam >/tmp/steam-msfs.log 2>&1 &
sleep 14

"$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" || true
sleep 85

echo "-- content state tail --"
tail -n 120 "$STEAM_DIR/logs/content_log.txt" | grep -nE "$MSFS_APPID|App Running|state changed" | tail -n 40 || true
echo "-- console tail --"
tail -n 180 "$STEAM_DIR/logs/console_log.txt" | grep -nE "$MSFS_APPID|Game process (added|updated|removed)|ExecCommandLine|waitforexitandrun|failed" | tail -n 80 || true
echo "-- latest crash --"
find "$HOME" -type f -name "AsoboReport-Crash-$MSFS_APPID*.txt" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true
echo "log_path=$LOG"
