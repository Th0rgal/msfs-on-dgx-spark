#!/usr/bin/env bash
# Enable user namespaces (for native Steam runtime) and force FEX Vulkan/GL thunks.
set -euo pipefail

ROOTFS_NAME="$(FEXGetConfig --current-rootfs 2>/dev/null || true)"
if [ -z "$ROOTFS_NAME" ]; then
  ROOTFS_NAME="Fedora_43"
fi

run_privileged() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required for non-root execution." >&2
    echo "Run this script as root or install sudo." >&2
    exit 1
  fi

  if sudo -n true >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  if [ -n "${SUDO_PASSWORD:-}" ]; then
    # Optional non-interactive path for automation; password is never stored in repo.
    printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@"
    return
  fi

  echo "ERROR: privileged command requires sudo access." >&2
  echo "Set up passwordless sudo, run this script as root, or export SUDO_PASSWORD for non-interactive automation." >&2
  exit 1
}

echo "[1/3] Enabling user namespaces (AppArmor gate)..."
run_privileged sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 >/dev/null
# This key may be missing on some builds.
run_privileged sysctl -w kernel.apparmor_restrict_unprivileged_unconfined=0 >/dev/null 2>&1 || true

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
