#!/usr/bin/env bash
# Force pressure-vessel Vulkan layer import off by wrapping sniper _v2-entry-point.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="$HOME/msfs-on-dgx-spark"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OUT_DIR="$REPO/output"
WAIT_SECONDS="${WAIT_SECONDS:-150}"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
SNIPER_EP="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"
SNIPER_EP_REAL="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point.real"
RUNFILE="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-RunningSession.txt"
CRASHFILE="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/sniper-entrypoint-vklayeroff-cycle-$TS.log"
SHOT="$OUT_DIR/sniper-entrypoint-vklayeroff-$TS.png"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"

mkdir -p "$OUT_DIR"

restore_entrypoint() {
  if [ -f "$SNIPER_EP_REAL" ]; then
    cp -f "$SNIPER_EP_REAL" "$SNIPER_EP" || true
    chmod +x "$SNIPER_EP" || true
  fi
}
trap restore_entrypoint EXIT

{
  echo "== $(date -u +%FT%TZ) sniper-entrypoint force vk-layer-off cycle =="

  echo "[1/8] Ensure userns + FEX thunks"
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/8] Kill stale processes"
  pkill -f FlightSimulator2024.exe || true
  pkill -f "AppId=$MSFS_APPID" || true
  pkill -x steamwebhelper >/dev/null 2>&1 || true
  pkill -x steam >/dev/null 2>&1 || true
  sleep 2

  echo "[3/8] Install entrypoint wrapper with forced pressure-vessel env"
  if [ ! -f "$SNIPER_EP_REAL" ]; then
    cp -f "$SNIPER_EP" "$SNIPER_EP_REAL"
  fi
  cat > "$SNIPER_EP" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
export PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0
export PRESSURE_VESSEL_REMOVE_GAME_OVERLAY=1
export VK_LOADER_LAYERS_DISABLE='*'
exec "$HOME/snap/steam/common/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point.real" "$@"
WRAP
  chmod +x "$SNIPER_EP"
  head -n 20 "$SNIPER_EP"

  echo "[4/8] Set minimal launch options and clear proton log"
  launch_opts="PROTON_LOG=1 PROTON_LOG_DIR=$OUT_DIR %command% -FastLaunch"
  LAUNCH_OPTIONS="$launch_opts" "$REPO/scripts/28-set-localconfig-launch-options.sh"
  rm -f "$PROTON_LOG"

  echo "[5/8] Ensure NVIDIA display and launch native FEX Steam"
  DISPLAY="$DISPLAY_NUM" xrandr --setmonitor HEADLESS 1920/520x1080/320+0+0 none 2>/dev/null || true
  DISPLAY_NUM="$DISPLAY_NUM" "$REPO/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 25

  echo "[6/8] Dispatch launch"
  WAIT_SECONDS="$WAIT_SECONDS" "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[7/8] Evidence collection"
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"
  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|waitforexitandrun|_v2-entry-point|Steam Linux Runtime" "$STEAM_DIR/logs/compat_log.txt" | tail -n 180 || true
  grep -nE "pressure-vessel-wrap|Internal error: .*vulkan|Adding process|Removing process|D3D12|DXGI|vkd3d_create_vk_device|Failed to create Vulkan device|Impossible to create DirectX12|Proton:" "$STEAM_DIR/logs/console-linux.txt" | tail -n 280 || true
  if [ -f "$PROTON_LOG" ]; then
    grep -nE "Found device|vkd3d_create_vk_device|Failed to create Vulkan device|D3D12CreateDevice|Feature level|DXGI|vkCreate|err:vulkan" "$PROTON_LOG" | tail -n 260 || true
  else
    echo "No proton log found: $PROTON_LOG"
  fi
  ls -lt "$RUNFILE" "$CRASHFILE" 2>/dev/null || true
  [ -f "$RUNFILE" ] && tail -n 120 "$RUNFILE" || true
  [ -f "$CRASHFILE" ] && tail -n 120 "$CRASHFILE" || true

  echo "[8/8] Process snapshot"
  pgrep -af "FlightSimulator2024.exe|proton waitforexitandrun|wineserver|steam-launch-wrapper|pv-bwrap|pressure-vessel" | sed -n "1,100p" || true
  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
