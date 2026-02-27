#!/usr/bin/env bash
# Restart headless Steam and bring UI to Library and MSFS details page.
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
MSFS_APPID="${MSFS_APPID:-2537590}"

"$(dirname "$0")/15-remap-proton-experimental-to-ge.sh"

pkill -f "/snap/steam/.*/fex_launcher.sh" >/dev/null 2>&1 || true
pkill -f "steamwebhelper" >/dev/null 2>&1 || true
pkill -f "/ubuntu12_32/steam" >/dev/null 2>&1 || true
sleep 2

"$(dirname "$0")/05-resume-headless-msfs.sh" install >/tmp/msfs-resume-after-remap.log 2>&1 || true
sleep 8

run_uri() {
  local uri="$1"
  timeout 12s env DISPLAY="$DISPLAY_NUM" steam "$uri" >/tmp/msfs-uri-dispatch.log 2>&1 || true
}

run_uri "steam://nav/library"
sleep 2
run_uri "steam://nav/games/details/${MSFS_APPID}"
sleep 3

if command -v import >/dev/null 2>&1; then
  DISPLAY="$DISPLAY_NUM" import -window root "/tmp/steam-msfs-after-remap-restart.png" || true
  echo "Screenshot: /tmp/steam-msfs-after-remap-restart.png"
fi

echo "Done. If Play does not dispatch from automation, click Play once manually in UI."
