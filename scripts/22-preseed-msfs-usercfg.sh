#!/usr/bin/env bash
# Pre-seed MSFS 2024 UserCfg paths in Proton prefix to avoid BOOT_INIT crashes
# where package roots are unresolved (NumRegisteredPackages=0).
set -euo pipefail

APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
PREFIX="$STEAM_DIR/steamapps/compatdata/${APPID}/pfx"
ROAMING="$PREFIX/drive_c/users/steamuser/AppData/Roaming"
MSFS2024_DIR="$ROAMING/Microsoft Flight Simulator 2024"
MSFS2020_DIR="$ROAMING/Microsoft Flight Simulator"

if [ ! -d "$PREFIX" ]; then
  echo "ERROR: Missing Proton prefix: $PREFIX"
  exit 1
fi

mkdir -p "$MSFS2024_DIR/Packages/Official" "$MSFS2024_DIR/Packages/Community"
mkdir -p "$MSFS2020_DIR"

# Use a Windows-style path the sim can resolve in Proton.
PKG_PATH='C:\users\steamuser\AppData\Roaming\Microsoft Flight Simulator 2024\Packages'

cat > "$MSFS2024_DIR/UserCfg.opt" <<CFG
{InstalledPackagesPath "$PKG_PATH"}
CFG

# Some components/tools still probe the legacy Roaming folder name.
cp -f "$MSFS2024_DIR/UserCfg.opt" "$MSFS2020_DIR/UserCfg.opt"

# Clear zero-byte cfg that may carry stale/invalid state.
if [ -f "$MSFS2024_DIR/FlightSimulator2024.CFG" ] && [ ! -s "$MSFS2024_DIR/FlightSimulator2024.CFG" ]; then
  mv "$MSFS2024_DIR/FlightSimulator2024.CFG" "$MSFS2024_DIR/FlightSimulator2024.CFG.bak.$(date -u +%Y%m%dT%H%M%SZ)"
fi

echo "Seeded UserCfg files:"
ls -l "$MSFS2024_DIR/UserCfg.opt" "$MSFS2020_DIR/UserCfg.opt"
echo "2024 UserCfg contents:"
cat "$MSFS2024_DIR/UserCfg.opt"
