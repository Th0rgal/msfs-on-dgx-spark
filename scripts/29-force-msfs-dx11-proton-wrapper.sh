#!/usr/bin/env bash
# Force DX11-style startup for MSFS by wrapping GE-Proton entrypoint used by Steam.
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

# Apply only to MSFS 2024 invocation.
if printf '%s\n' "$*" | grep -q 'MSFS2024/FlightSimulator2024.exe'; then
  export WINEDLLOVERRIDES="d3d12,d3d12core=n"
  export PROTON_LOG=1
  export PROTON_LOG_DIR="/home/th0rgal/msfs-on-dgx-spark/output"
  export STEAM_LINUX_RUNTIME_LOG=1
  exec "$REAL" "$@" -dx11 -FastLaunch
fi

exec "$REAL" "$@"
WRAP

chmod +x "$PROTON"

echo "Wrapped: $PROTON"
head -n 24 "$PROTON"
