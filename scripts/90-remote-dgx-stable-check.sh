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

MSFS_APPID="${MSFS_APPID:-2537590}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-20}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
ATTEMPT_PAUSE_SECONDS="${ATTEMPT_PAUSE_SECONDS:-12}"
DISPATCH_MAX_ATTEMPTS="${DISPATCH_MAX_ATTEMPTS:-2}"
DISPATCH_RETRY_DELAY_SECONDS="${DISPATCH_RETRY_DELAY_SECONDS:-8}"
DISPATCH_RECOVER_ON_NO_ACCEPT="${DISPATCH_RECOVER_ON_NO_ACCEPT:-1}"
DISPATCH_ACCEPT_WAIT_SECONDS="${DISPATCH_ACCEPT_WAIT_SECONDS:-45}"
DISPATCH_FALLBACK_APP_LAUNCH="${DISPATCH_FALLBACK_APP_LAUNCH:-1}"
DISPATCH_FALLBACK_WAIT_SECONDS="${DISPATCH_FALLBACK_WAIT_SECONDS:-20}"
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

if [ -n "$DGX_HOST" ]; then
  DGX_HOST_CANDIDATES="$DGX_HOST"
fi

BASE_SSH_COMMON_OPTS=(
  -o StrictHostKeyChecking=no
  -o ConnectTimeout="${SSH_CONNECT_TIMEOUT_SECONDS}"
  -o ConnectionAttempts="${SSH_CONNECTION_ATTEMPTS}"
  -o ServerAliveInterval="${SSH_SERVER_ALIVE_INTERVAL_SECONDS}"
  -o ServerAliveCountMax="${SSH_SERVER_ALIVE_COUNT_MAX}"
)
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

is_tailscale_daemon_ready() {
  command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1
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
      tailscale status 2>/dev/null | sed -n '1,40p' || true
    else
      echo "tailscale daemon unavailable (tailscaled not running or inaccessible)"
    fi
    echo "-- tailscale ping (best-effort) --"
    if is_tailscale_daemon_ready; then
      tailscale ping -c 2 spark-de79 2>/dev/null || true
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
  if is_tailscale_daemon_ready; then
    IFS=',' read -r -a _candidate_hosts <<< "$DGX_HOST_CANDIDATES"
    for candidate in "${_candidate_hosts[@]}"; do
      candidate="$(echo "$candidate" | xargs)"
      [ -z "$candidate" ] && continue
      if resolved_ip="$(tailscale ip -4 "$candidate" 2>/dev/null | head -n 1)"; then
        resolved_ip="$(echo "$resolved_ip" | xargs)"
        if [ -n "$resolved_ip" ]; then
          discovered_hosts="$(append_host_candidate "$resolved_ip" "$discovered_hosts")"
        fi
      fi
    done
  else
    echo "WARN: skipping Tailscale IP discovery because tailscaled is unavailable."
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
  echo "Hint: verify Tailscale connectivity, set DGX_PORT_CANDIDATES, or set DGX_HOST to a reachable endpoint."
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
  DISPATCH_FALLBACK_APP_LAUNCH='${DISPATCH_FALLBACK_APP_LAUNCH}' \
  DISPATCH_FALLBACK_WAIT_SECONDS='${DISPATCH_FALLBACK_WAIT_SECONDS}' \
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
