#!/usr/bin/env bash
# Repair known DGX Spark runtime blockers before launching MSFS 2024.
#
# Repairs included:
# 1) Ensure host pv-adverb path exists (via FEX wrapper install script)
# 2) Populate pressure-vessel Vulkan override manifests to avoid runtime internal errors
# 3) Bridge MSFS package probe paths in Proton prefix to canonical game Packages root
set -euo pipefail

MSFS_APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
INSTALL_PV_ADVERB_WRAPPER="${INSTALL_PV_ADVERB_WRAPPER:-1}"
FIX_VULKAN_OVERRIDES="${FIX_VULKAN_OVERRIDES:-1}"
FIX_MSFS2024_PACKAGE_PATHS="${FIX_MSFS2024_PACKAGE_PATHS:-1}"
HARDEN_LAUNCH_OPTIONS="${HARDEN_LAUNCH_OPTIONS:-1}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PV_HOST_WRAPPER="/usr/lib/pressure-vessel/from-host/libexec/steam-runtime-tools-0/pv-adverb"
PV_OVR_BASE="/usr/lib/pressure-vessel/overrides/share/vulkan"
PV_OVR_IMPLICIT="$PV_OVR_BASE/implicit_layer.d"
PV_OVR_EXPLICIT="$PV_OVR_BASE/explicit_layer.d"

if [ ! -d "$STEAM_DIR" ]; then
  echo "WARN: Steam dir not found: $STEAM_DIR"
  echo "Skipping preflight repairs."
  exit 0
fi

echo "MSFS runtime preflight repair"
echo "  AppID: $MSFS_APPID"
echo "  Steam dir: $STEAM_DIR"

repair_pv_adverb_wrapper() {
  local installer="$SCRIPT_DIR/52-install-pvadverb-fex-wrapper.sh"
  if [ "$INSTALL_PV_ADVERB_WRAPPER" != "1" ]; then
    echo "[pv-adverb] skipped (INSTALL_PV_ADVERB_WRAPPER=0)"
    return 0
  fi

  if [ -x "$PV_HOST_WRAPPER" ]; then
    echo "[pv-adverb] host wrapper already present: $PV_HOST_WRAPPER"
    return 0
  fi

  if [ ! -x "$installer" ]; then
    echo "WARN: missing installer script: $installer"
    return 0
  fi

  echo "[pv-adverb] installing host wrapper..."
  "$installer" || true
  if [ -x "$PV_HOST_WRAPPER" ]; then
    echo "[pv-adverb] installed: $PV_HOST_WRAPPER"
  else
    echo "WARN: pv-adverb wrapper install did not produce $PV_HOST_WRAPPER"
  fi
}

populate_vulkan_overrides() {
  local copied_implicit=0
  local copied_explicit=0
  local src f
  local implicit_sources=(
    "$HOME/snap/steam/common/x86_rootfs/usr/share/vulkan/implicit_layer.d"
    "$HOME/snap/steam/common/.local/share/vulkan/implicit_layer.d"
    "/snap/steam/current/usr/share/vulkan/implicit_layer.d"
    "/snap/steam/241/usr/share/vulkan/implicit_layer.d"
  )
  local explicit_sources=(
    "$HOME/snap/steam/common/x86_rootfs/usr/share/vulkan/explicit_layer.d"
    "/snap/steam/current/usr/share/vulkan/explicit_layer.d"
    "/snap/steam/241/usr/share/vulkan/explicit_layer.d"
  )

  if [ "$FIX_VULKAN_OVERRIDES" != "1" ]; then
    echo "[vulkan-overrides] skipped (FIX_VULKAN_OVERRIDES=0)"
    return 0
  fi

  echo "[vulkan-overrides] syncing manifests into $PV_OVR_BASE"
  sudo mkdir -p "$PV_OVR_IMPLICIT" "$PV_OVR_EXPLICIT"
  sudo chmod 755 /usr/lib/pressure-vessel /usr/lib/pressure-vessel/overrides \
    /usr/lib/pressure-vessel/overrides/share "$PV_OVR_BASE" "$PV_OVR_IMPLICIT" "$PV_OVR_EXPLICIT"

  for src in "${implicit_sources[@]}"; do
    [ -d "$src" ] || continue
    for f in "$src"/*.json; do
      [ -f "$f" ] || continue
      sudo install -m 644 "$f" "$PV_OVR_IMPLICIT/$(basename "$f")"
      copied_implicit=$((copied_implicit + 1))
    done
  done

  for src in "${explicit_sources[@]}"; do
    [ -d "$src" ] || continue
    for f in "$src"/*.json; do
      [ -f "$f" ] || continue
      sudo install -m 644 "$f" "$PV_OVR_EXPLICIT/$(basename "$f")"
      copied_explicit=$((copied_explicit + 1))
    done
  done

  echo "[vulkan-overrides] copied implicit=$copied_implicit explicit=$copied_explicit"
}

ln_replace() {
  local target="$1"
  local link="$2"
  if [ -L "$link" ] || [ -f "$link" ]; then
    rm -f "$link"
  elif [ -d "$link" ]; then
    rm -rf "$link"
  fi
  ln -s "$target" "$link"
}

to_win_z_path() {
  local p="$1"
  p="${p//\//\\}"
  printf 'Z:%s' "$p"
}

repair_msfs2024_packages() {
  local game_dir="$STEAM_DIR/steamapps/common/MSFS2024"
  local prefix="$STEAM_DIR/steamapps/compatdata/${MSFS_APPID}/pfx"
  local user_win_home="$prefix/drive_c/users/steamuser"
  local canonical_pkg="$game_dir/Packages"
  local roaming_2024="$user_win_home/AppData/Roaming/Microsoft Flight Simulator 2024"
  local roaming_legacy="$user_win_home/AppData/Roaming/Microsoft Flight Simulator"
  local local_pkg_root="$user_win_home/AppData/Local/Packages"
  local win_pkg_path marker_count family

  if [ "$FIX_MSFS2024_PACKAGE_PATHS" != "1" ]; then
    echo "[package-paths] skipped (FIX_MSFS2024_PACKAGE_PATHS=0)"
    return 0
  fi

  if [ "$MSFS_APPID" != "2537590" ]; then
    echo "[package-paths] skipping for non-2024 appid: $MSFS_APPID"
    return 0
  fi

  if [ ! -d "$prefix" ]; then
    echo "WARN: Proton prefix missing: $prefix"
    return 0
  fi
  if [ ! -d "$game_dir" ]; then
    echo "WARN: game dir missing (install may not be complete yet): $game_dir"
    return 0
  fi

  echo "[package-paths] wiring package probes to canonical root..."
  mkdir -p "$canonical_pkg/Official/Steam" "$canonical_pkg/Community"
  if [ ! -e "$canonical_pkg/Official/OneStore" ]; then
    ln -s "Steam" "$canonical_pkg/Official/OneStore"
  fi

  mkdir -p "$roaming_2024" "$roaming_legacy" "$local_pkg_root"
  ln_replace "$canonical_pkg" "$roaming_2024/Packages"
  ln_replace "$canonical_pkg" "$roaming_legacy/Packages"

  for family in \
    "Microsoft.FlightSimulator_8wekyb3d8bbwe" \
    "Microsoft.Limitless_8wekyb3d8bbwe" \
    "Microsoft.FlightSimulator2024_8wekyb3d8bbwe"
  do
    mkdir -p "$local_pkg_root/$family/LocalCache"
    ln_replace "$canonical_pkg" "$local_pkg_root/$family/LocalCache/Packages"
  done

  win_pkg_path="$(to_win_z_path "$canonical_pkg")"
  printf 'InstalledPackagesPath "%s"\n' "$win_pkg_path" > "$roaming_2024/UserCfg.opt"
  cp -f "$roaming_2024/UserCfg.opt" "$roaming_legacy/UserCfg.opt"
  echo "[package-paths] UserCfg.opt => $win_pkg_path"

  marker_count="$(find "$canonical_pkg" -maxdepth 6 -type f \( -name 'manifest.json' -o -name 'layout.json' -o -name '*.fspackage' -o -name '*.fsarchive' \) | wc -l)"
  echo "[package-paths] package markers: $marker_count"
  if [ "$marker_count" -eq 0 ]; then
    echo "WARN: no package markers found under $canonical_pkg"
  fi
}

set_safe_launch_options() {
  local launch_setter="$SCRIPT_DIR/28-set-localconfig-launch-options.sh"
  local repo_output="$HOME/msfs-on-dgx-spark/output"
  local safe_opts

  if [ "$HARDEN_LAUNCH_OPTIONS" != "1" ]; then
    echo "[launch-options] skipped (HARDEN_LAUNCH_OPTIONS=0)"
    return 0
  fi

  if [ ! -x "$launch_setter" ]; then
    echo "WARN: launch option setter not found: $launch_setter"
    return 0
  fi

  safe_opts="PROTON_LOG=1 PROTON_LOG_DIR=${repo_output} VK_LOADER_LAYERS_DISABLE=~implicit~ DISABLE_VK_LAYER_VALVE_steam_overlay_1=1 DISABLE_VK_LAYER_MESA_device_select=1 VK_LAYER_PATH= VK_ADD_LAYER_PATH= PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0 PRESSURE_VESSEL_REMOVE_GAME_OVERLAY=1 %command% -FastLaunch"
  echo "[launch-options] setting hardened launch options"
  MSFS_APPID="$MSFS_APPID" STEAM_DIR="$STEAM_DIR" LAUNCH_OPTIONS="$safe_opts" "$launch_setter" || true
}

repair_pv_adverb_wrapper
populate_vulkan_overrides
repair_msfs2024_packages
set_safe_launch_options

echo "Preflight repair complete."
