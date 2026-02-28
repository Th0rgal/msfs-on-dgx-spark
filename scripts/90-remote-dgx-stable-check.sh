#!/usr/bin/env bash
# Sync the current checkout to DGX Spark and run stable-runtime verification remotely.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# Accept optional KEY=VALUE overrides as positional args for convenience.
# This allows invocations like:
#   ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1
for arg in "$@"; do
  if [[ "$arg" == *=* ]]; then
    export "$arg"
  else
    echo "ERROR: unsupported argument: $arg"
    echo "Hint: pass overrides as KEY=VALUE (for example MIN_STABLE_SECONDS=30)."
    exit 1
  fi
done

DGX_HOST="${DGX_HOST:-}"
DGX_USER="${DGX_USER:-th0rgal}"
DGX_PASS="${DGX_PASS:-}"
DGX_PORT="${DGX_PORT:-22}"
DGX_PORT_CANDIDATES="${DGX_PORT_CANDIDATES:-$DGX_PORT,22,2222}"
DGX_ENDPOINT_CANDIDATES="${DGX_ENDPOINT_CANDIDATES:-}"
DGX_TARGET_DIR="${DGX_TARGET_DIR:-\$HOME/msfs-on-dgx-spark-run-\$(date -u +%Y%m%dT%H%M%SZ)}"
DGX_HOST_CANDIDATES="${DGX_HOST_CANDIDATES:-spark-de79,100.77.4.93}"
DGX_DISCOVER_TAILSCALE_IPS="${DGX_DISCOVER_TAILSCALE_IPS:-1}"
SSH_CONNECT_TIMEOUT_SECONDS="${SSH_CONNECT_TIMEOUT_SECONDS:-15}"
SSH_CONNECTION_ATTEMPTS="${SSH_CONNECTION_ATTEMPTS:-1}"
SSH_SERVER_ALIVE_INTERVAL_SECONDS="${SSH_SERVER_ALIVE_INTERVAL_SECONDS:-10}"
SSH_SERVER_ALIVE_COUNT_MAX="${SSH_SERVER_ALIVE_COUNT_MAX:-2}"
DGX_PROBE_ATTEMPTS="${DGX_PROBE_ATTEMPTS:-2}"
DGX_PROBE_BACKOFF_SECONDS="${DGX_PROBE_BACKOFF_SECONDS:-2}"
DGX_SSH_PROXY_JUMP="${DGX_SSH_PROXY_JUMP:-}"
DGX_SSH_PROXY_COMMAND="${DGX_SSH_PROXY_COMMAND:-}"
DGX_SSH_EXTRA_OPTS_CSV="${DGX_SSH_EXTRA_OPTS_CSV:-}"
DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE="${DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE:-1}"
BOOTSTRAP_LOCAL_TAILSCALE="${BOOTSTRAP_LOCAL_TAILSCALE:-0}"
LOCAL_TAILSCALE_DIR="${LOCAL_TAILSCALE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/msfs-on-dgx-spark}"
LOCAL_TAILSCALE_SOCKET="${LOCAL_TAILSCALE_SOCKET:-}"
LOCAL_TAILSCALE_STATE="${LOCAL_TAILSCALE_STATE:-}"
LOCAL_TAILSCALE_LOG="${LOCAL_TAILSCALE_LOG:-}"
LOCAL_TAILSCALE_SOCKS5_ADDR="${LOCAL_TAILSCALE_SOCKS5_ADDR:-127.0.0.1:1055}"
LOCAL_TAILSCALE_AUTHKEY="${LOCAL_TAILSCALE_AUTHKEY:-}"
LOCAL_TAILSCALE_AUTHKEY_FILE="${LOCAL_TAILSCALE_AUTHKEY_FILE:-}"
LOCAL_TAILSCALE_AUTHKEY_DEFAULT_FILE="${LOCAL_TAILSCALE_AUTHKEY_DEFAULT_FILE:-$HOME/.config/msfs-on-dgx-spark/tailscale-authkey}"
AUTO_LOAD_LOCAL_TAILSCALE_AUTHKEY_FILE="${AUTO_LOAD_LOCAL_TAILSCALE_AUTHKEY_FILE:-1}"
REQUIRE_LOCAL_TAILSCALE_AUTHKEY_FILE_PERMS="${REQUIRE_LOCAL_TAILSCALE_AUTHKEY_FILE_PERMS:-1}"
LOCAL_TAILSCALE_UP_TIMEOUT_SECONDS="${LOCAL_TAILSCALE_UP_TIMEOUT_SECONDS:-30}"
LOCAL_TAILSCALE_LOGIN_TIMEOUT_SECONDS="${LOCAL_TAILSCALE_LOGIN_TIMEOUT_SECONDS:-300}"
LOCAL_TAILSCALE_INTERACTIVE_LOGIN="${LOCAL_TAILSCALE_INTERACTIVE_LOGIN:-0}"
LOCAL_TAILSCALE_ACCEPT_ROUTES="${LOCAL_TAILSCALE_ACCEPT_ROUTES:-0}"
LOCAL_TAILSCALE_BOOTSTRAP_RETRIES="${LOCAL_TAILSCALE_BOOTSTRAP_RETRIES:-2}"
LOCAL_TAILSCALE_BOOTSTRAP_RETRY_DELAY_SECONDS="${LOCAL_TAILSCALE_BOOTSTRAP_RETRY_DELAY_SECONDS:-2}"

MSFS_APPID="${MSFS_APPID:-2537590}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-20}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
ATTEMPT_PAUSE_SECONDS="${ATTEMPT_PAUSE_SECONDS:-12}"
DISPATCH_MAX_ATTEMPTS="${DISPATCH_MAX_ATTEMPTS:-2}"
DISPATCH_RETRY_DELAY_SECONDS="${DISPATCH_RETRY_DELAY_SECONDS:-8}"
DISPATCH_RECOVER_ON_NO_ACCEPT="${DISPATCH_RECOVER_ON_NO_ACCEPT:-1}"
DISPATCH_ACCEPT_WAIT_SECONDS="${DISPATCH_ACCEPT_WAIT_SECONDS:-45}"
PIPE_WRITE_TIMEOUT_SECONDS="${PIPE_WRITE_TIMEOUT_SECONDS:-6}"
PIPE_WRITE_RETRIES="${PIPE_WRITE_RETRIES:-3}"
PIPE_WRITE_RETRY_DELAY_SECONDS="${PIPE_WRITE_RETRY_DELAY_SECONDS:-5}"
PIPE_WRITE_RECOVER_ON_TIMEOUT="${PIPE_WRITE_RECOVER_ON_TIMEOUT:-1}"
URI_FALLBACK_ON_PIPE_FAILURE="${URI_FALLBACK_ON_PIPE_FAILURE:-1}"
URI_FALLBACK_TIMEOUT_SECONDS="${URI_FALLBACK_TIMEOUT_SECONDS:-20}"
DISPATCH_FALLBACK_APP_LAUNCH="${DISPATCH_FALLBACK_APP_LAUNCH:-1}"
DISPATCH_FALLBACK_WAIT_SECONDS="${DISPATCH_FALLBACK_WAIT_SECONDS:-20}"
DISPATCH_FORCE_UI_ON_FAILURE="${DISPATCH_FORCE_UI_ON_FAILURE:-1}"
DISPATCH_FALLBACK_CHAIN="${DISPATCH_FALLBACK_CHAIN:-applaunch,steam_uri,snap_uri}"
STRICT_MIN_STABLE_SECONDS="${STRICT_MIN_STABLE_SECONDS:-}"
STRICT_MAX_ATTEMPTS="${STRICT_MAX_ATTEMPTS:-3}"
RECOVER_BETWEEN_ATTEMPTS="${RECOVER_BETWEEN_ATTEMPTS:-0}"
STRICT_RECOVER_BETWEEN_ATTEMPTS="${STRICT_RECOVER_BETWEEN_ATTEMPTS:-$RECOVER_BETWEEN_ATTEMPTS}"
RECOVER_ON_EXIT_CODES="${RECOVER_ON_EXIT_CODES:-2,3,4}"
FATAL_EXIT_CODES="${FATAL_EXIT_CODES-7}"
AUTO_REAUTH_ON_AUTH_FAILURE="${AUTO_REAUTH_ON_AUTH_FAILURE:-}"
STEAM_GUARD_CODE="${STEAM_GUARD_CODE:-}"
STEAM_USERNAME="${STEAM_USERNAME:-}"
STEAM_PASSWORD="${STEAM_PASSWORD:-}"
AUTH_AUTO_FILL="${AUTH_AUTO_FILL:-1}"
AUTH_SUBMIT_LOGIN="${AUTH_SUBMIT_LOGIN:-1}"
AUTH_USE_STEAM_LOGIN_CLI="${AUTH_USE_STEAM_LOGIN_CLI:-1}"
AUTH_RESTORE_WINDOWS="${AUTH_RESTORE_WINDOWS:-1}"
REAUTH_LOGIN_WAIT_SECONDS="${REAUTH_LOGIN_WAIT_SECONDS:-300}"
AUTH_DEBUG_ON_REAUTH_FAILURE="${AUTH_DEBUG_ON_REAUTH_FAILURE:-1}"
ALLOW_UI_AUTH_FALLBACK="${ALLOW_UI_AUTH_FALLBACK:-0}"
AUTH_BOOTSTRAP_STEAM_STACK="${AUTH_BOOTSTRAP_STEAM_STACK:-1}"
AUTH_BOOTSTRAP_WAIT_SECONDS="${AUTH_BOOTSTRAP_WAIT_SECONDS:-8}"
AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER="${AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER:-1}"
LOAD_REMOTE_AUTH_ENV="${LOAD_REMOTE_AUTH_ENV:-1}"
REMOTE_AUTH_ENV_FILE="${REMOTE_AUTH_ENV_FILE:-\$HOME/.config/msfs-on-dgx-spark/steam-auth.env}"
REQUIRE_REMOTE_AUTH_ENV_PERMS="${REQUIRE_REMOTE_AUTH_ENV_PERMS:-1}"
PUSH_REMOTE_AUTH_ENV="${PUSH_REMOTE_AUTH_ENV:-0}"
LOCAL_AUTH_ENV_FILE="${LOCAL_AUTH_ENV_FILE:-$HOME/.config/msfs-on-dgx-spark/steam-auth.env}"
REQUIRE_LOCAL_AUTH_ENV_PERMS="${REQUIRE_LOCAL_AUTH_ENV_PERMS:-1}"
FETCH_EVIDENCE="${FETCH_EVIDENCE:-1}"
LOCAL_EVIDENCE_DIR="${LOCAL_EVIDENCE_DIR:-$REPO_ROOT/output/remote-runs}"

TMP_TAR="/tmp/msfs-on-dgx-spark-sync-$$.tgz"
trap 'rm -f "$TMP_TAR"' EXIT

if ! command -v ssh >/dev/null 2>&1; then
  echo "ERROR: ssh is required."
  exit 1
fi
if ! command -v scp >/dev/null 2>&1; then
  echo "ERROR: scp is required."
  exit 1
fi
if [ "$BOOTSTRAP_LOCAL_TAILSCALE" = "1" ]; then
  if [ -z "$LOCAL_TAILSCALE_SOCKET" ]; then
    LOCAL_TAILSCALE_SOCKET="/tmp/msfs-on-dgx-spark-tailscaled.sock"
  fi
  if [ -z "$LOCAL_TAILSCALE_STATE" ]; then
    LOCAL_TAILSCALE_STATE="$LOCAL_TAILSCALE_DIR/tailscaled.state"
  fi
  if [ -z "$LOCAL_TAILSCALE_LOG" ]; then
    LOCAL_TAILSCALE_LOG="$LOCAL_TAILSCALE_DIR/tailscaled.log"
  fi
  if ! command -v tailscale >/dev/null 2>&1; then
    echo "ERROR: BOOTSTRAP_LOCAL_TAILSCALE=1 requires tailscale."
    exit 1
  fi
  if ! command -v tailscaled >/dev/null 2>&1; then
    echo "ERROR: BOOTSTRAP_LOCAL_TAILSCALE=1 requires tailscaled."
    exit 1
  fi
  if [ -n "$LOCAL_TAILSCALE_AUTHKEY" ] && [ -n "$LOCAL_TAILSCALE_AUTHKEY_FILE" ]; then
    echo "ERROR: set only one of LOCAL_TAILSCALE_AUTHKEY or LOCAL_TAILSCALE_AUTHKEY_FILE."
    exit 1
  fi
  if [ -z "$LOCAL_TAILSCALE_AUTHKEY" ] \
    && [ -z "$LOCAL_TAILSCALE_AUTHKEY_FILE" ] \
    && [ "$AUTO_LOAD_LOCAL_TAILSCALE_AUTHKEY_FILE" = "1" ] \
    && [ -n "$LOCAL_TAILSCALE_AUTHKEY_DEFAULT_FILE" ] \
    && [ -f "$LOCAL_TAILSCALE_AUTHKEY_DEFAULT_FILE" ]; then
    LOCAL_TAILSCALE_AUTHKEY_FILE="$LOCAL_TAILSCALE_AUTHKEY_DEFAULT_FILE"
    echo "Auto-loading LOCAL_TAILSCALE_AUTHKEY_FILE: $LOCAL_TAILSCALE_AUTHKEY_FILE"
  fi
  if [ -n "$LOCAL_TAILSCALE_AUTHKEY_FILE" ]; then
    if [ ! -f "$LOCAL_TAILSCALE_AUTHKEY_FILE" ]; then
      echo "ERROR: LOCAL_TAILSCALE_AUTHKEY_FILE does not exist: $LOCAL_TAILSCALE_AUTHKEY_FILE"
      exit 1
    fi
    if [ "$REQUIRE_LOCAL_TAILSCALE_AUTHKEY_FILE_PERMS" = "1" ]; then
      local_authkey_perms="$(stat -c '%a' "$LOCAL_TAILSCALE_AUTHKEY_FILE" 2>/dev/null || true)"
      if [ "$local_authkey_perms" != "600" ]; then
        echo "ERROR: LOCAL_TAILSCALE_AUTHKEY_FILE must be mode 600: $LOCAL_TAILSCALE_AUTHKEY_FILE (current: ${local_authkey_perms:-unknown})"
        exit 1
      fi
    fi
    LOCAL_TAILSCALE_AUTHKEY="$(sed -n '1p' "$LOCAL_TAILSCALE_AUTHKEY_FILE" | tr -d '\r\n')"
    if [ -z "$LOCAL_TAILSCALE_AUTHKEY" ]; then
      echo "ERROR: LOCAL_TAILSCALE_AUTHKEY_FILE is empty: $LOCAL_TAILSCALE_AUTHKEY_FILE"
      exit 1
    fi
    echo "Loaded LOCAL_TAILSCALE_AUTHKEY from file: $LOCAL_TAILSCALE_AUTHKEY_FILE"
  fi
fi

if [ -n "$DGX_HOST" ]; then
  DGX_HOST_CANDIDATES="$DGX_HOST"
fi

tailscale_cmd() {
  if [ -n "$LOCAL_TAILSCALE_SOCKET" ]; then
    tailscale --socket "$LOCAL_TAILSCALE_SOCKET" "$@"
  else
    tailscale "$@"
  fi
}

is_tailscale_daemon_ready() {
  local status_json
  if ! command -v tailscale >/dev/null 2>&1; then
    return 1
  fi
  status_json="$(tailscale_cmd status --json 2>/dev/null || true)"
  echo "$status_json" | tr -d '\n' | grep -Eq '"BackendState"[[:space:]]*:'
}

is_tailscale_running() {
  command -v tailscale >/dev/null 2>&1 \
    && tailscale_cmd status --json 2>/dev/null | tr -d '\n' | grep -Eq '"BackendState"[[:space:]]*:[[:space:]]*"Running"'
}

is_process_zombie_or_missing() {
  local pid="$1"
  local proc_state
  proc_state="$(ps -o stat= -p "$pid" 2>/dev/null | head -n 1 | tr -d '[:space:]')"
  if [ -z "$proc_state" ]; then
    return 0
  fi
  [[ "$proc_state" == Z* ]]
}

increment_socks5_addr_port() {
  local addr="$1"
  local increment="$2"
  local host="${addr%:*}"
  local port="${addr##*:}"
  if [ -z "$host" ] || [ -z "$port" ] || ! [[ "$port" =~ ^[0-9]+$ ]]; then
    echo "$addr"
    return 0
  fi
  echo "${host}:$((port + increment))"
}

bootstrap_local_tailscale_userspace() {
  if [ "$BOOTSTRAP_LOCAL_TAILSCALE" != "1" ]; then
    return 0
  fi

  if ! is_tailscale_daemon_ready; then
    echo "Bootstrapping local userspace tailscaled (socket: $LOCAL_TAILSCALE_SOCKET)..."
    echo "Using local userspace tailscale state: $LOCAL_TAILSCALE_STATE"
    mkdir -p "$(dirname "$LOCAL_TAILSCALE_SOCKET")" "$(dirname "$LOCAL_TAILSCALE_STATE")" "$(dirname "$LOCAL_TAILSCALE_LOG")"
    if [ -S "$LOCAL_TAILSCALE_SOCKET" ]; then
      echo "Removing stale tailscaled socket before bootstrap: $LOCAL_TAILSCALE_SOCKET"
      rm -f "$LOCAL_TAILSCALE_SOCKET"
    fi
    bootstrap_try=1
    bootstrap_started=0
    while [ "$bootstrap_try" -le "$LOCAL_TAILSCALE_BOOTSTRAP_RETRIES" ]; do
      attempt_socket="$LOCAL_TAILSCALE_SOCKET"
      attempt_log="$LOCAL_TAILSCALE_LOG"
      attempt_socks="$LOCAL_TAILSCALE_SOCKS5_ADDR"
      if [ "$bootstrap_try" -gt 1 ]; then
        attempt_socket="${LOCAL_TAILSCALE_SOCKET}.retry${bootstrap_try}"
        attempt_log="${LOCAL_TAILSCALE_LOG}.retry${bootstrap_try}"
        attempt_socks="$(increment_socks5_addr_port "$LOCAL_TAILSCALE_SOCKS5_ADDR" $((bootstrap_try - 1)))"
      fi
      rm -f "$attempt_socket"
      echo "Bootstrap attempt ${bootstrap_try}/${LOCAL_TAILSCALE_BOOTSTRAP_RETRIES} (socket: $attempt_socket, socks: $attempt_socks)"
      PORT=0 nohup tailscaled \
        --tun=userspace-networking \
        --socks5-server="$attempt_socks" \
        --state="$LOCAL_TAILSCALE_STATE" \
        --socket="$attempt_socket" \
        >"$attempt_log" 2>&1 &
      bootstrap_pid=$!
      daemon_wait=0
      daemon_ready=0
      while [ "$daemon_wait" -lt 20 ]; do
        if tailscale --socket "$attempt_socket" status --json 2>/dev/null | tr -d '\n' | grep -Eq '"BackendState"[[:space:]]*:'; then
          daemon_ready=1
          break
        fi
        if is_process_zombie_or_missing "$bootstrap_pid"; then
          break
        fi
        daemon_wait=$((daemon_wait + 1))
        sleep 1
      done
      if [ "$daemon_ready" -eq 1 ]; then
        LOCAL_TAILSCALE_SOCKET="$attempt_socket"
        LOCAL_TAILSCALE_LOG="$attempt_log"
        LOCAL_TAILSCALE_SOCKS5_ADDR="$attempt_socks"
        bootstrap_started=1
        break
      fi
      echo "WARN: userspace tailscaled failed to become ready on attempt $bootstrap_try."
      echo "Hint: check $attempt_log"
      echo "Log tail:"
      tail -n 40 "$attempt_log" || true
      if ! is_process_zombie_or_missing "$bootstrap_pid"; then
        kill "$bootstrap_pid" >/dev/null 2>&1 || true
        wait "$bootstrap_pid" >/dev/null 2>&1 || true
      fi
      if [ "$bootstrap_try" -lt "$LOCAL_TAILSCALE_BOOTSTRAP_RETRIES" ] && [ "$LOCAL_TAILSCALE_BOOTSTRAP_RETRY_DELAY_SECONDS" -gt 0 ]; then
        sleep "$LOCAL_TAILSCALE_BOOTSTRAP_RETRY_DELAY_SECONDS"
      fi
      bootstrap_try=$((bootstrap_try + 1))
    done
    if [ "$bootstrap_started" -ne 1 ]; then
      echo "ERROR: tailscaled did not become ready after ${LOCAL_TAILSCALE_BOOTSTRAP_RETRIES} attempt(s)."
      echo "State file: $LOCAL_TAILSCALE_STATE"
      echo "Log: $LOCAL_TAILSCALE_LOG"
      return 1
    fi
  fi

  if ! is_tailscale_running; then
    echo "Bringing local tailscale online..."
    up_log_file="$(mktemp)"
    up_cmd=(tailscale_cmd up --timeout "${LOCAL_TAILSCALE_UP_TIMEOUT_SECONDS}s")
    if [ "$LOCAL_TAILSCALE_ACCEPT_ROUTES" = "1" ]; then
      up_cmd+=(--accept-routes)
    fi
    if [ -n "$LOCAL_TAILSCALE_AUTHKEY" ]; then
      up_cmd+=(--auth-key "$LOCAL_TAILSCALE_AUTHKEY")
    fi
    if ! "${up_cmd[@]}" >"$up_log_file" 2>&1; then
      echo "WARN: tailscale up did not complete successfully."
      sed -n '1,30p' "$up_log_file" || true
    fi
    rm -f "$up_log_file"
  fi

  if ! is_tailscale_running && [ -z "$LOCAL_TAILSCALE_AUTHKEY" ]; then
    if [ "$LOCAL_TAILSCALE_INTERACTIVE_LOGIN" = "1" ]; then
      echo "Attempting interactive tailscale login URL retrieval..."
      login_log_file="$(mktemp)"
      if ! tailscale_cmd login --timeout "${LOCAL_TAILSCALE_LOGIN_TIMEOUT_SECONDS}s" >"$login_log_file" 2>&1; then
        echo "WARN: tailscale login URL retrieval did not complete."
      fi
      sed -n '1,30p' "$login_log_file" || true
      rm -f "$login_log_file"
    else
      login_url="$(tailscale_cmd status 2>/dev/null | sed -n 's/^Log in at:[[:space:]]*//p' | head -n 1 || true)"
      if [ -n "$login_url" ]; then
        echo "Local tailscale needs login: $login_url"
      else
        echo "Local tailscale needs login. Run:"
        echo "  tailscale --socket '$LOCAL_TAILSCALE_SOCKET' login"
      fi
      echo "Set LOCAL_TAILSCALE_INTERACTIVE_LOGIN=1 to let this script run the interactive login flow."
    fi
  fi

  if ! is_tailscale_running; then
    echo "ERROR: local tailscale is not in Running state after bootstrap."
    echo "Hint: set LOCAL_TAILSCALE_AUTHKEY or run:"
    echo "  tailscale --socket '$LOCAL_TAILSCALE_SOCKET' login"
    echo "  tailscale --socket '$LOCAL_TAILSCALE_SOCKET' up"
    echo "State file: $LOCAL_TAILSCALE_STATE"
    echo "Log: $LOCAL_TAILSCALE_LOG"
    return 1
  fi

  if [ -z "$DGX_SSH_PROXY_JUMP" ] && [ -z "$DGX_SSH_PROXY_COMMAND" ]; then
    if ! command -v nc >/dev/null 2>&1; then
      echo "ERROR: userspace tailscale bootstrap requires nc for SOCKS proxying."
      return 1
    fi
    DGX_SSH_PROXY_COMMAND="nc -x ${LOCAL_TAILSCALE_SOCKS5_ADDR} -X 5 %h %p"
    echo "Using userspace tailscale SOCKS proxy for SSH: $DGX_SSH_PROXY_COMMAND"
  fi
}

bootstrap_local_tailscale_userspace

BASE_SSH_COMMON_OPTS=(
  -o StrictHostKeyChecking=no
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT_SECONDS}"
  -o ConnectionAttempts="${SSH_CONNECTION_ATTEMPTS}"
  -o ServerAliveInterval="${SSH_SERVER_ALIVE_INTERVAL_SECONDS}"
  -o ServerAliveCountMax="${SSH_SERVER_ALIVE_COUNT_MAX}"
)
if [ -n "$DGX_SSH_PROXY_JUMP" ] && [ -n "$DGX_SSH_PROXY_COMMAND" ]; then
  echo "ERROR: set only one of DGX_SSH_PROXY_JUMP or DGX_SSH_PROXY_COMMAND."
  exit 1
fi
if [ -n "$DGX_SSH_PROXY_JUMP" ]; then
  BASE_SSH_COMMON_OPTS+=(-J "$DGX_SSH_PROXY_JUMP")
fi
if [ -n "$DGX_SSH_PROXY_COMMAND" ]; then
  BASE_SSH_COMMON_OPTS+=(-o "ProxyCommand=$DGX_SSH_PROXY_COMMAND")
fi
if [ -n "$DGX_SSH_EXTRA_OPTS_CSV" ]; then
  IFS=',' read -r -a _ssh_extra_opts <<< "$DGX_SSH_EXTRA_OPTS_CSV"
  for _opt in "${_ssh_extra_opts[@]}"; do
    _opt="$(echo "$_opt" | xargs)"
    [ -z "$_opt" ] && continue
    BASE_SSH_COMMON_OPTS+=(-o "$_opt")
  done
fi
build_ssh_base_cmd() {
  local port="$1"
  local cmd=(ssh "${BASE_SSH_COMMON_OPTS[@]}" -p "$port")
  if [ -n "$DGX_PASS" ]; then
    cmd=(sshpass -p "$DGX_PASS" "${cmd[@]}")
  fi
  printf '%s\n' "${cmd[@]}"
}
build_scp_base_cmd() {
  local port="$1"
  local cmd=(scp "${BASE_SSH_COMMON_OPTS[@]}" -P "$port")
  if [ -n "$DGX_PASS" ]; then
    cmd=(sshpass -p "$DGX_PASS" "${cmd[@]}")
  fi
  printf '%s\n' "${cmd[@]}"
}

if [ -n "$DGX_PASS" ]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "ERROR: DGX_PASS is set but sshpass is not installed."
    exit 1
  fi
fi

is_tailscale_ip() {
  local ip="$1"
  [[ "$ip" =~ ^100\.([6-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
}

is_likely_tailscale_host() {
  local host="$1"
  if [[ "$host" == *.ts.net ]]; then
    return 0
  fi
  # Tailscale IPs are allocated from 100.64.0.0/10.
  if is_tailscale_ip "$host"; then
    return 0
  fi
  # Hostnames may still resolve to a Tailscale IP (for example `spark-de79`).
  if command -v getent >/dev/null 2>&1; then
    resolved_ip="$(getent ahostsv4 "$host" 2>/dev/null | awk 'NR==1 {print $1}')"
    resolved_ip="$(echo "$resolved_ip" | xargs)"
    if [ -n "$resolved_ip" ] && is_tailscale_ip "$resolved_ip"; then
      return 0
    fi
  fi
  return 1
}

all_hosts_require_tailscale() {
  local host_csv="$1"
  IFS=',' read -r -a _hosts <<< "$host_csv"
  local saw_host=0
  for _host in "${_hosts[@]}"; do
    _host="$(echo "$_host" | xargs)"
    [ -z "$_host" ] && continue
    saw_host=1
    if ! is_likely_tailscale_host "$_host"; then
      return 1
    fi
  done
  [ "$saw_host" -eq 1 ]
}

all_endpoints_require_tailscale() {
  local endpoint_csv="$1"
  local default_port="$2"
  IFS=',' read -r -a _endpoints <<< "$endpoint_csv"
  local saw_endpoint=0
  for _endpoint in "${_endpoints[@]}"; do
    _endpoint="$(echo "$_endpoint" | xargs)"
    [ -z "$_endpoint" ] && continue
    if split_result="$(split_endpoint_candidate "$_endpoint" "$default_port")"; then
      endpoint_host="${split_result%%,*}"
      endpoint_host="$(echo "$endpoint_host" | xargs)"
      [ -z "$endpoint_host" ] && continue
      saw_endpoint=1
      if ! is_likely_tailscale_host "$endpoint_host"; then
        return 1
      fi
    else
      return 1
    fi
  done
  [ "$saw_endpoint" -eq 1 ]
}

print_reachability_diagnostics() {
  local host_list="$1"
  local port_list="$2"
  echo
  echo "===== DGX reachability diagnostics ====="
  date -u +"UTC now: %Y-%m-%dT%H:%M:%SZ" || true
  if command -v tailscale >/dev/null 2>&1; then
    echo "-- tailscale status --"
    if is_tailscale_daemon_ready; then
      tailscale_cmd status 2>/dev/null | sed -n '1,40p' || true
      echo "-- tailscale backend state --"
      if is_tailscale_running; then
        echo "Running"
      else
        tailscale_cmd status --json 2>/dev/null | tr -d '\n' | sed -n 's/.*"BackendState"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p'
      fi
    else
      echo "tailscale daemon unavailable (tailscaled not running or inaccessible)"
    fi
    echo "-- tailscale ping (best-effort) --"
    if is_tailscale_daemon_ready; then
      tailscale_cmd ping -c 2 spark-de79 2>/dev/null || true
    else
      echo "tailscale ping skipped (daemon unavailable)"
    fi
  else
    echo "tailscale: not installed on local host"
  fi
  if command -v ip >/dev/null 2>&1; then
    echo "-- local routes (first lines) --"
    ip route show 2>/dev/null | sed -n '1,20p' || true
  fi
  IFS=',' read -r -a _diag_hosts <<< "$host_list"
  for _h in "${_diag_hosts[@]}"; do
    _h="$(echo "$_h" | xargs)"
    [ -z "$_h" ] && continue
    echo "-- host: $_h --"
    if command -v getent >/dev/null 2>&1; then
      getent hosts "$_h" 2>/dev/null || echo "getent: unresolved"
    fi
    if command -v ping >/dev/null 2>&1; then
      ping -c 1 -W 2 "$_h" >/dev/null 2>&1 && echo "icmp: reachable" || echo "icmp: no-reply"
    fi
    if command -v nc >/dev/null 2>&1; then
      IFS=',' read -r -a _diag_ports <<< "$port_list"
      for _p in "${_diag_ports[@]}"; do
        _p="$(echo "$_p" | xargs)"
        [ -z "$_p" ] && continue
        nc -z -w 2 "$_h" "$_p" >/dev/null 2>&1 && echo "tcp/${_p}: open" || echo "tcp/${_p}: closed-or-timeout"
      done
    fi
  done
  echo "===== end diagnostics ====="
}

append_host_candidate() {
  local new_host="$1"
  local existing_list="$2"
  if [ -z "$new_host" ]; then
    echo "$existing_list"
    return 0
  fi
  IFS=',' read -r -a _hosts <<< "$existing_list"
  for _h in "${_hosts[@]}"; do
    if [ "$(echo "$_h" | xargs)" = "$new_host" ]; then
      echo "$existing_list"
      return 0
    fi
  done
  if [ -z "$existing_list" ]; then
    echo "$new_host"
  else
    echo "${existing_list},${new_host}"
  fi
}

normalize_csv_candidates() {
  local csv="$1"
  local normalized=()
  IFS=',' read -r -a _entries <<< "$csv"
  for _entry in "${_entries[@]}"; do
    _entry="$(echo "$_entry" | xargs)"
    [ -z "$_entry" ] && continue
    local seen=0
    for _existing in "${normalized[@]}"; do
      if [ "$_existing" = "$_entry" ]; then
        seen=1
        break
      fi
    done
    if [ "$seen" -eq 0 ]; then
      normalized+=("$_entry")
    fi
  done
  (IFS=','; echo "${normalized[*]}")
}

split_endpoint_candidate() {
  local endpoint="$1"
  local default_port="$2"
  local host=""
  local port=""
  if [[ "$endpoint" == *:* ]]; then
    host="${endpoint%%:*}"
    port="${endpoint##*:}"
  else
    host="$endpoint"
    port="$default_port"
  fi
  host="$(echo "$host" | xargs)"
  port="$(echo "$port" | xargs)"
  if [ -z "$host" ] || [ -z "$port" ]; then
    return 1
  fi
  printf '%s,%s\n' "$host" "$port"
}

probe_ssh_candidate() {
  local host="$1"
  local port="$2"
  local attempt=1
  local stderr_file
  stderr_file="$(mktemp)"
  while [ "$attempt" -le "$DGX_PROBE_ATTEMPTS" ]; do
    mapfile -t _probe_ssh_cmd < <(build_ssh_base_cmd "$port")
    echo "Checking DGX SSH reachability (${DGX_USER}@${host}, port ${port}, attempt ${attempt}/${DGX_PROBE_ATTEMPTS})..." >&2
    if "${_probe_ssh_cmd[@]}" "${DGX_USER}@${host}" "echo 'DGX SSH reachable' >/dev/null" 2>"$stderr_file"; then
      rm -f "$stderr_file"
      return 0
    fi
    if [ "$attempt" -lt "$DGX_PROBE_ATTEMPTS" ] && [ "$DGX_PROBE_BACKOFF_SECONDS" -gt 0 ]; then
      sleep "$DGX_PROBE_BACKOFF_SECONDS"
    fi
    attempt=$((attempt + 1))
  done
  if [ -s "$stderr_file" ]; then
    tr '\n' ' ' <"$stderr_file" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
  else
    echo "ssh probe failed with no stderr output"
  fi
  rm -f "$stderr_file"
  return 1
}

if [ "$DGX_DISCOVER_TAILSCALE_IPS" = "1" ] && command -v tailscale >/dev/null 2>&1; then
  discovered_hosts="$DGX_HOST_CANDIDATES"
  if is_tailscale_running; then
    IFS=',' read -r -a _candidate_hosts <<< "$DGX_HOST_CANDIDATES"
    for candidate in "${_candidate_hosts[@]}"; do
      candidate="$(echo "$candidate" | xargs)"
      [ -z "$candidate" ] && continue
      if resolved_ip="$(tailscale_cmd ip -4 "$candidate" 2>/dev/null | head -n 1)"; then
        resolved_ip="$(echo "$resolved_ip" | xargs)"
        if [ -n "$resolved_ip" ]; then
          discovered_hosts="$(append_host_candidate "$resolved_ip" "$discovered_hosts")"
        fi
      fi
    done
  else
    echo "WARN: skipping Tailscale IP discovery because tailscaled is unavailable or not running."
  fi
  DGX_HOST_CANDIDATES="$discovered_hosts"
fi

DGX_HOST_CANDIDATES="$(normalize_csv_candidates "$DGX_HOST_CANDIDATES")"
DGX_PORT_CANDIDATES="$(normalize_csv_candidates "$DGX_PORT_CANDIDATES")"
DGX_ENDPOINT_CANDIDATES="$(normalize_csv_candidates "$DGX_ENDPOINT_CANDIDATES")"
probe_target_summary="Ports tested: $DGX_PORT_CANDIDATES"
if [ -n "$DGX_ENDPOINT_CANDIDATES" ]; then
  probe_target_summary="Endpoints tested: $DGX_ENDPOINT_CANDIDATES"
fi

if [ "$DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE" = "1" ] && [ -z "$DGX_SSH_PROXY_JUMP" ] && [ -z "$DGX_SSH_PROXY_COMMAND" ]; then
  if ! is_tailscale_running; then
    requires_tailscale=0
    if [ -n "$DGX_ENDPOINT_CANDIDATES" ]; then
      if all_endpoints_require_tailscale "$DGX_ENDPOINT_CANDIDATES" "$DGX_PORT"; then
        requires_tailscale=1
      fi
    elif all_hosts_require_tailscale "$DGX_HOST_CANDIDATES"; then
      requires_tailscale=1
    fi
    if [ "$requires_tailscale" -eq 1 ]; then
      echo "ERROR: local tailscale is not Running and all DGX candidates are Tailscale endpoints."
      echo "$probe_target_summary"
      echo "Hint: start/authenticate tailscaled, enable BOOTSTRAP_LOCAL_TAILSCALE=1, set DGX_SSH_PROXY_JUMP / DGX_SSH_PROXY_COMMAND, or provide a non-Tailscale DGX_HOST/DGX_ENDPOINT_CANDIDATES."
      print_reachability_diagnostics "$DGX_HOST_CANDIDATES" "$DGX_PORT_CANDIDATES"
      exit 1
    fi
  fi
fi

selected_host=""
selected_port=""
failed_candidates=()
if [ -n "$DGX_ENDPOINT_CANDIDATES" ]; then
  IFS=',' read -r -a endpoint_candidates <<< "$DGX_ENDPOINT_CANDIDATES"
  for endpoint_candidate in "${endpoint_candidates[@]}"; do
    endpoint_candidate="$(echo "$endpoint_candidate" | xargs)"
    [ -z "$endpoint_candidate" ] && continue
    if split_result="$(split_endpoint_candidate "$endpoint_candidate" "$DGX_PORT")"; then
      endpoint_host="${split_result%%,*}"
      endpoint_port="${split_result##*,}"
      if probe_error="$(probe_ssh_candidate "$endpoint_host" "$endpoint_port")"; then
        selected_host="$endpoint_host"
        selected_port="$endpoint_port"
        break
      else
        failed_candidates+=("${endpoint_host}:${endpoint_port} -> ${probe_error}")
      fi
    else
      failed_candidates+=("${endpoint_candidate} -> invalid endpoint candidate (expected host or host:port)")
    fi
  done
else
  IFS=',' read -r -a host_candidates <<< "$DGX_HOST_CANDIDATES"
  IFS=',' read -r -a port_candidates <<< "$DGX_PORT_CANDIDATES"
  for host_candidate in "${host_candidates[@]}"; do
    host_candidate="$(echo "$host_candidate" | xargs)"
    [ -z "$host_candidate" ] && continue
    for port_candidate in "${port_candidates[@]}"; do
      port_candidate="$(echo "$port_candidate" | xargs)"
      [ -z "$port_candidate" ] && continue
      if probe_error="$(probe_ssh_candidate "$host_candidate" "$port_candidate")"; then
        selected_host="$host_candidate"
        selected_port="$port_candidate"
        break 2
      else
        failed_candidates+=("${host_candidate}:${port_candidate} -> ${probe_error}")
      fi
    done
  done
fi

if [ -z "$selected_host" ]; then
  echo "ERROR: unable to reach DGX over SSH for any host candidate: $DGX_HOST_CANDIDATES"
  echo "$probe_target_summary"
  echo "Hint: verify Tailscale connectivity, set DGX_PORT_CANDIDATES, set DGX_HOST to a reachable endpoint, or use DGX_SSH_PROXY_JUMP / DGX_SSH_PROXY_COMMAND."
  if [ "${#failed_candidates[@]}" -gt 0 ]; then
    echo "Per-candidate SSH probe errors:"
    for failed in "${failed_candidates[@]}"; do
      echo "  - $failed"
    done
  fi
  print_reachability_diagnostics "$DGX_HOST_CANDIDATES" "$DGX_PORT_CANDIDATES"
  exit 1
fi
DGX_HOST="$selected_host"
DGX_PORT="$selected_port"
mapfile -t SSH_BASE_CMD < <(build_ssh_base_cmd "$DGX_PORT")
mapfile -t SCP_BASE_CMD < <(build_scp_base_cmd "$DGX_PORT")
SSH_CMD=("${SSH_BASE_CMD[@]}" "${DGX_USER}@${DGX_HOST}")
SCP_CMD=("${SCP_BASE_CMD[@]}")
echo "Using DGX host: $DGX_HOST (port $DGX_PORT)"

echo "Packing local checkout..."
# Keep remote sync lean: exclude local artifacts/caches that are not needed to execute scripts.
tar \
  --exclude-vcs \
  --exclude='./output' \
  --exclude='./.git' \
  --exclude='./.venv' \
  --exclude='./venv' \
  --exclude='./node_modules' \
  -czf "$TMP_TAR" \
  -C "$REPO_ROOT" .

echo "Resolving remote run directory..."
RESOLVED_TARGET_DIR="$("${SSH_CMD[@]}" "eval echo \"$DGX_TARGET_DIR\"")"
if [ -z "$RESOLVED_TARGET_DIR" ]; then
  echo "ERROR: failed to resolve remote target dir from DGX_TARGET_DIR=$DGX_TARGET_DIR"
  exit 1
fi
echo "Remote run directory: $RESOLVED_TARGET_DIR"

RESOLVED_REMOTE_AUTH_ENV=""
if [ "$PUSH_REMOTE_AUTH_ENV" = "1" ]; then
  if [ ! -f "$LOCAL_AUTH_ENV_FILE" ]; then
    echo "ERROR: PUSH_REMOTE_AUTH_ENV=1 but LOCAL_AUTH_ENV_FILE does not exist: $LOCAL_AUTH_ENV_FILE"
    exit 1
  fi
  if [ "$REQUIRE_LOCAL_AUTH_ENV_PERMS" = "1" ]; then
    local_perms="$(stat -c '%a' "$LOCAL_AUTH_ENV_FILE" 2>/dev/null || true)"
    if [ "$local_perms" != "600" ]; then
      echo "ERROR: local auth env must be mode 600: $LOCAL_AUTH_ENV_FILE (current: ${local_perms:-unknown})"
      exit 1
    fi
  fi
  RESOLVED_REMOTE_AUTH_ENV="$("${SSH_CMD[@]}" "eval echo \"$REMOTE_AUTH_ENV_FILE\"")"
  if [ -z "$RESOLVED_REMOTE_AUTH_ENV" ]; then
    echo "ERROR: failed to resolve remote auth env path from REMOTE_AUTH_ENV_FILE=$REMOTE_AUTH_ENV_FILE"
    exit 1
  fi
  echo "Provisioning remote auth env..."
  remote_auth_parent="$(dirname "$RESOLVED_REMOTE_AUTH_ENV")"
  "${SSH_CMD[@]}" "mkdir -p '$remote_auth_parent'"
  "${SCP_CMD[@]}" "$LOCAL_AUTH_ENV_FILE" "${DGX_USER}@${DGX_HOST}:${RESOLVED_REMOTE_AUTH_ENV}"
  "${SSH_CMD[@]}" "chmod 600 '$RESOLVED_REMOTE_AUTH_ENV'"
  echo "Remote auth env updated: $RESOLVED_REMOTE_AUTH_ENV"
fi

echo "Uploading checkout to ${DGX_USER}@${DGX_HOST}..."
"${SCP_CMD[@]}" "$TMP_TAR" "${DGX_USER}@${DGX_HOST}:/tmp/msfs-on-dgx-spark-sync.tgz"

echo "Running remote stable-runtime verification..."
if [ -n "$STRICT_MIN_STABLE_SECONDS" ]; then
  remote_runner="./scripts/56-run-staged-stability-check.sh"
else
  remote_runner="./scripts/55-run-until-stable-runtime.sh"
fi

set +e
"${SSH_CMD[@]}" "set -euo pipefail
TARGET_DIR='${RESOLVED_TARGET_DIR}'
mkdir -p \"\$TARGET_DIR\"
tar xzf /tmp/msfs-on-dgx-spark-sync.tgz -C \"\$TARGET_DIR\"
cd \"\$TARGET_DIR\"
mkdir -p output
if [ \"${LOAD_REMOTE_AUTH_ENV}\" = \"1\" ]; then
  remote_auth_env='${REMOTE_AUTH_ENV_FILE}'
  if [ -f \"\$remote_auth_env\" ]; then
    if [ \"${REQUIRE_REMOTE_AUTH_ENV_PERMS}\" = \"1\" ]; then
      perms=\"\$(stat -c '%a' \"\$remote_auth_env\" 2>/dev/null || true)\"
      if [ \"\$perms\" != \"600\" ]; then
        echo \"ERROR: remote auth env must be mode 600: \$remote_auth_env (current: \${perms:-unknown})\"
        exit 9
      fi
    fi
    set -a
    . \"\$remote_auth_env\"
    set +a
    echo \"Loaded remote auth env: \$remote_auth_env\"
  fi
fi
auth_gate='${AUTO_REAUTH_ON_AUTH_FAILURE}'
if [ -z \"\$auth_gate\" ]; then
  auth_gate=\"\${AUTO_REAUTH_ON_AUTH_FAILURE:-0}\"
fi
if [ \"\$auth_gate\" = \"1\" ]; then
  echo \"Running optional Steam auth recovery gate before verification...\"
  auth_username='${STEAM_USERNAME}'
  if [ -z \"\$auth_username\" ]; then
    auth_username=\"\${STEAM_USERNAME:-}\"
  fi
  auth_password='${STEAM_PASSWORD}'
  if [ -z \"\$auth_password\" ]; then
    auth_password=\"\${STEAM_PASSWORD:-}\"
  fi
  auth_guard_code='${STEAM_GUARD_CODE}'
  if [ -z \"\$auth_guard_code\" ]; then
    auth_guard_code=\"\${STEAM_GUARD_CODE:-}\"
  fi
  set +e
  LOGIN_WAIT_SECONDS='${REAUTH_LOGIN_WAIT_SECONDS}' \
  STEAM_USERNAME=\"\$auth_username\" \
  STEAM_PASSWORD=\"\$auth_password\" \
  AUTH_AUTO_FILL='${AUTH_AUTO_FILL}' \
  AUTH_SUBMIT_LOGIN='${AUTH_SUBMIT_LOGIN}' \
  AUTH_USE_STEAM_LOGIN_CLI='${AUTH_USE_STEAM_LOGIN_CLI}' \
  AUTH_RESTORE_WINDOWS='${AUTH_RESTORE_WINDOWS}' \
  STEAM_GUARD_CODE=\"\$auth_guard_code\" \
  ALLOW_UI_AUTH_FALLBACK='${ALLOW_UI_AUTH_FALLBACK}' \
  ./scripts/58-ensure-steam-auth.sh
  auth_recover_rc=\$?
  set -e
  if [ \"\$auth_recover_rc\" -ne 0 ]; then
    echo \"Auth recovery failed (exit \$auth_recover_rc).\"
    if [ \"${AUTH_DEBUG_ON_REAUTH_FAILURE}\" = \"1\" ]; then
      echo \"Capturing Steam UI/process diagnostics for auth failure...\"
      OUT_DIR=\"\$TARGET_DIR/output\" ./scripts/11-debug-steam-window-state.sh || true
    fi
    exit \"\$auth_recover_rc\"
  fi
fi
MSFS_APPID='${MSFS_APPID}' \
MIN_STABLE_SECONDS='${MIN_STABLE_SECONDS}' \
MAX_ATTEMPTS='${MAX_ATTEMPTS}' \
WAIT_SECONDS='${WAIT_SECONDS}' \
  DISPATCH_MAX_ATTEMPTS='${DISPATCH_MAX_ATTEMPTS}' \
  DISPATCH_RETRY_DELAY_SECONDS='${DISPATCH_RETRY_DELAY_SECONDS}' \
  DISPATCH_RECOVER_ON_NO_ACCEPT='${DISPATCH_RECOVER_ON_NO_ACCEPT}' \
  DISPATCH_ACCEPT_WAIT_SECONDS='${DISPATCH_ACCEPT_WAIT_SECONDS}' \
  PIPE_WRITE_TIMEOUT_SECONDS='${PIPE_WRITE_TIMEOUT_SECONDS}' \
  PIPE_WRITE_RETRIES='${PIPE_WRITE_RETRIES}' \
  PIPE_WRITE_RETRY_DELAY_SECONDS='${PIPE_WRITE_RETRY_DELAY_SECONDS}' \
  PIPE_WRITE_RECOVER_ON_TIMEOUT='${PIPE_WRITE_RECOVER_ON_TIMEOUT}' \
  URI_FALLBACK_ON_PIPE_FAILURE='${URI_FALLBACK_ON_PIPE_FAILURE}' \
  URI_FALLBACK_TIMEOUT_SECONDS='${URI_FALLBACK_TIMEOUT_SECONDS}' \
  DISPATCH_FALLBACK_APP_LAUNCH='${DISPATCH_FALLBACK_APP_LAUNCH}' \
  DISPATCH_FALLBACK_WAIT_SECONDS='${DISPATCH_FALLBACK_WAIT_SECONDS}' \
  DISPATCH_FORCE_UI_ON_FAILURE='${DISPATCH_FORCE_UI_ON_FAILURE}' \
  DISPATCH_FALLBACK_CHAIN='${DISPATCH_FALLBACK_CHAIN}' \
  ATTEMPT_PAUSE_SECONDS='${ATTEMPT_PAUSE_SECONDS}' \
  STRICT_MIN_STABLE_SECONDS='${STRICT_MIN_STABLE_SECONDS}' \
  STRICT_MAX_ATTEMPTS='${STRICT_MAX_ATTEMPTS}' \
  RECOVER_BETWEEN_ATTEMPTS='${RECOVER_BETWEEN_ATTEMPTS}' \
  STRICT_RECOVER_BETWEEN_ATTEMPTS='${STRICT_RECOVER_BETWEEN_ATTEMPTS}' \
  RECOVER_ON_EXIT_CODES='${RECOVER_ON_EXIT_CODES}' \
  FATAL_EXIT_CODES='${FATAL_EXIT_CODES}' \
  AUTH_DEBUG_ON_REAUTH_FAILURE='${AUTH_DEBUG_ON_REAUTH_FAILURE}' \
  ALLOW_UI_AUTH_FALLBACK='${ALLOW_UI_AUTH_FALLBACK}' \
  AUTH_BOOTSTRAP_STEAM_STACK='${AUTH_BOOTSTRAP_STEAM_STACK}' \
  AUTH_BOOTSTRAP_WAIT_SECONDS='${AUTH_BOOTSTRAP_WAIT_SECONDS}' \
  AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER='${AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER}' \
  BASELINE_MIN_STABLE_SECONDS='${MIN_STABLE_SECONDS}' \
  BASELINE_MAX_ATTEMPTS='${MAX_ATTEMPTS}' \
  \"${remote_runner}\"
echo
echo \"Remote run directory: \$TARGET_DIR\"
echo \"Latest verify log:\"
ls -1t \"\$TARGET_DIR\"/output/verify-launch-${MSFS_APPID}-*.log 2>/dev/null | head -n 1 || true
"
remote_rc=$?
set -e

if [ "$remote_rc" -ne 0 ]; then
  echo "Remote runner exited with code: $remote_rc"
fi

if [ "$FETCH_EVIDENCE" = "1" ]; then
  echo "Fetching remote evidence to local checkout..."
  if "${SSH_CMD[@]}" "test -d '${RESOLVED_TARGET_DIR}/output'"; then
    local_run_dir="$LOCAL_EVIDENCE_DIR/$(basename "$RESOLVED_TARGET_DIR")"
    mkdir -p "$local_run_dir"
    "${SCP_CMD[@]}" -r "${DGX_USER}@${DGX_HOST}:${RESOLVED_TARGET_DIR}/output" "$local_run_dir/"
    echo "Local evidence copied to: $local_run_dir/output"
  else
    echo "No remote output directory present (run exited before artifacts were produced)."
  fi
fi

exit "$remote_rc"
