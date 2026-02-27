#!/usr/bin/env bash
set -euo pipefail

APPID="${MSFS_APPID:-2537590}"
STEAM_DIR="$HOME/snap/steam/common/.local/share/Steam"
PREFIX="$STEAM_DIR/steamapps/compatdata/${APPID}/pfx"
ROAMING="$PREFIX/drive_c/users/steamuser/AppData/Roaming"
MSFS2024_DIR="$ROAMING/Microsoft Flight Simulator 2024"
MSFS2020_DIR="$ROAMING/Microsoft Flight Simulator"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$HOME/msfs-on-dgx-spark/output/usercfg-fix-cycle-${TS}.log"

mkdir -p "$MSFS2024_DIR/Packages/Official" "$MSFS2024_DIR/Packages/Community" "$MSFS2020_DIR"
PKG_PATH='C:\users\steamuser\AppData\Roaming\Microsoft Flight Simulator 2024\Packages'

# Canonical UserCfg syntax expected by MSFS parsers.
printf 'InstalledPackagesPath "%s"\n' "$PKG_PATH" > "$MSFS2024_DIR/UserCfg.opt"
cp -f "$MSFS2024_DIR/UserCfg.opt" "$MSFS2020_DIR/UserCfg.opt"

if [ -f "$MSFS2024_DIR/FlightSimulator2024.CFG" ] && [ ! -s "$MSFS2024_DIR/FlightSimulator2024.CFG" ]; then
  rm -f "$MSFS2024_DIR/FlightSimulator2024.CFG"
fi

{
  echo "== usercfg fix cycle =="
  date -u +%FT%TZ
  echo "APPID=$APPID"
  echo "UserCfg 2024:"; cat "$MSFS2024_DIR/UserCfg.opt"
  echo "UserCfg legacy:"; cat "$MSFS2020_DIR/UserCfg.opt"
  echo "FlightSimulator2024.CFG exists?"; ls -l "$MSFS2024_DIR"/FlightSimulator2024.CFG* 2>/dev/null || true

  echo "-- launch via steam pipe --"
  "$HOME/msfs-on-dgx-spark/scripts/19-dispatch-via-steam-pipe.sh" "steam://rungameid/${APPID}"

  echo "-- watch app events (75s) --"
  timeout 75 bash -lc "tail -n 0 -F '$STEAM_DIR/logs/connection_log.txt' '$STEAM_DIR/logs/bootstrap_log.txt' '$STEAM_DIR/logs/console_log.txt'" \
    | grep -E "(StartSession|GameAction|App Running|AppID ${APPID}|Creating process|waitforexitandrun|error|failed|crash)" || true

  echo "-- latest crash report --"
  ls -1t "$HOME/.local/share/Steam/steamapps/common/MSFS2024/AsoboReport-Crash.txt" "$STEAM_DIR/steamapps/common/MSFS2024/AsoboReport-Crash.txt" 2>/dev/null | head -n 1 | while read -r p; do
    echo "crash=$p"
    cp -f "$p" "$HOME/msfs-on-dgx-spark/output/AsoboReport-Crash-2537590-usercfgfix-${TS}.txt" || true
    grep -E "Code=|LastStates|NumRegisteredPackages|EnableD3D12|TimeUTC=" "$p" || true
  done
} | tee "$OUT"

echo "$OUT"
