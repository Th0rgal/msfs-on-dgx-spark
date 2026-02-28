#!/usr/bin/env bash
# Clean-prefix Valve Experimental cycle with strict Vulkan loader layer disable controls.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="${REPO:-$HOME/msfs-on-dgx-spark}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
OUT_DIR="${OUT_DIR:-$REPO/output}"
WAIT_SECONDS="${WAIT_SECONDS:-150}"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID"
RUNFILE="$COMPAT_DIR/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-RunningSession.txt"
CRASHFILE="$COMPAT_DIR/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/valve-exp-vkloader-strict-layer-disable-cycle-$TS.log"
SHOT="$OUT_DIR/valve-exp-vkloader-strict-layer-disable-$TS.png"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"

mkdir -p "$OUT_DIR"

if [ ! -d "$REPO/scripts" ]; then
  echo "ERROR: Repo scripts dir not found: $REPO/scripts"
  exit 2
fi

if [ ! -d "$STEAM_DIR" ]; then
  echo "ERROR: Steam dir not found: $STEAM_DIR"
  exit 3
fi

{
  echo "== $(date -u +%FT%TZ) valve-exp strict vk-loader layer-disable cycle =="

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

  echo "[4/8] Verify Valve Proton Experimental and clean prefix"
  if [ -L "$EXP_DIR" ]; then
    echo "ERROR: $EXP_DIR is symlink; restore Valve install first"
    ls -ld "$EXP_DIR"
    exit 4
  fi
  rm -rf "$COMPAT_DIR"
  mkdir -p "$COMPAT_DIR"

  echo "[5/8] Set strict layer-disable launch options"
  launch_opts="PROTON_LOG=1 PROTON_LOG_DIR=$OUT_DIR VK_LOADER_LAYERS_DISABLE=~implicit~ DISABLE_VK_LAYER_VALVE_steam_overlay_1=1 DISABLE_VK_LAYER_MESA_device_select=1 VK_LAYER_PATH= VK_ADD_LAYER_PATH= PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0 PRESSURE_VESSEL_REMOVE_GAME_OVERLAY=1 %command% -FastLaunch"
  LAUNCH_OPTIONS="$launch_opts" "$REPO/scripts/28-set-localconfig-launch-options.sh"
  rm -f "$PROTON_LOG"

  echo "[6/8] Launch native Steam under FEX"
  DISPLAY_NUM="$DISPLAY_NUM" "$REPO/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 25

  echo "[7/8] Dispatch launch"
  WAIT_SECONDS="$WAIT_SECONDS" "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[8/8] Evidence collection"
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"
  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|waitforexitandrun|_v2-entry-point|Steam Linux Runtime" "$STEAM_DIR/logs/compat_log.txt" | tail -n 160 || true
  grep -nE "pressure-vessel-wrap|Internal error: .*vulkan|vkd3d_create_vk_device|Failed to create Vulkan device|D3D12CreateDevice|DXGI|Impossible to create DirectX12|Adding process|Removing process" "$STEAM_DIR/logs/console-linux.txt" | tail -n 280 || true
  if [ -f "$PROTON_LOG" ]; then
    grep -nE "Found device|vkd3d_create_vk_device|Failed to create Vulkan device|D3D12CreateDevice|Feature level|DXGI|vkCreate|err:vulkan|layer" "$PROTON_LOG" | tail -n 260 || true
  else
    echo "No proton log found: $PROTON_LOG"
  fi
  ls -lt "$RUNFILE" "$CRASHFILE" 2>/dev/null || true
  [ -f "$RUNFILE" ] && tail -n 120 "$RUNFILE" || true
  [ -f "$CRASHFILE" ] && tail -n 120 "$CRASHFILE" || true
  pgrep -af "FlightSimulator2024.exe|proton waitforexitandrun|wineserver|steam-launch-wrapper|pv-bwrap|pressure-vessel" | sed -n "1,100p" || true
  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
