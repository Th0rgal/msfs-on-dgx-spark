#!/usr/bin/env bash
# Trigger a Steam in-game screenshot (F12) and export the newest MSFS image into output/.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-display.sh"

DISPLAY_NUM="${DISPLAY_NUM:-$(resolve_display_num "$SCRIPT_DIR")}"
MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-20}"
POLL_SECONDS="${POLL_SECONDS:-1}"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"

if ! [[ "$WAIT_SECONDS" =~ ^[0-9]+$ ]] || [ "$WAIT_SECONDS" -lt 1 ]; then
  echo "ERROR: WAIT_SECONDS must be a positive integer"
  exit 2
fi
if ! [[ "$POLL_SECONDS" =~ ^[0-9]+$ ]] || [ "$POLL_SECONDS" -lt 1 ]; then
  echo "ERROR: POLL_SECONDS must be a positive integer"
  exit 2
fi

for cmd in xdotool find stat cp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing required tool: $cmd"
    exit 1
  fi
done

if [ ! -d "$STEAM_DIR/userdata" ]; then
  echo "ERROR: Steam userdata not found: $STEAM_DIR/userdata"
  exit 1
fi

mkdir -p "$OUT_DIR"

newest_screenshot() {
  find "$STEAM_DIR/userdata" -type f \
    -path "*/760/remote/${MSFS_APPID}/screenshots/*.png" -print 2>/dev/null \
    | xargs -r stat -c '%Y %n' 2>/dev/null \
    | sort -n \
    | tail -n 1 \
    | cut -d' ' -f2-
}

baseline_file="$(newest_screenshot || true)"
baseline_mtime=0
if [ -n "${baseline_file:-}" ] && [ -f "$baseline_file" ]; then
  baseline_mtime="$(stat -c '%Y' "$baseline_file" 2>/dev/null || echo 0)"
fi

mapfile -t app_windows < <(
  timeout 4s env DISPLAY="$DISPLAY_NUM" xdotool search --all --class "steam_app_${MSFS_APPID}" 2>/dev/null || true
)

if [ "${#app_windows[@]}" -eq 0 ]; then
  mapfile -t app_windows < <(
    timeout 4s env DISPLAY="$DISPLAY_NUM" xdotool search --all --name "Microsoft Flight Simulator" 2>/dev/null || true
  )
fi

if [ "${#app_windows[@]}" -gt 0 ]; then
  target_win="${app_windows[0]}"
  timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool windowactivate "$target_win" >/dev/null 2>&1 || true
  timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool key --window "$target_win" F12 >/dev/null 2>&1 || true
else
  timeout 3s env DISPLAY="$DISPLAY_NUM" xdotool key F12 >/dev/null 2>&1 || true
fi

start_ts="$(date +%s)"
found=""
while true; do
  now_file="$(newest_screenshot || true)"
  if [ -n "${now_file:-}" ] && [ -f "$now_file" ]; then
    now_mtime="$(stat -c '%Y' "$now_file" 2>/dev/null || echo 0)"
    if [ "$now_mtime" -gt "$baseline_mtime" ]; then
      found="$now_file"
      break
    fi
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
    break
  fi
  sleep "$POLL_SECONDS"
done

if [ -z "$found" ]; then
  echo "ERROR: no new Steam screenshot found after F12 (${WAIT_SECONDS}s)"
  exit 3
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
export_path="$OUT_DIR/msfs-steam-f12-${MSFS_APPID}-${stamp}.png"
cp -f "$found" "$export_path"

echo "RESULT: steam screenshot captured"
echo "  source: $found"
echo "  export: $export_path"
