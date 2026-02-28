# Troubleshooting

Common issues and solutions when running MSFS on the DGX Spark.

## Vulkan Issues

### vulkaninfo only shows llvmpipe

**Symptom**: `vulkaninfo --summary` shows only `llvmpipe` (software renderer), no NVIDIA GPU.

**Cause**: The `libnvidia-gl-580` package is not installed. This is a known bug in the shipped DGX Spark image.

**Fix**:
```bash
sudo apt-get update
sudo apt-get install libnvidia-gl-580
# Verify:
vulkaninfo --summary | grep NVIDIA
```

Reference: https://gist.github.com/solatticus/14313d9629c4896abfdf57aaf421a07a

### vkCreateInstance fails with ERROR_INCOMPATIBLE_DRIVER

**Cause**: Driver mismatch or Vulkan loader issue.

**Fix**:
```bash
# Reinstall the Vulkan loader and NVIDIA GL package
sudo apt-get install --reinstall libvulkan1 libnvidia-gl-580

# Check ICD files
ls /usr/share/vulkan/icd.d/
cat /usr/share/vulkan/icd.d/nvidia_icd.json

# If nvidia_icd.json is missing, reinstall the driver package
sudo apt-get install --reinstall libnvidia-gl-580
```

### Vulkan extensions missing

**Symptom**: VKD3D-Proton or DXVK reports missing Vulkan extensions.

**Check**:
```bash
vulkaninfo | grep -i "VK_KHR\|VK_NV\|VK_EXT" | sort
```

**Possible fix**: Update the driver if a newer version is available:
```bash
apt list --upgradable 2>/dev/null | grep nvidia
```

## Steam Issues

### Retry runner exits with code 7 (unauthenticated session)

**Symptom**: `scripts/55-run-until-stable-runtime.sh` or `scripts/90-remote-dgx-stable-check.sh` exits quickly with:
- `RESULT: Steam session unauthenticated; launch skipped.`
- `RESULT: non-retryable failure encountered (exit code 7)`

**Cause**: Steam logged out (for example after runtime recovery/restart), so launch dispatch cannot be accepted.

`54-launch-and-capture-evidence.sh` now captures auth-debug artifacts by default on this failure path:
- `output/steam-debug-<timestamp>.log` (window/process snapshot)
- `output/steam-debug-<timestamp>.png` (root screenshot, when ImageMagick `import` is available)

**Fix**:
```bash
# Verify Steam auth/session state
./scripts/06-verify-msfs-state.sh

# Re-authenticate and relaunch the headless session (enter Steam Guard if prompted)
./scripts/05-resume-headless-msfs.sh launch

# Re-run proof check
MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=2 ./scripts/55-run-until-stable-runtime.sh
```

Remote helper equivalents:
```bash
# Run remote check and fail-fast on unauthenticated sessions (default)
DGX_PASS='<password>' ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1

# Unattended remote re-auth (credential form + optional Steam Guard), then verify launch stability
DGX_PASS='<password>' AUTO_REAUTH_ON_AUTH_FAILURE=1 STEAM_USERNAME='<steam_user>' STEAM_PASSWORD='<steam_pass>' STEAM_GUARD_CODE='<code>' REAUTH_LOGIN_WAIT_SECONDS=180 ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1

# Headless fallback: force CLI credential login when no visible login dialog appears
DGX_PASS='<password>' AUTO_REAUTH_ON_AUTH_FAILURE=1 STEAM_USERNAME='<steam_user>' STEAM_PASSWORD='<steam_pass>' AUTH_USE_STEAM_LOGIN_CLI=1 ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1

# Keep credentials only on DGX in a 600-permission env file and auto-load it during remote runs
# (run once on DGX)
mkdir -p ~/.config/msfs-on-dgx-spark
cat > ~/.config/msfs-on-dgx-spark/steam-auth.env <<'EOF'
AUTO_REAUTH_ON_AUTH_FAILURE=1
STEAM_USERNAME='your_user'
STEAM_PASSWORD='your_pass'
EOF
chmod 600 ~/.config/msfs-on-dgx-spark/steam-auth.env
DGX_PASS='<password>' ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1

# Temporarily allow UI-only auth signal during interactive recovery windows
DGX_PASS='<password>' ALLOW_UI_AUTH_FALLBACK=1 FATAL_EXIT_CODES='' ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1

# If direct DGX SSH is unreachable from this runner, route via bastion/jump host
DGX_PASS='<password>' DGX_SSH_PROXY_JUMP='user@jump-host' ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1

# Alternative proxy command mode (custom transport)
DGX_PASS='<password>' DGX_SSH_PROXY_COMMAND='ssh -W %h:%p jump-host' ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1
```

By default, `90-remote-dgx-stable-check.sh` now exits early when all DGX candidates resolve to Tailscale endpoints and local `tailscaled` is unavailable (`DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE=1`). Set `DGX_FAST_FAIL_ON_UNREACHABLE_TAILSCALE=0` only when you intentionally want full SSH timeout probing.

If auth recovery times out and debug logs show no visible Steam/login windows, `58-ensure-steam-auth.sh` now reports that condition explicitly; use `AUTH_USE_STEAM_LOGIN_CLI=1` (default) with credentials to avoid depending on visible UI prompts.
It also attempts Steam window restore/focus by default (`AUTH_RESTORE_WINDOWS=1`) so headless-minimized dialogs can be surfaced automatically.
Window geometry normalization is also enabled during restore (`AUTH_NORMALIZE_WINDOWS=1`), resizing/moving tiny or off-screen Steam windows to a visible region by default.
`90-remote-dgx-stable-check.sh` now supports remote credential sourcing via `REMOTE_AUTH_ENV_FILE` (default `$HOME/.config/msfs-on-dgx-spark/steam-auth.env`) with permission check (`REQUIRE_REMOTE_AUTH_ENV_PERMS=1` expects mode `600`).
If unauthenticated failures occur with no active `steamwebhelper`, keep `AUTH_BOOTSTRAP_STEAM_STACK=1` and `AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER=1` (defaults) so verification first restarts the Steam/UI stack and repairs runtime roots before deciding auth is missing.

### Dispatch not accepted (`exit 4`) after auth succeeds

**Symptom**: dispatch logs report `RESULT: no launch session accepted via pipe in this attempt.`

**Fix**:
```bash
# Normalize Steam UI, then run multiple fallback dispatch methods in order
DISPATCH_FORCE_UI_ON_FAILURE=1 \
DISPATCH_FALLBACK_CHAIN='applaunch,steam_uri,snap_uri' \
./scripts/54-launch-and-capture-evidence.sh

# Same knobs can be forwarded through remote DGX orchestration
DGX_PASS='<password>' DISPATCH_FORCE_UI_ON_FAILURE=1 \
DISPATCH_FALLBACK_CHAIN='applaunch,steam_uri,snap_uri' \
./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1
```

### Steam crashes on launch

**Symptom**: Steam exits immediately or shows a blank window.

**Fixes**:
```bash
# Clear Steam's web cache
rm -rf ~/.local/share/Steam/config/htmlcache

# If using FEX, ensure binfmt is registered
ls /proc/sys/fs/binfmt_misc/FEX*

# If using the Snap version
snap refresh steam --edge
```

### Steam doesn't detect the GPU

**Symptom**: Steam's system info shows no GPU or shows llvmpipe.

**Fix**: Same as the Vulkan llvmpipe issue above. Steam relies on Vulkan being properly configured.

## MSFS Issues

### Crash on startup (before menus)

**Possible causes and fixes**:

1. **Intro video crash** — Add `-FastLaunch` to launch options
2. **Arxan DRM triggering** — This may be a hard blocker on ARM. Check Proton logs:
   ```bash
   PROTON_LOG=1 %command% -FastLaunch 2>&1 | tee ~/msfs-proton.log
   ```
3. **Wrong Proton version** — Try Proton Experimental (Bleeding Edge) or Proton-GE
4. **Missing Visual C++ runtime** — Proton usually handles this, but try:
   ```bash
   protontricks 1250410 vcrun2019
   ```

### Crash after Microsoft Account login

**Symptom**: Game launches, shows login page, then crashes after authentication.

**Possible causes**:
- The WebView2-based login window may not work through the translation stack
- Check if the crash is in the Wine C++ runtime (known issue, Proton GitHub #7845)

**Workarounds**:
- Try logging in via Xbox app first (if installable through Proton)
- Use a different Proton version
- Check `~/.local/share/Steam/steamapps/compatdata/1250410/pfx/drive_c/users/steamuser/AppData/Local/` for crash logs

### Black screen after loading

**Symptom**: Game loads but displays a black screen.

**Fixes**:
```bash
# Force windowed mode
%command% -FastLaunch -Windowed

# Disable fullscreen optimizations
WINE_FULLSCREEN_FSR=0 %command% -FastLaunch
```

### Extremely low FPS (< 5)

**Possible causes**:

1. **Rendering on llvmpipe instead of GPU** — Check DXVK HUD overlay. If it says "llvmpipe", fix Vulkan drivers.
2. **DLSS not available** — Without DLSS/MFG, expect lower FPS. Check if DLSS shows in MSFS graphics settings.
3. **CPU bottleneck** — MSFS is CPU-intensive. The x86→ARM translation overhead compounds this.
   ```bash
   # Check CPU usage
   htop
   # Set performance governor
   sudo cpupower frequency-set -g performance
   ```
4. **Shader compilation** — First launch compiles shaders, causing heavy stuttering. Give it time.

### Content download stuck

**Symptom**: MSFS downloads additional content (scenery, world data) but gets stuck.

**Fixes**:
- MSFS downloads over 100 GB of content on first launch — this is normal
- Check network connectivity
- If download stalls, delete the content cache and restart:
  ```bash
  # Location varies but typically:
  rm -rf ~/.local/share/Steam/steamapps/compatdata/1250410/pfx/drive_c/users/steamuser/AppData/Local/Packages/Microsoft.FlightSimulator*
  ```

## FEX-Emu Issues

### FEX crashes with SIGILL

**Symptom**: Illegal instruction signal when running x86-64 binaries.

**Fix**: Ensure FEX is built for the correct ARM architecture. The DGX Spark uses Cortex-X925/A725 cores.

### Poor performance through FEX

**Check**: Verify FEX is using DynaRec (JIT) not interpreter mode:
```bash
# FEX should show JIT compilation messages in verbose mode
FEX_VERBOSE=1 FEXBash -c "echo test"
```

### DLSS not available in games

**Symptom**: Game doesn't show DLSS options despite using FEX + Proton 10.x.

**Requirements for DLSS through FEX**:
- Proton 10.0-2 (beta) or later
- DXVK-NVAPI must be enabled (Proton 10.x enables it by default)
- The game must detect the GPU as an RTX-class card

**Debug**:
```bash
# Check if NVAPI is loaded
DXVK_LOG_LEVEL=info %command% 2>&1 | grep -i nvapi
```

## General Debugging

### Enable verbose logging

```bash
# Proton log (captures Wine, DXVK, VKD3D-Proton output)
PROTON_LOG=1 %command% -FastLaunch 2>&1 | tee ~/msfs-proton.log

# DXVK debug log
DXVK_LOG_LEVEL=info %command% -FastLaunch 2>&1 | tee ~/msfs-dxvk.log

# VKD3D-Proton debug log (for DX12 / MSFS 2024)
VKD3D_DEBUG=warn %command% -FastLaunch 2>&1 | tee ~/msfs-vkd3d.log

# FEX debug log
FEX_VERBOSE=1 %command% -FastLaunch 2>&1 | tee ~/msfs-fex.log
```

### Check GPU state

```bash
nvidia-smi                           # GPU utilization and memory
nvidia-smi -q | grep -i "compute\|graphics\|video"  # GPU mode
vulkaninfo --summary                 # Vulkan device info
```

### Report issues

When filing an issue on this repo, include:
1. Output of `nvidia-smi`
2. Output of `vulkaninfo --summary`
3. The Proton log from the crash
4. DGX OS version (`cat /etc/os-release`)
5. Driver version (`nvidia-smi --query-gpu=driver_version --format=csv,noheader`)
6. FEX version (`FEXInterpreter --version`)
