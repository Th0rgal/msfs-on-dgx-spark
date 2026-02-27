# Progress Log

## 2026-02-27

Validated on live DGX Spark host `spark-de79`:

- `scripts/01-fix-vulkan.sh`: Vulkan already active on NVIDIA driver `580.95.05`.
- `scripts/02-install-fex-steam.sh`: Steam Snap installed and launches on ARM64.
- `scripts/03-configure-msfs.sh`: created `~/launch-msfs.sh`.
- `scripts/04-setup-streaming.sh`: updated to install Sunshine from the official `.deb` release URL (Snap no longer available for this path).
- Headless stack is operational: `Xvfb :1`, `openbox`, `steam`, and `x11vnc` on `127.0.0.1:5901`.
- Re-verified live on 2026-02-27 01:16 UTC: Steam is reachable on `DISPLAY=:1` and currently blocked at Steam Guard code prompt for account login.

Current blocker for full end-to-end launch:

- Steam login requires a fresh Steam Guard email code for account authentication.
- Until Steam Guard is completed, MSFS `AppID 1250410` cannot be queued/installed, so launch verification remains pending.
- `~/.steam/steam/steamapps/appmanifest_1250410.acf` is still missing in the current account session (not installed yet).

Artifacts:

- `output/steam-root-latest.png` captures the live Steam Guard prompt.
- `output/steam-state-now3.png` captures the current Steam Guard prompt from the latest live session.

Next command after Steam Guard completion:

```bash
./scripts/05-resume-headless-msfs.sh install
```

Then after download completes:

```bash
./scripts/05-resume-headless-msfs.sh launch
```

Optional verification at any time:

```bash
./scripts/06-verify-msfs-state.sh
```

## 2026-02-27 (continued)

Additional live validation on `spark-de79` at `2026-02-27T01:57:10Z`:

- `scripts/06-verify-msfs-state.sh` confirms runtime services are healthy (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine active).
- Steam remains blocked at email Steam Guard prompt for account `her3sy`; no authenticated SteamID is present yet.
- MSFS install manifest remains absent (`appmanifest_1250410.acf`), confirming no queued install while unauthenticated.
- Added `scripts/07-await-login-and-install.sh` to automatically continue once Steam auth succeeds: waits for non-zero SteamID, triggers `steam://install/1250410`, and prints manifest-based progress.

## 2026-02-27 (02:37 UTC)

Latest live verification on `spark-de79`:

- `scripts/06-verify-msfs-state.sh` confirms runtime services active (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- Steam UI is still at Steam Guard email code prompt for `her3sy`.
- MSFS `1250410` manifest is still missing (install cannot start before authenticated Steam session).
- Added `scripts/08-finalize-auth-and-run-msfs.sh` to orchestrate final mile: optional Guard code entry, auth wait, install queue, and launch trigger.

Verification artifacts captured during this run:

- `/tmp/steam-state-1250410.png`
- `/tmp/verify-msfs-20260227T023730Z.log`

## 2026-02-27 (04:39 UTC)

Latest live retest on `spark-de79`:

- `scripts/06-verify-msfs-state.sh` confirms runtime remains healthy (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine active).
- `scripts/08-finalize-auth-and-run-msfs.sh` re-tested with `LOGIN_WAIT_SECONDS=60`; it times out waiting for authenticated Steam session.
- Steam is still unauthenticated (`steamid=0`) and waiting at Steam Guard prompt.
- MSFS `AppID 1250410` manifest remains missing, so install/launch cannot proceed before Steam Guard is completed.

Artifacts from this retest:

- `/tmp/steam-state-1250410.png`
- `/tmp/verify-msfs-20260227T0438Z.log`
- `/tmp/finalize-msfs-20260227T0438Z.log`

## 2026-02-27 (05:17 UTC)

Live re-validation on `spark-de79`:

- `scripts/06-verify-msfs-state.sh` still reports healthy runtime services (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- Steam is still unauthenticated (`steamid=0`) at Guard challenge, so authenticated install actions cannot proceed.
- MSFS `AppID 1250410` manifest is still missing.
- `compatibilitytools.vdf` is still absent in this unauthenticated state (expected before first successful login / compatibility selection).

Artifacts from this check:

- `/tmp/steam-state-now.png`
- `/tmp/finalize-msfs-<timestamp>.log`

## 2026-02-27 (05:57 UTC)

Live re-test on `spark-de79`:

- `scripts/06-verify-msfs-state.sh` confirms service health (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- `scripts/08-finalize-auth-and-run-msfs.sh` re-tested with `LOGIN_WAIT_SECONDS=120`; timed out waiting for authenticated Steam session.
- Steam remains unauthenticated (`steamid=0`) at Guard prompt.
- MSFS `AppID 1250410` manifest remains missing, so install/launch cannot start yet.

Artifacts from this re-test:

- `/tmp/steam-state-1250410.png`
- `/tmp/finalize-msfs-20260227T0557Z.log`
