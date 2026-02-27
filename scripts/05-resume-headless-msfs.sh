#!/usr/bin/env bash
# Resume headless Steam session and trigger MSFS install/launch on DGX Spark.
set -euo pipefail

"$(dirname "$0")/17-fix-xdg-user-dirs.sh" >/dev/null 2>&1 || true

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
RESOLUTION="${RESOLUTION:-1920x1080x24}"
MSFS_APPID="${MSFS_APPID:-2537590}"
ACTION="${1:-install}"   # install|launch

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
    echo "ERROR: Steam directory not found. Run scripts/02-install-fex-steam.sh first."
    exit 1
fi

MANIFEST="$STEAM_DIR/steamapps/appmanifest_${MSFS_APPID}.acf"

if ! pgrep -f "Xvfb ${DISPLAY_NUM}" >/dev/null; then
    Xvfb "$DISPLAY_NUM" -screen 0 "$RESOLUTION" >/tmp/xvfb-msfs.log 2>&1 &
    sleep 1
fi

if ! pgrep -x openbox >/dev/null; then
    DISPLAY="$DISPLAY_NUM" openbox >/tmp/openbox-msfs.log 2>&1 &
    sleep 1
fi

if ! pgrep -f steamwebhelper >/dev/null; then
    DISPLAY="$DISPLAY_NUM" steam >/tmp/steam-msfs.log 2>&1 &
    sleep 4
fi

if ! pgrep -f "x11vnc .* -rfbport 5901" >/dev/null; then
    x11vnc -display "$DISPLAY_NUM" -forever -shared -rfbport 5901 -localhost -nopw >/tmp/x11vnc-msfs.log 2>&1 &
    sleep 1
fi

if [ "$ACTION" = "install" ]; then
    timeout 12s env DISPLAY="$DISPLAY_NUM" steam "steam://install/${MSFS_APPID}" >/tmp/msfs-install-uri.log 2>&1 || true
    echo "Triggered Steam install URI for AppID ${MSFS_APPID}."
else
    timeout 12s env DISPLAY="$DISPLAY_NUM" steam "steam://rungameid/${MSFS_APPID}" >/tmp/msfs-launch-uri.log 2>&1 || true
    echo "Triggered Steam launch URI for AppID ${MSFS_APPID}."
fi

echo ""
echo "Session status:"
echo "  DISPLAY=${DISPLAY_NUM}"
echo "  Steam dir: ${STEAM_DIR}"
if [ -f "$MANIFEST" ]; then
    echo "  Manifest: present (${MANIFEST})"
    grep -E '"StateFlags"|"buildid"|"BytesDownloaded"|"BytesToDownload"' "$MANIFEST" || true
else
    echo "  Manifest: missing (MSFS not yet queued/installed in this Steam account)"
fi

echo ""
echo "VNC tunnel target is localhost-only on DGX: 127.0.0.1:5901"
echo "Use: ssh -L 5901:127.0.0.1:5901 th0rgal@100.77.4.93"
