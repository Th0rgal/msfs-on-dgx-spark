#!/usr/bin/env bash
# Set up Sunshine (remote streaming server) on DGX Spark
#
# Since the DGX Spark may be headless or you may want to play from
# another device, Sunshine + Moonlight provides low-latency game streaming.
set -euo pipefail

echo "=== Sunshine Streaming Setup ==="
echo ""

# Check if a display is available
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "No display server detected."
    echo "Sunshine needs a display (real or virtual) to capture."
    echo ""
    echo "Options:"
    echo "  1. Connect a physical display to the DGX Spark"
    echo "  2. Use a virtual display (Xvfb) + x11vnc"
    echo ""
fi

echo "[1/3] Installing Sunshine..."
if command -v sunshine &>/dev/null; then
    echo "  Sunshine already installed."
    sunshine --version 2>/dev/null | head -n 3 || true
else
    ARCH=$(dpkg --print-architecture)
    if [[ "$ARCH" != "arm64" && "$ARCH" != "amd64" ]]; then
        echo "  ERROR: Unsupported architecture for packaged Sunshine: $ARCH"
        exit 1
    fi

    DEB_URL="https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-ubuntu-24.04-${ARCH}.deb"
    DEB_FILE="/tmp/sunshine-ubuntu-24.04-${ARCH}.deb"

    echo "  Downloading Sunshine package: $DEB_URL"
    curl -fL "$DEB_URL" -o "$DEB_FILE"

    echo "  Installing Sunshine package..."
    sudo dpkg -i "$DEB_FILE" || sudo apt-get -f install -y

    echo "  Verifying Sunshine installation..."
    if command -v sunshine &>/dev/null; then
        sunshine --version 2>/dev/null | head -n 3 || true
    else
        echo "  ERROR: Sunshine install failed."
        exit 1
    fi
fi

# Virtual display setup
echo ""
echo "[2/3] Virtual display configuration..."
echo ""
echo "  If running headless, you need a virtual display for Sunshine to capture."
echo ""
echo "  Quick headless option (temporary):"
echo "    Xvfb :1 -screen 0 1920x1080x24 &"
echo "    DISPLAY=:1 openbox &"
echo "    DISPLAY=:1 sunshine"
echo ""
echo "  Persistent option:"
echo "    Configure a real or virtual monitor in Xorg, or use a headless HDMI dummy plug."

# Moonlight client info
echo ""
echo "[3/3] Moonlight client setup..."
echo ""
echo "  Install Moonlight on your client device:"
echo "  - PC/Mac: https://moonlight-stream.org/"
echo "  - iOS: App Store -> Moonlight Game Streaming"
echo "  - Android: Play Store -> Moonlight Game Streaming"
echo ""
echo "  Pairing:"
echo "  1. Start Sunshine on DGX Spark: sunshine"
echo "  2. Open browser: https://<dgx-spark-ip>:47990"
echo "  3. Set up credentials on first run"
echo "  4. Open Moonlight on client and pair with the DGX Spark"
echo ""
echo "  For best results:"
echo "  - Use wired ethernet on both devices"
echo "  - Set Moonlight to 1080p 60fps initially"
echo "  - Enable HEVC/H.265 codec for lower bandwidth"
echo "  - NVIDIA NVENC hardware encoding is available on GB10"
echo ""
echo "=== Streaming Setup Complete ==="
