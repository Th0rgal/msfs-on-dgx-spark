#!/usr/bin/env bash
# Verify DGX Spark MSFS readiness/install state and capture a current Steam screen.
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-:1}"
MSFS_APPID="${MSFS_APPID:-2537590}"
SHOT_PATH="${SHOT_PATH:-/tmp/steam-state-${MSFS_APPID}.png}"

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

auth_status() {
  local sid
  sid="$(steamid_from_processes || true)"
  if [ -n "$sid" ]; then
    echo "authenticated (steamid=$sid)"
    return
  fi

  if command -v xdotool >/dev/null 2>&1; then
    if DISPLAY="$DISPLAY_NUM" xdotool search --name "Steam" >/dev/null 2>&1 \
      && ! DISPLAY="$DISPLAY_NUM" xdotool search --name "Sign in to Steam" >/dev/null 2>&1; then
      echo "authenticated (ui-detected)"
      return
    fi
  fi

  echo "unauthenticated"
}

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi

MANIFEST="$STEAM_DIR/steamapps/appmanifest_${MSFS_APPID}.acf"
COMPAT_TOOL_VDF="$STEAM_DIR/config/compatibilitytools.vdf"

printf "DGX MSFS verification\n"
printf "  Time (UTC): %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
printf "  Host: %s\n" "$(hostname)"
printf "  DISPLAY: %s\n" "$DISPLAY_NUM"
printf "  Steam dir: %s\n" "$STEAM_DIR"
printf "  Steam auth: %s\n" "$(auth_status)"

printf "\nProcess checks\n"
for pat in "Xvfb $DISPLAY_NUM" "openbox" "steamwebhelper"; do
  if pgrep -af "$pat" >/dev/null; then
    printf "  [OK] %s\n" "$pat"
  else
    printf "  [MISSING] %s\n" "$pat"
  fi
done

if pgrep -af 'x11vnc .* -rfbport 5901' >/dev/null || pgrep -af 'x11vnc .* -rfbport 5900' >/dev/null; then
  printf "  [OK] x11vnc rfbport 5900/5901\n"
else
  printf "  [MISSING] x11vnc rfbport 5900/5901\n"
fi

printf "\nMSFS install state\n"
if [ -f "$MANIFEST" ]; then
  printf "  Manifest: present (%s)\n" "$MANIFEST"
  awk -F '"' '
    /"name"/ {name=$4}
    /"StateFlags"/ {state=$4}
    /"buildid"/ {buildid=$4}
    /"BytesDownloaded"/ {dl=$4}
    /"BytesToDownload"/ {todo=$4}
    END {
      printf("  Name: %s\n", name)
      printf("  StateFlags: %s\n", state)
      printf("  BuildID: %s\n", buildid)
      printf("  BytesDownloaded: %s\n", dl)
      printf("  BytesToDownload: %s\n", todo)
      if (todo+0 > 0) {
        printf("  DownloadPercent: %.2f%%\n", (dl+0)*100/(todo+0))
      }
    }
  ' "$MANIFEST"
else
  printf "  Manifest: missing (MSFS not installed/queued in logged-in account)\n"
fi

printf "\nProton compatibility config\n"
if [ -f "$COMPAT_TOOL_VDF" ]; then
  if command -v rg >/dev/null 2>&1; then
    MATCH_CMD=(rg -n "1250410|2537590|proton|Proton" "$COMPAT_TOOL_VDF")
  else
    MATCH_CMD=(grep -En "1250410|2537590|proton|Proton" "$COMPAT_TOOL_VDF")
  fi
  if "${MATCH_CMD[@]}" >/dev/null 2>&1; then
    printf "  [OK] compatibilitytools.vdf exists and contains Proton/app override entries\n"
  else
    printf "  [WARN] compatibilitytools.vdf found, but no obvious Proton/app override match\n"
  fi
else
  printf "  [WARN] %s missing\n" "$COMPAT_TOOL_VDF"
fi

printf "\nSunshine service\n"
if systemctl --user is-active sunshine >/dev/null 2>&1; then
  printf "  [OK] sunshine user service: active\n"
else
  printf "  [WARN] sunshine user service: inactive\n"
fi

if command -v ss >/dev/null 2>&1; then
  printf "\nStreaming ports\n"
  ss -ltnup 2>/dev/null | awk 'NR==1 || /:47984|:47989|:47990|:48010|:5900|:5901/' || true
fi

printf "\nCurrent UI capture\n"
if command -v import >/dev/null 2>&1; then
  DISPLAY="$DISPLAY_NUM" import -window root "$SHOT_PATH"
  printf "  Screenshot: %s\n" "$SHOT_PATH"
else
  printf "  [WARN] imagemagick 'import' not found; screenshot skipped\n"
fi
