#!/usr/bin/env bash
# Force hidden/tiny Steam windows to become visible in headless DGX sessions.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-display.sh"
source "$SCRIPT_DIR/lib-steam-auth.sh"

DISPLAY_NUM="${DISPLAY_NUM:-$(resolve_display_num "$SCRIPT_DIR")}"
AUTH_WINDOW_WIDTH="${AUTH_WINDOW_WIDTH:-1600}"
AUTH_WINDOW_HEIGHT="${AUTH_WINDOW_HEIGHT:-900}"
AUTH_WINDOW_X="${AUTH_WINDOW_X:-50}"
AUTH_WINDOW_Y="${AUTH_WINDOW_Y:-50}"
OPEN_MAIN_UI="${OPEN_MAIN_UI:-1}"

echo "Steam UI recovery"
echo "  DISPLAY: $DISPLAY_NUM"

if [ "$OPEN_MAIN_UI" = "1" ]; then
  if command -v snap >/dev/null 2>&1; then
    timeout 12s env DISPLAY="$DISPLAY_NUM" snap run steam steam://open/main \
      >/tmp/msfs-force-steam-ui-open-main.log 2>&1 || true
    echo "  Requested steam://open/main"
  fi
fi

if steam_force_show_windows "$DISPLAY_NUM" "$AUTH_WINDOW_WIDTH" "$AUTH_WINDOW_HEIGHT" "$AUTH_WINDOW_X" "$AUTH_WINDOW_Y"; then
  echo "  Result: Steam windows normalized to ${AUTH_WINDOW_WIDTH}x${AUTH_WINDOW_HEIGHT}+${AUTH_WINDOW_X}+${AUTH_WINDOW_Y}"
else
  echo "  Result: no Steam windows found to normalize"
  exit 1
fi

if [ -x "$SCRIPT_DIR/11-debug-steam-window-state.sh" ]; then
  DISPLAY_NUM="$DISPLAY_NUM" "$SCRIPT_DIR/11-debug-steam-window-state.sh"
fi
