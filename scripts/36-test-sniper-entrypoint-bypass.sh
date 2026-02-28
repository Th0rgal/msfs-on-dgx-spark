#!/usr/bin/env bash
# Test bypassing SteamLinuxRuntime_sniper container entrypoint for MSFS launch.
# This is a reversible A/B intended to isolate pressure-vessel as the DX12 init blocker.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
OUT_DIR="${OUT_DIR:-$HOME/msfs-on-dgx-spark/output}"
WAIT_SECONDS="${WAIT_SECONDS:-110}"
SNIPER_EP="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point"
SNIPER_EP_REAL="$STEAM_DIR/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point.real"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/sniper-entrypoint-bypass-cycle-$TS.log"
SS="$OUT_DIR/sniper-entrypoint-bypass-$TS.png"
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
  echo "== $(date -u +%FT%TZ) sniper-entrypoint-bypass cycle =="

  echo "[1/8] Ensure userns + FEX thunks"
  "$HOME/msfs-on-dgx-spark/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/8] Launch native FEX Steam on snap HOME"
  "$HOME/msfs-on-dgx-spark/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 12

  echo "[3/8] Install pass-through _v2-entry-point wrapper"
  if [ ! -f "$SNIPER_EP" ]; then
    echo "ERROR: missing sniper entrypoint: $SNIPER_EP"
    exit 2
  fi
  if [ ! -f "$SNIPER_EP_REAL" ]; then
    cp -f "$SNIPER_EP" "$SNIPER_EP_REAL"
  fi
  cat > "$SNIPER_EP" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
# Pass-through test wrapper: ignore container orchestration flags and exec target directly.
while [ $# -gt 0 ]; do
  case "$1" in
    --verb=*|-v|--verbose)
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done
exec "$@"
WRAP
  chmod +x "$SNIPER_EP"
  head -n 20 "$SNIPER_EP"

  echo "[4/8] Ensure Proton wrapper is pristine (no stale launch wrappers)"
  EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
  if [ -f "$EXP_DIR/proton.real" ]; then
    cp -f "$EXP_DIR/proton.real" "$EXP_DIR/proton"
    chmod +x "$EXP_DIR/proton"
  fi

  echo "[5/8] Clear old proton log"
  rm -f "$PROTON_LOG"

  echo "[6/8] Dispatch launch"
  WAIT_SECONDS=25 "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[7/8] Watch process/runtime state"
  for i in 1 2 3 4 5; do
    date -u +%FT%TZ
    pgrep -af "FlightSimulator2024.exe|proton|wineserver|SteamLaunch|steam-launch-wrapper" | head -n 30 || true
    pgrep -af "pressure-vessel|srt-bwrap|pv-adverb" | head -n 20 || true
    sleep 20
  done

  echo "[8/8] Collect evidence"
  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|waitforexitandrun|Game process (added|updated|removed)" "$STEAM_DIR/logs/compat_log.txt" | tail -n 120 || true
  grep -nE "$MSFS_APPID|App Running|state changed" "$STEAM_DIR/logs/content_log.txt" | tail -n 60 || true
  if [ -f "$PROTON_LOG" ]; then
    echo "proton log: $PROTON_LOG"
    grep -nE "vkd3d|D3D12CreateDevice|DXGI|vkCreateDevice|Found device|err:|warn:" "$PROTON_LOG" | tail -n 220 || true
  else
    echo "No proton log at $PROTON_LOG"
  fi
  DISPLAY=:3 import -window root "$SS" 2>/dev/null || true
  echo "screenshot: $SS"
  CRDIR="$HOME/snap/steam/common/.steam/steam/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024"
  ls -lt "$CRDIR"/AsoboReport-* 2>/dev/null | head -n 8 || true
  [ -f "$CRDIR/AsoboReport-RunningSession.txt" ] && tail -n 80 "$CRDIR/AsoboReport-RunningSession.txt" || true
  [ -f "$CRDIR/AsoboReport-Crash.txt" ] && tail -n 120 "$CRDIR/AsoboReport-Crash.txt" || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
