#!/usr/bin/env bash
# Force MSFS to use NVIDIA Vulkan adapter for vkd3d without disabling D3D12.
set -euo pipefail

GE_DIR="${GE_DIR:-$HOME/snap/steam/common/.local/share/Steam/compatibilitytools.d/GE-Proton10-32}"
PROTON="$GE_DIR/proton"
REAL="$GE_DIR/proton.real"

if [ ! -f "$PROTON" ]; then
  echo "ERROR: proton entrypoint not found: $PROTON"
  exit 2
fi

if [ ! -f "$REAL" ]; then
  mv -f "$PROTON" "$REAL"
fi

cat > "$PROTON" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
SELF_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
REAL="$SELF_DIR/proton.real"

if printf '%s\n' "$*" | grep -q 'MSFS2024/FlightSimulator2024.exe'; then
  export PROTON_LOG=1
  export PROTON_LOG_DIR="/home/th0rgal/msfs-on-dgx-spark/output"
  export STEAM_LINUX_RUNTIME_LOG=1

  # Force vkd3d to the NVIDIA GPU, avoid llvmpipe auto-selection.
  export VKD3D_VULKAN_DEVICE=0
  export VKD3D_FILTER_DEVICE_NAME="NVIDIA Tegra NVIDIA GB10"
  export DXVK_FILTER_DEVICE_NAME="NVIDIA Tegra NVIDIA GB10"
  export VKD3D_DEBUG=warn

  exec "$REAL" "$@" -FastLaunch
fi

exec "$REAL" "$@"
WRAP

chmod +x "$PROTON"
echo "Wrapped for NVIDIA vkd3d selection: $PROTON"
head -n 80 "$PROTON"
