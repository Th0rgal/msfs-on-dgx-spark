#!/usr/bin/env bash
# Sync the current checkout to DGX Spark and run stable-runtime verification remotely.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

DGX_HOST="${DGX_HOST:-100.77.4.93}"
DGX_USER="${DGX_USER:-th0rgal}"
DGX_PASS="${DGX_PASS:-}"
DGX_TARGET_DIR="${DGX_TARGET_DIR:-\$HOME/msfs-on-dgx-spark-run-\$(date -u +%Y%m%dT%H%M%SZ)}"

MSFS_APPID="${MSFS_APPID:-2537590}"
MIN_STABLE_SECONDS="${MIN_STABLE_SECONDS:-20}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-2}"
WAIT_SECONDS="${WAIT_SECONDS:-120}"
ATTEMPT_PAUSE_SECONDS="${ATTEMPT_PAUSE_SECONDS:-12}"
STRICT_MIN_STABLE_SECONDS="${STRICT_MIN_STABLE_SECONDS:-}"
STRICT_MAX_ATTEMPTS="${STRICT_MAX_ATTEMPTS:-3}"
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
MSFS_APPID='${MSFS_APPID}' \
MIN_STABLE_SECONDS='${MIN_STABLE_SECONDS}' \
MAX_ATTEMPTS='${MAX_ATTEMPTS}' \
WAIT_SECONDS='${WAIT_SECONDS}' \
ATTEMPT_PAUSE_SECONDS='${ATTEMPT_PAUSE_SECONDS}' \
STRICT_MIN_STABLE_SECONDS='${STRICT_MIN_STABLE_SECONDS}' \
STRICT_MAX_ATTEMPTS='${STRICT_MAX_ATTEMPTS}' \
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
  local_run_dir="$LOCAL_EVIDENCE_DIR/$(basename "$RESOLVED_TARGET_DIR")"
  mkdir -p "$local_run_dir"
  "${SCP_CMD[@]}" -r "${DGX_USER}@${DGX_HOST}:${RESOLVED_TARGET_DIR}/output" "$local_run_dir/"
  echo "Local evidence copied to: $local_run_dir/output"
fi

exit "$remote_rc"
