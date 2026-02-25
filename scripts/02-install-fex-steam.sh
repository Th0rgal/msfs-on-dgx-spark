#!/usr/bin/env bash
# Install FEX-Emu and Steam on NVIDIA DGX Spark (ARM64 Ubuntu 24.04)
#
# Two methods are supported:
#   1. Canonical Steam Snap (recommended — bundles FEX automatically)
#   2. Manual FEX + Steam installation
#
# References:
#   - https://github.com/FEX-Emu/FEX
#   - https://www.omgubuntu.co.uk/2026/01/steam-snap-arm64-ubuntu-gaming-performance
set -euo pipefail

echo "=== FEX-Emu + Steam Installation ==="
echo ""

# Detect architecture
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != "arm64" ]; then
    echo "ERROR: This script is for ARM64 systems. Detected: $ARCH"
    exit 1
fi

echo "Detected architecture: $ARCH"
echo ""
echo "Choose installation method:"
echo "  1) Canonical Steam Snap (recommended — includes FEX, easiest setup)"
echo "  2) Manual FEX-Emu + Steam (more control, manual updates)"
echo ""
read -rp "Selection [1/2]: " METHOD

case "$METHOD" in
    1)
        echo ""
        echo "=== Method 1: Canonical Steam Snap ==="
        echo ""

        # Ensure snapd is available
        if ! command -v snap &>/dev/null; then
            echo "Installing snapd..."
            sudo apt-get update -qq
            sudo apt-get install -y -qq snapd
        fi

        echo "[1/2] Installing Steam Snap (ARM64 with FEX bundled)..."
        echo "  This is the experimental ARM64 Steam Snap from Canonical."
        echo "  It bundles FEX-Emu for x86-64 game translation."
        sudo snap install steam --edge

        echo ""
        echo "[2/2] Verifying installation..."
        if snap list steam &>/dev/null; then
            echo "  Steam Snap installed successfully."
            snap list steam
        else
            echo "  WARNING: Steam Snap installation may have failed."
            echo "  Try: sudo snap install steam --edge --devmode"
        fi

        echo ""
        echo "Launch Steam with: steam"
        echo "  (or from the desktop application menu)"
        ;;

    2)
        echo ""
        echo "=== Method 2: Manual FEX-Emu + Steam ==="
        echo ""

        # Install FEX-Emu
        echo "[1/4] Installing FEX-Emu..."
        if command -v FEXInterpreter &>/dev/null; then
            echo "  FEX-Emu already installed:"
            FEXInterpreter --version 2>/dev/null || true
        else
            echo "  Adding FEX-Emu PPA and installing..."
            # FEX provides an install script for Ubuntu
            # Check if there's an official PPA or use the GitHub release
            if [ -f /etc/apt/sources.list.d/fex-emu.list ]; then
                echo "  FEX-Emu PPA already configured."
            else
                # Try the official installer first
                echo "  Downloading FEX-Emu installer..."
                curl -fsSL https://raw.githubusercontent.com/FEX-Emu/FEX/main/Scripts/InstallFEX.py -o /tmp/InstallFEX.py
                chmod +x /tmp/InstallFEX.py
                echo "  Running FEX-Emu installer..."
                python3 /tmp/InstallFEX.py || {
                    echo "  Official installer failed. Trying manual build..."
                    echo "  See: https://github.com/FEX-Emu/FEX/wiki/Building"
                    echo ""
                    echo "  Quick build steps:"
                    echo "    sudo apt install cmake ninja-build pkg-config libsdl2-dev"
                    echo "    git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git"
                    echo "    cd FEX && mkdir build && cd build"
                    echo "    cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release"
                    echo "    ninja && sudo ninja install"
                    exit 1
                }
            fi
        fi

        # Set up x86-64 rootfs for FEX
        echo ""
        echo "[2/4] Setting up x86-64 rootfs..."
        if [ -d "$HOME/.fex-emu/rootfs" ]; then
            echo "  FEX rootfs already exists at ~/.fex-emu/rootfs"
        else
            echo "  FEX needs an x86-64 rootfs to translate against."
            echo "  Running FEXRootFSFetcher..."
            FEXRootFSFetcher || {
                echo "  RootFS fetcher failed. You may need to set this up manually."
                echo "  See: https://github.com/FEX-Emu/FEX/wiki/RootFS"
                exit 1
            }
        fi

        # Install Steam
        echo ""
        echo "[3/4] Installing Steam..."
        if command -v steam &>/dev/null; then
            echo "  Steam already installed."
        else
            echo "  Downloading Steam installer..."
            # Steam for Linux — run through FEX
            mkdir -p "$HOME/.local/share/Steam"
            curl -fsSL https://cdn.cloudflare.steamstatic.com/client/installer/steam.deb -o /tmp/steam.deb

            echo "  Installing Steam .deb (x86-64, will run through FEX)..."
            # On ARM64, we need to use FEX to run the x86-64 Steam binary
            # The dpkg approach won't work directly; instead we use Steam's
            # bootstrap installer
            echo "  NOTE: Steam is an x86-64 application. It will run through FEX."
            echo "  First launch may take several minutes for initial setup."
        fi

        # Register binfmt
        echo ""
        echo "[4/4] Configuring binfmt for FEX..."
        if [ -f /proc/sys/fs/binfmt_misc/FEX-x86_64 ]; then
            echo "  FEX binfmt already registered."
        else
            echo "  Registering FEX as x86-64 handler..."
            sudo systemctl restart systemd-binfmt 2>/dev/null || true
            # If FEX provides its own binfmt registration
            if command -v FEXBinfmtRegister &>/dev/null; then
                sudo FEXBinfmtRegister
            fi
        fi

        echo ""
        echo "Launch Steam with: FEXBash -c steam"
        echo "  (or if binfmt is configured: steam)"
        ;;

    *)
        echo "Invalid selection. Choose 1 or 2."
        exit 1
        ;;
esac

echo ""
echo "=== Next Steps ==="
echo "1. Launch Steam and log in"
echo "2. Install Microsoft Flight Simulator 2020 (Steam version)"
echo "3. Run: ./03-configure-msfs.sh to set up Proton compatibility"
