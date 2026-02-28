#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${DISPLAY_NUM:-}" ] && [ -f "$SCRIPT_DIR/lib-display.sh" ]; then
  # Prefer the same display resolution logic as launch/verify scripts.
  # Fall back to :1 for portability when helpers are unavailable.
  source "$SCRIPT_DIR/lib-display.sh"
  DISPLAY_NUM="$(resolve_display_num "$SCRIPT_DIR")"
fi
DISPLAY_NUM="${DISPLAY_NUM:-:1}"
OUT_DIR="${OUT_DIR:-$PWD/output}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT_DIR"

screenshot="$OUT_DIR/steam-debug-${TS}.png"
report="$OUT_DIR/steam-debug-${TS}.log"

window_dump() {
  local ids=()
  mapfile -t ids < <(DISPLAY="$DISPLAY_NUM" xdotool search --onlyvisible --class steam 2>/dev/null || true)
  if [ "${#ids[@]}" -eq 0 ]; then
    mapfile -t ids < <(DISPLAY="$DISPLAY_NUM" xdotool search --onlyvisible --name "Steam|Friends|Sign in to Steam" 2>/dev/null || true)
  fi

  if [ "${#ids[@]}" -eq 0 ]; then
    echo "(none)"
    return
  fi

  for id in "${ids[@]}"; do
    local name geom
    name="$(DISPLAY="$DISPLAY_NUM" xdotool getwindowname "$id" 2>/dev/null || true)"
    geom="$(DISPLAY="$DISPLAY_NUM" xdotool getwindowgeometry --shell "$id" 2>/dev/null | tr "\n" " ")"
    echo "$id | $geom | $name"
  done
}

window_dump_any() {
  if command -v xwininfo >/dev/null 2>&1; then
    DISPLAY="$DISPLAY_NUM" xwininfo -root -tree 2>/dev/null \
      | sed -n 's/^ *\(0x[0-9a-f][0-9a-f]*\) "\(.*\)".*/\1 \2/pI' \
      | awk 'BEGIN { IGNORECASE=1 } $0 ~ /(steam|steamwebhelper|sign in to steam|steam guard|friends|library|store)/ { print }'
  else
    echo "(xwininfo not installed)"
  fi
}

{
  echo "timestamp_utc=${TS}"
  echo "display=${DISPLAY_NUM}"
  echo
  echo "[display_monitors]"
  if command -v xrandr >/dev/null 2>&1; then
    DISPLAY="$DISPLAY_NUM" xrandr --listmonitors 2>/dev/null || echo "(xrandr failed)"
  else
    echo "(xrandr not installed)"
  fi
  echo
  echo "[steamid_from_steamwebhelper]"
  pgrep -af steamwebhelper \
    | sed -n "s/.*-steamid=\([0-9][0-9]*\).*/\1/p" \
    | awk "{print}" || true
  echo
  echo "[visible_steam_windows]"
  window_dump
  echo
  echo "[steam_windows_any]"
  window_dump_any
  echo
  echo "[steam_processes]"
  pgrep -af "steam |steamwebhelper|fex_launcher" || true
  echo
  echo "[connection_log_tail]"
  steam_dir="$HOME/snap/steam/common/.local/share/Steam"
  if [ -f "$steam_dir/logs/connection_log.txt" ]; then
    tail -n 40 "$steam_dir/logs/connection_log.txt" || true
  else
    echo "(missing: $steam_dir/logs/connection_log.txt)"
  fi
} > "$report"

if command -v import >/dev/null 2>&1; then
  DISPLAY="$DISPLAY_NUM" import -window root "$screenshot" >/dev/null 2>&1 || true
fi

echo "report=$report"
echo "screenshot=$screenshot"
