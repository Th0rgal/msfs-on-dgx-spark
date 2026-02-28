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

steam_window_ids() {
  local display_num="${1:-}"
  [ -n "$display_num" ] || return 1

  local ids=()
  local id

  if command -v xdotool >/dev/null 2>&1; then
    while IFS= read -r id; do
      [ -n "$id" ] && ids+=("$id")
    done < <(
      timeout 6s env DISPLAY="$display_num" xdotool search --class "Steam|steam|Steamwebhelper|steamwebhelper" 2>/dev/null || true
    )
    while IFS= read -r id; do
      [ -n "$id" ] && ids+=("$id")
    done < <(
      timeout 6s env DISPLAY="$display_num" xdotool search --name "Steam|steamwebhelper|Sign in to Steam|Steam Guard|Friends|Library|Store" 2>/dev/null || true
    )
  fi

  if command -v xwininfo >/dev/null 2>&1; then
    while IFS= read -r id; do
      [ -n "$id" ] && ids+=("$id")
    done < <(
      timeout 8s env DISPLAY="$display_num" xwininfo -root -tree 2>/dev/null \
        | sed -n 's/^ *\(0x[0-9a-f][0-9a-f]*\) "\(.*\)".*/\1 \2/pI' \
        | awk 'BEGIN { IGNORECASE=1 } $0 ~ /(steam|steamwebhelper|sign in to steam|steam guard|friends|library|store)/ { print $1 }'
    )
  fi

  if [ "${#ids[@]}" -eq 0 ]; then
    return 1
  fi

  printf '%s\n' "${ids[@]}" | awk '!seen[$0]++'
  return 0
}

steam_force_show_windows() {
  local display_num="${1:-}"
  local width="${2:-1600}"
  local height="${3:-900}"
  local x="${4:-50}"
  local y="${5:-50}"
  local max_windows="${STEAM_WINDOW_RECOVERY_MAX_WINDOWS:-8}"
  [ -n "$display_num" ] || return 1
  command -v xdotool >/dev/null 2>&1 || return 1

  local ids=()
  local id
  while IFS= read -r id; do
    [ -n "$id" ] && ids+=("$id")
  done < <(steam_window_ids "$display_num" || true)

  [ "${#ids[@]}" -gt 0 ] || return 1
  if ! [[ "$max_windows" =~ ^[0-9]+$ ]] || [ "$max_windows" -lt 1 ]; then
    max_windows=8
  fi

  local processed=0
  for id in "${ids[@]}"; do
    processed=$((processed + 1))
    if [ "$processed" -gt "$max_windows" ]; then
      break
    fi
    timeout 3s env DISPLAY="$display_num" xdotool windowmap "$id" >/dev/null 2>&1 || true
    timeout 3s env DISPLAY="$display_num" xdotool windowsize "$id" "$width" "$height" >/dev/null 2>&1 || true
    timeout 3s env DISPLAY="$display_num" xdotool windowmove "$id" "$x" "$y" >/dev/null 2>&1 || true
    timeout 3s env DISPLAY="$display_num" xdotool windowraise "$id" >/dev/null 2>&1 || true
  done
  timeout 3s env DISPLAY="$display_num" xdotool windowactivate "${ids[0]}" >/dev/null 2>&1 || true
  return 0
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
    # Some DGX headless sessions create tiny/off-screen Steam windows;
    # count those as UI evidence only after forcing them on-screen.
    if steam_force_show_windows "$display_num" >/dev/null 2>&1; then
      if DISPLAY="$display_num" xdotool search --onlyvisible --name "Steam|steamwebhelper|Friends|Library|Store" >/dev/null 2>&1; then
        has_visible_window=0
      fi
    fi
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
