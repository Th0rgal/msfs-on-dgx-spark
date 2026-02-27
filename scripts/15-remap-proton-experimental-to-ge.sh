#!/usr/bin/env bash
# Force Steam Proton-Experimental launch path to resolve to GE-Proton.
# Useful when per-app compat mappings are ignored in headless sessions.
set -euo pipefail

GE_TOOL="${GE_TOOL:-GE-Proton10-32}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
COMMON_DIR="$STEAM_DIR/steamapps/common"
GE_DIR="$HOME/snap/steam/common/.steam/steam/compatibilitytools.d/$GE_TOOL"
EXP_DIR="$COMMON_DIR/Proton - Experimental"

if [ ! -d "$GE_DIR" ]; then
  echo "ERROR: GE tool not found: $GE_DIR"
  echo "Install first with scripts/14-install-ge-proton.sh"
  exit 1
fi

if [ -d "$EXP_DIR" ] && [ ! -L "$EXP_DIR" ]; then
  backup="$COMMON_DIR/Proton - Experimental.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  mv "$EXP_DIR" "$backup"
  echo "Backed up original Proton-Experimental dir to: $backup"
fi

ln -sfn "$GE_DIR" "$EXP_DIR"
echo "Remapped: $EXP_DIR -> $GE_DIR"
ls -ld "$EXP_DIR"
