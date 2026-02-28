#!/usr/bin/env bash
# Test forcing launcher service to proton and disabling imported Vulkan layers.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="$HOME/msfs-on-dgx-spark"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OUT_DIR="$REPO/output"
WAIT_SECONDS="${WAIT_SECONDS:-150}"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
RUNFILE="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-RunningSession.txt"
CRASHFILE="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/launchsvc-proton-vklayersoff-cycle-$TS.log"
SHOT="$OUT_DIR/launchsvc-proton-vklayersoff-$TS.png"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"

mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) launcher-service=proton + vk-layers-off cycle =="

  echo "[1/8] Ensure userns + FEX thunks"
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/8] Ensure NVIDIA display has a virtual monitor"
  DISPLAY="$DISPLAY_NUM" xrandr --setmonitor HEADLESS 1920/520x1080/320+0+0 none 2>/dev/null || true
  DISPLAY="$DISPLAY_NUM" xrandr --listmonitors || true

  echo "[3/8] Kill stale processes"
  pkill -f FlightSimulator2024.exe || true
  pkill -f "AppId=$MSFS_APPID" || true
  pkill -x steamwebhelper >/dev/null 2>&1 || true
  pkill -x steam >/dev/null 2>&1 || true
  sleep 2

  echo "[4/8] Set launch options to force proton launcher service and disable host Vulkan layer import"
  launch_opts="PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0 PRESSURE_VESSEL_REMOVE_GAME_OVERLAY=1 STEAM_COMPAT_LAUNCHER_SERVICE=proton PROTON_LOG=1 PROTON_LOG_DIR=$OUT_DIR %command% -FastLaunch"
  LAUNCH_OPTIONS="$launch_opts" "$REPO/scripts/28-set-localconfig-launch-options.sh"

  echo "[5/8] Launch native Steam under FEX on $DISPLAY_NUM"
  DISPLAY_NUM="$DISPLAY_NUM" "$REPO/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 25

  echo "[6/8] Dispatch launch"
  rm -f "$PROTON_LOG"
  WAIT_SECONDS="$WAIT_SECONDS" "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[7/8] Evidence collection"
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"

  echo "--- compat markers"
  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|waitforexitandrun|_v2-entry-point|Steam Linux Runtime|proton run|launcher_service|PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS" "$STEAM_DIR/logs/compat_log.txt" | tail -n 180 || true

  echo "--- console markers"
  grep -nE "pressure-vessel-wrap|Internal error: .*vulkan|Adding process|Removing process|D3D12|DXGI|vkd3d_create_vk_device|Failed to create Vulkan device|Impossible to create DirectX12|Proton:|Game process added|Game process removed" "$STEAM_DIR/logs/console-linux.txt" | tail -n 260 || true

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

  echo "[8/8] Process snapshot"
  pgrep -af "FlightSimulator2024.exe|proton waitforexitandrun|wineserver|steam-launch-wrapper|pv-bwrap|pressure-vessel" | sed -n "1,100p" || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
