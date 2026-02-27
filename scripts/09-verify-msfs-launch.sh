#!/usr/bin/env bash
# Verify whether MSFS appears to be running in the current Steam/FEX/Proton session.
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
POLL_SECONDS="${POLL_SECONDS:-5}"

find_steam_dir() {
  local paths=(
    "$HOME/snap/steam/common/.local/share/Steam"
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
  )
  local p
  for p in "${paths[@]}"; do
    if [ -d "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi

MANIFEST="$STEAM_DIR/steamapps/appmanifest_${MSFS_APPID}.acf"

is_launched() {
  # FlightSimulator.exe is the key signal; proton/fex helpers are fallback indicators.
  pgrep -af "FlightSimulator\\.exe|gamelaunchhelper\\.exe|proton|rungameid/${MSFS_APPID}" >/dev/null 2>&1
}

echo "MSFS launch verification"
echo "  Time (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "  Host: $(hostname)"
echo "  DISPLAY: ${DISPLAY_NUM}"

if [ -f "$MANIFEST" ]; then
  echo "  Manifest: present (${MANIFEST})"
else
  echo "  Manifest: missing (${MANIFEST})"
fi

start_ts="$(date +%s)"
while true; do
  if is_launched; then
    echo "RESULT: detected candidate MSFS/launch processes"
    pgrep -af "FlightSimulator\\.exe|gamelaunchhelper\\.exe|proton|rungameid/${MSFS_APPID}" || true
    exit 0
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
    echo "RESULT: no MSFS launch process detected after ${WAIT_SECONDS}s"
    echo "Hint: check Steam UI (install dialog, EULA/first-run prompt, or auth challenge)."
    exit 2
  fi

  sleep "$POLL_SECONDS"
done
