#!/usr/bin/env bash
# Best-effort UI automation for Steam/MSFS first-run prompts on headless DGX.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-display.sh"
source "$SCRIPT_DIR/lib-steam-auth.sh"

DISPLAY_NUM="${DISPLAY_NUM:-$(resolve_display_num "$SCRIPT_DIR")}"
AUTO_CONFIRM_SECONDS="${AUTO_CONFIRM_SECONDS:-120}"
AUTO_CONFIRM_INTERVAL="${AUTO_CONFIRM_INTERVAL:-2}"
AUTO_CONFIRM_MAX_WINDOWS="${AUTO_CONFIRM_MAX_WINDOWS:-6}"

if ! [[ "$AUTO_CONFIRM_SECONDS" =~ ^[0-9]+$ ]] || [ "$AUTO_CONFIRM_SECONDS" -lt 1 ]; then
  echo "ERROR: AUTO_CONFIRM_SECONDS must be a positive integer"
  exit 2
fi
if ! [[ "$AUTO_CONFIRM_INTERVAL" =~ ^[0-9]+$ ]] || [ "$AUTO_CONFIRM_INTERVAL" -lt 1 ]; then
  echo "ERROR: AUTO_CONFIRM_INTERVAL must be a positive integer"
  exit 2
fi
if ! [[ "$AUTO_CONFIRM_MAX_WINDOWS" =~ ^[0-9]+$ ]] || [ "$AUTO_CONFIRM_MAX_WINDOWS" -lt 1 ]; then
  echo "ERROR: AUTO_CONFIRM_MAX_WINDOWS must be a positive integer"
  exit 2
fi

for cmd in xdotool; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "WARN: missing required tool: $cmd"
    exit 0
  fi
done

click_window_hotspots() {
  local window_id="$1"
  local geom x y w h
  geom="$(timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool getwindowgeometry --shell "$window_id" 2>/dev/null || true)"
  [ -n "$geom" ] || return 0

  # shellcheck disable=SC2034
  eval "$geom"
  x="${X:-0}"
  y="${Y:-0}"
  w="${WIDTH:-0}"
  h="${HEIGHT:-0}"

  [ "$w" -gt 0 ] || return 0
  [ "$h" -gt 0 ] || return 0

  # Click center and bottom-right where Steam buttons ("Play", "OK", "Continue")
  # are commonly rendered.
  timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool mousemove --sync $((x + w / 2)) $((y + h / 2)) click 1 >/dev/null 2>&1 || true
  timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool mousemove --sync $((x + w - 140)) $((y + h - 55)) click 1 >/dev/null 2>&1 || true
}

echo "Auto-confirming Steam prompts on ${DISPLAY_NUM} for up to ${AUTO_CONFIRM_SECONDS}s"
start_ts="$(date +%s)"
while true; do
  now="$(date +%s)"
  elapsed=$(( now - start_ts ))
  if [ "$elapsed" -ge "$AUTO_CONFIRM_SECONDS" ]; then
    echo "Auto-confirm timeout reached (${AUTO_CONFIRM_SECONDS}s)"
    break
  fi

  steam_force_show_windows "$DISPLAY_NUM" >/dev/null 2>&1 || true

  mapfile -t win_ids < <(steam_window_ids "$DISPLAY_NUM" 2>/dev/null || true)
  if [ "${#win_ids[@]}" -gt 0 ]; then
    processed=0
    for wid in "${win_ids[@]}"; do
      processed=$((processed + 1))
      if [ "$processed" -gt "$AUTO_CONFIRM_MAX_WINDOWS" ]; then
        break
      fi
      timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool windowactivate "$wid" >/dev/null 2>&1 || true
      timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool key --window "$wid" --delay 80 Escape Return >/dev/null 2>&1 || true
      timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool key --window "$wid" --delay 80 Tab Tab Return >/dev/null 2>&1 || true
      click_window_hotspots "$wid"
    done
  fi

  sleep "$AUTO_CONFIRM_INTERVAL"
done
