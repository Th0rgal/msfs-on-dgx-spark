#!/usr/bin/env bash
# Wrap official Proton Experimental to force DX11 args for MSFS only.
set -euo pipefail

EXP_DIR="$HOME/snap/steam/common/.local/share/Steam/steamapps/common/Proton - Experimental"
PROTON="$EXP_DIR/proton"
REAL="$EXP_DIR/proton.real"

if [ ! -f "$PROTON" ]; then
  echo "ERROR: Missing proton at $PROTON"
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
  exec "$REAL" "$@" -dx11 -FastLaunch
fi

exec "$REAL" "$@"
WRAP
chmod +x "$PROTON"

echo "Wrapped $PROTON"
head -n 60 "$PROTON"
