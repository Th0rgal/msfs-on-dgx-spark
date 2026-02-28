#!/usr/bin/env bash
# Retest MSFS launch with explicit FEX hypervisor-bit hiding in runtime path.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
OUT_DIR="${OUT_DIR:-$HOME/msfs-on-dgx-spark/output}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/hide-hypervisor-cycle-$TS.log"
SS="$OUT_DIR/hide-hypervisor-$TS.png"
CRDIR="$HOME/snap/steam/common/.steam/steam/steamapps/compatdata/$MSFS_APPID/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024"

mkdir -p "$OUT_DIR"

{
  echo "== $(date -u +%FT%TZ) hide-hypervisor cycle =="
  echo "[1/6] Apply userns + FEX config"
  "$HOME/msfs-on-dgx-spark/scripts/26-enable-userns-and-fex-thunks.sh"

  echo "[2/6] Verify FEX_HIDEHYPERVISORBIT works"
  FEX_HIDEHYPERVISORBIT=1 FEXBash -c "grep -m1 ^flags /proc/cpuinfo"

  echo "[3/6] Launch native FEX Steam (with hidden hypervisor bit)"
  "$HOME/msfs-on-dgx-spark/scripts/27-launch-native-fex-steam-on-snap-home.sh"
  sleep 14

  echo "[4/6] Ensure Proton executable is pristine"
  EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
  if [ -f "$EXP_DIR/proton.real" ]; then
    cp -f "$EXP_DIR/proton.real" "$EXP_DIR/proton"
    chmod +x "$EXP_DIR/proton"
  fi

  echo "[5/6] Dispatch MSFS launch"
  WAIT_SECONDS=25 "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[6/6] Post-checks"
  for i in 1 2 3 4 5; do
    date -u +%FT%TZ
    pgrep -af "FlightSimulator2024.exe|proton|wineserver|SteamLaunch" | head -n 20 || true
    sleep 20
  done

  grep -nE "StartSession: appID $MSFS_APPID|Command prefix|waitforexitandrun" "$STEAM_DIR/logs/compat_log.txt" | tail -n 80 || true
  grep -nE "$MSFS_APPID|App Running|state changed" "$STEAM_DIR/logs/content_log.txt" | tail -n 40 || true
  DISPLAY=:3 import -window root "$SS" 2>/dev/null || true
  echo "screenshot: $SS"

  ls -lt "$CRDIR"/AsoboReport-* 2>/dev/null | head -n 8 || true
  [ -f "$CRDIR/AsoboReport-RunningSession.txt" ] && tail -n 120 "$CRDIR/AsoboReport-RunningSession.txt" || true
  [ -f "$CRDIR/AsoboReport-Crash.txt" ] && tail -n 120 "$CRDIR/AsoboReport-Crash.txt" || true

  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
