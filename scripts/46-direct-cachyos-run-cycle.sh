#!/usr/bin/env bash
set -euo pipefail
TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPO="$HOME/msfs-on-dgx-spark"
OUT="$REPO/output"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
TOOL="$STEAM_DIR/compatibilitytools.d/proton-cachyos-10.0-20260207-slr-arm64/proton"
APPID=2537590
COMPAT="$STEAM_DIR/steamapps/compatdata/$APPID"
EXE="$STEAM_DIR/steamapps/common/MSFS2024/FlightSimulator2024.exe"
LOG="$OUT/direct-cachyos-run-$TS.log"
SHOT="$OUT/direct-cachyos-run-$TS.png"
mkdir -p "$OUT"

pkill -f FlightSimulator2024.exe >/dev/null 2>&1 || true
sleep 2

env DISPLAY=:2 \
  SteamAppId=$APPID \
  STEAM_COMPAT_APP_ID=$APPID \
  STEAM_COMPAT_DATA_PATH=$COMPAT \
  STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_DIR \
  PROTON_LOG=1 \
  PROTON_LOG_DIR=$OUT \
  timeout 180 "$TOOL" waitforexitandrun "$EXE" > "$LOG" 2>&1 || true

DISPLAY=:2 import -window root "$SHOT" 2>/dev/null || true

echo "LOG=$LOG"
echo "SHOT=$SHOT"
tail -n 300 "$LOG" | grep -nE "vkd3d_create_vk_device|D3D12CreateDevice|DXGI|Impossible to create DirectX12|wine: failed|err:|Found device|Default prefix|CrashReport|FrameCount|LastStates|C0000005" || true
pgrep -fa FlightSimulator2024.exe || true
