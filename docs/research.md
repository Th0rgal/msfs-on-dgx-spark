# Research Notes

Full research findings on running Microsoft Flight Simulator on NVIDIA DGX hardware.

## Why Not the DGX Station A100?

The original plan targeted the DGX Station A100. Research revealed a fundamental hardware blocker:

**The NVIDIA A100 (GA100 die) has no 3D graphics engine.** This is a silicon-level limitation — the die was designed with the graphics pipeline removed to maximize space for tensor cores and compute units. No driver or software workaround can enable graphics rendering on hardware that doesn't exist.

| GPU | Architecture | 3D Engine | Vulkan Graphics | Gaming Viable |
|-----|-------------|-----------|-----------------|---------------|
| **A100** (GA100) | Ampere | **None** | Non-functional | No |
| **H100** (GH100) | Hopper | 2/50+ TPCs | Below iGPU | No |
| **V100** (GV100) | Volta | Reduced | Partial | Marginal |
| **GB10** (Blackwell) | Blackwell | **Full** | Vulkan 1.4 | **Yes** |
| **L40S** (AD102) | Ada Lovelace | Full | Vulkan 1.3 | Yes |
| **T4** (TU104) | Turing | Full | Vulkan 1.3 | Yes |

The H100 was benchmarked in 3DMark Time Spy and scored 2,681 — below the AMD Radeon 680M integrated GPU (2,710). NVIDIA's own GeForce NOW uses L40G GPUs, not A100s.

This led to pivoting to the **DGX Spark**, which uses the GB10 Blackwell Superchip with a full graphics pipeline.

## DGX Spark Hardware Findings

Gathered via SSH to the actual device:

- **CPU**: 20 cores — 10x Cortex-X925 (performance) + 10x Cortex-A725 (efficiency)
- **GPU**: NVIDIA GB10 Blackwell, reporting as "NVIDIA RTX" product brand
- **Memory**: 128 GB unified (shared CPU/GPU), ~119 GiB usable
- **Storage**: 3.7 TB NVMe, 1.8 TB free
- **OS**: Ubuntu 24.04.3 LTS, kernel 6.14.0-1015-nvidia (aarch64)
- **Driver**: NVIDIA 580.95.05, CUDA 13.0
- **Docker**: Available (v28.5.1)
- **Vulkan**: Libraries present (`libnvidia-gl-580`, `mesa-vulkan-drivers`, `libvulkan1`)
- **Snap**: Available

Not pre-installed: Box64, FEX-Emu, Steam, Wine, Flatpak, vulkaninfo.

The GPU reports a graphics clock of 2405 MHz (max 3003 MHz), confirming it has a functional graphics pipeline.

## x86-to-ARM Translation: FEX-Emu vs Box64

### FEX-Emu (recommended)

- Funded by Valve, integrated into SteamOS for ARM
- ~10-20% overhead (comparable to Apple Rosetta 2)
- **DLSS 4 + Multi-Frame Generation works** through Proton 10.x
- First-class Proton integration
- Canonical provides a Steam Snap bundling FEX for Ubuntu ARM64
- Cyberpunk 2077: **175+ FPS** at 1080p High, Ultra RT, DLSS 4 MFG on DGX Spark

### Box64

- Community-driven, broader architecture support (ARM64, RISC-V, LoongArch)
- ~80% native performance (DynaRec)
- **DLSS does NOT work** (NVIDIA DLSS libraries are x86-specific, can't be translated)
- Requires separate Box86 (32-bit) + Box64 (64-bit) or WoW64 mode
- Cyberpunk 2077: **~50 FPS** at 1080p Medium, no DLSS on DGX Spark

The 3.5x performance difference (50 vs 175+ FPS in Cyberpunk) is entirely attributable to DLSS 4 Multi-Frame Generation, which only works through FEX.

## MSFS Proton Compatibility

### MSFS 2020
- **ProtonDB rating: Gold**
- Works with Proton-GE and Proton Experimental
- Supports DX11 mode (translated by DXVK — more mature)
- Known issues: crash on intro videos (workaround: `-FastLaunch`), Wine C++ runtime errors
- Steam version only — Microsoft Store version does not work on Linux

### MSFS 2024
- Playable as of Proton 10.0-1 (April 2025)
- **DX12 only** (translated by VKD3D-Proton — less mature than DXVK)
- Shorter compatibility history, more risk on ARM

### DRM: Arxan Anti-Tamper
- MSFS uses Arxan Anti-Tamper DRM (not anti-cheat)
- Arxan performs integrity checks on executable code in memory
- Under x86→ARM translation, the code layout changes in memory
- This could trigger tamper detection — untested with MSFS on ARM
- Box64 v0.4.0 improved DRM compatibility; FEX handles this differently
- No anti-cheat system present (EasyAntiCheat, BattlEye, etc.)

## Alternative Approaches Considered and Rejected

### Windows VM with GPU Passthrough (VFIO) on DGX A100
- A100 registers as PCI class "3D controller" (0302), not "VGA compatible controller"
- Windows requires vGPU licensing for any graphics API on data center GPUs
- vGPU is not officially supported on DGX platforms
- NVLink mesh makes IOMMU isolation difficult
- Even if passthrough works, A100 has no 3D engine — DirectX won't function

### Wine/Proton Directly on DGX A100
- DXVK/VKD3D-Proton require functional Vulkan graphics queues
- A100's Vulkan support is compute-only — no graphics queue families
- Multiple failure reports on NVIDIA Developer Forums

### Looking Glass / VFIO on DGX Spark
- The DGX Spark has a single GPU — can't split between host and guest
- No IOMMU groups for passthrough
- Would eliminate direct GPU access for the host OS

## Key References

- [Fixing Vulkan on DGX Spark](https://gist.github.com/solatticus/14313d9629c4896abfdf57aaf421a07a)
- [DGX Spark Cyberpunk 2077 (175 FPS)](https://www.guru3d.com/story/nvidia-dgx-spark-achieves-175-fps-in-cyberpunk-2077-guide-enables-dlss-4-and-path-tracing/)
- [DGX Spark Cyberpunk 2077 (50 FPS, Box64)](https://www.tomshardware.com/video-games/pc-gaming/as-expected-nvidias-usd3-999-mini-ai-supercomputer-is-terrible-for-gaming)
- [Ubuntu ARM64 Steam Snap](https://www.omgubuntu.co.uk/2026/01/steam-snap-arm64-ubuntu-gaming-performance)
- [MSFS 2020 ProtonDB](https://www.protondb.com/app/1250410)
- [MSFS on Linux](https://flightsimonlinux.com/msfs)
- [H100 Gaming Benchmarks](https://www.tomshardware.com/news/nvidia-h100-benchmarkedin-games)
- [FEX-Emu GitHub](https://github.com/FEX-Emu/FEX)
- [VKD3D-Proton GitHub](https://github.com/HansKristian-Work/vkd3d-proton)
- [DXVK GitHub](https://github.com/doitsujin/dxvk)
