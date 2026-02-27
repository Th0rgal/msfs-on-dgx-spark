#!/usr/bin/env bash
# Clean Valve Proton Experimental test: remove wrapper contamination, force launch opts,
# and test SLR bypass + seccomp disable in one reproducible cycle.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
PROTON="$EXP_DIR/proton"
REAL="$EXP_DIR/proton.real"
OUT_DIR="${OUT_DIR:-$HOME/msfs-on-dgx-spark/output}"
WAIT_SECONDS="${WAIT_SECONDS:-95}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/clean-valve-slr0-seccomp-$TS.log"
PROTON_LOG="$OUT_DIR/steam-$MSFS_APPID.log"

mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) clean-valve-slr0-seccomp =="

  echo "[1/7] Ensure userns+FEX thunk config"
  "$HOME/msfs-on-dgx-spark/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/7] Launch native FEX Steam on snap HOME"
  "$HOME/msfs-on-dgx-spark/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 12

  echo "[3/7] Restore pristine Proton Experimental binary (remove wrapper if present)"
  if [ -f "$REAL" ]; then
    cp -f "$REAL" "$PROTON"
    chmod +x "$PROTON"
    echo "Restored $PROTON from proton.real"
  else
    echo "No proton.real found; Proton likely already pristine"
  fi
  head -n 5 "$PROTON" || true

  echo "[4/7] Set localconfig LaunchOptions for this app"
  launch_opts='STEAM_LINUX_RUNTIME=0 WINE_DISABLE_SECCOMP=1 PROTON_LOG=1 PROTON_LOG_DIR=/home/th0rgal/msfs-on-dgx-spark/output STEAM_LINUX_RUNTIME_LOG=1 %command% -FastLaunch'
  LAUNCH_OPTIONS="$launch_opts" "$HOME/msfs-on-dgx-spark/scripts/28-set-localconfig-launch-options.sh"

  echo "[5/7] Clear old proton log"
  rm -f "$PROTON_LOG"

  echo "[6/7] Dispatch launch via steam pipe"
  WAIT_SECONDS="$WAIT_SECONDS" "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[7/7] Post-checks"
  echo "--- compat_log tail"
  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|Proton Experimental|Steam Linux Runtime" "$STEAM_DIR/logs/compat_log.txt" | tail -n 80 || true

  echo "--- latest proton log header"
  if [ -f "$PROTON_LOG" ]; then
    sed -n '1,40p' "$PROTON_LOG"
    echo "--- seccomp markers in proton log"
    grep -nE "install_bpf|PR_SET_SECCOMP|WINE_DISABLE_SECCOMP|pressure-vessel|sniper" "$PROTON_LOG" | head -n 120 || true
    echo "--- dxgi markers in proton log"
    grep -nE "dxgi|DirectX12|0x80070057|vkCreateInstance|Failed to initialize DXVK" "$PROTON_LOG" | head -n 160 || true
  else
    echo "No proton log found at $PROTON_LOG"
  fi

  echo "--- runtime process check"
  pgrep -af FlightSimulator2024.exe || true
  pgrep -af wineserver || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
