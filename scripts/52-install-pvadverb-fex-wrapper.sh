#!/usr/bin/env bash
# Install a host pv-adverb wrapper that runs the x86_64 helper via FEX.
#
# Why this exists:
# On DGX Spark ARM64 + Steam Snap, webhelper can loop with:
#   bwrap: execvp .../pv-adverb: No such file or directory
# because pressure-vessel expects a host pv-adverb path.
#
# Trust boundary note:
# This script writes to /usr/lib/pressure-vessel/from-host/... using sudo.
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this script as a normal user (it uses sudo internally)."
  exit 1
fi

if ! command -v FEXInterpreter >/dev/null 2>&1; then
  echo "ERROR: FEXInterpreter not found. Install/enable FEX first."
  exit 1
fi

find_steam_dir() {
  local paths=(
    "$HOME/snap/steam/common/.local/share/Steam"
    "$HOME/.local/share/Steam"
    "$HOME/.steam/steam"
  )
  local p
  for p in "${paths[@]}"; do
    if [ -d "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi

PV_SRC="$STEAM_DIR/steamrt64/pv-runtime/steam-runtime-steamrt/pressure-vessel/libexec/steam-runtime-tools-0/pv-adverb"
if [ ! -x "$PV_SRC" ]; then
  echo "ERROR: pv-adverb source binary missing: $PV_SRC"
  exit 1
fi

PV_HOST_DIR="/usr/lib/pressure-vessel/from-host/libexec/steam-runtime-tools-0"
PV_HOST_WRAPPER="$PV_HOST_DIR/pv-adverb"
PV_HOST_X86="$PV_HOST_DIR/pv-adverb.x86_64"
TS="$(date -u +%Y%m%dT%H%M%SZ)"

echo "Installing host pv-adverb FEX wrapper..."
echo "  Steam dir: $STEAM_DIR"
echo "  Source:    $PV_SRC"
echo "  Host dir:  $PV_HOST_DIR"

sudo mkdir -p "$PV_HOST_DIR"
if [ -e "$PV_HOST_WRAPPER" ] || [ -L "$PV_HOST_WRAPPER" ]; then
  sudo cp -a "$PV_HOST_WRAPPER" "$PV_HOST_WRAPPER.bak.$TS" || true
fi

sudo cp -f "$PV_SRC" "$PV_HOST_X86"
sudo chmod 0755 "$PV_HOST_X86"
sudo tee "$PV_HOST_WRAPPER" >/dev/null <<EOF
#!/bin/sh
set -eu
exec /usr/bin/FEXInterpreter "$PV_HOST_X86" "\$@"
EOF
sudo chmod 0755 "$PV_HOST_WRAPPER"

echo "Verifying wrapper..."
sudo ls -l "$PV_HOST_WRAPPER" "$PV_HOST_X86"
set +e
"$PV_HOST_WRAPPER" --help >/tmp/pv-adverb-wrapper-help.txt 2>&1
code=$?
set -e
if [ "$code" -ne 0 ]; then
  echo "WARN: wrapper self-test returned non-zero ($code)."
else
  echo "Wrapper self-test succeeded."
fi
sed -n '1,10p' /tmp/pv-adverb-wrapper-help.txt || true

cat <<'MSG'
Done.
Recommended next step:
  1) Restart Steam processes.
  2) Re-run scripts/08-finalize-auth-and-run-msfs.sh.
MSG
