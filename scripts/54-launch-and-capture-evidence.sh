#!/usr/bin/env bash
# Launch MSFS once through Steam pipe and capture runtime/crash evidence artifacts.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MSFS_APPID="${MSFS_APPID:-2537590}"
source "$SCRIPT_DIR/lib-display.sh"
source "$SCRIPT_DIR/lib-steam-auth.sh"
DISPLAY_NUM="$(resolve_display_num "$SCRIPT_DIR")"
WAIT_SECONDS="${WAIT_SECONDS:-240}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-45}"
AUTH_DEBUG_ON_FAILURE="${AUTH_DEBUG_ON_FAILURE:-1}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
PFX="$STEAM_DIR/steamapps/compatdata/${MSFS_APPID}/pfx"

mkdir -p "$OUT_DIR"

auth_log="$OUT_DIR/auth-state-${MSFS_APPID}-${STAMP}.log"
if ! steam_session_authenticated "$DISPLAY_NUM" "$STEAM_DIR"; then
  debug_note=""
  if [ "$AUTH_DEBUG_ON_FAILURE" = "1" ] && [ -x "$SCRIPT_DIR/11-debug-steam-window-state.sh" ]; then
    set +e
    debug_output="$(
      DISPLAY_NUM="$DISPLAY_NUM" OUT_DIR="$OUT_DIR" "$SCRIPT_DIR/11-debug-steam-window-state.sh" 2>&1
    )"
    set -e
    debug_report="$(printf '%s\n' "$debug_output" | sed -n 's/^report=//p' | tail -n 1)"
    debug_screenshot="$(printf '%s\n' "$debug_output" | sed -n 's/^screenshot=//p' | tail -n 1)"
    if [ -n "${debug_report:-}" ] || [ -n "${debug_screenshot:-}" ]; then
      debug_note="  Auth debug: report=${debug_report:-n/a} screenshot=${debug_screenshot:-n/a}"
    fi
  fi
  {
    echo "RESULT: Steam session unauthenticated; launch skipped."
    echo "  DISPLAY: $DISPLAY_NUM"
    echo "  Steam dir: $STEAM_DIR"
    echo "  Auth status: $(steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true)"
    [ -n "$debug_note" ] && echo "$debug_note"
    echo "Hint: complete Steam login/Steam Guard in the active UI session, then retry."
  } | tee "$auth_log"
  exit 7
fi
{
  echo "RESULT: Steam session authenticated."
  echo "  Auth status: $(steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true)"
} >"$auth_log"

echo "[1/5] Preflight runtime repair"
MSFS_APPID="$MSFS_APPID" "$SCRIPT_DIR/53-preflight-runtime-repair.sh" \
  >"$OUT_DIR/preflight-${MSFS_APPID}-${STAMP}.log" 2>&1 || true

echo "[2/5] Launch dispatch via Steam pipe"
MSFS_APPID="$MSFS_APPID" DISPLAY_NUM="$DISPLAY_NUM" WAIT_SECONDS=20 \
  "$SCRIPT_DIR/19-dispatch-via-steam-pipe.sh" \
  >"$OUT_DIR/dispatch-${MSFS_APPID}-${STAMP}.log" 2>&1 || true

echo "[3/5] Runtime stability verification"
set +e
MSFS_APPID="$MSFS_APPID" DISPLAY_NUM="$DISPLAY_NUM" WAIT_SECONDS="$WAIT_SECONDS" \
  MIN_STABLE_SECONDS="$MIN_STABLE_SECONDS" \
  "$SCRIPT_DIR/09-verify-msfs-launch.sh" \
  >"$OUT_DIR/verify-launch-${MSFS_APPID}-${STAMP}.log" 2>&1
verify_rc=$?
set -e
echo "  verify exit code: $verify_rc"

echo "[4/5] Snapshot key logs"
if [ -f "$STEAM_DIR/logs/content_log.txt" ]; then
  grep -n "AppID ${MSFS_APPID} state changed" "$STEAM_DIR/logs/content_log.txt" | tail -n 60 \
    >"$OUT_DIR/content-state-${MSFS_APPID}-${STAMP}.log" || true
fi
if [ -f "$STEAM_DIR/logs/compat_log.txt" ]; then
  grep -nE "appID ${MSFS_APPID}|StartSession|ReleaseSession|Command prefix|waitforexitandrun" \
    "$STEAM_DIR/logs/compat_log.txt" | tail -n 200 \
    >"$OUT_DIR/compat-state-${MSFS_APPID}-${STAMP}.log" || true
fi

echo "[5/5] Copy latest crash artifacts (if present)"
if [ -d "$PFX" ]; then
  crashdata="$PFX/drive_c/users/steamuser/AppData/Roaming/Microsoft Flight Simulator 2024/crashdata.txt"
  if [ -f "$crashdata" ]; then
    cp -f "$crashdata" "$OUT_DIR/crashdata-${MSFS_APPID}-${STAMP}.txt"
    if command -v iconv >/dev/null 2>&1; then
      iconv -f UTF-16LE -t UTF-8 "$crashdata" \
        >"$OUT_DIR/crashdata-${MSFS_APPID}-${STAMP}.utf8.txt" 2>/dev/null || true
    fi
  fi

  latest_bifrost="$(ls -1t "$PFX"/drive_c/users/steamuser/AppData/Local/XboxGameStudios/Bifrost/Bifrost-*.log 2>/dev/null | head -n 1 || true)"
  if [ -n "${latest_bifrost:-}" ] && [ -f "$latest_bifrost" ]; then
    cp -f "$latest_bifrost" "$OUT_DIR/$(basename "${latest_bifrost%.log}")-${MSFS_APPID}-${STAMP}.log"
  fi

  latest_asobo="$(ls -1t "$PFX"/drive_c/users/steamuser/AppData/Roaming/Microsoft\ Flight\ Simulator\ 2024/AsoboReport-Crash.txt 2>/dev/null | head -n 1 || true)"
  if [ -n "${latest_asobo:-}" ] && [ -f "$latest_asobo" ]; then
    cp -f "$latest_asobo" "$OUT_DIR/AsoboReport-Crash-${MSFS_APPID}-${STAMP}.txt"
  fi
fi

echo
echo "Evidence written under: $OUT_DIR"
echo "  dispatch-${MSFS_APPID}-${STAMP}.log"
echo "  verify-launch-${MSFS_APPID}-${STAMP}.log"
echo "  content-state-${MSFS_APPID}-${STAMP}.log"
echo "  compat-state-${MSFS_APPID}-${STAMP}.log"
echo "Verifier exit codes: 0=stable runtime, 3=transient runtime, 2=no launch observed."
exit "$verify_rc"
