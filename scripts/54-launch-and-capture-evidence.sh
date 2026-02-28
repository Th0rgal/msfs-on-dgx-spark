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
AUTH_BOOTSTRAP_STEAM_STACK="${AUTH_BOOTSTRAP_STEAM_STACK:-1}"
AUTH_BOOTSTRAP_WAIT_SECONDS="${AUTH_BOOTSTRAP_WAIT_SECONDS:-8}"
AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER="${AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER:-1}"
DISPATCH_MAX_ATTEMPTS="${DISPATCH_MAX_ATTEMPTS:-2}"
DISPATCH_RETRY_DELAY_SECONDS="${DISPATCH_RETRY_DELAY_SECONDS:-8}"
DISPATCH_RECOVER_ON_NO_ACCEPT="${DISPATCH_RECOVER_ON_NO_ACCEPT:-1}"
DISPATCH_ACCEPT_WAIT_SECONDS="${DISPATCH_ACCEPT_WAIT_SECONDS:-45}"
DISPATCH_FALLBACK_APP_LAUNCH="${DISPATCH_FALLBACK_APP_LAUNCH:-1}"
DISPATCH_FALLBACK_WAIT_SECONDS="${DISPATCH_FALLBACK_WAIT_SECONDS:-20}"
DISPATCH_FORCE_UI_ON_FAILURE="${DISPATCH_FORCE_UI_ON_FAILURE:-1}"
DISPATCH_FALLBACK_CHAIN="${DISPATCH_FALLBACK_CHAIN:-applaunch,steam_uri,snap_uri}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/output}"
STEAM_DIR="${STEAM_DIR:-$HOME/snap/steam/common/.local/share/Steam}"
PFX="$STEAM_DIR/steamapps/compatdata/${MSFS_APPID}/pfx"

mkdir -p "$OUT_DIR"
RUN_START_EPOCH="$(date +%s)"

if [ "$AUTH_BOOTSTRAP_STEAM_STACK" = "1" ]; then
  bootstrap_log="$OUT_DIR/auth-bootstrap-${MSFS_APPID}-${STAMP}.log"
  set +e
  MSFS_APPID="$MSFS_APPID" DISPLAY_NUM="$DISPLAY_NUM" "$SCRIPT_DIR/05-resume-headless-msfs.sh" install \
    >"$bootstrap_log" 2>&1
  bootstrap_rc=$?
  set -e
  if [ "$bootstrap_rc" -ne 0 ]; then
    echo "WARN: auth bootstrap via 05-resume-headless-msfs.sh failed (rc=$bootstrap_rc): $bootstrap_log"
  fi
  sleep "$AUTH_BOOTSTRAP_WAIT_SECONDS"

  if [ "$AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER" = "1" ] && ! pgrep -af steamwebhelper >/dev/null 2>&1; then
    recover_log="$OUT_DIR/auth-bootstrap-recover-${MSFS_APPID}-${STAMP}.log"
    set +e
    OUT_DIR="$OUT_DIR" DISPLAY_NUM="$DISPLAY_NUM" "$SCRIPT_DIR/57-recover-steam-runtime.sh" \
      >"$recover_log" 2>&1
    recover_rc=$?
    set -e
    if [ "$recover_rc" -ne 0 ]; then
      echo "WARN: auth bootstrap runtime recovery failed (rc=$recover_rc): $recover_log"
    fi
    sleep "$AUTH_BOOTSTRAP_WAIT_SECONDS"
  fi
fi

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
if ! [[ "$DISPATCH_MAX_ATTEMPTS" =~ ^[0-9]+$ ]] || [ "$DISPATCH_MAX_ATTEMPTS" -lt 1 ]; then
  echo "ERROR: DISPATCH_MAX_ATTEMPTS must be a positive integer (got: $DISPATCH_MAX_ATTEMPTS)"
  exit 1
fi

dispatch_rc=4
d=1
while [ "$d" -le "$DISPATCH_MAX_ATTEMPTS" ]; do
  dispatch_log="$OUT_DIR/dispatch-${MSFS_APPID}-${STAMP}-d${d}.log"
  set +e
  MSFS_APPID="$MSFS_APPID" DISPLAY_NUM="$DISPLAY_NUM" WAIT_SECONDS="$DISPATCH_ACCEPT_WAIT_SECONDS" \
    "$SCRIPT_DIR/19-dispatch-via-steam-pipe.sh" \
    >"$dispatch_log" 2>&1
  dispatch_rc=$?
  set -e

  if [ "$dispatch_rc" -eq 0 ]; then
    break
  fi

  if [ "$d" -lt "$DISPATCH_MAX_ATTEMPTS" ]; then
    echo "  dispatch attempt $d/$DISPATCH_MAX_ATTEMPTS failed (rc=$dispatch_rc): $dispatch_log"
    if [ "$DISPATCH_RECOVER_ON_NO_ACCEPT" = "1" ] && [ "$dispatch_rc" -eq 4 ]; then
      echo "  running Steam runtime recovery before redispatch"
      OUT_DIR="$OUT_DIR" DISPLAY_NUM="$DISPLAY_NUM" "$SCRIPT_DIR/57-recover-steam-runtime.sh" \
        >"$OUT_DIR/dispatch-recover-${MSFS_APPID}-${STAMP}-d${d}.log" 2>&1 || true
    fi
    sleep "$DISPATCH_RETRY_DELAY_SECONDS"
  fi

  d=$((d + 1))
done

if [ "$dispatch_rc" -ne 0 ]; then
  echo "  WARN: launch dispatch did not confirm acceptance after $DISPATCH_MAX_ATTEMPTS attempt(s) (last rc=$dispatch_rc)"
  if [ "$DISPATCH_FORCE_UI_ON_FAILURE" = "1" ] && [ -x "$SCRIPT_DIR/59-force-steam-ui.sh" ]; then
    echo "  normalizing Steam UI before fallback dispatches"
    DISPLAY_NUM="$DISPLAY_NUM" "$SCRIPT_DIR/59-force-steam-ui.sh" \
      >"$OUT_DIR/dispatch-force-ui-${MSFS_APPID}-${STAMP}.log" 2>&1 || true
    sleep 2
  fi
  if [ "$DISPATCH_FALLBACK_APP_LAUNCH" = "1" ]; then
    IFS=',' read -r -a fallback_steps <<< "$DISPATCH_FALLBACK_CHAIN"
    fallback_uri="steam://rungameid/${MSFS_APPID}"
    for step in "${fallback_steps[@]}"; do
      step="$(echo "$step" | xargs)"
      [ -z "$step" ] && continue
      fallback_log="$OUT_DIR/dispatch-fallback-${step}-${MSFS_APPID}-${STAMP}.log"
      set +e
      case "$step" in
        applaunch)
          echo "  trying DISPLAY-bound steam -applaunch fallback"
          timeout "${DISPATCH_FALLBACK_WAIT_SECONDS}s" env DISPLAY="$DISPLAY_NUM" steam -applaunch "$MSFS_APPID" \
            >"$fallback_log" 2>&1
          ;;
        steam_uri)
          echo "  trying DISPLAY-bound steam URI fallback"
          timeout "${DISPATCH_FALLBACK_WAIT_SECONDS}s" env DISPLAY="$DISPLAY_NUM" steam "$fallback_uri" \
            >"$fallback_log" 2>&1
          ;;
        snap_uri)
          echo "  trying DISPLAY-bound snap run steam URI fallback"
          timeout "${DISPATCH_FALLBACK_WAIT_SECONDS}s" env DISPLAY="$DISPLAY_NUM" snap run steam "$fallback_uri" \
            >"$fallback_log" 2>&1
          ;;
        *)
          echo "  WARN: unknown DISPATCH_FALLBACK_CHAIN step '$step' (skipping)"
          : >"$fallback_log"
          ;;
      esac
      fallback_rc=$?
      set -e
      echo "  fallback '$step' exit code: $fallback_rc"
      sleep 2
    done
  fi
fi

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

recent_crash_detected() {
  local latest=""
  local latest_ts=0
  local f ts
  for f in \
    "$OUT_DIR/crashdata-${MSFS_APPID}-${STAMP}.txt" \
    "$OUT_DIR/crashdata-${MSFS_APPID}-${STAMP}.utf8.txt" \
    "$OUT_DIR/AsoboReport-Crash-${MSFS_APPID}-${STAMP}.txt" \
    "$OUT_DIR"/Bifrost-*-"${MSFS_APPID}-${STAMP}.log"; do
    [ -f "$f" ] || continue
    ts="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    if [ "${ts:-0}" -gt "$latest_ts" ]; then
      latest="$f"
      latest_ts="$ts"
    fi
  done
  if [ -n "$latest" ] && [ "$latest_ts" -ge "$RUN_START_EPOCH" ]; then
    echo "$latest"
    return 0
  fi
  return 1
}

if [ "$verify_rc" -eq 2 ]; then
  if crash_file="$(recent_crash_detected)"; then
    echo "  INFO: crash artifacts detected for this run: $crash_file"
    echo "  INFO: remapping verifier result 2 -> 3 (launch observed, transient crash)."
    verify_rc=3
  fi
fi

echo
echo "Evidence written under: $OUT_DIR"
echo "  dispatch-${MSFS_APPID}-${STAMP}-d*.log"
echo "  verify-launch-${MSFS_APPID}-${STAMP}.log"
echo "  content-state-${MSFS_APPID}-${STAMP}.log"
echo "  compat-state-${MSFS_APPID}-${STAMP}.log"
echo "Verifier exit codes: 0=stable runtime, 3=transient runtime, 2=no launch observed."
exit "$verify_rc"
