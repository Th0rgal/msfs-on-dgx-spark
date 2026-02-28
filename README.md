# MSFS on DGX Spark

Running Microsoft Flight Simulator on the NVIDIA DGX Spark — an ARM-based AI supercomputer running Ubuntu.

## Why This Exists

Microsoft Flight Simulator (MSFS) is a Windows-only game. The DGX Spark is an ARM64 Linux machine with a Blackwell GPU. Getting MSFS running requires bridging three gaps simultaneously:

1. **OS**: Windows → Linux (Wine/Proton)
2. **Architecture**: x86-64 → ARM64 (FEX-Emu)
3. **GPU drivers**: Game-ready → data center (NVIDIA 580.x data center drivers)

Nobody has done this before. This repo documents the attempt.

## Hardware

| Component | Spec |
|-----------|------|
| CPU | 20-core ARM (10x Cortex-X925 + 10x Cortex-A725) |
| GPU | NVIDIA GB10 Blackwell, 6,144 CUDA cores, RT cores, Vulkan 1.4 |
| Memory | 128 GB unified LPDDR5X (~273 GB/s bandwidth) |
| Storage | 4 TB NVMe |
| OS | DGX OS (Ubuntu 24.04 LTS), kernel 6.14 |
| Driver | NVIDIA 580.95.05, CUDA 13.0 |

## Prior Art

| Game | Method | FPS | Settings |
|------|--------|-----|----------|
| Cyberpunk 2077 | Box64 + Steam | ~50 | 1080p Medium, no DLSS |
| Cyberpunk 2077 | FEX + Proton 10.x | 175+ | 1080p High, Ultra RT, DLSS 4 MFG |
| Cyberpunk 2077 | Canonical Steam Snap | 200+ | 1080p, DLSS |

FEX-Emu with Proton 10.x is the clear winner — it enables DLSS 4 and Multi-Frame Generation, which Box64 cannot.

## Approach

We use **FEX-Emu** (not Box64) as the x86-to-ARM translation layer, combined with **Steam + Proton 10.x** for Windows-to-Linux compatibility. The full stack:

```
MSFS 2020 (DX11 mode) or MSFS 2024 (DX12)
    ↓
Proton 10.x (Wine + DXVK/VKD3D-Proton)
    ↓
FEX-Emu (x86-64 → ARM64 translation)
    ↓
Vulkan 1.4 (native ARM64)
    ↓
NVIDIA GB10 Blackwell GPU
```

### Why FEX-Emu over Box64

- FEX is **funded by Valve** and integrated into SteamOS for ARM
- **DLSS 4 with Multi-Frame Generation works** through FEX + Proton 10.x (impossible on Box64)
- ~10-20% overhead vs Box64's ~20% overhead
- First-class Proton integration (Valve ships it with Steam Frame)
- Canonical provides a Steam Snap with FEX bundled for Ubuntu ARM64

### Why MSFS 2020 (Steam) First

- MSFS 2020 is rated **Gold on ProtonDB** — hundreds of confirmed working reports on x86 Linux
- Supports **DX11 mode** (translated by DXVK, more mature than VKD3D-Proton for DX12)
- MSFS 2024 is DX12-only and has a shorter Proton compatibility history
- **Steam version is mandatory** — Microsoft Store version cannot run on Linux at all
- MSFS 2024 will be attempted as a stretch goal

## Known Risks

### Likely Blockers
- **Arxan Anti-Tamper DRM** performs integrity checks on executable code in memory. Under x86→ARM translation, the code layout changes, which could trigger tamper detection. Box64 v0.4.0 improved DRM compatibility, and FEX may handle this differently, but it's untested with MSFS.
- **Memory bandwidth** — the DGX Spark's unified LPDDR5X provides ~273 GB/s, significantly less than dedicated GDDR7 on desktop RTX 50 series cards. MSFS is memory-hungry.

### Possible Issues
- **Shader compilation stuttering** — VKD3D-Proton shader compilation is CPU-intensive; under translation it could be worse
- **Microsoft Account authentication** — MSFS requires always-online auth. Should work through Proton but untested on ARM.
- **Vulkan driver maturity** — the DGX Spark shipped with a broken Vulkan driver (missing `libnvidia-gl-580`). Driver 580.105.08+ fixes this.
- **No game-ready drivers** — NVIDIA does not ship game-optimized drivers for the DGX Spark

### Not a Problem
- **Anti-cheat** — MSFS has no anti-cheat system, only Arxan anti-tamper
- **GPU graphics capability** — unlike the A100/H100 (which lack 3D engines), the GB10 Blackwell has a **full graphics pipeline** with RT cores and Vulkan 1.4

## Setup

### Prerequisites

- NVIDIA DGX Spark with DGX OS
- Steam account with MSFS 2020 purchased (Steam version)
- Display or remote streaming setup (Sunshine/Moonlight)

### Quick Start

```bash
# 1. Fix Vulkan drivers (if vulkaninfo only shows llvmpipe)
./scripts/01-fix-vulkan.sh

# 2. Install FEX-Emu + Steam
./scripts/02-install-fex-steam.sh

# 3. Configure Proton for MSFS
./scripts/03-configure-msfs.sh

# 4. (Optional) Set up remote streaming
./scripts/04-setup-streaming.sh

# 5. Resume/create headless Steam session and trigger MSFS install
./scripts/05-resume-headless-msfs.sh install

# 6. Verify current readiness/download state and capture Steam screen
./scripts/06-verify-msfs-state.sh

# 7. Optional: wait for Steam auth, auto-trigger install, and monitor progress
./scripts/07-await-login-and-install.sh

# 8. Optional: one-shot finalize (Steam Guard code -> install -> launch)
./scripts/08-finalize-auth-and-run-msfs.sh <STEAM_GUARD_CODE>

# 9. Optional: verify MSFS launch reached stable runtime
./scripts/09-verify-msfs-launch.sh

# 10. Optional: run DGX runtime preflight repairs directly
./scripts/53-preflight-runtime-repair.sh

# 11. Optional: retry launch cycles until stable runtime is observed
MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=5 ./scripts/55-run-until-stable-runtime.sh

# 12. Optional: from your local workstation, sync this repo to DGX and run stable check remotely
DGX_PASS='<password>' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh

# 13. Optional: staged reliability check (baseline + strict gate) on remote DGX
DGX_PASS='<password>' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=2 STRICT_MIN_STABLE_SECONDS=45 STRICT_MAX_ATTEMPTS=3 ./scripts/90-remote-dgx-stable-check.sh

# 14. Optional: staged reliability with automatic Steam runtime recovery between strict retries
DGX_PASS='<password>' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 STRICT_MIN_STABLE_SECONDS=60 STRICT_MAX_ATTEMPTS=2 STRICT_RECOVER_BETWEEN_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh

# 15. Optional: include remote Steam auth recovery before verification (supports username/password + Steam Guard)
DGX_PASS='<password>' AUTO_REAUTH_ON_AUTH_FAILURE=1 STEAM_USERNAME='<steam_user>' STEAM_PASSWORD='<steam_pass>' STEAM_GUARD_CODE='<code>' REAUTH_LOGIN_WAIT_SECONDS=180 ./scripts/90-remote-dgx-stable-check.sh

# 16. Optional: force credential-based CLI login when headless UI windows are not visible
DGX_PASS='<password>' AUTO_REAUTH_ON_AUTH_FAILURE=1 STEAM_USERNAME='<steam_user>' STEAM_PASSWORD='<steam_pass>' AUTH_USE_STEAM_LOGIN_CLI=1 ./scripts/90-remote-dgx-stable-check.sh

# 17. Optional: keep Steam credentials only on DGX (chmod 600) and let remote checks load them
# on DGX:
#   mkdir -p ~/.config/msfs-on-dgx-spark
#   cat > ~/.config/msfs-on-dgx-spark/steam-auth.env <<'EOF'
#   AUTO_REAUTH_ON_AUTH_FAILURE=1
#   STEAM_USERNAME='your_user'
#   STEAM_PASSWORD='your_pass'
#   # optional:
#   # STEAM_GUARD_CODE='12345'
#   EOF
#   chmod 600 ~/.config/msfs-on-dgx-spark/steam-auth.env
DGX_PASS='<password>' ./scripts/90-remote-dgx-stable-check.sh

# 18. Optional: bootstrap local userspace tailscale + SOCKS proxy when this runner has no system tailscaled
DGX_PASS='<password>' BOOTSTRAP_LOCAL_TAILSCALE=1 LOCAL_TAILSCALE_AUTHKEY='<tskey-auth-...>' ./scripts/90-remote-dgx-stable-check.sh
```

`09-verify-msfs-launch.sh` now requires a stable runtime window (default `30s`) to avoid false positives from short-lived launch wrappers. Tune with `MIN_STABLE_SECONDS=<N>`.
Launch/verify scripts now auto-select an NVIDIA-backed X display when available (typically `:2` on DGX). Override explicitly with `DISPLAY_NUM=:N` when needed.
`54-launch-and-capture-evidence.sh` now enforces a Steam authenticated-session gate and exits with code `7` when the session is logged out, so retry loops fail fast on auth drift instead of reporting ambiguous launch failures.
When the auth gate fails, `54-launch-and-capture-evidence.sh` now captures Steam UI diagnostics by default (`AUTH_DEBUG_ON_FAILURE=1`), writing `steam-debug-*.log` and `steam-debug-*.png` into `output/`.
`54-launch-and-capture-evidence.sh` now also bootstraps the Steam/UI stack before auth checks (`AUTH_BOOTSTRAP_STEAM_STACK=1`) and will run `57-recover-steam-runtime.sh` if `steamwebhelper` is missing (`AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER=1`), reducing false unauthenticated failures caused by partial Steam startup.
`90-remote-dgx-stable-check.sh` now resolves a deterministic remote run directory and, by default, copies the remote `output/` evidence bundle back to local `output/remote-runs/<run-dir>/output` (`FETCH_EVIDENCE=0` disables copying).
Remote evidence fetch is performed even when remote verification fails, so strict-gate/transient runs still produce local artifacts.
`90-remote-dgx-stable-check.sh` can optionally run a staged gate when `STRICT_MIN_STABLE_SECONDS` is set: baseline success proves local run-path health; strict gate captures higher-stability confidence without conflating the two.
`90-remote-dgx-stable-check.sh` supports `DGX_PORT=<port>` for non-default SSH ports and `DGX_PORT_CANDIDATES=22,2222,...` to probe multiple ports automatically before failing; candidates are normalized/deduplicated before probing. It also accepts `DGX_ENDPOINT_CANDIDATES=host1:22,host2:2222,...` when you need explicit host+port pair ordering, and auto-discovers Tailscale IPv4 endpoints from the candidate host list by default (`DGX_DISCOVER_TAILSCALE_IPS=1`, disable with `0`). For routed access, use `DGX_SSH_PROXY_JUMP=user@jump-host` or `DGX_SSH_PROXY_COMMAND='ssh -W %h:%p jump-host'` (mutually exclusive), and optional `DGX_SSH_EXTRA_OPTS_CSV='IdentityFile=/path/key,UserKnownHostsFile=/dev/null'` for additional `ssh -o` options. When all targets are Tailscale-only and local `tailscaled` is unavailable, the script now fails fast by default (`DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE=1`, set `0` to force full SSH probing anyway).
For non-systemd/local-container runners, set `BOOTSTRAP_LOCAL_TAILSCALE=1` to start userspace `tailscaled` and auto-wire SSH through `nc -x <LOCAL_TAILSCALE_SOCKS5_ADDR> -X 5`; provide `LOCAL_TAILSCALE_AUTHKEY` for unattended login, or run `tailscale --socket <LOCAL_TAILSCALE_SOCKET> login` once interactively.
When strict retries are enabled, `STRICT_RECOVER_BETWEEN_ATTEMPTS=1` can rebuild Steam runtime state between retries to reduce contamination from prior transient launch attempts.
Default recovery-trigger exit codes are `2,3,4` (`no launch observed`, `transient launch`, and `launch seen but not stable in time window`); override with `RECOVER_ON_EXIT_CODES`.
When auth drift is expected, `AUTO_REAUTH_ON_AUTH_FAILURE=1` runs `58-ensure-steam-auth.sh` remotely before verification; for unattended recovery provide `STEAM_USERNAME`/`STEAM_PASSWORD` (login form) and optionally `STEAM_GUARD_CODE` (2FA).
`58-ensure-steam-auth.sh` also supports `AUTH_USE_STEAM_LOGIN_CLI=1` (default), which attempts `steam -login <user> <pass>` for headless cases where no visible login dialog is exposed.
`58-ensure-steam-auth.sh` now also attempts to restore/focus Steam windows by default (`AUTH_RESTORE_WINDOWS=1`), which helps when dialogs are present but headless-minimized.
During restore, auth recovery now also normalizes Steam window geometry by default (`AUTH_NORMALIZE_WINDOWS=1`, `AUTH_WINDOW_WIDTH=1600`, `AUTH_WINDOW_HEIGHT=900`, `AUTH_WINDOW_X=50`, `AUTH_WINDOW_Y=50`) so tiny/off-screen windows become visible for VNC/manual login.
Auth checks now require strong Steam session evidence by default (`steamid` via process/log); UI-only detection is treated as unauthenticated unless `ALLOW_UI_AUTH_FALLBACK=1` is explicitly set.
`90-remote-dgx-stable-check.sh` forwards `ALLOW_UI_AUTH_FALLBACK` and `FATAL_EXIT_CODES` to the remote runners, and also accepts trailing `KEY=VALUE` overrides for convenience (for example `./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1`).
`90-remote-dgx-stable-check.sh` can load an optional remote auth env file (`REMOTE_AUTH_ENV_FILE`, default `$HOME/.config/msfs-on-dgx-spark/steam-auth.env`) and will enforce `0600` permissions by default (`REQUIRE_REMOTE_AUTH_ENV_PERMS=1`) before sourcing it.
`90-remote-dgx-stable-check.sh` can also push a local auth env to DGX before execution (`PUSH_REMOTE_AUTH_ENV=1`, `LOCAL_AUTH_ENV_FILE=...`), with `0600` enforcement on both sides by default.
When `AUTO_REAUTH_ON_AUTH_FAILURE=1` is enabled and auth recovery fails, `90-remote-dgx-stable-check.sh` now captures `steam-debug-*.log/.png` before exit (`AUTH_DEBUG_ON_REAUTH_FAILURE=1` by default), ensuring remote auth failures still sync actionable evidence locally.
`FATAL_EXIT_CODES=''` is treated as an intentional empty list (fatal auth exits disabled), not auto-reset to defaults.
`54-launch-and-capture-evidence.sh` now retries dispatch inside a single attempt (`DISPATCH_MAX_ATTEMPTS`, default `2`) and can auto-run `57-recover-steam-runtime.sh` between redispatches (`DISPATCH_RECOVER_ON_NO_ACCEPT=1`) before launch verification begins; these dispatch knobs are forwarded by `90-remote-dgx-stable-check.sh`.
When dispatch still fails, fallback now runs as an ordered chain (`DISPATCH_FALLBACK_CHAIN`, default `applaunch,steam_uri,snap_uri`) and can auto-normalize Steam windows first (`DISPATCH_FORCE_UI_ON_FAILURE=1`) to recover from hidden/off-screen UI states before retrying launch methods.

See [docs/setup-guide.md](docs/setup-guide.md) for detailed instructions, and [docs/progress.md](docs/progress.md) for live validation notes.

## Project Status

| Phase | Status |
|-------|--------|
| Research & documentation | Done |
| Vulkan driver fix | Validated on DGX (580.95.05 Vulkan active) |
| FEX + Steam installation | Validated (Steam Snap on ARM64) |
| MSFS 2024 install | Done (`AppID 2537590`, manifest present, bytes fully downloaded) |
| MSFS launch dispatch | Done (Steam pipe dispatch + `StartSession` + running process tree observed) |
| First-frame stability | Reproducible (`09-verify-msfs-launch.sh` stable runtime window passed at `>=30s` on `DISPLAY=:2`, including remote clean-run validation via `90-remote-dgx-stable-check.sh`; long-session hardening still in progress) |
| MSFS 2020 parity path | Pending |
| Performance tuning (DLSS, MFG) | Not started |

## Repository Structure

```
.
├── README.md                  # This file
├── scripts/
│   ├── 01-fix-vulkan.sh       # Fix Vulkan driver on DGX Spark
│   ├── 02-install-fex-steam.sh # Install FEX-Emu and Steam
│   ├── 03-configure-msfs.sh   # Configure Proton for MSFS
│   ├── 04-setup-streaming.sh  # Set up Sunshine for remote play
│   ├── 05-resume-headless-msfs.sh # Resume headless Steam session + MSFS install/launch
│   ├── 06-verify-msfs-state.sh # Verify readiness/install state + capture Steam screen
│   ├── 07-await-login-and-install.sh # Wait for Steam auth and auto-queue MSFS install
│   ├── 08-finalize-auth-and-run-msfs.sh # One-shot auth/install/launch orchestrator
│   ├── 52-install-pvadverb-fex-wrapper.sh # Repair pressure-vessel host pv-adverb path on ARM
│   ├── 53-preflight-runtime-repair.sh # Repairs pv-adverb, Vulkan overrides, and MSFS package paths
│   ├── 54-launch-and-capture-evidence.sh # One-shot launch + verification + crash artifact collection
│   ├── 55-run-until-stable-runtime.sh # Repeat launch+verify cycles until stable runtime succeeds
│   ├── 56-run-staged-stability-check.sh # Baseline + strict staged stability gates
│   ├── 57-recover-steam-runtime.sh # Rebuild Steam runtime namespace between retries
│   ├── 58-ensure-steam-auth.sh # Ensure authenticated Steam session (optional credential + Steam Guard automation)
│   ├── 90-remote-dgx-stable-check.sh # Sync current checkout to DGX and run staged checks remotely
│   ├── 14-install-ge-proton.sh # Install latest GE-Proton into compatibilitytools.d
└── docs/
    ├── setup-guide.md         # Detailed setup walkthrough
    ├── progress.md            # Live validation status and blockers
    ├── research.md            # Full research notes
    └── troubleshooting.md     # Known issues and fixes
```
## Contributing

This is uncharted territory. If you have a DGX Spark and want to help, open an issue or PR. Particularly useful:

- Testing MSFS with different Proton versions
- Profiling performance bottlenecks (CPU translation vs GPU vs memory bandwidth)
- Arxan DRM compatibility findings
- Driver version comparisons

## License

MIT
