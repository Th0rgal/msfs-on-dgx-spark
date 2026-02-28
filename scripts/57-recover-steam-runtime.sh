#!/usr/bin/env bash
# Recover Steam launch-control runtime by rebuilding runtime roots and restarting snap Steam.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-display.sh"

DISPLAY_NUM="${DISPLAY_NUM:-$(resolve_display_num "$SCRIPT_DIR")}"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"
SNAP_HOME="${SNAP_HOME:-$HOME/snap/steam/common}"
STEAM_DIR="${STEAM_DIR:-$SNAP_HOME/.local/share/Steam}"
STEAM_PIPE="${STEAM_PIPE:-$SNAP_HOME/.steam/steam.pipe}"
PIPE_WAIT_SECONDS="${PIPE_WAIT_SECONDS:-90}"
RECOVER_RUNTIME_ROOTS="${RECOVER_RUNTIME_ROOTS:-1}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RECOVER_LOG="$OUT_DIR/steam-runtime-recover-$STAMP.log"
RUNTIME_BACKUP_ROOT="${RUNTIME_BACKUP_ROOT:-$STEAM_DIR/steamrt64/recovery-backups}"
BACKUP_DIR="$RUNTIME_BACKUP_ROOT/$STAMP"
STEAM_LAUNCH_LOG="$OUT_DIR/snap-run-steam-$STAMP.log"

mkdir -p "$OUT_DIR"

if [ ! -d "$STEAM_DIR" ]; then
  echo "ERROR: Steam dir not found: $STEAM_DIR"
  exit 2
fi

{
  echo "Steam runtime recovery"
  echo "  Time (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "  DISPLAY: $DISPLAY_NUM"
  echo "  Steam dir: $STEAM_DIR"
  echo "  Recover runtime roots: $RECOVER_RUNTIME_ROOTS"
  echo "  Runtime backup dir: $BACKUP_DIR"

  echo "[1/5] Stop existing Steam process tree"
  pkill -x steamwebhelper >/dev/null 2>&1 || true
  pkill -f steamwebhelper_sniper_wrap >/dev/null 2>&1 || true
  pkill -f pressure-vessel >/dev/null 2>&1 || true
  pkill -x steam >/dev/null 2>&1 || true
  sleep 2

  if [ "$RECOVER_RUNTIME_ROOTS" = "1" ]; then
    echo "[2/5] Move runtime roots aside (non-destructive)"
    mkdir -p "$BACKUP_DIR"
    if [ -e "$STEAM_DIR/steamrt64/pv-runtime" ]; then
      mv "$STEAM_DIR/steamrt64/pv-runtime" "$BACKUP_DIR/pv-runtime"
    fi
    shopt -s nullglob
    for d in "$STEAM_DIR"/steamrt64/var/tmp-*; do
      mv "$d" "$BACKUP_DIR/$(basename "$d")"
    done
    shopt -u nullglob
  else
    echo "[2/5] Runtime root move skipped"
  fi

  echo "[3/5] Ensure userns/FEX prerequisites"
  "$SCRIPT_DIR/26-enable-userns-and-fex-thunks.sh" >/dev/null 2>&1 || true

  echo "[4/5] Relaunch Steam in a single snap namespace"
  nohup env HOME="$SNAP_HOME" DISPLAY="$DISPLAY_NUM" XDG_RUNTIME_DIR="/run/user/$(id -u)" \
    dbus-run-session -- bash -lc 'snap run steam -silent' >"$STEAM_LAUNCH_LOG" 2>&1 &

  echo "[5/5] Wait for steam pipe"
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

  echo "RESULT: Steam runtime recovered; pipe is available"
  ls -l "$STEAM_PIPE"
  pgrep -af "snap run steam|/snap/steam|steamwebhelper|pressure-vessel" | sed -n '1,100p' || true
} | tee "$RECOVER_LOG"

echo "$RECOVER_LOG"
