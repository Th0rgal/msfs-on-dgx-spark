#!/usr/bin/env bash
# Test whether disabling present_id/present_wait avoids vkd3d vkCreateDevice vr -3.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
PROTON="$EXP_DIR/proton"
REAL="$EXP_DIR/proton.real"
OUT_DIR="${OUT_DIR:-$HOME/msfs-on-dgx-spark/output}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/vkd3d-presentid-disable-cycle-$TS.log"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"

mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) vkd3d-presentid-disable cycle =="

  echo "[1/6] Ensure userns + FEX Vulkan thunks"
  "$HOME/msfs-on-dgx-spark/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/6] Launch native FEX Steam on Snap HOME"
  "$HOME/msfs-on-dgx-spark/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 12

  echo "[3/6] Ensure proton.real exists"
  if [ ! -f "$REAL" ]; then
    mv -f "$PROTON" "$REAL"
  fi

  echo "[4/6] Install wrapper (unconditional env injection)"
  cat > "$PROTON" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REAL="$SELF_DIR/proton.real"

export PROTON_LOG=1
export PROTON_LOG_DIR="/home/th0rgal/msfs-on-dgx-spark/output"
export STEAM_LINUX_RUNTIME_LOG=1
export PROTON_ENABLE_WAYLAND=0
export VKD3D_FEATURE_LEVEL=12_0
export VKD3D_CONFIG=nodxr
export VKD3D_DISABLE_EXTENSIONS="VK_KHR_present_id,VK_KHR_present_wait,VK_NVX_binary_import,VK_NVX_image_view_handle"
exec "$REAL" "$@"
WRAP
  chmod +x "$PROTON"
  head -n 60 "$PROTON" || true

  echo "[5/6] Dispatch launch"
  rm -f "$PROTON_LOG"
  WAIT_SECONDS="$WAIT_SECONDS" "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[6/6] Collect evidence"
  if [ -f "$PROTON_LOG" ]; then
    echo "--- relevant proton markers"
    grep -nE 'Found device|vkd3d_create_vk_device|Failed to create Vulkan device|D3D12CreateDevice|DXGI|vkCreateInstance|VK_KHR_present|err:vulkan|Unhandled VkResult|steam.exe.*FlightSimulator2024' "$PROTON_LOG" | tail -n 260 || true
  else
    echo "No proton log found at $PROTON_LOG"
  fi

  echo "--- latest Asobo running/crash markers"
  ls -1t "$OUT_DIR"/AsoboReport-RunningSession*.txt "$OUT_DIR"/AsoboReport-Crash-2537590*.txt 2>/dev/null | head -n 6 || true

  echo "--- process state"
  pgrep -af FlightSimulator2024.exe || true
  pgrep -af wineserver || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
