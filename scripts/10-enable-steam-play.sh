#!/usr/bin/env bash
# Ensure Steam Play compatibility mappings exist for MSFS titles on Linux.
set -euo pipefail

PROTON_TOOL="${PROTON_TOOL:-proton_experimental}"

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

CONFIG_DIR="$STEAM_DIR/config"
mkdir -p "$CONFIG_DIR"
COMPAT_VDF="$CONFIG_DIR/compatibilitytools.vdf"

if [ -f "$COMPAT_VDF" ]; then
  cp -f "$COMPAT_VDF" "$COMPAT_VDF.bak.$(date +%Y%m%d%H%M%S)"
fi

cat > "$COMPAT_VDF" <<VDF
"CompatToolMapping"
{
	"0"
	{
		"name"		"$PROTON_TOOL"
		"config"		""
		"priority"		"250"
	}
	"1250410"
	{
		"name"		"$PROTON_TOOL"
		"config"		""
		"priority"		"250"
	}
	"2537590"
	{
		"name"		"$PROTON_TOOL"
		"config"		""
		"priority"		"250"
	}
}
VDF

chmod 644 "$COMPAT_VDF"

echo "Steam Play compatibility mappings written: $COMPAT_VDF"
echo "  Tool: $PROTON_TOOL"
