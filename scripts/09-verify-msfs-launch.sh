#!/usr/bin/env bash
# Verify whether MSFS launch reaches a stable running state (not just transient wrappers).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-display.sh"
DISPLAY_NUM="$(resolve_display_num "$SCRIPT_DIR")"
MSFS_APPID="${MSFS_APPID:-2537590}"
WAIT_SECONDS="${WAIT_SECONDS:-180}"
POLL_SECONDS="${POLL_SECONDS:-5}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-30}"

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

MANIFEST="$STEAM_DIR/steamapps/appmanifest_${MSFS_APPID}.acf"

candidate_processes() {
  pgrep -af "FlightSimulator2024|FlightSimulator\\.exe|gamelaunchhelper\\.exe|AppId=${MSFS_APPID}|proton\\.real|wineserver|rungameid/${MSFS_APPID}" || true
}

strong_processes() {
  local lines="$1"
  printf "%s\n" "$lines" \
    | grep -Ei 'FlightSimulator2024(\.exe)?|FlightSimulator\.exe|gamelaunchhelper\.exe|c:\\windows\\system32\\steam\.exe.*FlightSimulator|Z:\\.*FlightSimulator' \
    | grep -Evi 'waitforexitandrun|steam-launch-wrapper|SteamLaunch AppId|pressure-vessel|/reaper' \
    || true
}

echo "MSFS launch verification"
echo "  Time (UTC): $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "  Host: $(hostname)"
echo "  DISPLAY: ${DISPLAY_NUM}"
echo "  Stability window: ${MIN_STABLE_SECONDS}s"

if [ -f "$MANIFEST" ]; then
  echo "  Manifest: present (${MANIFEST})"
else
  echo "  Manifest: missing (${MANIFEST})"
fi

start_ts="$(date +%s)"
first_any_seen=-1
first_strong_seen=-1
last_any_seen=-1
last_strong_seen=-1
first_any_dump=""
first_strong_dump=""
while true; do
  now="$(date +%s)"
  lines="$(candidate_processes)"
  strong="$(strong_processes "$lines")"

  if [ -n "$lines" ]; then
    last_any_seen="$now"
    if [ "$first_any_seen" -lt 0 ]; then
      first_any_seen="$now"
      first_any_dump="$lines"
      echo "Observed launch candidate processes; monitoring for stability..."
    fi
  fi

  if [ -n "$strong" ]; then
    last_strong_seen="$now"
    if [ "$first_strong_seen" -lt 0 ]; then
      first_strong_seen="$now"
      first_strong_dump="$strong"
      echo "Observed strong MSFS runtime processes:"
      printf "%s\n" "$strong"
    fi

    strong_age=$(( now - first_strong_seen ))
    if [ "$strong_age" -ge "$MIN_STABLE_SECONDS" ]; then
      echo "RESULT: MSFS reached stable runtime (>=${MIN_STABLE_SECONDS}s)"
      printf "%s\n" "$strong"
      exit 0
    fi
  fi

  if [ "$first_any_seen" -ge 0 ] && [ -z "$lines" ]; then
    echo "RESULT: transient launch only; processes exited before stability window"
    echo "  First launch evidence:"
    printf "%s\n" "$first_any_dump"
    if [ "$first_strong_seen" -ge 0 ]; then
      lived=$(( last_strong_seen - first_strong_seen + POLL_SECONDS ))
      echo "  Strong runtime lifetime: ~${lived}s (<${MIN_STABLE_SECONDS}s)"
      echo "  First strong evidence:"
      printf "%s\n" "$first_strong_dump"
    else
      lived=$(( last_any_seen - first_any_seen + POLL_SECONDS ))
      echo "  Wrapper-only lifetime: ~${lived}s"
    fi
    exit 3
  fi

  elapsed=$(( now - start_ts ))
  if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
    if [ "$first_any_seen" -lt 0 ]; then
      echo "RESULT: no MSFS launch process detected after ${WAIT_SECONDS}s"
      echo "Hint: check Steam UI (install dialog, EULA/first-run prompt, or auth challenge)."
      exit 2
    fi
    echo "RESULT: launch seen but did not reach stable runtime within ${WAIT_SECONDS}s"
    if [ "$first_strong_seen" -ge 0 ]; then
      lived=$(( last_strong_seen - first_strong_seen + POLL_SECONDS ))
      echo "  Strong runtime lifetime: ~${lived}s"
    fi
    exit 4
  fi

  sleep "$POLL_SECONDS"
done
