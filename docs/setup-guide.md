# Setup Guide: MSFS on DGX Spark

Step-by-step instructions for running Microsoft Flight Simulator on the NVIDIA DGX Spark.

## Prerequisites

- NVIDIA DGX Spark with DGX OS (Ubuntu 24.04)
- SSH access or direct console access
- Steam account with **MSFS 2020 (Steam version)** purchased
- Internet connection (MSFS requires always-online authentication)
- A client device for streaming (if running headless)

## Phase 1: Fix Vulkan Drivers

The DGX Spark ships with driver 580.95.05 which has a known Vulkan bug. The `libnvidia-gl-580` package may not be installed, causing Vulkan to fall back to `llvmpipe` (CPU software rendering).

### Verify current state

```bash
vulkaninfo --summary 2>/dev/null | grep -E "GPU|driver"
```

If you see only `llvmpipe` or no NVIDIA GPU listed, run the fix:

```bash
# Install the missing GL/Vulkan package
sudo apt-get update
sudo apt-get install libnvidia-gl-580

# Verify
vulkaninfo --summary
```

You should see something like:
```
GPU0:
    apiVersion = 1.4.x
    driverVersion = 580.x.x
    vendorID = 0x10de
    deviceID = ...
    deviceName = NVIDIA GB10
```

### Driver update (recommended)

Driver 580.105.08+ fixes additional Vulkan issues:

```bash
# Check for available updates
apt list --upgradable 2>/dev/null | grep nvidia

# If an update is available
sudo apt-get upgrade libnvidia-gl-580 nvidia-driver-580
sudo reboot
```

## Phase 2: Install FEX-Emu and Steam

FEX-Emu translates x86-64 binaries to ARM64 at near-native speed. It's funded by Valve and integrated into SteamOS for ARM. DLSS 4 and Multi-Frame Generation work through FEX + Proton 10.x, which is critical for playable performance.

### Option A: Canonical Steam Snap (recommended)

Canonical provides an experimental ARM64 Steam Snap that bundles FEX automatically:

```bash
sudo snap install steam --edge
```

Launch with:
```bash
steam
```

### Option B: Manual FEX + Steam

1. **Install FEX-Emu:**

```bash
# From FEX-Emu's official installer
curl -fsSL https://raw.githubusercontent.com/FEX-Emu/FEX/main/Scripts/InstallFEX.py -o /tmp/InstallFEX.py
python3 /tmp/InstallFEX.py
```

Or build from source:
```bash
sudo apt install cmake ninja-build pkg-config libsdl2-dev libepoxy-dev
git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git
cd FEX && mkdir build && cd build
cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release
ninja
sudo ninja install
```

2. **Set up x86-64 rootfs:**

```bash
FEXRootFSFetcher
```

This downloads an x86-64 Ubuntu rootfs that FEX uses for library resolution.

3. **Register binfmt:**

```bash
sudo systemctl restart systemd-binfmt
```

This lets the kernel automatically route x86-64 binaries through FEX.

4. **Install Steam:**

```bash
# Steam will run through FEX's x86-64 translation
FEXBash -c "steam"
```

## Phase 3: Install and Configure MSFS

### Install MSFS 2020

1. Launch Steam and log in
2. Search for "Microsoft Flight Simulator" (AppID: 1250410)
3. Install the game (requires ~150 GB)

### Set Proton version

1. Right-click MSFS 2020 in Steam Library
2. Properties → Compatibility
3. Check "Force the use of a specific Steam Play compatibility tool"
4. Select **Proton 10.0-2 (beta)** or later

If Proton 10.0-2 is not available, install it:
- Steam → Settings → Compatibility → Enable Steam Play for all titles
- Library → Tools → search "Proton" → install the latest beta

### Set launch options

Right-click MSFS 2020 → Properties → General → Launch Options:

```
DXVK_HUD=fps,devinfo %command% -FastLaunch
```

| Option | Purpose |
|--------|---------|
| `DXVK_HUD=fps,devinfo` | Show FPS counter and GPU info overlay |
| `-FastLaunch` | Skip intro videos (prevents a known Wine crash) |

### First launch

1. Launch the game through Steam
2. MSFS will prompt for Microsoft Account login — this happens in a web browser overlay through Proton's built-in browser
3. The game will download additional content (scenery, world data) — this is normal and can be 100+ GB
4. Monitor the terminal for errors

### Headless resume (Steam Guard / reconnect-safe)

If your SSH/VNC session drops or Steam Guard interrupts login, run:

```bash
./scripts/05-resume-headless-msfs.sh install
```

This restarts `Xvfb`, `openbox`, Steam, and `x11vnc` on `127.0.0.1:5901`, then re-triggers the MSFS install URI.

After installation completes, trigger launch:

```bash
./scripts/05-resume-headless-msfs.sh launch
```

At any point, collect a one-shot readiness report and screenshot:

```bash
./scripts/06-verify-msfs-state.sh
```

This prints process health (`Xvfb`, `openbox`, Steam, `x11vnc`), MSFS AppID `1250410` manifest/download status, Sunshine service state, and writes a Steam desktop screenshot to `/tmp/steam-state-1250410.png`.

If you are currently blocked at Steam Guard, you can keep one watcher running that automatically queues install as soon as login succeeds:

```bash
./scripts/07-await-login-and-install.sh
```


For a single command that can enter Steam Guard (if provided), queue install, and trigger launch:

```bash
./scripts/08-finalize-auth-and-run-msfs.sh <STEAM_GUARD_CODE>
```

If Steam webhelper is crash-looping with:
`bwrap: execvp .../pv-adverb: No such file or directory`,
install the host `pv-adverb` wrapper once (requires sudo):

```bash
./scripts/52-install-pvadverb-fex-wrapper.sh
```

Then restart the flow:

```bash
./scripts/08-finalize-auth-and-run-msfs.sh
```

`08-finalize-auth-and-run-msfs.sh` now supports offline launch continuation for already downloaded builds.
Set `ALLOW_OFFLINE_LAUNCH_IF_INSTALLED=0` to force strict authenticated-session behavior.

After launch is triggered, verify a candidate MSFS process is actually running:

```bash
./scripts/09-verify-msfs-launch.sh
```

By default this verifier requires a stable runtime window of 30 seconds (to avoid wrapper-only false positives). Override when needed:

```bash
MIN_STABLE_SECONDS=20 ./scripts/09-verify-msfs-launch.sh
```

For one-shot launch plus artifact capture (dispatch log, verify log, Steam state excerpts, and latest crash files):

```bash
./scripts/54-launch-and-capture-evidence.sh
```

If pipe dispatch is flaky in your session, keep the fallback chain enabled (default) and tune it explicitly:

```bash
DISPATCH_FORCE_UI_ON_FAILURE=1 \
DISPATCH_FALLBACK_CHAIN='applaunch,steam_uri,snap_uri' \
./scripts/54-launch-and-capture-evidence.sh
```

For repeated retries until a stable runtime window is reached:

```bash
MIN_STABLE_SECONDS=20 MAX_ATTEMPTS=5 ./scripts/55-run-until-stable-runtime.sh
```

From a local workstation, you can also sync your current checkout to DGX and run the same stable-runtime validation remotely:

```bash
DGX_PASS='<password>' ./scripts/90-remote-dgx-stable-check.sh
```

When remote auth recovery is enabled and the login UI is not visibly rendered in headless mode, credential-based CLI login can be forced:

```bash
DGX_PASS='<password>' AUTO_REAUTH_ON_AUTH_FAILURE=1 STEAM_USERNAME='<steam_user>' STEAM_PASSWORD='<steam_pass>' AUTH_USE_STEAM_LOGIN_CLI=1 ./scripts/90-remote-dgx-stable-check.sh
```

For unattended runs, you can keep Steam credentials only on DGX and let remote checks load them:

```bash
# run on DGX once
mkdir -p ~/.config/msfs-on-dgx-spark
cat > ~/.config/msfs-on-dgx-spark/steam-auth.env <<'EOF'
AUTO_REAUTH_ON_AUTH_FAILURE=1
STEAM_USERNAME='your_user'
STEAM_PASSWORD='your_pass'
# optional:
# STEAM_GUARD_CODE='12345'
EOF
chmod 600 ~/.config/msfs-on-dgx-spark/steam-auth.env

# then from local workstation
DGX_PASS='<password>' ./scripts/90-remote-dgx-stable-check.sh
```

Window restore is also enabled by default during re-auth (`AUTH_RESTORE_WINDOWS=1`) to unminimize/focus hidden Steam windows before timing out.
Re-auth now also normalizes Steam window geometry by default (`AUTH_NORMALIZE_WINDOWS=1`) so tiny/off-screen windows are resized/moved into a visible area for manual login.
During launch verification, auth checks now bootstrap Steam/UI first (`AUTH_BOOTSTRAP_STEAM_STACK=1`) and can auto-run runtime recovery when `steamwebhelper` is missing (`AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER=1`).

Useful overrides:

```bash
DGX_HOST=100.77.4.93 DGX_USER=th0rgal MSFS_APPID=2537590 MIN_STABLE_SECONDS=20 \
MAX_ATTEMPTS=2 WAIT_SECONDS=120 ./scripts/90-remote-dgx-stable-check.sh
```

If your local runner cannot reach DGX directly, route SSH through a jump host:

```bash
DGX_PASS='<password>' DGX_SSH_PROXY_JUMP='user@jump-host' \
MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh
```

Or provide a custom proxy command:

```bash
DGX_PASS='<password>' DGX_SSH_PROXY_COMMAND='ssh -W %h:%p jump-host' \
DGX_SSH_EXTRA_OPTS_CSV='IdentityFile=/path/to/key,UserKnownHostsFile=/dev/null' \
./scripts/90-remote-dgx-stable-check.sh
```

If all configured DGX targets are Tailscale-only and local `tailscaled` is unavailable, remote checks fail fast by default (`DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE=1`) unless direct TCP reachability is detected; when a candidate port is directly reachable, the script continues with SSH probing automatically. Set `DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE=0` to force full timeout-based SSH probing in all cases.
When local Tailscale state is available, known-offline Tailscale candidates are skipped by default (`DGX_SKIP_OFFLINE_TAILSCALE_CANDIDATES=1`), and failure output includes peer `last seen` diagnostics. Set `DGX_SKIP_OFFLINE_TAILSCALE_CANDIDATES=0` to force probing offline peers anyway.

In non-systemd runners, you can bootstrap a local userspace Tailscale daemon and route SSH/SCP through its SOCKS endpoint automatically:

```bash
DGX_PASS='<password>' BOOTSTRAP_LOCAL_TAILSCALE=1 \
LOCAL_TAILSCALE_AUTHKEY='<tskey-auth-...>' \
./scripts/90-remote-dgx-stable-check.sh
```

Or source the auth key from a local file (recommended to avoid shell history leaks):

```bash
cat > ~/.config/msfs-on-dgx-spark/tailscale-authkey <<'EOF'
tskey-auth-...
EOF
chmod 600 ~/.config/msfs-on-dgx-spark/tailscale-authkey
DGX_PASS='<password>' BOOTSTRAP_LOCAL_TAILSCALE=1 \
LOCAL_TAILSCALE_AUTHKEY_FILE="$HOME/.config/msfs-on-dgx-spark/tailscale-authkey" \
./scripts/90-remote-dgx-stable-check.sh
```

If you omit `LOCAL_TAILSCALE_AUTHKEY`, authenticate once with:

```bash
tailscale --socket /tmp/msfs-on-dgx-spark-tailscaled.sock login
tailscale --socket /tmp/msfs-on-dgx-spark-tailscaled.sock up
```

Then re-run the remote check command with `BOOTSTRAP_LOCAL_TAILSCALE=1`.
With defaults, the script will auto-load `LOCAL_TAILSCALE_AUTHKEY_FILE` from `$HOME/.config/msfs-on-dgx-spark/tailscale-authkey` when present (`AUTO_LOAD_LOCAL_TAILSCALE_AUTHKEY_FILE=1`), still enforcing mode `600`.
By default, userspace state is persisted at `${XDG_STATE_HOME:-$HOME/.local/state}/msfs-on-dgx-spark/tailscaled.state` so login can be reused on later runs. Override with `LOCAL_TAILSCALE_STATE=...` when needed.
By default the script does not execute interactive `tailscale login` (`LOCAL_TAILSCALE_INTERACTIVE_LOGIN=0`) to avoid long blocking waits in CI/headless shells. Enable it explicitly when you want the script to retrieve the login URL itself:

```bash
DGX_PASS='<password>' BOOTSTRAP_LOCAL_TAILSCALE=1 \
LOCAL_TAILSCALE_INTERACTIVE_LOGIN=1 \
./scripts/90-remote-dgx-stable-check.sh
```

If login URL retrieval times out before you can complete browser auth, raise `LOCAL_TAILSCALE_LOGIN_TIMEOUT_SECONDS` (for example `LOCAL_TAILSCALE_LOGIN_TIMEOUT_SECONDS=120`).
To make this auth gate orchestration-friendly, set `LOCAL_TAILSCALE_AUTH_URL_FILE=/path/to/url.txt` so the script writes the login URL to disk whenever available; unauthenticated bootstrap exits with `LOCAL_TAILSCALE_NEEDS_LOGIN_EXIT_CODE` (default `10`).
If userspace daemon startup is flaky in your runner, tune bootstrap retries with `LOCAL_TAILSCALE_BOOTSTRAP_RETRIES` and `LOCAL_TAILSCALE_BOOTSTRAP_RETRY_DELAY_SECONDS`; bootstrap now also removes stale sockets and isolates retry socket/log paths automatically.
If the script bootstraps userspace `tailscaled`, it now stops that script-started daemon on exit by default (`LOCAL_TAILSCALE_CLEANUP_ON_EXIT=1`) to avoid lingering local daemons in CI/headless environments. Set `LOCAL_TAILSCALE_CLEANUP_ON_EXIT=0` only when you intentionally want to preserve it for debugging.
`LOCAL_TAILSCALE_AUTHKEY_FILE` is fail-closed by default: it must exist, be non-empty, and be mode `600` (`REQUIRE_LOCAL_TAILSCALE_AUTHKEY_FILE_PERMS=1`).

Optional staged gate (baseline + strict):

```bash
DGX_PASS='<password>' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 \
STRICT_MIN_STABLE_SECONDS=45 STRICT_MAX_ATTEMPTS=2 \
./scripts/90-remote-dgx-stable-check.sh
```

Optional unattended re-auth gate (credential form + optional Steam Guard) before verification:

```bash
DGX_PASS='<password>' AUTO_REAUTH_ON_AUTH_FAILURE=1 \
STEAM_USERNAME='<steam_user>' STEAM_PASSWORD='<steam_pass>' STEAM_GUARD_CODE='<code>' \
REAUTH_LOGIN_WAIT_SECONDS=180 ./scripts/90-remote-dgx-stable-check.sh
```

`90-remote-dgx-stable-check.sh` loads `REMOTE_AUTH_ENV_FILE` (default `$HOME/.config/msfs-on-dgx-spark/steam-auth.env`) when `LOAD_REMOTE_AUTH_ENV=1` (default). For safety, the file must be mode `600` unless `REQUIRE_REMOTE_AUTH_ENV_PERMS=0` is explicitly set.

To provision/update that remote auth env from your local workstation before each run, set:

```bash
DGX_PASS='<password>' PUSH_REMOTE_AUTH_ENV=1 \
LOCAL_AUTH_ENV_FILE="$HOME/.config/msfs-on-dgx-spark/steam-auth.env" \
./scripts/90-remote-dgx-stable-check.sh
```

When `STRICT_MIN_STABLE_SECONDS` is set, remote checks run in two stages:
- baseline gate (`MIN_STABLE_SECONDS`/`MAX_ATTEMPTS`) proves local run-path health
- strict gate (`STRICT_MIN_STABLE_SECONDS`/`STRICT_MAX_ATTEMPTS`) measures higher stability confidence

## Phase 4: Remote Streaming (Optional)

If the DGX Spark is headless or you want to play from another device, use Sunshine + Moonlight.

### Install Sunshine

```bash
ARCH=$(dpkg --print-architecture)
curl -fL "https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-ubuntu-24.04-${ARCH}.deb" -o /tmp/sunshine.deb
sudo dpkg -i /tmp/sunshine.deb || sudo apt-get -f install -y
```

The Snap package is no longer available on this DGX image; use the GitHub release .deb instead.

### Configure Sunshine

```bash
sunshine
```

Open `https://<dgx-spark-ip>:47990` in a browser to set up credentials.

### Install Moonlight (client)

Download from [moonlight-stream.org](https://moonlight-stream.org/) for your client device.

### Pair and connect

1. Open Moonlight on your client
2. Add the DGX Spark's IP address
3. Pair using the PIN displayed in Sunshine's web UI
4. Select the desktop or Steam Big Picture as the streaming target

### Recommended streaming settings

- Resolution: 1080p (start here, increase if bandwidth allows)
- FPS: 60
- Codec: HEVC (H.265) for lower bandwidth, AV1 if supported
- Bitrate: 30-50 Mbps on wired, 15-20 Mbps on WiFi

## Performance Tuning

### CPU governor

Set the CPU to performance mode for consistent frame times:

```bash
sudo cpupower frequency-set -g performance
```

### Shader cache

Pre-warm the shader cache to reduce compilation stuttering:

```bash
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=10737418240  # 10 GB
```

### MSFS in-game settings

Start conservative and increase:

| Setting | Recommended Start |
|---------|------------------|
| Resolution | 1080p |
| Render scaling | 100% (TAA) |
| Global quality | Medium |
| Terrain LOD | 100 |
| Object LOD | 100 |
| Clouds | Medium |
| VSync | Off |

If DLSS is available (FEX + Proton 10.x enables this):
- Enable DLSS in Quality or Balanced mode
- Enable Frame Generation if DLSS 3+ is available
- Enable Multi-Frame Generation if DLSS 4 is available

### Environment variables for advanced tuning

```bash
# Force DX11 mode (MSFS 2020 only — uses DXVK instead of VKD3D-Proton)
PROTON_USE_WINED3D=0 %command% -FastLaunch

# Debug VKD3D-Proton issues (MSFS 2024 DX12)
VKD3D_DEBUG=warn VKD3D_CONFIG=dxr %command% -FastLaunch

# Disable DXVK HUD after initial testing
# Just remove DXVK_HUD from launch options

# Serialize launch/retry/remote orchestrators (enabled by default)
ENABLE_SCRIPT_LOCKS=1
MSFS_LAUNCH_LOCK_WAIT_SECONDS=0
MSFS_STABLE_RUN_LOCK_WAIT_SECONDS=0
MSFS_REMOTE_CHECK_LOCK_WAIT_SECONDS=0
```
