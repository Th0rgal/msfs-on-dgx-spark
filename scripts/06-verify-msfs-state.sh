#!/usr/bin/env bash
# Verify DGX Spark MSFS readiness/install state and capture a current Steam screen.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-steam-auth.sh"
DISPLAY_NUM="${DISPLAY_NUM:-$("$SCRIPT_DIR/00-select-msfs-display.sh")}"
MSFS_APPID="${MSFS_APPID:-2537590}"
SHOT_PATH="${SHOT_PATH:-/tmp/steam-state-${MSFS_APPID}.png}"

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
printf "  Steam auth: %s\n" "$(steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true)"

printf "\nProcess checks\n"
if DISPLAY="$DISPLAY_NUM" glxinfo -B 2>/dev/null | grep -Eq 'OpenGL renderer string:.*NVIDIA|OpenGL vendor string: NVIDIA'; then
  printf "  [OK] GPU display active on %s (NVIDIA GL)\n" "$DISPLAY_NUM"
else
  if pgrep -af "Xvfb $DISPLAY_NUM" >/dev/null; then
    printf "  [OK] Xvfb %s\n" "$DISPLAY_NUM"
  else
    printf "  [MISSING] Xvfb %s\n" "$DISPLAY_NUM"
  fi
fi

for pat in "openbox" "steamwebhelper"; do
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
