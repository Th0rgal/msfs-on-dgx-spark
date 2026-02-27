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
