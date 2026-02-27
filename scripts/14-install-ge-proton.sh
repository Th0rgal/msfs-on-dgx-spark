#!/usr/bin/env bash
# Install the latest GE-Proton release into Steam compatibilitytools.d.
set -euo pipefail

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

TOOLS_DIR="$STEAM_DIR/compatibilitytools.d"
mkdir -p "$TOOLS_DIR"

API_JSON="$(curl -fsSL "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest")"
TAG="$(printf '%s\n' "$API_JSON" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
URL="$(printf '%s\n' "$API_JSON" | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\.tar\.gz\)".*/\1/p' | head -n1)"

if [ -z "$TAG" ] || [ -z "$URL" ]; then
  echo "ERROR: Could not resolve latest GE-Proton release info from GitHub API."
  exit 2
fi

ARCHIVE="/tmp/${TAG}.tar.gz"
TARGET_DIR="$TOOLS_DIR/$TAG"

echo "Latest GE-Proton tag: $TAG"
echo "Download URL: $URL"

if [ ! -f "$ARCHIVE" ]; then
  echo "Downloading archive to $ARCHIVE ..."
  curl -L --fail --retry 3 -o "$ARCHIVE" "$URL"
else
  echo "Using cached archive: $ARCHIVE"
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Extracting to: $TOOLS_DIR"
  tar -xzf "$ARCHIVE" -C "$TOOLS_DIR"
else
  echo "Already installed: $TARGET_DIR"
fi

echo "Installed GE-Proton directory:"
echo "  $TARGET_DIR"

