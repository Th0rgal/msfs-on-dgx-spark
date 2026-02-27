#!/usr/bin/env bash
# Make Proton-CachyOS effective in headless Steam sessions that ignore per-app mappings.
set -euo pipefail

STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
CACHY_TOOL="${CACHY_TOOL:-proton-cachyos-10.0-20260207-slr-arm64}"

CACHY_DIR="$STEAM_DIR/compatibilitytools.d/$CACHY_TOOL"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
TM="$CACHY_DIR/toolmanifest.vdf"

if [ ! -d "$CACHY_DIR" ]; then
  echo "ERROR: Cachy tool not found: $CACHY_DIR"
  exit 1
fi

if [ ! -f "$TM" ]; then
  echo "ERROR: Missing tool manifest: $TM"
  exit 2
fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"
cp -f "$TM" "$TM.bak.$ts"

# Some arm64 Cachy builds ship with a non-existent dependency appid on this host.
sed -i 's/"require_tool_appid" "4185400"/"require_tool_appid" "1628350"/' "$TM"

if [ -e "$EXP_DIR" ] && [ ! -L "$EXP_DIR" ]; then
  mv "$EXP_DIR" "${EXP_DIR}.bak.${ts}"
fi
ln -sfn "$CACHY_DIR" "$EXP_DIR"

echo "Applied compat fix."
echo "  toolmanifest: $TM"
echo "  remap: $EXP_DIR -> $CACHY_DIR"
echo "Next: restart Steam and launch once via scripts/19-dispatch-via-steam-pipe.sh"
