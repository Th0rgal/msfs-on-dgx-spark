#!/usr/bin/env bash
# Hard-disable Steam overlay in native FEX runtime and retest MSFS launch.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
PROTON="$EXP_DIR/proton"
REAL="$EXP_DIR/proton.real"
OUT_DIR="${OUT_DIR:-$HOME/msfs-on-dgx-spark/output}"
WAIT_SECONDS="${WAIT_SECONDS:-95}"

OV32="$STEAM_DIR/ubuntu12_32/gameoverlayrenderer.so"
OV64="$STEAM_DIR/ubuntu12_64/gameoverlayrenderer.so"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/native-no-overlay-cycle-$TS.log"
SHOT="$OUT_DIR/native-no-overlay-$TS.png"

restore_overlay() {
  [ -f "$OV32.bak" ] && mv -f "$OV32.bak" "$OV32" || true
  [ -f "$OV64.bak" ] && mv -f "$OV64.bak" "$OV64" || true
}

trap restore_overlay EXIT
mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) native-no-overlay cycle =="

  echo "[1/7] Ensure userns + FEX thunks"
  "$HOME/msfs-on-dgx-spark/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/7] Stop running MSFS/Steam game session"
  pkill -f FlightSimulator2024.exe || true
  pkill -f "AppId=2537590" || true
  sleep 2

  echo "[3/7] Hard-disable overlay renderer shared objects"
  [ -f "$OV32" ] && mv -f "$OV32" "$OV32.bak"
  [ -f "$OV64" ] && mv -f "$OV64" "$OV64.bak"
  ls -l "$OV32"* "$OV64"* || true

  echo "[4/7] Launch native FEX Steam"
  "$HOME/msfs-on-dgx-spark/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 12

  echo "[5/7] Install proton wrapper that strips LD_PRELOAD"
  if [ ! -f "$REAL" ]; then
    mv -f "$PROTON" "$REAL"
  fi
  cat > "$PROTON" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REAL="$SELF_DIR/proton.real"
unset LD_PRELOAD
export PROTON_ENABLE_WAYLAND=0
export VKD3D_CONFIG=nodxr
export VKD3D_FEATURE_LEVEL=12_0
exec "$REAL" "$@"
WRAP
  chmod +x "$PROTON"

  echo "[6/7] Dispatch launch"
  WAIT_SECONDS="$WAIT_SECONDS" "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[7/7] Capture state"
  if command -v import >/dev/null; then
    DISPLAY=:3 import -window root "$SHOT" || true
    echo "screenshot: $SHOT"
  fi
  echo "--- compat lines"
  grep -nE 'Game process added|Game process removed|StartSession|gameoverlayrenderer|AppID 2537590 state changed' "$STEAM_DIR/logs/console_log.txt" | tail -n 120 || true
  pgrep -af FlightSimulator2024.exe || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
