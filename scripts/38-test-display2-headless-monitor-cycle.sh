#!/usr/bin/env bash
# Test MSFS launch on NVIDIA-backed Xorg (:2) with a virtual headless monitor.
set -euo pipefail

REPO="$HOME/msfs-on-dgx-spark"
RUNFILE="$HOME/snap/steam/common/.local/share/Steam/steamapps/compatdata/2537590/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-RunningSession.txt"

cd "$REPO"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="output/display2-cleanrun-${TS}.log"
STEAM_LOG="output/native-fex-display2-cleanrun-${TS}.log"

# Keep Proton launch args/logging explicit for this cycle.
./scripts/31-wrap-valve-exp-dx11.sh >/dev/null || true

# Kill stale app/runtime processes from old sessions.
PIDS="$(ps -eo pid=,args= | grep -E "FlightSimulator2024\\.exe|AppId=2537590|Proton - Experimental/proton waitforexitandrun|wineserver" | grep -v grep | awk "{print \$1}")"
if [ -n "$PIDS" ]; then
  kill -9 $PIDS || true
fi
pkill -x steamwebhelper >/dev/null 2>&1 || true
pkill -x steam >/dev/null 2>&1 || true

# Ensure headless monitor object exists on NVIDIA X server.
DISPLAY=:2 xrandr --setmonitor HEADLESS 1920/520x1080/320+0+0 none 2>/dev/null || true

rm -f output/steam-2537590.log output/steam-2537590.log.* || true

{
  echo "[INFO] TS=$TS"
  echo "[STEP] display monitor state"
  DISPLAY=:2 xrandr --listmonitors || true

  echo "[STEP] pre-run running-session"
  ls -l --time-style=iso "$RUNFILE" || true

  echo "[STEP] launch native steam on :2"
  nohup env HOME="$HOME/snap/steam/common" DISPLAY=:2 XDG_RUNTIME_DIR="/run/user/$(id -u)" \
    dbus-run-session -- bash -lc "cd /root/fex-steam-native/steam-launcher && FEX_HIDEHYPERVISORBIT=1 FEXBash -c ./steam -silent" \
    >"$STEAM_LOG" 2>&1 &
  sleep 25

  echo "[STEP] dispatch"
  WAIT_SECONDS=95 ./scripts/19-dispatch-via-steam-pipe.sh || true

  echo "[STEP] process snapshot"
  ps -eo pid=,etimes=,args= | grep -E "FlightSimulator2024.exe|AppId=2537590|Proton - Experimental/proton waitforexitandrun|wineserver" | grep -v grep || true

  echo "[STEP] proton log tail"
  ls -lt output/steam-2537590.log* 2>/dev/null || true
  tail -n 220 output/steam-2537590.log 2>/dev/null || true

  echo "[STEP] post-run running-session"
  ls -l --time-style=iso "$RUNFILE" || true
  cat "$RUNFILE" || true
} | tee "$LOG"

echo "[DONE] $LOG"
