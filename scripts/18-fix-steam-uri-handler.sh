#!/usr/bin/env bash
# Ensure steam:// URLs resolve to Steam in headless environments.
set -euo pipefail

mkdir -p "$HOME/.config" "$HOME/.local/share/applications"

# Snap desktop entry may not be in default XDG_DATA_DIRS for xdg-open; copy it locally.
if [ -f /var/lib/snapd/desktop/applications/steam_steam.desktop ]; then
  cp -f /var/lib/snapd/desktop/applications/steam_steam.desktop \
    "$HOME/.local/share/applications/steam_steam.desktop"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

MIMEAPPS="$HOME/.config/mimeapps.list"
if [ ! -f "$MIMEAPPS" ]; then
  printf "[Default Applications]\n" > "$MIMEAPPS"
fi

if grep -q '^x-scheme-handler/steam=' "$MIMEAPPS"; then
  sed -i 's|^x-scheme-handler/steam=.*$|x-scheme-handler/steam=steam_steam.desktop|' "$MIMEAPPS"
else
  if ! grep -q '^\[Default Applications\]' "$MIMEAPPS"; then
    printf '\n[Default Applications]\n' >> "$MIMEAPPS"
  fi
  awk '
    BEGIN {in_default=0; inserted=0}
    /^\[Default Applications\]$/ {print; in_default=1; next}
    /^\[/ {
      if (in_default && !inserted) {
        print "x-scheme-handler/steam=steam_steam.desktop"
        inserted=1
      }
      in_default=0
      print
      next
    }
    { print }
    END {
      if (!inserted) {
        if (!in_default) print "[Default Applications]"
        print "x-scheme-handler/steam=steam_steam.desktop"
      }
    }
  ' "$MIMEAPPS" > "$MIMEAPPS.tmp"
  mv "$MIMEAPPS.tmp" "$MIMEAPPS"
fi

xdg-mime default steam_steam.desktop x-scheme-handler/steam >/dev/null 2>&1 || true

echo "steam URI handler: $(xdg-mime query default x-scheme-handler/steam 2>/dev/null || true)"
