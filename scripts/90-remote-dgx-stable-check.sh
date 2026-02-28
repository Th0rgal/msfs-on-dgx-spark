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

DGX_HOST="${DGX_HOST:-100.77.4.93}"
DGX_USER="${DGX_USER:-th0rgal}"
DGX_PASS="${DGX_PASS:-}"
DGX_TARGET_DIR="${DGX_TARGET_DIR:-\$HOME/msfs-on-dgx-spark-run-\$(date -u +%Y%m%dT%H%M%SZ)}"

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

SSH_CMD=(ssh -o StrictHostKeyChecking=no "${DGX_USER}@${DGX_HOST}")
SCP_CMD=(scp -o StrictHostKeyChecking=no)

if [ -n "$DGX_PASS" ]; then
  if ! command -v sshpass >/dev/null 2>&1; then
    echo "ERROR: DGX_PASS is set but sshpass is not installed."
    exit 1
  fi
  SSH_CMD=(sshpass -p "$DGX_PASS" "${SSH_CMD[@]}")
  SCP_CMD=(sshpass -p "$DGX_PASS" "${SCP_CMD[@]}")
fi

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
