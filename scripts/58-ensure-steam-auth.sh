#!/usr/bin/env bash
# Ensure Steam is authenticated in the active headless session
# (optionally via login credentials + Steam Guard code).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-steam-auth.sh"
source "$SCRIPT_DIR/lib-display.sh"

DISPLAY_NUM="$(resolve_display_num "$SCRIPT_DIR")"
LOGIN_WAIT_SECONDS="${LOGIN_WAIT_SECONDS:-300}"
POLL_SECONDS="${POLL_SECONDS:-10}"
GUARD_CODE="${1:-${STEAM_GUARD_CODE:-}}"
STEAM_USERNAME="${STEAM_USERNAME:-}"
STEAM_PASSWORD="${STEAM_PASSWORD:-}"
AUTH_AUTO_FILL="${AUTH_AUTO_FILL:-1}"
AUTH_SUBMIT_LOGIN="${AUTH_SUBMIT_LOGIN:-1}"
AUTH_USE_STEAM_LOGIN_CLI="${AUTH_USE_STEAM_LOGIN_CLI:-1}"
AUTH_FORCE_OPEN_MAIN="${AUTH_FORCE_OPEN_MAIN:-1}"
AUTH_RESTORE_WINDOWS="${AUTH_RESTORE_WINDOWS:-1}"
AUTH_NORMALIZE_WINDOWS="${AUTH_NORMALIZE_WINDOWS:-1}"
AUTH_WINDOW_WIDTH="${AUTH_WINDOW_WIDTH:-1600}"
AUTH_WINDOW_HEIGHT="${AUTH_WINDOW_HEIGHT:-900}"
AUTH_WINDOW_X="${AUTH_WINDOW_X:-50}"
AUTH_WINDOW_Y="${AUTH_WINDOW_Y:-50}"

STEAM_DIR="$(find_steam_dir || true)"
if [ -z "$STEAM_DIR" ]; then
  echo "ERROR: Steam directory not found."
  exit 1
fi

echo "Ensuring headless Steam stack is running..."
"$SCRIPT_DIR/05-resume-headless-msfs.sh" install >/tmp/msfs-ensure-auth-resume.log 2>&1 || true

if steam_session_authenticated "$DISPLAY_NUM" "$STEAM_DIR"; then
  echo "Steam session already authenticated."
  steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true
  exit 0
fi

steam_login_dialog_visible() {
  command -v xdotool >/dev/null 2>&1 || return 1
  DISPLAY="$DISPLAY_NUM" xdotool search --onlyvisible --name "Sign in to Steam" >/dev/null 2>&1
}

steam_any_window_present() {
  command -v xwininfo >/dev/null 2>&1 || return 1
  DISPLAY="$DISPLAY_NUM" xwininfo -root -tree 2>/dev/null | grep -Eiq "steam|steamwebhelper|sign in to steam|steam guard"
}

restore_steam_windows() {
  [ "$AUTH_RESTORE_WINDOWS" = "1" ] || return 1
  command -v xdotool >/dev/null 2>&1 || return 1

  local ids=()
  mapfile -t ids < <(DISPLAY="$DISPLAY_NUM" xdotool search --class steam 2>/dev/null || true)
  if [ "${#ids[@]}" -eq 0 ]; then
    mapfile -t ids < <(DISPLAY="$DISPLAY_NUM" xdotool search --name "Steam|steamwebhelper|Sign in to Steam|Steam Guard|Friends|Library|Store" 2>/dev/null || true)
  fi
  if [ "${#ids[@]}" -eq 0 ]; then
    return 1
  fi

  local id
  for id in "${ids[@]}"; do
    DISPLAY="$DISPLAY_NUM" xdotool windowmap "$id" >/dev/null 2>&1 || true
    if [ "$AUTH_NORMALIZE_WINDOWS" = "1" ]; then
      DISPLAY="$DISPLAY_NUM" xdotool windowsize "$id" "$AUTH_WINDOW_WIDTH" "$AUTH_WINDOW_HEIGHT" >/dev/null 2>&1 || true
      DISPLAY="$DISPLAY_NUM" xdotool windowmove "$id" "$AUTH_WINDOW_X" "$AUTH_WINDOW_Y" >/dev/null 2>&1 || true
    fi
    DISPLAY="$DISPLAY_NUM" xdotool windowraise "$id" >/dev/null 2>&1 || true
  done
  DISPLAY="$DISPLAY_NUM" xdotool windowactivate --sync "${ids[0]}" >/dev/null 2>&1 || true
  return 0
}

open_steam_main_ui() {
  [ "$AUTH_FORCE_OPEN_MAIN" = "1" ] || return 1
  command -v snap >/dev/null 2>&1 || return 1
  DISPLAY="$DISPLAY_NUM" snap run steam steam://open/main >/tmp/msfs-auth-open-main.log 2>&1 || true
  return 0
}

launch_cli_login() {
  [ "$AUTH_USE_STEAM_LOGIN_CLI" = "1" ] || return 1
  [ -n "$STEAM_USERNAME" ] || return 1
  [ -n "$STEAM_PASSWORD" ] || return 1
  command -v snap >/dev/null 2>&1 || return 1

  DISPLAY="$DISPLAY_NUM" snap run steam -login "$STEAM_USERNAME" "$STEAM_PASSWORD" >/tmp/msfs-auth-steam-login.log 2>&1 || true
  return 0
}

fill_login_form() {
  command -v xdotool >/dev/null 2>&1 || return 1
  [ -n "$STEAM_USERNAME" ] || return 1
  [ -n "$STEAM_PASSWORD" ] || return 1

  local win_id
  win_id="$(DISPLAY="$DISPLAY_NUM" xdotool search --onlyvisible --name "Sign in to Steam" 2>/dev/null | head -n1 || true)"
  [ -n "$win_id" ] || return 1

  DISPLAY="$DISPLAY_NUM" xdotool windowactivate --sync "$win_id" || true
  sleep 0.2
  DISPLAY="$DISPLAY_NUM" xdotool key --window "$win_id" --clearmodifiers ctrl+a BackSpace || true
  DISPLAY="$DISPLAY_NUM" xdotool type --window "$win_id" --delay 12 "$STEAM_USERNAME" || true
  DISPLAY="$DISPLAY_NUM" xdotool key --window "$win_id" Tab || true
  DISPLAY="$DISPLAY_NUM" xdotool key --window "$win_id" --clearmodifiers ctrl+a BackSpace || true
  DISPLAY="$DISPLAY_NUM" xdotool type --window "$win_id" --delay 12 "$STEAM_PASSWORD" || true
  if [ "$AUTH_SUBMIT_LOGIN" = "1" ]; then
    DISPLAY="$DISPLAY_NUM" xdotool key --window "$win_id" Return || true
  fi
  return 0
}

type_guard_code() {
  [ -n "$GUARD_CODE" ] || return 1
  command -v xdotool >/dev/null 2>&1 || return 1

  local win_id
  win_id="$(DISPLAY="$DISPLAY_NUM" xdotool search --onlyvisible --name "Steam Guard|Sign in to Steam" 2>/dev/null | head -n1 || true)"
  if [ -n "$win_id" ]; then
    DISPLAY="$DISPLAY_NUM" xdotool windowactivate --sync "$win_id" || true
    sleep 0.2
    DISPLAY="$DISPLAY_NUM" xdotool key --window "$win_id" --delay 80 "$GUARD_CODE" Return || true
  else
    DISPLAY="$DISPLAY_NUM" xdotool key --delay 80 "$GUARD_CODE" Return || true
  fi
  return 0
}

if [ "$AUTH_AUTO_FILL" = "1" ] && steam_login_dialog_visible; then
  if fill_login_form; then
    echo "Submitted Steam login form on ${DISPLAY_NUM}."
  else
    echo "Steam login dialog visible but missing STEAM_USERNAME/STEAM_PASSWORD or xdotool."
  fi
fi

if [ "$AUTH_FORCE_OPEN_MAIN" = "1" ]; then
  open_steam_main_ui || true
fi
if [ "$AUTH_RESTORE_WINDOWS" = "1" ]; then
  restore_steam_windows || true
fi

cli_login_attempted=0
if [ "$AUTH_USE_STEAM_LOGIN_CLI" = "1" ] && [ -n "$STEAM_USERNAME" ] && [ -n "$STEAM_PASSWORD" ]; then
  if launch_cli_login; then
    cli_login_attempted=1
    echo "Submitted Steam credential login via CLI on ${DISPLAY_NUM}."
  fi
fi

if [ -n "$GUARD_CODE" ]; then
  echo "Attempting Steam Guard code entry on ${DISPLAY_NUM}..."
  if type_guard_code; then
    :
  else
    echo "WARN: unable to auto-type Steam Guard code (missing xdotool/window context)."
  fi
else
  echo "No Steam Guard code supplied; waiting for manual login completion."
fi

echo "Waiting for authenticated Steam session (timeout: ${LOGIN_WAIT_SECONDS}s)..."
start_ts="$(date +%s)"
while true; do
  if steam_session_authenticated "$DISPLAY_NUM" "$STEAM_DIR"; then
    echo "Steam session authenticated."
    steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true
    exit 0
  fi

  elapsed=$(( $(date +%s) - start_ts ))
  if [ "$elapsed" -ge "$LOGIN_WAIT_SECONDS" ]; then
    echo "ERROR: timed out waiting for Steam authentication."
    steam_auth_status "$DISPLAY_NUM" "$STEAM_DIR" || true
    if steam_any_window_present; then
      echo "Observed Steam X11 windows, but no visible login/auth dialog was detected."
      if [ "$AUTH_RESTORE_WINDOWS" = "1" ]; then
        echo "Tried to restore/focus Steam windows automatically (`AUTH_RESTORE_WINDOWS=1`)."
        if [ "$AUTH_NORMALIZE_WINDOWS" = "1" ]; then
          echo "Applied window normalization (`${AUTH_WINDOW_WIDTH}x${AUTH_WINDOW_HEIGHT}+${AUTH_WINDOW_X}+${AUTH_WINDOW_Y}`) while restoring."
        fi
      fi
      echo "Hint: window manager/UI may be headless-minimized; run ./scripts/11-debug-steam-window-state.sh for evidence."
    fi
    echo "Hint: complete login/Steam Guard on VNC, or pass STEAM_GUARD_CODE and rerun."
    exit 2
  fi

  if [ "$AUTH_AUTO_FILL" = "1" ] && steam_login_dialog_visible; then
    fill_login_form || true
  fi
  if [ "$AUTH_FORCE_OPEN_MAIN" = "1" ]; then
    open_steam_main_ui || true
  fi
  if [ "$AUTH_RESTORE_WINDOWS" = "1" ]; then
    restore_steam_windows || true
  fi
  if [ "$cli_login_attempted" -eq 0 ] && [ "$AUTH_USE_STEAM_LOGIN_CLI" = "1" ] && [ -n "$STEAM_USERNAME" ] && [ -n "$STEAM_PASSWORD" ]; then
    launch_cli_login || true
    cli_login_attempted=1
  fi
  if [ -n "$GUARD_CODE" ]; then
    type_guard_code || true
  fi

  printf "  waiting login... (%ss elapsed)\n" "$elapsed"
  sleep "$POLL_SECONDS"
done
