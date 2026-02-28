#!/usr/bin/env bash
# Enable user namespaces (for native Steam runtime) and force FEX Vulkan/GL thunks.
set -euo pipefail

ROOTFS_NAME="$(FEXGetConfig --current-rootfs 2>/dev/null || true)"
if [ -z "$ROOTFS_NAME" ]; then
  ROOTFS_NAME="Fedora_43"
fi

echo "[1/3] Enabling user namespaces (AppArmor gate)..."
echo "odkwgfQM" | sudo -S sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 >/dev/null
# This key may be missing on some builds.
echo "odkwgfQM" | sudo -S sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=0 >/dev/null 2>&1 || true

echo "[2/3] Writing FEX thunk config..."
mkdir -p "$HOME/.fex-emu"
cat > "$HOME/.fex-emu/Config.json" <<JSON
{
  "Config": {
    "RootFS": "$ROOTFS_NAME",
    "HideHypervisorBit": true
  },
  "ThunksDB": {
    "Vulkan": 1,
    "GL": 1,
    "drm": 1,
    "WaylandClient": 1,
    "asound": 1
  }
}
JSON

echo "[3/3] Verifying FEX sees NVIDIA Vulkan..."
FEXBash -c "vulkaninfo --summary" 2>/tmp/fex-vk-verify.err | grep -E "GPU0:|deviceName|driverName|vendorID|driverID" | sed -n "1,12p"

echo
echo "Done."
echo "  apparmor_restrict_unprivileged_userns=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)"
echo "  apparmor_restrict_unprivileged_unconfined=$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_unconfined 2>/dev/null || echo n/a)"
