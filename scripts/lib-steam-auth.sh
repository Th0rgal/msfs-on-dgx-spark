#!/usr/bin/env bash
# Shared Steam auth/session helpers for DGX MSFS scripts.
set -euo pipefail

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

steamid_from_connection_log() {
  local steam_dir="$1"
  local connection_log="$steam_dir/logs/connection_log.txt"
  local line state sid

  [ -f "$connection_log" ] || return 1

  line="$(tac "$connection_log" | grep -m1 -E '\[(Logged On|Logged Off|Logging On|Logging Off),[^]]*\] \[U:1:[0-9]+\]' || true)"
  [ -n "$line" ] || return 1

  state="$(printf '%s\n' "$line" | sed -n 's/.*\[\(Logged On\|Logged Off\|Logging On\|Logging Off\),[^]]*\] \[U:1:[0-9][0-9]*\].*/\1/p')"
  sid="$(printf '%s\n' "$line" | sed -n 's/.*\[U:1:\([0-9][0-9]*\)\].*/\1/p')"

  if [ "$state" = "Logged On" ] && [ -n "$sid" ] && [ "$sid" != "0" ]; then
    echo "$sid"
    return 0
  fi

  return 1
}

steam_ui_authenticated() {
  local display_num="${1:-}"
  local has_visible_window=1
  [ -n "$display_num" ] || return 1

  command -v xdotool >/dev/null 2>&1 || return 1

  # Require at least one visible Steam-related window as UI evidence.
  if DISPLAY="$display_num" xdotool search --onlyvisible --class steam >/dev/null 2>&1; then
    has_visible_window=0
  elif DISPLAY="$display_num" xdotool search --onlyvisible --name "Steam|Friends|Library|Store" >/dev/null 2>&1; then
    has_visible_window=0
  fi

  if [ "$has_visible_window" -ne 0 ]; then
    return 1
  fi

  # A visible login/guard dialog means session is not authenticated.
  if DISPLAY="$display_num" xdotool search --onlyvisible --name "Sign in to Steam|Steam Guard" >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

steam_auth_status() {
  local display_num="${1:-}"
  local steam_dir="${2:-}"
  local allow_ui_fallback="${ALLOW_UI_AUTH_FALLBACK:-0}"
  local sid

  sid="$(steamid_from_processes || true)"
  if [ -n "$sid" ]; then
    echo "authenticated (steamid=$sid)"
    return 0
  fi

  if [ -n "$steam_dir" ]; then
    sid="$(steamid_from_connection_log "$steam_dir" || true)"
    if [ -n "$sid" ]; then
      echo "authenticated (connection-log steamid=$sid)"
      return 0
    fi
  fi

  if steam_ui_authenticated "$display_num"; then
    if [ "$allow_ui_fallback" = "1" ]; then
      echo "authenticated (ui-fallback)"
      return 0
    fi
    echo "unauthenticated (ui-only evidence; set ALLOW_UI_AUTH_FALLBACK=1 to override)"
    return 1
  fi

  echo "unauthenticated"
  return 1
}

steam_session_authenticated() {
  local display_num="${1:-}"
  local steam_dir="${2:-}"

  steam_auth_status "$display_num" "$steam_dir" >/dev/null 2>&1
}
