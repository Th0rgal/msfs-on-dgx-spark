#!/usr/bin/env bash
# Ensure Steam is authenticated in the active headless session (optionally via Steam Guard code).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-steam-auth.sh"
source "$SCRIPT_DIR/lib-display.sh"

DISPLAY_NUM="$(resolve_display_num "$SCRIPT_DIR")"
LOGIN_WAIT_SECONDS="${LOGIN_WAIT_SECONDS:-300}"
POLL_SECONDS="${POLL_SECONDS:-10}"
GUARD_CODE="${1:-${STEAM_GUARD_CODE:-}}"

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi

echo "Ensuring headless Steam stack is running..."
"$SCRIPT_DIR/05-resume-headless-msfs.sh" install >/tmp/msfs-ensure-auth-resume.log 2>&1 || true

if steam_session_authenticated "$DISPLAY_NUM" "$STEAM_DIR"; then
  echo "Steam session already authenticated."
  steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true
  exit 0
fi

if [ -n "$GUARD_CODE" ]; then
  echo "Attempting Steam Guard code entry on ${DISPLAY_NUM}..."
  if command -v xdotool >/dev/null 2>&1; then
    DISPLAY="$DISPLAY_NUM" xdotool key --delay 80 "$GUARD_CODE" Return || true
  else
    echo "WARN: xdotool not installed; cannot auto-type Steam Guard code."
  fi
else
  echo "No Steam Guard code supplied; waiting for manual login completion."
fi

echo "Waiting for authenticated Steam session (timeout: ${LOGIN_WAIT_SECONDS}s)..."
start_ts="$(date +%s)"
while true; do
  if steam_session_authenticated "$DISPLAY_NUM" "$STEAM_DIR"; then
    echo "Steam session authenticated."
    steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true
    exit 0
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  if [ "$elapsed" -ge "$LOGIN_WAIT_SECONDS" ]; then
    echo "ERROR: timed out waiting for Steam authentication."
    steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true
    echo "Hint: complete login/Steam Guard on VNC, or pass STEAM_GUARD_CODE and rerun."
    exit 2
  fi

  printf "  waiting login... (%ss elapsed)\n" "$elapsed"
  sleep "$POLL_SECONDS"
done
