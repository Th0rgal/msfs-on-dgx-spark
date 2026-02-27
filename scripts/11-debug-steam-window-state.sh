#!/usr/bin/env bash
set -euo pipefail

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

{
  echo "timestamp_utc=${TS}"
  echo "display=${DISPLAY_NUM}"
  echo
  echo "[steamid_from_steamwebhelper]"
  pgrep -af steamwebhelper \
    | sed -n "s/.*-steamid=\([0-9][0-9]*\).*/\1/p" \
    | awk "{print}"
  echo
  echo "[visible_steam_windows]"
  window_dump
  echo
  echo "[steam_processes]"
  pgrep -af "steam |steamwebhelper|fex_launcher" || true
} > "$report"

if command -v import >/dev/null 2>&1; then
  DISPLAY="$DISPLAY_NUM" import -window root "$screenshot" >/dev/null 2>&1 || true
fi

echo "report=$report"
echo "screenshot=$screenshot"
