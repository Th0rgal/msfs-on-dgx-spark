#!/usr/bin/env bash
# Wait for authenticated Steam session, then trigger and monitor MSFS install state.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-steam-auth.sh"
DISPLAY_NUM="${DISPLAY_NUM:-$("$SCRIPT_DIR/00-select-msfs-display.sh")}"
MSFS_APPID="${MSFS_APPID:-2537590}"
POLL_SECONDS="${POLL_SECONDS:-15}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-1800}"  # 30 min login wait

print_manifest_state() {
  local manifest="$1"
  awk -F '"' '
    /"StateFlags"/ {state=$4}
    /"BytesDownloaded"/ {dl=$4}
    /"BytesToDownload"/ {todo=$4}
    END {
      if (todo+0 > 0) {
        pct=((dl+0)*100)/(todo+0)
      } else {
        pct=0
      }
      printf("StateFlags=%s BytesDownloaded=%s BytesToDownload=%s Progress=%.2f%%\n", state, dl, todo, pct)
    }
  ' "$manifest"
}

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi
MANIFEST="$STEAM_DIR/steamapps/appmanifest_${MSFS_APPID}.acf"

echo "[1/4] Ensuring headless Steam stack is up..."
"$(dirname "$0")/05-resume-headless-msfs.sh" install >/tmp/msfs-resume.log 2>&1 || true

start_ts="$(date +%s)"
echo "[2/4] Waiting for authenticated Steam session..."
while true; do
  if steam_session_authenticated "$DISPLAY_NUM" "$STEAM_DIR"; then
    sid="$(steamid_from_processes || true)"
    [ -z "$sid" ] && sid="$(steamid_from_connection_log "$STEAM_DIR" || true)"
    [ -z "$sid" ] && sid="ui-detected"
    echo "Authenticated Steam session detected: steamid=$sid"
    break
  fi

  now_ts="$(date +%s)"
  elapsed=$((now_ts - start_ts))
  if [ "$elapsed" -ge "$TIMEOUT_SECONDS" ]; then
    echo "ERROR: Timed out waiting for Steam login."
    echo "Hint: Complete Steam Guard in the VNC/desktop session, then rerun this script."
    exit 2
  fi

  printf "  still waiting... (%ss elapsed)\n" "$elapsed"
  sleep "$POLL_SECONDS"
done

echo "[3/4] Triggering install URI for AppID ${MSFS_APPID}..."
DISPLAY="$DISPLAY_NUM" steam "steam://install/${MSFS_APPID}" >/tmp/msfs-install-uri.log 2>&1 || true

wait_manifest_start="$(date +%s)"
while [ ! -f "$MANIFEST" ]; do
  now_ts="$(date +%s)"
  elapsed=$((now_ts - wait_manifest_start))
  if [ "$elapsed" -ge 300 ]; then
    echo "WARN: Install manifest not present after 5m. Steam UI may still need one manual click."
    echo "Open Library and confirm install for AppID ${MSFS_APPID}."
    exit 3
  fi
  printf "  waiting for manifest... (%ss)\n" "$elapsed"
  sleep "$POLL_SECONDS"
done

echo "[4/4] Manifest detected: $MANIFEST"
print_manifest_state "$MANIFEST"
echo "Done. Re-run this script any time to check install progress."
