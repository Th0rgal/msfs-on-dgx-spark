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

## 2026-02-27 (06:37 UTC)

Live retest on `spark-de79`:

- SSH/device access and headless stack still healthy (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine active).
- `scripts/08-finalize-auth-and-run-msfs.sh` re-run with `LOGIN_WAIT_SECONDS=45`; timed out waiting for authenticated Steam session.
- Steam UI remains on email Steam Guard challenge for account `her3sy` (unauthenticated `steamid=0`).
- MSFS `AppID 1250410` manifest is still missing; install/launch cannot proceed until Steam Guard is completed.

Artifacts from this run:

- `/tmp/steam-state-20260227T063725Z.png`
- `/tmp/finalize-msfs-20260227T063725Z.log`
- `/tmp/verify-msfs-20260227T063725Z.log`

## 2026-02-27 (07:21 UTC)

Live re-test on `spark-de79` with additional launch verification:

- Runtime stack remains healthy (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- Steam remains unauthenticated (`steamid=0`) at Steam Guard, so MSFS `1250410` is still not installable in this session.
- Added `scripts/09-verify-msfs-launch.sh` to explicitly detect candidate launch processes after launch trigger.
- Updated `scripts/08-finalize-auth-and-run-msfs.sh` to invoke launch verification as step `[6/6]`.
- Re-ran finalize flow (`LOGIN_WAIT_SECONDS=45`): timed out waiting for Steam auth as expected.

Artifacts from this run:

- `/tmp/steam-state-20260227T0719Z.png`
- `/tmp/finalize-msfs-20260227T0719Z.log`
- `/tmp/verify-msfs-20260227T0719Z.log`
- `/tmp/verify-launch-20260227T0720Z.log`

## 2026-02-27 (07:57 UTC)

Live retest on `spark-de79`:

- SSH connectivity is healthy and runtime stack remains up (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- `scripts/06-verify-msfs-state.sh` confirms `steamid=0` state and missing MSFS manifest (`appmanifest_1250410.acf`).
- `scripts/08-finalize-auth-and-run-msfs.sh` re-run (`LOGIN_WAIT_SECONDS=120`, `POLL_SECONDS=10`) and continues waiting for authenticated Steam session.
- Fresh UI screenshot confirms Steam is blocked at 5-character email Steam Guard prompt for account `her3sy`.

Artifacts from this run:

- `/tmp/steam-state-1250410.png`
- `output/verify-20260227T075730Z.log`
- `output/finalize-20260227T075730Z.log`

## 2026-02-27 (08:57 UTC)

License-path validation for user request (Xbox sign-in without Steam purchase):

- Reconnected to `spark-de79` and confirmed Steam UI session is reachable in headless desktop.
- Triggered direct install attempts for `AppID 1250410` from the current Steam session (`steam://install/1250410` and finalize script path).
- No `appmanifest_1250410.acf` was created after install triggers; install did not queue.
- This project path targets the Steam build under Proton/FEX. Xbox/Microsoft sign-in is an in-game identity step, not a package entitlement source for Steam.
- Therefore, local install/launch on this Linux DGX path requires Steam entitlement for `1250410` on the logged-in Steam account.

Conclusion:

- Goal remains blocked for the requested "Xbox login only, no Steam purchase" path.
- To proceed locally on DGX, use a Steam account that already owns MSFS 2020 (or purchase on Steam), then complete first launch and sign into Xbox inside MSFS.

## 2026-02-27 (09:10 UTC)

Live progress after Steam Guard completion on `spark-de79`:

- Steam account `her3sy` is now authenticated and stable in Library view (persona `Thomas`).
- Updated automation/auth logic to avoid false negatives when `steamwebhelper` reports `-steamid=0` despite authenticated UI:
  - `scripts/07-await-login-and-install.sh`
  - `scripts/08-finalize-auth-and-run-msfs.sh`
  - `scripts/06-verify-msfs-state.sh`
- Verifier now reports `Steam auth: authenticated (ui-detected)` and accepts `x11vnc` on `5900` or `5901`.
- `AppID 1250410` still does not auto-create an install manifest when triggered via URI in this session.
- Library UI now clearly shows **Microsoft Flight Simulator 2024** with an Install flow (install dialog opened successfully). This indicates Steam entitlement exists for 2024 on this account.

Current blocker to final "running" proof:

- Install confirmation/download for the selected MSFS title has not yet been driven to an active manifest/download state in this unattended run.
- Therefore, end-to-end launch verification is still pending.

Artifacts from this run:

- `output/steam-after-login-attempt-20260227T085252Z.png` (authenticated Steam UI)
- `output/finalize-20260227T085915Z.log` (auth success + 1250410 manifest timeout)
- `output/verify-20260227T090458Z.log` (updated verifier output)
- `output/steam-state-20260227T090458Z.png` (Library with MSFS 2024 visible)
- `output/steam-msfs2024-after-install-click-20260227T090739Z.png` (MSFS 2024 install dialog)

## 2026-02-27 (MSFS 2024 entitlement pass)

- Switched automation defaults to **MSFS 2024 AppID `2537590`** in runtime scripts:
  - `scripts/05-resume-headless-msfs.sh`
  - `scripts/09-verify-msfs-launch.sh`
- Regenerated launcher guidance via `scripts/03-configure-msfs.sh` and updated next-step text for 2024 launch options.
- Verified Steam account session is online (`connection_log.txt` shows successful logon for `U:1:391443739`).
- Reproduced install flow in UI with rich captures:
  - Install dialog appears for **Microsoft Flight Simulator 2024** and accepts click on **Install**.
  - After dialog closes, Steam returns to game page still showing **INSTALL** and no manifest is created.
- Current hard blocker: `~/snap/steam/common/.local/share/Steam/steamapps/appmanifest_2537590.acf` is still missing, so download/launch cannot proceed.

## 2026-02-27 (09:52 UTC)

Retest and automation hardening for MSFS 2024 (`2537590`) on `spark-de79`:

- Confirmed Steam is authenticated and MSFS 2024 is present in Library under account persona `Thomas`.
- Added `scripts/10-enable-steam-play.sh` to enforce Proton mappings in `config/compatibilitytools.vdf` for:
  - default (`0`)
  - `1250410`
  - `2537590`
- Updated `scripts/08-finalize-auth-and-run-msfs.sh`:
  - new explicit compatibility step (`[4/7]`) calling `10-enable-steam-play.sh`
  - fixed launch argument selection so `MSFS_APPID=2537590` uses `~/launch-msfs.sh 2024` (not `2020`)
  - step numbering adjusted to `[1/7]..[7/7]`
- Re-ran full finalize flow (`MSFS_APPID=2537590 LOGIN_WAIT_SECONDS=30 POLL_SECONDS=10`).
  - Steam auth check succeeded (`authenticated: ui-detected`).
  - Manifest wait still timed out after 300s.

Current blocker remains unchanged:

- `~/snap/steam/common/.local/share/Steam/steamapps/appmanifest_2537590.acf` is still not being created in unattended mode, so download queue and launch verification cannot complete yet.
- Steam UI still appears to require a manual in-client install confirmation path that automation is not reliably triggering in this headless session.

## 2026-02-27 (later pass, MSFS 2024)

Validated again on `spark-de79` after successful Steam account login:

- Steam is authenticated (`steamid=76561198351709467`) and headless services remain healthy (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- Confirmed `Microsoft Flight Simulator 2024` appears in the Steam Library (`AppID 2537590`) and can be selected in UI.
- Repeated install attempts were executed through:
  - Steam URI flow (`steam://install/2537590`) from scripts.
  - Direct UI clicks in Steam (headless + VNC control path).
  - Keyboard-triggered install attempts from the selected library row.

Current hard blocker:

- Steam still does not create `steamapps/appmanifest_2537590.acf` after install attempts.
- Because manifest creation never starts, no download queue is created and first-launch verification cannot proceed.

Latest artifacts (workspace):

- `output/vnc-msfs-row-attempt3.png` (MSFS 2024 selected in Library with INSTALL button visible)
- `output/vnc-msfs-install-click-successpath.png` (post-click state still not queued)
- `output/vnc-msfs-enter-from-list.png` (selected-row keyboard attempt)

Artifacts from this pass:

- `/tmp/finalize-msfs-retest.log`
- `/tmp/msfs-enable-steamplay.log`
- `/tmp/steam-after-finalize-retest.png`

## 2026-02-27 (11:30 UTC)

Deep-dive retry on `spark-de79` for MSFS 2024 (`AppID 2537590`):

- Steam was previously authenticated (`steamid=76561198351709467`) and MSFS 2024 page showed `INSTALL`.
- Repeated install triggers were attempted from both URI and UI paths:
  - `steam://install/2537590`
  - direct library tile/navigation clicks in headless X11 session
  - install button click/confirm retries on the MSFS 2024 details page
- No install manifest was created (`appmanifest_2537590.acf` remained absent), and control test app install URI also did not create a manifest.
- During repeated UI automation, Steam WebUI entered a broken renderer state:
  - main client shows a black content area with `data:text/html,...` in the URL row
  - this state persists across Steam process restarts and htmlcache reset
- After forced process recycle, current Steam client instance is now unauthenticated (`steamid=0`), so install flow is blocked again at auth level.

Current hard blocker:

- Steam WebUI instability in this headless Snap/FEX session (black page + `data:text/html`) prevents reliable install action dispatch.
- Session auth was lost during recovery; Steam must be re-authenticated before any further install attempts.
- End-to-end MSFS launch proof is still pending.

## 2026-02-27 (12:30 UTC)

Latest live recheck on `spark-de79` while continuing MSFS 2024 (`2537590`) install automation:

- Reconnected and confirmed headless stack remains up (`Xvfb :1`, `openbox`, Steam, `x11vnc`, Sunshine).
- Steam briefly showed authenticated Store session (`THOMAS` persona visible), but install URI and scripted UI actions still did not create `appmanifest_2537590.acf`.
- Attempted fallback to non-Snap Steam client (`steam-installer`) is not available on this ARM64 Ubuntu target (`no installation candidate`), so Snap+FEX remains the active/only client path.
- During cleanup/restart attempts, Steam authentication state regressed back to unauthenticated (`steamid=0`), so install/launch cannot proceed in this pass.
- Added diagnostic helper `scripts/11-debug-steam-window-state.sh` to capture:
  - parsed SteamIDs from `steamwebhelper`
  - visible X11 window inventory (IDs, geometry, names)
  - Steam/FEX process snapshot
  - root-window screenshot

Current blocker:

- Steam session must be re-authenticated and kept stable long enough to queue `2537590` into Downloads (`appmanifest_2537590.acf` creation is the gating signal).

Immediate next command after re-authentication:

```bash
cd ~/msfs-on-dgx-spark
MSFS_APPID=2537590 ./scripts/08-finalize-auth-and-run-msfs.sh
```

## 2026-02-27 (13:10 UTC)

Fresh live pass on `spark-de79` with direct UI manipulation and verifier re-run:

- Steam client is visible and logged in as `THOMAS`; headless stack is healthy (`Xvfb :1`, `openbox`, `steamwebhelper`, `x11vnc`, Sunshine).
- Cleared modal overlays (age-gate/news popups) and reached Library view where `Microsoft Flight Simulator 2024` is visible in the games list/recent shelf.
- Multiple install dispatch attempts were executed (row open/double-click, details-pane install region, install confirm region).
- Verifier still reports no MSFS install queue because `appmanifest_2537590.acf` is absent.

Observed behavior in this pass:

- Steam UI navigation is stateful and frequently diverted by modal overlays/pages (age-gate/store/news), causing install clicks to be intercepted or redirected.
- `steam://install/2537590` and repeated UI-trigger attempts still did not materialize the app manifest.

Artifacts:

- `/tmp/steam-state-2537590.png`
- `output/verify-msfs-2537590-20260227T131053Z.log`
- `output/steam-msfs-details-opened.png`
- `output/steam-msfs-details-after-close-overlay.png`
- `output/steam-geom-install-click.png`

Current blocker remains unchanged:

- `~/snap/steam/common/.local/share/Steam/steamapps/appmanifest_2537590.acf` is still missing, so download/launch cannot be validated end-to-end yet.

## 2026-02-27 (14:10 UTC)

Focused install deep-dive on `spark-de79` for MSFS 2024 (`AppID 2537590`) uncovered the next concrete gate after prior install-click failures:

- Reached stable Library view and reliably selected `Microsoft Flight Simulator 2024` from the left game list.
- Triggered install dialog consistently from the MSFS details page.
- Confirmed installer modal fields are present (`Install`, install location row, desktop/application shortcut toggles).
- Advanced one step further to a new modal gate: **MSFS EULA acceptance** dialog appears with `Accept`/`Cancel`.

Current blocker has shifted:

- Install queue is now blocked at the in-client EULA modal interaction. In this headless automation path, repeated synthetic click/keyboard attempts did not successfully dismiss the EULA dialog.
- As a result, `appmanifest_2537590.acf` is still not created yet and download does not start.

Artifacts from this pass:

- `output/msfs-2024-selected-20260227T134926Z.png` (MSFS 2024 selected in Library)
- `output/msfs-2024-install-dialog-20260227T135011Z.png` (install dialog reached)
- `output/msfs-2024-eula-modal-20260227T135950Z.png` (EULA gate reached)
- `output/msfs-2024-eula-scrolled-20260227T140601Z.png` (EULA modal still active after scroll/accept attempts)

Next unblock:

1. Manually click `Accept` in the MSFS EULA modal once via the live Steam UI session.
2. Immediately rerun:

```bash
cd ~/msfs-on-dgx-spark
MSFS_APPID=2537590 ./scripts/08-finalize-auth-and-run-msfs.sh
```

After EULA acceptance, manifest/download/launch verification should proceed in the existing flow.

## 2026-02-27 (14:35 UTC)

Post-EULA/install retest on `spark-de79` for MSFS 2024 (`AppID 2537590`):

- `scripts/08-finalize-auth-and-run-msfs.sh` now reaches manifest and reports full install completion:
  - `appmanifest_2537590.acf` present
  - `StateFlags=4`
  - `BytesDownloaded=7261863936` / `BytesToDownload=7261863936` (100%)
- Steam launch action is accepted and game process chain starts, but exits after ~50 seconds.
- Crash artifacts in prefix confirm early boot crash before playable state/Xbox sign-in:
  - `AsoboReport-Crash.txt` shows `Type="SEH" Code=0xC0000005`
  - crash context remains in `MainState:BOOT SubState:BOOT_INIT`

Current state:

- Install problem is resolved.
- Remaining blocker is runtime stability under current Snap Steam + FEX + Proton Experimental stack on DGX ARM; game exits during boot before handoff point.

Artifacts from this pass:

- `output/finalize-msfs-20260227T142909Z.log`
- `output/verify-msfs-20260227T143142Z.log`
- `/tmp/msfs-launch-state-2537590.png`
- `.../compatdata/2537590/.../Microsoft Flight Simulator 2024/AsoboReport-Crash.txt`
## 2026-02-27 (15:30 UTC, crash triage + launch-dispatch retest)

Live retest on `spark-de79` focused on root-cause isolation after the first real MSFS 2024 run/crash:

- Confirmed install is complete and owned:
  - `steamapps/appmanifest_2537590.acf` present with `StateFlags=4` and full depot bytes downloaded/staged.
- Confirmed historical launch actually happened from Steam client path (from `logs/console_log.txt`):
  - `GameAction [AppID 2537590]` advanced through `ProcessingInstallScript`, `CreatingProcess`, and process add/remove.
  - Steam launched via Proton chain:
    - `...SteamLinuxRuntime_sniper/_v2-entry-point --verb=waitforexitandrun -- 'Proton - Experimental'/proton waitforexitandrun .../MSFS2024/FlightSimulator2024.exe`
- Confirmed crash artifact remains the same early boot failure:
  - `AsoboReport-Crash.txt` unchanged, `SEH 0xC0000005`, state `BOOT::BOOT_INIT`, `EnableD3D12=true`.

New fixes attempted in this pass (all executed live on DGX):

1. `-dx11` launch attempts from command line (`steam -applaunch` / `steam://rungameid`) with Proton debug env.
2. Direct Proton invocation and direct `steam-launch-wrapper` invocation to bypass Steam UI dispatch.
3. Steam restart from clean process state (standard mode) followed by post-login launch URI retrigger.
4. UI-driving attempts with `xdotool` against Store->Library->MSFS path.

Observed results:

- CLI/URI launch dispatch did not create a fresh game process in this session.
- Direct invocation attempts hit architecture/runtime boundary when bypassing Steam launch path:
  - `Exec format error` for x86 wrapper/proton binaries when not run through Steam's FEX-managed chain.
- `xdotool` interaction remains unreliable against current Steam web UI surface in this headless setup (window IDs resolve to tiny helper windows; absolute clicks showed no UI state change).
- No new MSFS crash/session artifacts were generated in this pass; last true crash remains the 14:27 UTC record.

Current most likely next fix not yet validated end-to-end:

- Run one fresh in-client launch with explicit safe profile in Steam UI:
  - force non-Experimental Proton variant (e.g. `proton_10`/`proton_hotfix` or GE-Proton), and
  - force DX11 launch option.
- Then capture new Asobo/Proton artifacts to confirm whether boot passes `BOOT_INIT`.

## 2026-02-27 (15:46 UTC, safe launch profile + dispatch-path isolation)

Continued live triage on `spark-de79` with a focus on isolating whether the current blocker is runtime-crash or launch-dispatch:

- Added automation to set per-title launch options in Steam config:
  - `scripts/12-set-msfs-launch-options.sh`
  - Applied on DGX for `2537590`:
    - `PROTON_LOG=1 PROTON_USE_WINED3D=1 PROTON_NO_ESYNC=1 PROTON_NO_FSYNC=1 %command% -dx11 -FastLaunch`
- Added automation to verify whether Steam accepted a launch request by tracking `GameAction` deltas:
  - `scripts/13-debug-launch-dispatch.sh`
  - Ran both `uri` and `applaunch` modes live.

Observed results:

1. Launch options are now definitely written in `sharedconfig.vdf` for AppID `2537590`.
2. Both launch-dispatch paths still fail to enqueue a new launch in the current client state:
   - `steam://rungameid/2537590` -> no new `GameAction [AppID 2537590]` lines
   - `steam -applaunch 2537590` -> no new `GameAction [AppID 2537590]` lines
3. Existing crash file timestamp remained unchanged (last real game run still at `2026-02-27 14:27:42Z`), confirming no new runtime attempt was produced in this pass.
4. Attempting a fully direct FEX wrapper launch outside Steam dispatch failed earlier in container setup:
   - `steam-launch-wrapper: $XDG_RUNTIME_DIR not set`
   - `pressure-vessel-wrap ... bwrap: setting up uid map: Permission denied`
   - This means direct wrapper invocation is not a valid replacement for Steam-managed launch on this host.

Conclusion from this pass:

- Current top blocker has shifted to Steam client launch-dispatch acceptance in this headless session.
- Runtime crash (`BOOT_INIT` / `SEH 0xC0000005`) remains the last confirmed launch outcome, but we cannot test new runtime knobs until dispatch is accepted again.

Artifacts from this pass:

- `output/launch-dispatch-debug-20260227T1546Z.log`
- `output/msfs-direct-fex-20260227T1540Z.log`
- `output/steam-console-tail-20260227T1540Z.log`
- `output/steam-state-20260227T1540Z.png`

## 2026-02-27 (16:00 UTC, GE-Proton install + tool mapping test)

Continued runtime-fix iteration on `spark-de79` after manual Play crash reports:

- Confirmed fresh manual Play attempts at `15:49:46` and `15:49:55` did reach Steam launch tasks, but both exited in ~2 seconds (`Game process removed`), with no new Asobo crash artifact timestamps.
- Reverted aggressive launch options (`wined3d`, `-dx11`) and switched to log-focused launch options to avoid masking the original boot path.
- Installed latest GE-Proton from upstream GitHub release:
  - `GE-Proton10-32` extracted under `.../Steam/compatibilitytools.d/GE-Proton10-32`.
- Updated Steam compatibility mapping to target GE-Proton for default, `1250410`, and `2537590`.
- Restarted Steam and validated GE tool registration in `compat_log.txt`:
  - `Registering tool GE-Proton10-32`
  - `Command prefix for tool 0 "GE-Proton10-32" .../compatibilitytools.d/GE-Proton10-32/proton`

Current blocker in this pass:

- Steam session restarted into unauthenticated state (`steamid=0` in `steamwebhelper` args), so new launch attempts are not being accepted (`GameAction` count unchanged).
- Because no fresh launch occurred after GE mapping, runtime effect of GE-Proton on MSFS boot is still pending validation.

Artifacts from this pass:

- `output/steam-after-resume-ge.png`
- `output/ge-step1-library.png`
- `output/ge-step2-selected.png`
- `output/ge-step3-after-play.png`

## 2026-02-27 (16:10 UTC)

Additional recovery/fix cycle on `spark-de79` after manual Play crash reports:

What was tried:

- Forced app compatibility override to `GE-Proton10-32` for `2537590` by writing `config/compatibilitytools.vdf` via:
  - `PROTON_TOOL=GE-Proton10-32 ./scripts/10-enable-steam-play.sh`
- Performed controlled Steam restarts and re-ran launch dispatch via:
  - `steam://rungameid/2537590`
  - `steam -applaunch 2537590`
- Tried Steam UI recovery paths:
  - legacy `-vgui` startup (`steam -vgui -nochatui -nofriendsui`)
  - `dbus-run-session` wrapper startup for Steam client initialization
  - Openbox desktop/window re-home checks with `xdotool`

Verified findings:

- MSFS 2024 remains fully installed (`appmanifest_2537590.acf`, BuildID `21117911`, download 100%).
- GE-Proton tool is registered and command prefix exists in `compat_log.txt`.
- However, current Steam session is unauthenticated (`steamwebhelper ... -steamid=0`) after restart cycles, and no fresh `GameAction`/`StartSession` entries for `2537590` are generated in this state.
- Client UI is degraded in headless mode (tiny helper windows / unusable surface), so automated dispatch does not reach an actual game launch path.

Current blocker:

- Not a content/install issue anymore; launch is blocked by Steam session/auth/UI integrity in this headless client state.
- Need one stable authenticated Steam UI session (`steamid != 0`) before runtime crash-fix iteration can continue meaningfully.

Artifacts:

- `output/verify-msfs-20260227T160506Z.log`
- `output/compatibilitytools-20260227T160434Z.vdf`
- `output/steam-state-after-restart-20260227T160506Z.png`
- `output/steam-desktop3-20260227T160739Z.png`
- `output/steam-desktop0-20260227T160739Z.png`
- `output/steam-after-ge3-20260227T160726Z.png`
- `output/steam-vgui-recover-20260227T160821Z.log`
- `output/steam-dbus-20260227T160908Z.log`

## 2026-02-27 (16:45 UTC) additional runtime-fix cycle

New hypotheses tested and results on `spark-de79`:

- Confirmed the game install is intact (`appmanifest_2537590.acf` present, game files in `steamapps/common/MSFS2024`).
- Identified a UI-state blocker: Steam repeatedly lands on a Store age-gate page (`app/3764200`), and `steam://rungameid/2537590` dispatches create no fresh `App Running` event in this trapped state.
- Removed stale launcher blocker (`fex_launcher.sh steam://install/2537590`), but launch URI dispatch still did not produce a new run event.
- Applied an untried clean runtime path:
  - switched compatibility mapping to `proton_10` via `scripts/10-enable-steam-play.sh`
  - reset prefix by moving `compatdata/2537590` to backup (`2537590.bak.20260227T163452Z`)
  - restarted Steam and reattempted launch drive
- Observed that native `proton_10` binary is not actually installed under `steamapps/common` on this host (only `Proton - Experimental` and `GE-Proton10-32`).
- Tried direct GE-Proton invocation (bypassing Steam UI) with full compat env; this fails on ARM with:
  - `pressure-vessel-wrap: Exec format error`
  - confirms direct proton path is not viable here outside Steam/FEX dispatch.

Artifacts from this cycle:

- `output/attempt-cleanprefix-proton10-20260227T163452Z.log`
- `output/attempt-cleanprefix-proton10-20260227T163452Z.png`
- `output/click-attempt-postreset2-20260227T163647Z.log`
- `output/click-attempt-postreset2-20260227T163647Z.png`
- `output/ui-recover-20260227T163812Z.png`
- `output/agegate-clear-attempt-20260227T163924Z.png`
- `output/direct-geproton-20260227T164555Z.log`

Current assessment:

- Most likely immediate blocker is Steam UI trap/dispatch state (age-gate/store page), not file installation.
- Next practical fix path is to recover Steam to Library/details UI reliably (or restart into clean Library landing), then trigger Play from in-client details where dispatch can create a real `App Running` session for post-reset prefix.

## 2026-02-27 (17:00-18:10 UTC)

Additional fix cycle on `spark-de79` focused on launch runtime and dispatch reliability:

- Refined finding: when launch did dispatch earlier, Steam always executed
  `.../steamapps/common/Proton - Experimental/proton ...` for `AppID 2537590`.
- Existing compat mapping edits were not reliably taking effect in this headless session.
- Added a hard remap helper so Proton-Experimental resolves to GE-Proton:
  - `scripts/15-remap-proton-experimental-to-ge.sh`
- Added restart and navigation helper to re-open Steam directly at MSFS details after remap:
  - `scripts/16-restart-steam-and-open-msfs.sh`

Validated outcomes in this pass:

- Steam UI automation works for Store -> Library recovery and game detail navigation.
- Launch dispatch is currently session-sensitive: no fresh `GameAction [AppID 2537590]` entries were accepted during this cycle, so no new post-remap crash signature could be captured yet.
- Next critical validation is a real Play dispatch while remap is active.

Latest artifacts captured:

- `output/steam-main-window.png`
- `output/steam-main-after-library-tab.png`
- `output/steam-main-after-viewpage-btn.png`
- `output/msfs-details-before-play-remap.png`
- `output/msfs-details-after-play-remap.png`
- `output/msfs-filter-flight.png`
- `output/msfs-filter-selected.png`
- `output/msfs-filter-after-playclick.png`


## 2026-02-27 (17:31 UTC, XDG/dispatch debugging + clean retry)

Most likely untried root cause investigated in this cycle: malformed desktop/XDG environment was breaking protocol dispatch and causing unstable headless UI behavior.

What was validated and changed:
- Found corrupted `~/.config/user-dirs.dirs` (contained stray `EOF` and shell lines), which triggered repeated runtime warnings during URI/open attempts.
- Added `scripts/17-fix-xdg-user-dirs.sh` to rewrite `user-dirs.dirs` and ensure standard XDG folders exist.
- Hooked this repair into `scripts/05-resume-headless-msfs.sh` so every resume cycle normalizes the desktop environment.
- Confirmed Steam Play remap is still active:
  - `Proton Experimental` command prefix resolves to `GE-Proton10-32` in `compat_log.txt`.

Key observations from this pass:
- Steam auth state remains session-fragile:
  - At `17:24Z`, helper process showed authenticated `steamid=76561198351709467`.
  - Subsequent clean restart returned to unauthenticated `steamid=0`.
- `steam://` dispatch from CLI remains unreliable in this headless session; no fresh `StartSession: appID 2537590` events were created in this cycle.
- UI automation still landed on Steam Store and did not produce a launch event for AppID `2537590`.

Artifacts:
- `output/restart-open-after-xdgfix-20260227T172406Z.log`
- `output/finalize-after-xdgfix-20260227T172439Z.log`
- `output/ui-clean-resume-20260227T172921Z.log`
- `output/ui-clean-play-20260227T172921Z.log`
- `output/ui-clean-20260227T172921Z-4-postplay.png`

## 2026-02-27 (17:45-18:00 UTC, URI handler + dispatch cycle)

New likely root-cause tested: `steam://` protocol handler drifted away from Steam in headless session, causing URI launches to route into Firefox or no-op.

What was changed:

- Added `scripts/18-fix-steam-uri-handler.sh`.
  - Copies `steam_steam.desktop` into `~/.local/share/applications`.
  - Refreshes desktop MIME cache (`update-desktop-database` when available).
  - Enforces `x-scheme-handler/steam=steam_steam.desktop` in `~/.config/mimeapps.list`.
  - Applies `xdg-mime default steam_steam.desktop x-scheme-handler/steam`.
- Integrated handler fix into resume flow (`scripts/05-resume-headless-msfs.sh`).

Validation from this pass:

- `xdg-open steam://...` now resolves to Steam (`STEAMDIR: ...`) instead of Firefox.
- Steam was re-started and re-authenticated successfully (`connection_log.txt` shows fresh logged-on session at `17:51:06Z`).
- Despite handler and auth recovery, unattended URI dispatch still did not emit fresh `GameAction [AppID 2537590]` events in this cycle.
- UI click-scans against detected Steam webhelper surface also did not trigger launch events.

Current status:

- Install remains intact (`AppID 2537590` manifest present, fully downloaded).
- Runtime remap path remains in place (Proton-Experimental command prefix -> GE-Proton).
- Remaining blocker is reliable launch dispatch from this headless Steam UI state.

## 2026-02-27 (18:15-18:23 UTC, Steam pipe dispatch breakthrough + runtime retest)

New root-cause and fix path validated:
- CLI launch dispatch (`steam://...`/`-applaunch`) can be ignored in headless Snap session, but Steam IPC pipe dispatch works.
- Writing launch URI directly to `~/.steam/steam.pipe` reliably produced new launch sessions (`StartSession` for AppID `2537590`).

What was added:
- `scripts/19-dispatch-via-steam-pipe.sh`
  - Dispatches `steam://rungameid/2537590` via Steam pipe.
  - Verifies acceptance via `GameAction` / `StartSession` deltas.
- Updated `scripts/13-debug-launch-dispatch.sh`
  - Added `pipe` mode: `uri|applaunch|pipe`.

Runtime retest outcomes using pipe dispatch:
- Launch reached real game process chain repeatedly:
  - `steam-launch-wrapper ... waitforexitandrun ... FlightSimulator2024.exe`
  - `FlightSimulator2024.exe` process appeared.
- Game stayed up longer (~38-48s) than earlier ~2s failures, then exited.
- Crash signature remains unchanged:
  - `SEH 0xC0000005`
  - `MainState:BOOT SubState:BOOT_INIT`
  - `EnableD3D12=true`

Compatibility variant tested in this cycle:
- Restored true `Proton - Experimental` (removed GE remap for test run).
- Result remained early BOOT_INIT crash; no material improvement over GE-Proton run.

Artifacts:
- `output/pipe-dispatch-20260227T181511Z.log`
- `output/pipe-launch-cycle-20260227T181559Z.log`
- `output/runtime-watch-20260227T181635Z.log`
- `output/protonexp-rerun-20260227T181923Z.log`
- `output/AsoboReport-Crash-2537590-20260227T182254Z.txt`

Current status:
- Dispatch reliability blocker is largely solved via Steam pipe.
- Hard blocker is now runtime crash in BOOT_INIT (not install/entitlement/dispatch).

## 2026-02-27 (18:33-18:48 UTC, stale launch-state cleanup + GE remap retest)

Additional root-cause findings from this cycle:

- Found a real bug in `scripts/19-dispatch-via-steam-pipe.sh`:
  - It used `printf %sn`, which can emit malformed payloads such as
    `steam://rungameid/2537590n...` into Steam IPC.
  - This correlated with stale `ShowGameArgs "-dx11"` wait states in Steam logs.
- Fixed dispatch script to use `printf '%s\n'`.
- Also fixed `scripts/13-debug-launch-dispatch.sh` unsupported-mode error text.

Behavior validated after a full Steam core recycle (`steampid` replaced):

- Fresh pipe dispatch again produced real launch sessions for `2537590`.
- Confirmed that direct `compatibilitytools.vdf` app mapping to `GE-Proton10-32`
  was not sufficient by itself in this environment (Steam still used tool `1493710` path).
- Re-applied explicit Proton-Experimental remap (`scripts/15-remap-proton-experimental-to-ge.sh`)
  and re-ran launch on clean client state.
- Post-remap command prefix resolved to GE path as expected:
  - `.../compatibilitytools.d/GE-Proton10-32/proton waitforexitandrun ...`

Result:

- MSFS still exits during early boot with same signature:
  - `SEH 0xC0000005`
  - `MainState:BOOT SubState:BOOT_INIT`
  - latest crash timestamp observed: `2026-02-27T18:47:35Z`

Conclusion from this pass:

- Launch dispatch path is now reliable again after stale-state cleanup.
- Forcing GE via Proton-Experimental remap did not resolve the BOOT_INIT crash.
- Remaining blocker is runtime/platform-level stability under Snap Steam + FEX + Proton.

## 2026-02-27 (18:49 UTC, forced non-D3D12 profile retest)

Ran an additional controlled runtime experiment after GE remap was confirmed active:

- Temporary launch options tested for AppID `2537590`:
  - `PROTON_LOG=1`
  - `PROTON_ENABLE_NVAPI=0`
  - `PROTON_USE_WINED3D=1`
- Dispatch used Steam pipe (`steam://rungameid/2537590`).
- Result: launch session still exited in ~40s with the same crash pattern.
  - New crash timestamp observed: `2026-02-27T18:49:58Z`
  - Signature remained `SEH 0xC0000005` in early `BOOT_INIT`.

Post-test cleanup:

- Restored default launch options back to:
  - `PROTON_LOG=1 PROTON_LOG_DIR=/home/th0rgal/msfs-on-dgx-spark/output %command%`
## 2026-02-27 (19:00-19:08 UTC, GPU identity + overlay injection retests)

Another full runtime fix cycle on `spark-de79` focused on two untried high-probability causes:

1. GPU identity/NVAPI handling on ARM/FEX path (`GPUName="NVIDIA Tegra NVIDIA GB10"` in crash reports).
2. Steam overlay injection potentially destabilizing Proton/FEX startup.

What was changed:

- Fixed a bug in `scripts/19-dispatch-via-steam-pipe.sh` (`printf %sn` -> `printf %s\n`) so URI writes to `steam.pipe` are correctly newline-terminated.
- Added `scripts/20-test-gpu-spoof-launch.sh` to run one controlled launch cycle with:
  - `PROTON_HIDE_NVIDIA_GPU=1`
  - `PROTON_ENABLE_NVAPI=0`
  - `PROTON_NO_ESYNC=1`
  - `PROTON_NO_FSYNC=1`
- Added `scripts/21-test-overlay-off-launch.sh` to set per-app `OverlayAppEnable=0`, apply minimal launch options, launch via pipe, and capture crash/runtime evidence.

Validation outcomes:

- Pipe dispatch remains reliable (`GameAction` and `StartSession` increments observed each run).
- Both new fix paths still end in the same early crash signature:
  - `Code=0xC0000005`
  - `LastStates=" MainState:BOOT SubState:BOOT_INIT"`
  - `EnableD3D12=true`
  - `NumRegisteredPackages=0`
- Overlay disable flag did **not** stop overlay library injection in this environment:
  - pressure-vessel command line still includes `--ld-preload ... gameoverlayrenderer.so`.

Latest artifacts:

- `output/gpu-spoof-cycle-20260227T190139Z.log`
- `output/gpu-spoof-runtime-20260227T190139Z.log`
- `output/AsoboReport-Crash-2537590-20260227T190139Z.txt`
- `output/overlay-off-cycle-20260227T190546Z.log`
- `output/overlay-off-runtime-20260227T190546Z.log`
- `output/AsoboReport-Crash-2537590-overlayoff-20260227T190546Z.txt`

Current assessment:

- Install/auth/dispatch are now consistently working.
- The remaining blocker is an early runtime crash during BOOT initialization under the current ARM + FEX + Steam Snap + Proton stack.
- Most likely next attempts should target runtime container/proton internals (e.g., running outside Steam Snap confinement or testing a distinct proton/runtime build matrix), not Steam UI automation.

## 2026-02-27 (19:26-19:35 UTC, package-path preseed + non-Snap runtime attempt)

This cycle targeted two high-probability untried fixes:

1. Missing package path bootstrap (`NumRegisteredPackages=0` in every crash report).
2. Moving runtime off Steam Snap confinement via native Steam launcher under FEX.

What was changed:

- Added `scripts/22-preseed-msfs-usercfg.sh`.
  - Seeds `UserCfg.opt` for MSFS 2024 in Proton prefix:
    - `C:\users\steamuser\AppData\Roaming\Microsoft Flight Simulator 2024\Packages`
  - Creates `Packages/Official` + `Packages/Community`.
  - Mirrors `UserCfg.opt` into legacy `Microsoft Flight Simulator` roaming path.
  - Backs up zero-byte `FlightSimulator2024.CFG` if present.

Validation after preseed + launch via `steam.pipe`:

- Launch dispatch accepted and produced new `StartSession` / `GameAction` events.
- Crash signature unchanged:
  - `Code=0xC0000005`
  - `LastStates=" MainState:BOOT SubState:BOOT_INIT"`
  - `EnableD3D12=true`
  - `NumRegisteredPackages=0`
- Latest observed crash timestamp in this cycle: `2026-02-27T19:25:55Z`.

Non-Snap Steam attempt (new path):

- Downloaded Valve Steam launcher bundle to `~/fex-steam-native/steam-launcher`.
- Launched via `DISPLAY=:1 FEXBash ... ./steam`.
- Native Steam bootstrap fails before usable client start with:
  - `bwrap: setting up uid map: Permission denied`
  - `Error: Steam now requires user namespaces to be enabled.`
- Host-level checks show:
  - `/proc/sys/kernel/unprivileged_userns_clone=1`
  - `unshare -Urm true` still fails (`Operation not permitted`), including under FEX.
- Attempted workaround:
  - setuid root on `/usr/bin/bwrap` succeeded (`bwrap` basic test passes),
  - but Steam runtime check still fails with uid-map permission error.

Proton toolchain attempt:

- Triggered installs for `AppID 3658110` (Proton 10) and `2180100` (Hotfix) via Steam pipe.
- `appinfo_log` shows only `RequestAppInfoUpdate` entries; no content download/install occurred.

Artifacts:

- `output/preseed-usercfg-20260227T192636Z.log`
- `output/preseed-launch-20260227T192636Z.log`
- `output/native-steam-state-20260227T193240Z.png`

Current assessment update:

- Package-path preseed did not change BOOT_INIT failure behavior.
- Non-Snap Steam path is currently blocked by namespace/uid-map restrictions in this DGX environment.
- Remaining blocker continues to be runtime/platform stability on ARM + FEX + Proton for this title.

## 2026-02-27 (19:50-19:54 UTC, UserCfg syntax fix + hard overlay test)

This cycle targeted two untried high-probability causes:

1. `UserCfg.opt` syntax ambiguity (previous preseed used `{InstalledPackagesPath ...}` form).
2. Forcing one run with Steam overlay libraries physically removed from preload path.

What was changed:

- Added `scripts/23-fix-usercfg-format-and-test.sh`:
  - Writes canonical line format in both roaming paths:
    - `InstalledPackagesPath "C:\users\steamuser\AppData\Roaming\Microsoft Flight Simulator 2024\Packages"`
  - Removes zero-byte `FlightSimulator2024.CFG` if present.
  - Dispatches launch via `steam.pipe` and captures summary.
- Added `scripts/24-test-hard-disable-overlay.sh`:
  - Temporarily moves `gameoverlayrenderer.so` (32/64) before launch and restores afterward.
  - Captures launch summary and crash signature.

Validation outcomes:

- `UserCfg` format fix did not change crash signature.
  - New run at `2026-02-27T19:51:13Z` exited at `19:51:52Z`.
  - Crash report (`2026-02-27T19:51:51Z`) remained:
    - `Code=0xC0000005`
    - `MainState:BOOT SubState:BOOT_INIT`
    - `EnableD3D12=true`
    - `NumRegisteredPackages=0`
- Hard overlay-removal run also did not resolve boot crash.
  - New run at `2026-02-27T19:53:08Z` exited at `19:53:47Z`.
  - Crash report (`2026-02-27T19:53:46Z`) remained unchanged:
    - `Code=0xC0000005`
    - `MainState:BOOT SubState:BOOT_INIT`
    - `EnableD3D12=true`
    - `NumRegisteredPackages=0`

Artifacts:

- `output/usercfg-fix-cycle-20260227T195058Z.log`
- `output/AsoboReport-Crash-2537590-usercfgfix-20260227T195151Z.txt`
- `output/overlay-hardoff-cycle-20260227T195254Z.log`
- `output/AsoboReport-Crash-2537590-hardoverlayoff-20260227T195347Z.txt`

Updated assessment:

- Launch dispatch and auth are working; multiple new sessions were created and executed.
- Runtime still consistently fails in early boot with the same crash signature.
- Remaining blocker remains platform/runtime compatibility on this ARM + FEX + Proton stack, not install/auth/dispatch or UserCfg/overlay toggles.

## 2026-02-27 (20:40 UTC, compat-layer root cause + CachyOS enforcement)

New findings from the forum-driven compat deep dive:

- Root compat bug identified in installed `proton-cachyos` metadata:
  - `compatibilitytools.d/proton-cachyos-.../toolmanifest.vdf` required unknown tool appid `4185400`.
  - This matches prior `AppError_51` / `Tool 4185400 unknown` behavior and prevented clean tool selection.
- Patched dependency to `1628350` (Steam Linux Runtime sniper), then reloaded Steam.
- Confirmed `compatibilitytools.vdf` overrides are still ignored in this headless Snap/FEX path (Steam continued selecting tool `1493710` by default).
- Added deterministic bypass `scripts/20-fix-cachyos-compat.sh`:
  - patches the bad `require_tool_appid`
  - remaps `steamapps/common/Proton - Experimental` to `compatibilitytools.d/proton-cachyos-...`

Validation:

- Fresh launch sessions were produced via Steam pipe dispatch.
- Command prefix now resolves to CachyOS runtime in real launch command:
  - `.../compatibilitytools.d/proton-cachyos-.../proton waitforexitandrun ...`
- Runtime behavior changed (short early exit around ~3s) and no new Asobo crash report was generated for CachyOS runs.
- Last Asobo crash file remained the prior BOOT_INIT signature:
  - `Code=0xC0000005`
  - `TimeUTC=2026-02-27T20:34:53Z`
  - `LastStates=" MainState:BOOT SubState:BOOT_INIT"`
  - `NumRegisteredPackages=0`

Artifacts:

- `output/cachyos-exp-remap-test-20260227T203621Z.log`
- `output/cachyos-runtime-cycle-20260227T203852Z.log`

## 2026-02-27 (20:48-20:54 UTC, C: package mirror + clean-prefix GE retest)

New cycle targeted an untried package-registration hypothesis:

- Mirror full installed package tree into the prefix C: roaming path
  (`.../AppData/Roaming/Microsoft Flight Simulator 2024/Packages`) using hardlinks.
- Keep `UserCfg.opt` on C: path and retest with a clean prefix + forced GE-Proton.

What was changed/tested:

- Created C: package mirror with ~130 top-level package dirs.
- Added reusable script:
  - `scripts/25-test-cpath-mirror-cleanprefix-ge.sh`
- Ran live cycles:
  - `output/cpath-mirror-test-20260227T204803Z.log`
  - `output/cpath-mirror-launch-20260227T204812Z.log`
  - `output/cpath-mirror-ge-test-20260227T204942Z.log`
  - `output/cleanprefix-ge-cycle-20260227T205202Z.log`

Validation outcome:

- Launch dispatch remained accepted (`GameAction` and `StartSession` increments).
- GE runs still executed for ~40s and then exited (`App Running` -> `Fully Installed`).
- No fresh `AsoboReport-Crash-2537590*.txt` was generated after `2026-02-27T20:13:14Z`.
- Last known crash signature therefore remains unchanged:
  - `Code=0xC0000005`
  - `LastStates=" MainState:BOOT SubState:BOOT_INIT"`
  - `NumRegisteredPackages=0`

Additional observations:

- `installscriptevalutor_log.txt` shows repeated translated install paths for
  `MSFS2024` and `Steamworks Shared`, but no explicit install-script error lines.
- `ProcessingInstallScript` and occasional `RunningInstallScript` stages continue
  to appear before process creation.

Assessment update:

- C: package mirroring + clean prefix did not resolve startup exits.
- Remaining blocker still appears to be runtime/platform behavior on ARM + FEX + Proton,
  not Steam auth/dispatch or obvious package-path misconfiguration.

## 2026-02-27 (20:55-20:57 UTC, install-script bypass check)

New targeted check:

- Temporarily replaced `MSFS2024/InstallUtils/InstallScript.vdf` with a no-op body,
  launched once with GE, then restored original script file.

Observed behavior:

- `Running install script evaluator ... step(s)` dropped from `2` to `1` in `console_log`.
- Launch still followed the same path and exited after ~40s.
- No fresh Asobo crash report was generated; latest remains from `20:13:14Z`.

Artifacts:

- `output/installscript-bypass-test-20260227T205553Z.log`

Conclusion:

- Install script complexity is not the primary blocker.
- Runtime exit behavior remains unchanged after script bypass.
## 2026-02-27 (21:36-21:50 UTC, native FEX + userns + thunks breakthrough)

This cycle targeted two untried high-probability blockers at once:

1. Native Steam runtime launch under FEX was blocked by user namespace restrictions (`bwrap uid map permission denied`).
2. FEX Vulkan path was not forced to host thunks, so x86 clients were defaulting to llvmpipe in many runs.

What changed:

- Enabled AppArmor userns gates (runtime):
  - `kernel.apparmor_restrict_unprivileged_userns=0`
  - `kernel.apparmor_restrict_unprivileged_unconfined=0`
- Rewrote `~/.fex-emu/Config.json` to force thunk mappings:
  - `Vulkan=1`, `GL=1`, `drm=1`, `WaylandClient=1`, `asound=1`
- Verified FEX Vulkan now sees NVIDIA on host in direct test (`FEXBash -c vulkaninfo --summary`):
  - `deviceName = NVIDIA Tegra NVIDIA GB10`
- Launched **native Steam under FEX** while reusing Snap Steam state (`HOME=~/snap/steam/common`) and dispatched MSFS via `steam.pipe`.

Validation result (major behavior change):

- Dispatch accepted (`GameAction` and `StartSession` incremented at ~21:44 UTC).
- `FlightSimulator2024.exe` remained alive for >5 minutes (checked through `21:49:56 UTC`) with active wine/proton process tree.
- No fresh `AsoboReport-Crash-2537590.txt` was produced during this run window.
- This is a clear improvement vs prior repeat exits around ~40s in `BOOT_INIT`.

New scripts added:

- `scripts/26-enable-userns-and-fex-thunks.sh`
- `scripts/27-launch-native-fex-steam-on-snap-home.sh`

New artifacts:

- `output/native-msfs-run-20260227T214408Z.log`
- `output/native-xvfb3-msfs-20260227T214824Z.png`

Current assessment:

- We appear to have moved past the previous immediate BOOT_INIT crash loop in this configuration.
- Remaining work is to confirm interactive viability (window/splash progression and input path) and ensure this sustained run reproduces consistently.

## 2026-02-27 (22:03-22:14 UTC, launch-option injection + DX12 suppression trials)

This cycle targeted an untried root cause: Steam launch options were being written to `sharedconfig.vdf` but not actually reaching Proton/MSFS.

What was validated:

- `scripts/28-set-localconfig-launch-options.sh` added to write `LaunchOptions` in `userdata/<id>/config/localconfig.vdf`.
- Even with localconfig entries present, process environment still did not include `PROTON_LOG`/`WINEDLLOVERRIDES` when launched via Steam in this headless path.
- Added `scripts/29-force-msfs-dx11-proton-wrapper.sh` to wrap GE-Proton and force runtime arguments/env for MSFS launches.
- Wrapper confirmed effective by Proton log header:
  - `Command: ... FlightSimulator2024.exe -dx11 -FastLaunch`
  - `System/Effective WINEDLLOVERRIDES: d3d12,d3d12core=n`

Behavior changes observed:

- DirectX12 popup became intermittent instead of immediate in some runs.
- MSFS launch sessions became reproducible with forced args/env and longer runtime windows (~2-3 minutes).
- However, game still exits with no rendered frame and no global flow progression:
  - `AsoboReport-RunningSession.txt` remains `Where="CrashReport_Z::Init"`
  - `FrameCount=0`
  - `LastStates="<no global flow>@"`

Additional attempted bypass:

- Wrapped launch via Wine virtual desktop (`explorer /desktop=MSFS,1920x1080 ... -dx11 -FastLaunch`) to reduce monitor/adapter mismatch impact.
- This did not eliminate the startup failure; fatal popup still appears in some runs and process exits persist.

Artifacts from this cycle:

- `output/dx11-force-cycle-20260227T220311Z.log`
- `output/localconfig-dx11-cycle-20260227T220544Z.log`
- `output/localconfig-dx11-post95-20260227T220818Z.log`
- `output/wrapper-dx11-cycle-20260227T220929Z.log`
- `output/wrapper-dx11-n-cycle-20260227T221054Z.log`
- `output/virtualdesktop-cycle-20260227T221337Z.log`
- `output/steam-2537590.log`

Current assessment:

- Dispatch/auth/proton-tool selection are working.
- Forced launch arguments and dll overrides are now verified to apply.
- Remaining blocker is still pre-frame runtime/platform incompatibility on this ARM+FEX+Snap-Proton stack; not a missing launch option anymore.

## 2026-02-27 (22:27-22:32 UTC, compat cleanup + Vulkan forcing retest)

New tests in this cycle:

1. Updated `scripts/29-force-msfs-dx11-proton-wrapper.sh` to force NVIDIA Vulkan ICD and forum-aligned env toggles (`PROTON_ENABLE_WAYLAND=0`, `DXVK_HDR=0`).
2. Removed stale Steam per-user launch config (`localconfig.vdf`) and normalized `sharedconfig.vdf` launch options to remove malformed legacy override text.
3. Re-ran launch with clean commandline path and then with `PROTON_USE_WINED3D=1` fallback.

Key findings:

- Cleanup succeeded: launch path no longer injected `explorer /desktop=...` and now uses direct executable invocation:
  - `... proton.real waitforexitandrun .../FlightSimulator2024.exe -dx11 -FastLaunch`
- Forcing NVIDIA ICD in Proton runtime caused Vulkan instance creation failure:
  - `wine_vkCreateInstance Failed to create instance, res=-9`
  - `Failed to initialize DXVK`
- With ICD force removed + `PROTON_USE_WINED3D=1`, app still exits in init.
- Latest crash signature remains unchanged:
  - `Where="CrashReport_Z::Init"`
  - `FrameCount=0`
  - `LastStates="<no global flow>@"`
  - latest observed `TimeUTC=2026-02-27T22:32:07Z`

Assessment update:

- We did remove a real compat/config issue (stale virtual-desktop launch injection).
- The remaining blocker is still runtime/platform-level initialization failure under this ARM+FEX+Steam Runtime stack.
- Hard-forcing host NVIDIA ICD inside pressure-vessel is not viable in current session (DXVK init fails immediately).

## 2026-02-27 (22:53-23:00 UTC, direct DXGI triage + Valve Proton A/B)

This cycle focused on two likely untried causes of the persistent startup failure:

1. Potential wrong Vulkan adapter selection (llvmpipe vs NVIDIA) in vkd3d.
2. Corrupted compat runtime mapping where `Proton - Experimental` was symlinked to GE.

What was tried:

- Added `scripts/30-force-vkd3d-nvidia-wrapper.sh` to force:
  - `VKD3D_VULKAN_DEVICE=0`
  - `VKD3D_FILTER_DEVICE_NAME="NVIDIA Tegra NVIDIA GB10"`
  - `DXVK_FILTER_DEVICE_NAME="NVIDIA Tegra NVIDIA GB10"`
- Re-ran native-FEX launch path with userns + thunk config and pipe dispatch.
- Restored real Valve Proton Experimental by replacing symlinked `Proton - Experimental` with backed-up original directory.
- Cleared `config/compatibilitytools.vdf` overrides and verified `compat_log` eventually switched tool 1493710 prefix to `/steamapps/common/Proton - Experimental/proton`.
- Added `scripts/31-wrap-valve-exp-dx11.sh` to force `-dx11 -FastLaunch` on Valve Experimental and retested.

Key evidence:

- Proton log now shows repeat crash in Wine `dxgi.dll`, not just generic app init:
  - `Exception 0xc0000005`
  - `Unhandled page fault ... at 0x006ffffd011b47 in dxgi (+0x231b47)`
- Xvfb screenshots still show runtime popup:
  - `Fatal error: Impossible to create DirectX12 device`
  - `Error 0x80070057 (DXGI Unknown)`
- Same popup appears even when forcing `-dx11`, so startup still hard-depends on successful DXGI/D3D12 device init on this stack.

Artifacts:

- `output/vkd3d-nvidia-cycle-20260227T225323Z.log`
- `output/valve-exp-native-cycle-20260227T225746Z.log`
- `output/valve-exp-xvfb3-20260227T225906Z.png`
- `output/valve-exp-dx11-cycle-20260227T225935Z.log`
- `output/manual-check-20260227T230034Z.png`
- `output/steam-2537590.log` (contains `dxgi.dll` crash backtrace)

Assessment update:

- Compat/runtime path is now cleaner (true Valve Proton Experimental can be selected again).
- Primary blocker remains DXGI/D3D12 device creation on ARM+FEX+Proton runtime; this is not resolved by launch args, wrapper env, or GE-vs-Valve Proton switch in current environment.
