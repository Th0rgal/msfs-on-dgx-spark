#!/usr/bin/env bash
# Complete Steam auth (optional code entry), queue/install MSFS, and launch when ready.
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
MSFS_APPID="${MSFS_APPID:-2537590}"
LOGIN_WAIT_SECONDS="${LOGIN_WAIT_SECONDS:-3600}"
INSTALL_WAIT_SECONDS="${INSTALL_WAIT_SECONDS:-0}"  # 0 = do not wait for full download
POLL_SECONDS="${POLL_SECONDS:-20}"
LAUNCH_VERIFY_WAIT_SECONDS="${LAUNCH_VERIFY_WAIT_SECONDS:-120}"
ALLOW_OFFLINE_LAUNCH_IF_INSTALLED="${ALLOW_OFFLINE_LAUNCH_IF_INSTALLED:-1}"
GUARD_CODE="${1:-${STEAM_GUARD_CODE:-}}"

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

steamid_from_processes() {
  pgrep -af steamwebhelper \
    | sed -n 's/.*-steamid=\([0-9][0-9]*\).*/\1/p' \
    | awk '$1 != 0 { print; exit }'
}

steam_session_authenticated() {
  local sid
  sid="$(steamid_from_processes || true)"
  if [ -n "$sid" ]; then
    return 0
  fi

  if command -v xdotool >/dev/null 2>&1; then
    if DISPLAY="$DISPLAY_NUM" xdotool search --name "Steam" >/dev/null 2>&1 \
      && ! DISPLAY="$DISPLAY_NUM" xdotool search --name "Sign in to Steam" >/dev/null 2>&1; then
      return 0
    fi
  fi

  return 1
}

manifest_progress() {
  local manifest="$1"
  awk -F '"' '
    /"StateFlags"/ {state=$4}
    /"BytesDownloaded"/ {dl=$4}
    /"BytesToDownload"/ {todo=$4}
    END {
      if (todo+0 > 0) {
        pct=((dl+0)*100)/(todo+0)
      } else {
        pct=100
      }
      printf("StateFlags=%s BytesDownloaded=%s BytesToDownload=%s Progress=%.2f%%\n", state, dl, todo, pct)
    }
  ' "$manifest"
}

manifest_is_fully_installed() {
  local manifest="$1"
  [ -f "$manifest" ] || return 1
  local dl todo
  dl="$(awk -F '"' '/"BytesDownloaded"/ {print $4; exit}' "$manifest")"
  todo="$(awk -F '"' '/"BytesToDownload"/ {print $4; exit}' "$manifest")"
  [ -n "$dl" ] || dl=0
  [ -n "$todo" ] || todo=0
  [ "$todo" -gt 0 ] && [ "$dl" -ge "$todo" ]
}

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi
MANIFEST="$STEAM_DIR/steamapps/appmanifest_${MSFS_APPID}.acf"

echo "[1/7] Ensuring headless stack is running..."
"$(dirname "$0")/05-resume-headless-msfs.sh" install >/tmp/msfs-resume.log 2>&1 || true

if [ -n "$GUARD_CODE" ]; then
  echo "[2/7] Attempting Steam Guard code entry via xdotool on ${DISPLAY_NUM}..."
  if command -v xdotool >/dev/null 2>&1; then
    DISPLAY="$DISPLAY_NUM" xdotool key --delay 80 "$GUARD_CODE" Return || true
  else
    echo "WARN: xdotool not installed; cannot auto-type Steam Guard code."
  fi
else
  echo "[2/7] No Steam Guard code supplied; skipping code entry."
fi

echo "[3/7] Waiting for authenticated Steam session..."
start_ts="$(date +%s)"
allow_offline=0
while true; do
  if steam_session_authenticated; then
    sid="$(steamid_from_processes || true)"
    [ -z "$sid" ] && sid="ui-detected"
    echo "Authenticated Steam session detected: steamid=$sid"
    break
  fi

  if [ "$ALLOW_OFFLINE_LAUNCH_IF_INSTALLED" = "1" ] && manifest_is_fully_installed "$MANIFEST"; then
    allow_offline=1
    echo "Steam auth not detected, but manifest shows full install; continuing in offline launch mode."
    break
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  if [ "$elapsed" -ge "$LOGIN_WAIT_SECONDS" ]; then
    echo "ERROR: Timed out waiting for Steam login (${LOGIN_WAIT_SECONDS}s)."
    echo "Hint: complete Steam Guard on VNC, then rerun this script."
    exit 2
  fi

  printf "  waiting login... (%ss elapsed)\n" "$elapsed"
  sleep "$POLL_SECONDS"
done

echo "[4/8] Ensuring Steam Play compatibility mappings..."
"$(dirname "$0")/10-enable-steam-play.sh" >/tmp/msfs-enable-steamplay.log 2>&1 || true

echo "[5/8] Running runtime preflight repairs..."
"$(dirname "$0")/53-preflight-runtime-repair.sh" >/tmp/msfs-preflight-repair.log 2>&1 || true

echo "[6/8] Triggering install and checking manifest..."
if manifest_is_fully_installed "$MANIFEST"; then
  echo "Manifest already shows a fully downloaded install; skipping install trigger."
else
  DISPLAY="$DISPLAY_NUM" steam "steam://install/${MSFS_APPID}" >/tmp/msfs-install-uri.log 2>&1 || true

  wait_manifest_start="$(date +%s)"
  while [ ! -f "$MANIFEST" ]; do
    elapsed=$(( $(date +%s) - wait_manifest_start ))
    if [ "$elapsed" -ge 300 ]; then
      echo "ERROR: Manifest did not appear within 300s: $MANIFEST"
      echo "Steam UI may still need one manual click to confirm install."
      exit 3
    fi
    printf "  waiting manifest... (%ss)\n" "$elapsed"
    sleep "$POLL_SECONDS"
  done
fi

manifest_progress "$MANIFEST"

if [ "$INSTALL_WAIT_SECONDS" -gt 0 ]; then
  echo "Waiting up to ${INSTALL_WAIT_SECONDS}s for full download..."
  install_start="$(date +%s)"
  while true; do
    todo="$(awk -F '"' '/"BytesToDownload"/ {print $4; exit}' "$MANIFEST")"
    dl="$(awk -F '"' '/"BytesDownloaded"/ {print $4; exit}' "$MANIFEST")"
    [ -z "$todo" ] && todo=0
    [ -z "$dl" ] && dl=0
    manifest_progress "$MANIFEST"

    if [ "$todo" -gt 0 ] && [ "$dl" -ge "$todo" ]; then
      echo "MSFS download completed."
      break
    fi

    elapsed=$(( $(date +%s) - install_start ))
    if [ "$elapsed" -ge "$INSTALL_WAIT_SECONDS" ]; then
      echo "Reached INSTALL_WAIT_SECONDS without full completion."
      break
    fi
    sleep "$POLL_SECONDS"
  done
fi

echo "[7/8] Launching MSFS via ~/launch-msfs.sh ..."
if [ -x "$(dirname "$0")/19-dispatch-via-steam-pipe.sh" ]; then
  WAIT_SECONDS=20 "$(dirname "$0")/19-dispatch-via-steam-pipe.sh" >/tmp/msfs-launch.log 2>&1 || true
elif [ -x "$HOME/launch-msfs.sh" ]; then
  GAME_ARG="2020"
  if [ "$MSFS_APPID" = "2537590" ]; then
    GAME_ARG="2024"
  fi
  DISPLAY="$DISPLAY_NUM" "$HOME/launch-msfs.sh" "$GAME_ARG" >/tmp/msfs-launch.log 2>&1 || true
else
  DISPLAY="$DISPLAY_NUM" steam "steam://run/${MSFS_APPID}" >/tmp/msfs-launch.log 2>&1 || true
fi

sleep 8
if command -v import >/dev/null 2>&1; then
  DISPLAY="$DISPLAY_NUM" import -window root "/tmp/msfs-launch-state-${MSFS_APPID}.png" || true
  echo "Launch screenshot: /tmp/msfs-launch-state-${MSFS_APPID}.png"
fi

echo "[8/8] Verifying launch process state..."
if WAIT_SECONDS="$LAUNCH_VERIFY_WAIT_SECONDS" "$(dirname "$0")/09-verify-msfs-launch.sh"; then
  echo "Launch verification succeeded."
else
  echo "WARN: Launch verification did not find a running MSFS process yet."
  if [ "$allow_offline" -eq 1 ]; then
    echo "Note: this run used offline launch mode because auth was not detected."
  fi
fi

echo "Done. Review /tmp/msfs-launch.log and run scripts/06-verify-msfs-state.sh for current status."
