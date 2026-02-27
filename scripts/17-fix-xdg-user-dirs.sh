#!/usr/bin/env bash
# Normalize XDG user dirs expected by snap/steam runtime helpers.
set -euo pipefail

mkdir -p "$HOME/.config"
cat > "$HOME/.config/user-dirs.dirs" <<"EOD"
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_TEMPLATES_DIR="$HOME/Templates"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
EOD

for d in Desktop Downloads Templates Public Documents Music Pictures Videos; do
  mkdir -p "$HOME/$d"
done

echo "Fixed: $HOME/.config/user-dirs.dirs"
