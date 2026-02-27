#!/usr/bin/env bash
# Configure Proton for Microsoft Flight Simulator on DGX Spark
#
# This script sets up the correct Proton version and launch options
# for MSFS 2020 (and optionally MSFS 2024).
set -euo pipefail

MSFS_2020_APPID="1250410"
MSFS_2024_APPID="2537590"

echo "=== MSFS Proton Configuration ==="
echo ""

# Detect Steam installation
STEAM_DIR=""
POSSIBLE_PATHS=(
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
    "$HOME/snap/steam/common/.local/share/Steam"
)

for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        STEAM_DIR="$path"
        break
    fi
done

if [ -z "$STEAM_DIR" ]; then
    echo "ERROR: Steam installation not found."
    echo "Checked: ${POSSIBLE_PATHS[*]}"
    echo "Install Steam first with: ./02-install-fex-steam.sh"
    exit 1
fi

echo "Steam directory: $STEAM_DIR"
echo ""

# Check for Proton versions
echo "[1/3] Checking Proton installations..."
PROTON_DIR="$STEAM_DIR/steamapps/common"
if [ -d "$PROTON_DIR" ]; then
    echo "  Installed Proton versions:"
    ls -d "$PROTON_DIR"/Proton* 2>/dev/null | while read -r p; do
        echo "    - $(basename "$p")"
    done || echo "    (none found)"
else
    echo "  Proton directory not found. Steam may not have been run yet."
fi

echo ""
echo "  Recommended Proton versions for MSFS:"
echo "    - Proton 10.0-2 (beta) or later — best ARM compatibility"
echo "    - Proton Experimental (Bleeding Edge) — latest fixes"
echo "    - Proton-GE (community) — often better game compatibility"
echo ""
echo "  To install: Steam → Settings → Compatibility → enable Steam Play for all titles"
echo "  Then install the desired Proton version from Steam's Tools section."

# Set launch options
echo ""
echo "[2/3] Recommended launch options..."
echo ""
echo "  For MSFS 2020 (AppID: $MSFS_2020_APPID):"
echo "    Right-click → Properties → General → Launch Options:"
echo ""
echo "    DXVK_HUD=fps,devinfo %command% -FastLaunch"
echo ""
echo "    Breakdown:"
echo "      DXVK_HUD=fps,devinfo  — Show FPS and GPU info overlay"
echo "      -FastLaunch            — Skip intro videos (avoids Wine crash)"
echo ""
echo "  For MSFS 2024 (AppID: $MSFS_2024_APPID):"
echo "    Right-click → Properties → General → Launch Options:"
echo ""
echo "    VKD3D_CONFIG=dxr DXVK_HUD=fps,devinfo %command% -FastLaunch"
echo ""
echo "    Breakdown:"
echo "      VKD3D_CONFIG=dxr  — Enable DirectX Raytracing translation"

# Force Proton version
echo ""
echo "[3/3] Forcing Proton compatibility..."
echo ""
echo "  For each MSFS title in Steam:"
echo "    Right-click → Properties → Compatibility"
echo "    Check 'Force the use of a specific Steam Play compatibility tool'"
echo "    Select: Proton 10.0-2 (beta) or later"
echo ""

# Create a helper script for environment variables
HELPER_SCRIPT="$HOME/launch-msfs.sh"
cat > "$HELPER_SCRIPT" << 'LAUNCH_EOF'
#!/usr/bin/env bash
# Helper to launch MSFS with optimal settings on DGX Spark
# Usage: ./launch-msfs.sh [2020|2024]

GAME="${1:-2020}"

# Performance environment variables
export DXVK_HUD="fps,devinfo"
export WINE_FULLSCREEN_FSR=1
export WINE_FULLSCREEN_FSR_STRENGTH=2
export STAGING_SHARED_MEMORY=1
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240

# DGX Spark specific: prefer performance governor if available
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    CURRENT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
    if [ "$CURRENT_GOV" != "performance" ]; then
        echo "CPU governor is '$CURRENT_GOV'. For best performance:"
        echo "  sudo cpupower frequency-set -g performance"
    fi
fi

case "$GAME" in
    2020)
        echo "Launching MSFS 2020 via Steam..."
        echo "  AppID: 1250410"
        steam steam://rungameid/1250410
        ;;
    2024)
        echo "Launching MSFS 2024 via Steam..."
        echo "  AppID: 2537590"
        export VKD3D_CONFIG="dxr"
        steam steam://rungameid/2537590
        ;;
    *)
        echo "Usage: $0 [2020|2024]"
        exit 1
        ;;
esac
LAUNCH_EOF
chmod +x "$HELPER_SCRIPT"
echo "Created helper script: $HELPER_SCRIPT"
echo "  Usage: ~/launch-msfs.sh 2020"
echo "         ~/launch-msfs.sh 2024"
echo ""
echo "=== Configuration Complete ==="
echo ""
echo "Next steps:"
echo "  1. Launch Steam and install MSFS 2024"
echo "  2. Set Proton version to 10.0-2+ in game properties"
echo "  3. Add launch options: VKD3D_CONFIG=dxr DXVK_HUD=fps,devinfo %command% -FastLaunch"
echo "  4. Launch the game and report results!"
echo ""
echo "If the game crashes on startup, check docs/troubleshooting.md"
