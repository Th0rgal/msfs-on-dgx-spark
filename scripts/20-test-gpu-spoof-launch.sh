#!/usr/bin/env bash
# Apply a GPU-spoof/NVAPI-off launch profile and run one MSFS launch cycle via Steam pipe.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-75}"
OUTDIR="${OUTDIR:-$HOME/msfs-on-dgx-spark/output}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUTDIR"

PROFILE='PROTON_LOG=1 PROTON_LOG_DIR=/home/th0rgal/msfs-on-dgx-spark/output PROTON_HIDE_NVIDIA_GPU=1 PROTON_ENABLE_NVAPI=0 PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 %command% -FastLaunch'

echo "[1/4] Setting launch options profile"
LAUNCH_OPTIONS="$PROFILE" MSFS_APPID="$MSFS_APPID" "$(dirname "$0")/12-set-msfs-launch-options.sh" | tee "$OUTDIR/gpu-spoof-setopts-${TS}.log"

echo "[2/4] Dispatching launch via steam.pipe"
MSFS_APPID="$MSFS_APPID" WAIT_SECONDS=15 "$(dirname "$0")/19-dispatch-via-steam-pipe.sh" | tee "$OUTDIR/gpu-spoof-dispatch-${TS}.log" || true

echo "[3/4] Watching runtime for ${WAIT_SECONDS}s"
{
  echo "UTC_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  for i in $(seq 1 "$WAIT_SECONDS"); do
    ps -ef | grep -E "FlightSimulator2024\\.exe|proton|waitforexitandrun|gamelaunchhelper" | grep -v grep || true
    sleep 1
  done
  echo "UTC_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUTDIR/gpu-spoof-runtime-${TS}.log"

echo "[4/4] Capturing latest crash report snapshot"
CRASH_SRC="$HOME/snap/steam/common/.local/share/Steam/steamapps/compatdata/${MSFS_APPID}/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/AsoboReport-Crash.txt"
if [ -f "$CRASH_SRC" ]; then
  cp -f "$CRASH_SRC" "$OUTDIR/AsoboReport-Crash-${MSFS_APPID}-${TS}.txt"
  echo "Copied crash report: $OUTDIR/AsoboReport-Crash-${MSFS_APPID}-${TS}.txt"
  grep -E "TimeUTC=|Code=|LastStates=|EnableD3D12=|VideoMemoryBudget=|NumRegisteredPackages=" "$OUTDIR/AsoboReport-Crash-${MSFS_APPID}-${TS}.txt" || true
else
  echo "No crash report found at $CRASH_SRC"
fi

echo "Done. Artifacts timestamp: $TS"
