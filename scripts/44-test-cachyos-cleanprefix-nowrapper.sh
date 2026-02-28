#!/usr/bin/env bash
set -euo pipefail
MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="$HOME/msfs-on-dgx-spark"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OUT_DIR="$REPO/output"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
WAIT_SECONDS="${WAIT_SECONDS:-150}"
CACHY_TOOL="${CACHY_TOOL:-proton-cachyos-10.0-20260207-slr-arm64}"
CACHY_DIR="$STEAM_DIR/compatibilitytools.d/$CACHY_TOOL"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUT_DIR/cachyos-cleanprefix-nowrapper-cycle-$TS.log"
SHOT="$OUT_DIR/cachyos-cleanprefix-nowrapper-$TS.png"

mkdir -p "$OUT_DIR"
{
  echo "== $(date -u +%FT%TZ) cachyos cleanprefix no-wrapper =="
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh"
  LAUNCH_OPTIONS="%command%" "$REPO/scripts/28-set-localconfig-launch-options.sh"
  "$REPO/scripts/20-fix-cachyos-compat.sh"

  ln -sfn "$CACHY_DIR" "$EXP_DIR"
  ls -ld "$EXP_DIR"

  echo "[clean prefix]"
  rm -rf "$COMPAT_DIR"
  mkdir -p "$COMPAT_DIR"

  echo "[process recycle]"
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

  echo "--- console markers"
  tail -n 260 "$STEAM_DIR/logs/console_log.txt" | grep -nE "AppID $MSFS_APPID|CreatingProcess|Game process (added|updated|removed)|AppError|failed" || true
  echo "--- console-linux markers"
  tail -n 320 "$STEAM_DIR/logs/console-linux.txt" | grep -nE "\[2026-02-28|Proton: Default prefix|c0000135|D3D12|DXGI|vkd3d|Game Recording|Adding process|Removing process|error|failed" || true
  echo "--- gameprocess markers"
  tail -n 220 "$STEAM_DIR/logs/gameprocess_log.txt" | grep -nE "$MSFS_APPID|Remove 2537590|exit code" || true

  echo "--- compatdata state"
  ls -la "$COMPAT_DIR" || true
  find "$COMPAT_DIR" -maxdepth 3 -type d | sed -n '1,80p' || true

  echo "== done =="
} | tee "$LOG"

echo "$LOG"
