#!/usr/bin/env bash
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="$HOME/msfs-on-dgx-spark"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
OUT_DIR="$REPO/output"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
WAIT_SECONDS="${WAIT_SECONDS:-180}"
CACHY_TOOL="${CACHY_TOOL:-proton-cachyos-10.0-20260207-slr-arm64}"
CACHY_DIR="$STEAM_DIR/compatibilitytools.d/$CACHY_TOOL"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
COMPAT_DIR="$STEAM_DIR/steamapps/compatdata/$MSFS_APPID"
RUNFILE="$COMPAT_DIR/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-RunningSession.txt"
CRASHFILE="$COMPAT_DIR/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="$OUT_DIR/cachyos-cleanprefix-display2-cycle-$TS.log"
SHOT="$OUT_DIR/cachyos-cleanprefix-display2-$TS.png"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"
BAK_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental.cachybak-$TS"
CACHY_PROTON="$CACHY_DIR/proton"
CACHY_PROTON_REAL="$CACHY_DIR/proton.real"

mkdir -p "$OUT_DIR"

restore_all() {
  if [ -f "$CACHY_PROTON_REAL" ]; then
    mv -f "$CACHY_PROTON_REAL" "$CACHY_PROTON" || true
  fi
  if [ -d "$BAK_DIR" ]; then
    rm -rf "$EXP_DIR" || true
    mv "$BAK_DIR" "$EXP_DIR" || true
  fi
}
trap restore_all EXIT

{
  echo "== $(date -u +%FT%TZ) cachyos cleanprefix display2 cycle =="
  echo "CACHY_TOOL=$CACHY_TOOL"
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh"
  LAUNCH_OPTIONS="%command%" "$REPO/scripts/28-set-localconfig-launch-options.sh"

  "$REPO/scripts/20-fix-cachyos-compat.sh"

  if [ ! -d "$CACHY_DIR" ]; then
    echo "ERROR: missing CACHY_DIR=$CACHY_DIR"
    exit 2
  fi

  if [ -e "$EXP_DIR" ] && [ ! -L "$EXP_DIR" ]; then
    mv "$EXP_DIR" "$BAK_DIR"
  fi
  ln -sfn "$CACHY_DIR" "$EXP_DIR"
  ls -ld "$EXP_DIR"

  echo "[wrapper] adding PROTON_LOG for appid only"
  if [ -f "$CACHY_PROTON" ] && [ ! -f "$CACHY_PROTON_REAL" ]; then
    mv "$CACHY_PROTON" "$CACHY_PROTON_REAL"
    cat > "$CACHY_PROTON" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REAL="$SELF_DIR/proton.real"
APPID="${SteamAppId:-${STEAM_COMPAT_APP_ID:-}}"
if [ "$APPID" = "2537590" ]; then
  export PROTON_LOG=1
  export PROTON_LOG_DIR="$HOME/msfs-on-dgx-spark/output"
  export STEAM_LINUX_RUNTIME_LOG=1
fi
exec "$REAL" "$@"
WRAP
    chmod +x "$CACHY_PROTON"
  fi

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

  rm -f "$PROTON_LOG" "$PROTON_LOG".* || true
  WAIT_SECONDS="$WAIT_SECONDS" "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true

  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"

  echo "--- compat markers"
  grep -nE "StartSession: appID $MSFS_APPID|proton-cachyos|waitforexitandrun|Game process added|Game process updated|Game process removed|Tool 4185400 unknown" "$STEAM_DIR/logs/compat_log.txt" | tail -n 260 || true

  echo "--- proton markers"
  ls -lt "$OUT_DIR"/steam-$MSFS_APPID.log* 2>/dev/null || true
  if [ -f "$PROTON_LOG" ]; then
    grep -nE "vkd3d_create_vk_device|Failed to create Vulkan device|D3D12CreateDevice|DXGI|wine_vkCreateInstance|Found device|err:" "$PROTON_LOG" | tail -n 320 || true
    tail -n 180 "$PROTON_LOG" || true
  fi

  echo "--- running/crash files"
  ls -lt "$RUNFILE" "$CRASHFILE" 2>/dev/null || true
  [ -f "$RUNFILE" ] && tail -n 140 "$RUNFILE" || true
  [ -f "$CRASHFILE" ] && tail -n 140 "$CRASHFILE" || true

  echo "== done =="
} | tee "$LOG"

echo "$LOG"
