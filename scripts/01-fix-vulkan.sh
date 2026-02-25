#!/usr/bin/env bash
# Fix Vulkan drivers on NVIDIA DGX Spark
# The shipped driver (580.95.05) has a bug where libnvidia-gl-580 is not
# installed, causing vulkaninfo to only show llvmpipe (software rendering).
# Reference: https://gist.github.com/solatticus/14313d9629c4896abfdf57aaf421a07a
set -euo pipefail

echo "=== DGX Spark Vulkan Driver Fix ==="
echo ""

# Check current state
echo "[1/4] Checking current Vulkan status..."
if command -v vulkaninfo &>/dev/null; then
    VULKAN_GPUS=$(vulkaninfo --summary 2>/dev/null | grep -c "GPU" || true)
    VULKAN_NVIDIA=$(vulkaninfo --summary 2>/dev/null | grep -c "NVIDIA" || true)
    if [ "$VULKAN_NVIDIA" -gt 0 ]; then
        echo "  NVIDIA Vulkan driver already working. You may not need this fix."
        vulkaninfo --summary 2>/dev/null | grep -E "GPU|driver|apiVersion" || true
        read -rp "  Continue anyway? [y/N] " confirm
        if [[ "$confirm" != [yY] ]]; then
            echo "  Exiting."
            exit 0
        fi
    else
        echo "  Vulkan found but no NVIDIA GPU detected. Applying fix..."
    fi
else
    echo "  vulkaninfo not found. Installing vulkan-tools..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq vulkan-tools
fi

# Check if libnvidia-gl is installed
echo ""
echo "[2/4] Checking NVIDIA GL/Vulkan packages..."
if dpkg -l | grep -q "libnvidia-gl-580"; then
    echo "  libnvidia-gl-580 is installed."
    dpkg -l | grep "libnvidia-gl-580"
else
    echo "  libnvidia-gl-580 is MISSING. Installing..."
    sudo apt-get update -qq
    sudo apt-get install -y libnvidia-gl-580
fi

# Ensure the Vulkan ICD file points to the right library
echo ""
echo "[3/4] Checking Vulkan ICD configuration..."
NVIDIA_ICD="/usr/share/vulkan/icd.d/nvidia_icd.json"
if [ -f "$NVIDIA_ICD" ]; then
    echo "  NVIDIA Vulkan ICD file exists:"
    cat "$NVIDIA_ICD"
else
    echo "  WARNING: NVIDIA Vulkan ICD file not found at $NVIDIA_ICD"
    echo "  The driver package may need to be reinstalled."
fi

# Check for driver update
echo ""
echo "[4/4] Checking driver version..."
CURRENT_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null || echo "unknown")
echo "  Current driver: $CURRENT_DRIVER"
if [[ "$CURRENT_DRIVER" == "580.95.05" ]]; then
    echo "  NOTE: Driver 580.95.05 has known Vulkan bugs."
    echo "  Driver 580.105.08+ is recommended."
    echo "  Check for updates: sudo apt-get update && apt list --upgradable 2>/dev/null | grep nvidia"
fi

# Verify fix
echo ""
echo "=== Verification ==="
if command -v vulkaninfo &>/dev/null; then
    echo "Vulkan devices:"
    vulkaninfo --summary 2>/dev/null | grep -E "GPU|driver|apiVersion" || echo "  Failed to query Vulkan devices"
fi

echo ""
echo "If NVIDIA GPU still not showing, try:"
echo "  1. Reboot: sudo reboot"
echo "  2. Reinstall driver: sudo apt-get install --reinstall libnvidia-gl-580"
echo "  3. Check dmesg for GPU errors: dmesg | grep -i nvidia"
