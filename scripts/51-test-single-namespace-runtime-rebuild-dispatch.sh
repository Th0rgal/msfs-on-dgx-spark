#!/usr/bin/env bash
# Recover Steam dispatch by forcing a single snap-run namespace and rebuilding runtime roots.
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
REPO="${REPO:-$HOME/msfs-on-dgx-spark}"
SNAP_HOME="${SNAP_HOME:-$HOME/snap/steam/common}"
STEAM_DIR="${STEAM_DIR:-$SNAP_HOME/.local/share/Steam}"
OUT_DIR="${OUT_DIR:-$REPO/output}"
DISPLAY_NUM="${DISPLAY_NUM:-:2}"
WAIT_SECONDS="${WAIT_SECONDS:-40}"
PIPE_WAIT_SECONDS="${PIPE_WAIT_SECONDS:-90}"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_LOG="$OUT_DIR/single-namespace-runtime-rebuild-dispatch-cycle-$TS.log"
SHOT="$OUT_DIR/single-namespace-runtime-rebuild-dispatch-$TS.png"
STEAM_LAUNCH_LOG="$OUT_DIR/snap-run-steam-$TS.log"
BACKUP_DIR="$OUT_DIR/runtime-backup-$TS"
COMPAT_LOG="$STEAM_DIR/logs/compat_log.txt"
CONSOLE_LOG="$STEAM_DIR/logs/console_log.txt"
WEBHELPER_LOG="$STEAM_DIR/logs/webhelper-linux.txt"
CONNECTION_LOG="$STEAM_DIR/logs/connection_log.txt"
STEAM_PIPE="$SNAP_HOME/.steam/steam.pipe"

mkdir -p "$OUT_DIR"

if [ ! -d "$REPO/scripts" ]; then
  echo "ERROR: Repo scripts dir not found: $REPO/scripts"
  exit 2
fi

if [ ! -d "$STEAM_DIR" ]; then
  echo "ERROR: Steam dir not found: $STEAM_DIR"
  exit 3
fi

{
  echo "== $(date -u +%FT%TZ) single-namespace runtime rebuild dispatch cycle =="
  echo "repo=$REPO"
  echo "snap_home=$SNAP_HOME"
  echo "steam_dir=$STEAM_DIR"
  echo "display=$DISPLAY_NUM"

  echo "[1/8] Stop existing Steam/webhelper process tree"
  pkill -x steamwebhelper >/dev/null 2>&1 || true
  pkill -f steamwebhelper_sniper_wrap >/dev/null 2>&1 || true
  pkill -f pressure-vessel >/dev/null 2>&1 || true
  pkill -x steam >/dev/null 2>&1 || true
  sleep 2

  echo "[2/8] Move runtime roots out of the way (non-destructive)"
  mkdir -p "$BACKUP_DIR"
  if [ -e "$STEAM_DIR/steamrt64/pv-runtime" ]; then
    mv "$STEAM_DIR/steamrt64/pv-runtime" "$BACKUP_DIR/pv-runtime"
  fi
  shopt -s nullglob
  for d in "$STEAM_DIR"/steamrt64/var/tmp-*; do
    mv "$d" "$BACKUP_DIR/$(basename "$d")"
  done
  shopt -u nullglob
  ls -la "$BACKUP_DIR" || true

  echo "[3/8] Ensure userns/FEX prerequisites (for runtime tooling paths)"
  "$REPO/scripts/26-enable-userns-and-fex-thunks.sh" || true

  echo "[4/8] Launch Steam strictly via snap runtime namespace"
  nohup env HOME="$SNAP_HOME" DISPLAY="$DISPLAY_NUM" XDG_RUNTIME_DIR="/run/user/$(id -u)" \
    dbus-run-session -- bash -lc 'snap run steam -silent' >"$STEAM_LAUNCH_LOG" 2>&1 &
  sleep 5
  pgrep -af "snap run steam|/snap/steam|steamwebhelper|pressure-vessel" | sed -n "1,120p" || true

  echo "[5/8] Wait for steam pipe consumer"
  have_pipe=0
  for _ in $(seq 1 "$PIPE_WAIT_SECONDS"); do
    if [ -p "$STEAM_PIPE" ]; then
      have_pipe=1
      break
    fi
    sleep 1
  done
  if [ "$have_pipe" -ne 1 ]; then
    echo "ERROR: steam pipe missing after ${PIPE_WAIT_SECONDS}s: $STEAM_PIPE"
    tail -n 120 "$STEAM_LAUNCH_LOG" || true
    exit 4
  fi
  ls -l "$STEAM_PIPE"

  echo "[6/8] Dispatch launch via steam pipe"
  WAIT_SECONDS="$WAIT_SECONDS" PIPE_WRITE_TIMEOUT_SECONDS=3 "$REPO/scripts/19-dispatch-via-steam-pipe.sh" || true

  echo "[7/8] Collect auth/dispatch signals"
  if [ -f "$CONNECTION_LOG" ]; then
    stat -c "connection_log_mtime=%y" "$CONNECTION_LOG" || true
    tail -n 80 "$CONNECTION_LOG" || true
  fi
  if [ -f "$STEAM_DIR/config/loginusers.vdf" ]; then
    grep -nE '"(AccountName|PersonaName|SteamID|MostRecent|Timestamp)"' "$STEAM_DIR/config/loginusers.vdf" | tail -n 60 || true
  fi
  grep -nE "GameAction \\[AppID ${MSFS_APPID}|ExecCommandLine|StartSession: appID ${MSFS_APPID}|waitforexitandrun|App Running" "$CONSOLE_LOG" | tail -n 120 || true
  grep -nE "StartSession: appID ${MSFS_APPID}|Command prefix|_v2-entry-point|SteamLinuxRuntime|pressure-vessel" "$COMPAT_LOG" | tail -n 180 || true
  grep -nE "pv-adverb|bwrap: execvp|Failed to create browser window|NOTREACHED|steamwebhelper|pressure-vessel" "$WEBHELPER_LOG" | tail -n 180 || true

  echo "[8/8] Screenshot + process snapshot"
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT" 2>/dev/null || true
  echo "screenshot: $SHOT"
  pgrep -af "steam|steamwebhelper|FlightSimulator2024.exe|waitforexitandrun|pressure-vessel|pv-bwrap" | sed -n "1,180p" || true
  echo "== done =="
} | tee "$RUN_LOG"

echo "$RUN_LOG"
