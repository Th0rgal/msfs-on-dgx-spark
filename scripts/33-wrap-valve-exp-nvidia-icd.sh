#!/usr/bin/env bash
# Wrap Valve Proton Experimental to force NVIDIA-only Vulkan ICD for MSFS.
set -euo pipefail

STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
EXP_DIR="$STEAM_DIR/steamapps/common/Proton - Experimental"
PROTON="$EXP_DIR/proton"
REAL="$EXP_DIR/proton.real"

NVLIB_DIR="/tmp/nvlibs64"
ICD_JSON="/tmp/nvidia-only-icd.json"

mkdir -p "$NVLIB_DIR"
rm -f "$NVLIB_DIR"/*
for f in "$HOME"/snap/steam/common/x86_rootfs/usr/lib/x86_64-linux-gnu/libGLX_nvidia.so* \
         "$HOME"/snap/steam/common/x86_rootfs/usr/lib/x86_64-linux-gnu/libnvidia-*.so*; do
  [ -e "$f" ] && ln -sf "$f" "$NVLIB_DIR"/
done

cat > "$ICD_JSON" <<JSON
{
  "file_format_version": "1.0.1",
  "ICD": {
    "library_path": "$NVLIB_DIR/libGLX_nvidia.so.0",
    "api_version": "1.4.312"
  }
}
JSON

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
  export LD_LIBRARY_PATH="/tmp/nvlibs64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export VK_ICD_FILENAMES="/tmp/nvidia-only-icd.json"
  export VK_DRIVER_FILES="/tmp/nvidia-only-icd.json"
  export PROTON_ENABLE_WAYLAND=0
  export VKD3D_FEATURE_LEVEL=12_0
  export VKD3D_CONFIG=nodxr
  export VKD3D_DISABLE_EXTENSIONS="VK_NVX_binary_import,VK_NVX_image_view_handle,VK_KHR_ray_tracing_pipeline,VK_KHR_acceleration_structure,VK_KHR_ray_query"
  exec "$REAL" "$@" -FastLaunch
fi

exec "$REAL" "$@"
WRAP
chmod +x "$PROTON"

echo "Wrapped $PROTON"
head -n 50 "$PROTON"
echo "Prepared $ICD_JSON and $NVLIB_DIR"
ls -l "$ICD_JSON" "$NVLIB_DIR" | sed -n '1,20p'
