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
```
