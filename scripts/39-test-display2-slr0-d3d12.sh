#!/usr/bin/env bash
# Test native FEX Steam launch on NVIDIA Xorg (:2) with Steam Linux Runtime disabled.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="$HOME/msfs-on-dgx-spark"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OUT_DIR="$REPO/output"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
RUNFILE="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-RunningSession.txt"
CRASHFILE="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/display2-slr0-d3d12-cycle-$TS.log"
SHOT="$OUT_DIR/display2-slr0-d3d12-$TS.png"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"

mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) display2-slr0-d3d12 cycle =="

  echo "[1/9] Ensure userns + FEX thunks"
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/9] Ensure NVIDIA display has a virtual monitor"
  DISPLAY="$DISPLAY_NUM" xrandr --setmonitor HEADLESS 1920/520x1080/320+0+0 none 2>/dev/null || true
  DISPLAY="$DISPLAY_NUM" xrandr --listmonitors || true

  echo "[3/9] Kill stale processes"
  pkill -f FlightSimulator2024.exe || true
  pkill -f "AppId=$MSFS_APPID" || true
  pkill -x steamwebhelper >/dev/null 2>&1 || true
  pkill -x steam >/dev/null 2>&1 || true
  sleep 2

  echo "[4/9] Restore pristine Proton Experimental"
  EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
  if [ -f "$EXP_DIR/proton.real" ]; then
    cp -f "$EXP_DIR/proton.real" "$EXP_DIR/proton"
    chmod +x "$EXP_DIR/proton"
  fi
  head -n 5 "$EXP_DIR/proton" || true

  echo "[5/9] Force localconfig launch options (SLR=0, D3D12 default)"
  launch_opts="STEAM_LINUX_RUNTIME=0 PROTON_LOG=1 PROTON_LOG_DIR=/home/th0rgal/msfs-on-dgx-spark/output STEAM_LINUX_RUNTIME_LOG=1 %command% -FastLaunch"
  LAUNCH_OPTIONS="$launch_opts" "$REPO/scripts/28-set-localconfig-launch-options.sh"

  echo "[6/9] Launch native Steam under FEX on display $DISPLAY_NUM"
  DISPLAY_NUM="$DISPLAY_NUM" "$REPO/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 25

  echo "[7/9] Dispatch launch"
  rm -f "$PROTON_LOG"
  WAIT_SECONDS="$WAIT_SECONDS" "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[8/9] Evidence collection"
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"

  echo "--- compat markers"
  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|waitforexitandrun|Proton - Experimental|Steam Linux Runtime" "$STEAM_DIR/logs/compat_log.txt" | tail -n 120 || true

  echo "--- proton markers"
  if [ -f "$PROTON_LOG" ]; then
    grep -nE "Found device|vkd3d_create_vk_device|Failed to create Vulkan device|D3D12CreateDevice|Feature level|DXGI|vkCreate|err:vulkan|OpenXR|monitor|state" "$PROTON_LOG" | tail -n 260 || true
  else
    echo "No proton log found: $PROTON_LOG"
  fi

  echo "--- running/crash session files"
  ls -lt "$RUNFILE" "$CRASHFILE" 2>/dev/null || true
  [ -f "$RUNFILE" ] && tail -n 120 "$RUNFILE" || true
  [ -f "$CRASHFILE" ] && tail -n 120 "$CRASHFILE" || true

  echo "[9/9] Process snapshot"
  pgrep -af "FlightSimulator2024.exe|proton waitforexitandrun|wineserver|steam-launch-wrapper" | sed -n "1,80p" || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
