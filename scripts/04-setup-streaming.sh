#!/usr/bin/env bash
# Set up Sunshine (remote streaming server) on DGX Spark
#
# Since the DGX Spark may be headless or you may want to play from
# another device, Sunshine + Moonlight provides low-latency game streaming.
#
# Sunshine is the open-source self-hosted alternative to NVIDIA GameStream.
# Moonlight is the client (runs on PC, Mac, iOS, Android, etc.)
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
    echo "  2. Use a virtual display (instructions below)"
    echo ""
fi

echo "[1/3] Installing Sunshine..."
if command -v sunshine &>/dev/null; then
    echo "  Sunshine already installed."
    sunshine --version 2>/dev/null || true
else
    echo "  Installing Sunshine from GitHub releases..."
    echo ""
    echo "  Option A: Snap (easiest)"
    echo "    sudo snap install sunshine --edge"
    echo ""
    echo "  Option B: .deb package"
    echo "    Visit: https://github.com/LizardByte/Sunshine/releases"
    echo "    Download the arm64 .deb for Ubuntu 24.04"
    echo "    sudo dpkg -i sunshine-*.deb"
    echo "    sudo apt-get install -f"
    echo ""

    read -rp "  Install via snap? [Y/n] " INSTALL_SNAP
    if [[ "${INSTALL_SNAP:-y}" != [nN] ]]; then
        sudo snap install sunshine --edge || {
            echo "  Snap install failed. Try the .deb method above."
        }
    fi
fi

# Virtual display setup
echo ""
echo "[2/3] Virtual display configuration..."
echo ""
echo "  If running headless, you need a virtual display for Sunshine to capture."
echo ""
echo "  Method: udev virtual monitor (NVIDIA driver-level)"
echo "  Create /etc/X11/xorg.conf.d/99-virtual.conf with:"
echo ""
echo '  Section "Device"'
echo '      Identifier "NVIDIA"'
echo '      Driver "nvidia"'
echo '  EndSection'
echo ""
echo '  Section "Screen"'
echo '      Identifier "Default Screen"'
echo '      Device "NVIDIA"'
echo '      DefaultDepth 24'
echo '      SubSection "Display"'
echo '          Depth 24'
echo '          Modes "1920x1080"'
echo '      EndSubSection'
echo '  EndSection'
echo ""
echo "  Alternatively, use a headless HDMI dummy plug (~\$10) for a real signal."

# Moonlight client info
echo ""
echo "[3/3] Moonlight client setup..."
echo ""
echo "  Install Moonlight on your client device:"
echo "  - PC/Mac: https://moonlight-stream.org/"
echo "  - iOS: App Store → Moonlight Game Streaming"
echo "  - Android: Play Store → Moonlight Game Streaming"
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
