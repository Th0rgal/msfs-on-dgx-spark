#!/usr/bin/env bash
set -euo pipefail
MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="$HOME/msfs-on-dgx-spark"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OUT_DIR="$REPO/output"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
C="$STEAM_DIR/compatibilitytools.d/proton-cachyos-10.0-20260207-slr-arm64"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUT_DIR/cachyos-layoutfix-cycle-$TS.log"
SHOT="$OUT_DIR/cachyos-layoutfix-$TS.png"

mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) cachyos layout-fix cycle =="
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh"
  LAUNCH_OPTIONS="%command%" "$REPO/scripts/28-set-localconfig-launch-options.sh"
  "$REPO/scripts/20-fix-cachyos-compat.sh"

  echo "[layout symlink fixes]"
  cd "$C"
  [ -e files/share/default_pfx ] || ln -s default_pfx_arm64 files/share/default_pfx
  [ -e files/bin ] || ln -s bin-arm64 files/bin
  [ -e files/lib64 ] || ln -s lib files/lib64
  [ -e files/lib64/wine ] || ln -s ../lib/wine files/lib64/wine
  ls -ld files/share/default_pfx files/bin files/lib64 files/lib64/wine

  ln -sfn "$C" "$EXP_DIR"
  ls -ld "$EXP_DIR"

  echo "[clean prefix]"
  rm -rf "$COMPAT_DIR"
  mkdir -p "$COMPAT_DIR"

  echo "[recycle + launch]"
  pkill -f FlightSimulator2024.exe || true
  pkill -f "AppId=$MSFS_APPID" || true
  pkill -x steamwebhelper >/dev/null 2>&1 || true
  pkill -x steam >/dev/null 2>&1 || true
  sleep 2

  DISPLAY="$DISPLAY_NUM" xrandr --setmonitor HEADLESS 1920/520x1080/320+0+0 none 2>/dev/null || true
  DISPLAY_NUM="$DISPLAY_NUM" "$REPO/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 25

  WAIT_SECONDS="$WAIT_SECONDS" "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"

  echo "--- key console-linux markers"
  tail -n 340 "$STEAM_DIR/logs/console-linux.txt" | grep -nE "\[2026-02-28|Default prefix is missing|c0000135|D3D12|DXGI|vkd3d_create_vk_device|Failed to create Vulkan device|wine: failed|Adding process|Removing process" || true

  echo "--- compatdata tree"
  find "$COMPAT_DIR" -maxdepth 3 -type d | sed -n '1,100p' || true

  echo "== done =="
} | tee "$LOG"

echo "$LOG"
