# Progress Log

## 2026-02-28 (13:40-13:42 UTC, live DGX: auth window geometry normalization for headless recovery)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... AUTO_REAUTH_ON_AUTH_FAILURE=1 REAUTH_LOGIN_WAIT_SECONDS=30 MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=60 ./scripts/90-remote-dgx-stable-check.sh`
  - auth recovery still times out without credentials/Steam Guard (`exit 2`), but state is now `unauthenticated (ui-only evidence)` instead of hidden-window ambiguity.
  - synced debug evidence confirms Steam windows are now visible and normalized on `:2`:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T134028Z/output/steam-debug-20260228T134152Z.log`
    - visible windows include:
      - `steam` at `1600x900+52+82`
      - `steamwebhelper` at `1600x900+52+82`

Repo hardening in this pass:

- Updated `scripts/58-ensure-steam-auth.sh`:
  - added window normalization during restore (`AUTH_NORMALIZE_WINDOWS=1` by default),
  - added geometry controls (`AUTH_WINDOW_WIDTH`, `AUTH_WINDOW_HEIGHT`, `AUTH_WINDOW_X`, `AUTH_WINDOW_Y`),
  - applies `windowmap + windowsize + windowmove + windowraise` to Steam windows during recovery polls.
- Updated docs:
  - `README.md`, `docs/setup-guide.md`, and `docs/troubleshooting.md` now document default window normalization behavior.

Assessment update:

- This removes a major headless trust gap where Steam/login UI existed but was effectively invisible (`10x10`/off-screen).
- Remaining blocker is now explicit and expected: session credentials / Steam Guard completion.

## 2026-02-28 (13:36-13:40 UTC, live DGX: auth-gate bootstrap + deterministic diagnostics hardening)

Live check on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=90 ./scripts/90-remote-dgx-stable-check.sh`
  - still exits at auth gate (`exit 7`) because Steam remains logged out (`steamid=0`).
  - new bootstrap/debug artifacts are now emitted and synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T133627Z/output/auth-bootstrap-2537590-20260228T133629Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T133627Z/output/steam-debug-20260228T133639Z.log`

Repo hardening in this pass:

- Updated `scripts/54-launch-and-capture-evidence.sh`:
  - bootstraps Steam/UI stack before auth gate (`AUTH_BOOTSTRAP_STEAM_STACK=1` by default),
  - adds bootstrap wait control (`AUTH_BOOTSTRAP_WAIT_SECONDS`, default `8`),
  - optionally runs runtime recovery when no `steamwebhelper` is present (`AUTH_RECOVER_RUNTIME_ON_MISSING_WEBHELPER=1`).
- Updated `scripts/11-debug-steam-window-state.sh`:
  - no longer truncates output when `steamwebhelper` is absent,
  - captures monitor state (`xrandr --listmonitors`),
  - appends `connection_log.txt` tail for auth/session context.
- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - forwards the new auth-bootstrap knobs to remote runners.
- Updated docs:
  - `README.md`, `docs/setup-guide.md`, `docs/troubleshooting.md` now document auth bootstrap/recovery defaults.

Assessment update:

- Current blocker remains account/session authentication (`steamid=0`), not launch orchestration.
- Evidence quality is significantly improved: every auth-gate failure now includes pre-auth bootstrap context plus complete monitor/process/session diagnostics for deterministic triage.

## 2026-02-28 (13:24-13:31 UTC, live DGX: dispatch acceptance hardening + runtime rebuild redispatch)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=120 ./scripts/90-remote-dgx-stable-check.sh`
  - strict auth gate still fails (`exit 7`, unauthenticated).
  - evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132440Z/output/auth-state-2537590-20260228T132442Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132440Z/output/steam-debug-20260228T132442Z.log`
- `DGX_PASS=... ALLOW_UI_AUTH_FALLBACK=1 FATAL_EXIT_CODES='' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=120 ./scripts/90-remote-dgx-stable-check.sh`
  - bypassed strict auth gate but launch was not accepted (`StartSession` unchanged, verifier `exit 2`).
  - evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132452Z/output/dispatch-2537590-20260228T132454Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132452Z/output/verify-launch-2537590-20260228T132454Z.log`
- Re-ran with new dispatch retry/recovery patch:
  - `DGX_PASS=... ALLOW_UI_AUTH_FALLBACK=1 FATAL_EXIT_CODES='' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=120 ./scripts/90-remote-dgx-stable-check.sh`
  - dispatch attempt 1 failed (`rc=4`), runtime recovery executed, redispatch attempt 2 still unaccepted (`rc=4`), verifier still `exit 2`.
  - evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132803Z/output/dispatch-2537590-20260228T132805Z-d1.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132803Z/output/dispatch-recover-2537590-20260228T132805Z-d1.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T132803Z/output/dispatch-2537590-20260228T132805Z-d2.log`

Repo hardening in this pass:

- Updated `scripts/54-launch-and-capture-evidence.sh`:
  - added intra-attempt dispatch retries (`DISPATCH_MAX_ATTEMPTS`, default `2`),
  - added dispatch retry delay control (`DISPATCH_RETRY_DELAY_SECONDS`, default `8`),
  - added optional runtime rebuild between redispatches when dispatch is unaccepted (`DISPATCH_RECOVER_ON_NO_ACCEPT=1` + `57-recover-steam-runtime.sh`),
  - dispatch artifacts now include per-dispatch attempt suffix (`-d1`, `-d2`, ...).
- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - forwards `DISPATCH_MAX_ATTEMPTS`, `DISPATCH_RETRY_DELAY_SECONDS`, and `DISPATCH_RECOVER_ON_NO_ACCEPT` to remote verification runners.
- Updated `README.md` with dispatch-retry and redispatch-recovery knobs.

Assessment update:

- Dispatch reliability is better instrumented and now self-heals one common runtime-stall mode within a single attempt.
- Current blocker remains Steam session state/launch acceptance on the active DGX session; even after runtime rebuild and redispatch, `StartSession` is not advancing.

## 2026-02-28 (13:17-13:22 UTC, live DGX: headless Steam window restore during auth recovery)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=120 ./scripts/90-remote-dgx-stable-check.sh`
  - verification still fails at auth gate (`exit 7`, unauthenticated session).
  - evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131756Z/output/auth-state-2537590-20260228T131758Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131756Z/output/steam-debug-20260228T131758Z.log`
- `DGX_PASS=... AUTO_REAUTH_ON_AUTH_FAILURE=1 REAUTH_LOGIN_WAIT_SECONDS=180 MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=120 ./scripts/90-remote-dgx-stable-check.sh`
  - auth recovery still times out (`exit 2`) without credentials/Steam Guard code in this session.
  - timeout confirms Steam windows exist but no visible login/auth dialog.
  - evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131810Z/output/steam-debug-20260228T132121Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131810Z/output/steam-debug-20260228T132121Z.png`

Repo hardening in this pass:

- Updated `scripts/58-ensure-steam-auth.sh`:
  - added `AUTH_RESTORE_WINDOWS=1` (default),
  - actively attempts to unminimize/raise/focus Steam windows during re-auth polling,
  - emits explicit timeout note when restore mode was attempted.
- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - forwards `AUTH_RESTORE_WINDOWS` to remote auth recovery.
- Updated docs (`README.md`, `docs/setup-guide.md`, `docs/troubleshooting.md`) to document default window-restore behavior.

Assessment update:

- Launch/runtime path remains healthy; active blocker remains Steam account auth state.
- Headless auth recovery is now more resilient when Steam dialogs are hidden/minimized instead of truly absent.

## 2026-02-28 (13:14-13:16 UTC, live DGX: headless auth fallback hardening for invisible Steam UI)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - baseline verification still fails fast at auth gate (`exit 7`, unauthenticated), with evidence synced locally.
- `DGX_PASS=... AUTO_REAUTH_ON_AUTH_FAILURE=1 REAUTH_LOGIN_WAIT_SECONDS=20 MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - auth recovery now exits deterministically with `exit 2` and explicit headless diagnosis:
    - `Observed Steam X11 windows, but no visible login/auth dialog was detected.`
  - auth-debug evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131619Z/output/steam-debug-20260228T131650Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131619Z/output/steam-debug-20260228T131650Z.png`

Repo hardening in this pass:

- Updated `scripts/58-ensure-steam-auth.sh`:
  - added `AUTH_USE_STEAM_LOGIN_CLI=1` (default) to attempt `steam -login <user> <pass>` when credentials are provided,
  - added `AUTH_FORCE_OPEN_MAIN=1` (default) to nudge Steam UI exposure in headless sessions,
  - emits explicit timeout diagnostics when Steam windows exist but no visible login/guard dialog is available.
- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - now forwards `AUTH_USE_STEAM_LOGIN_CLI` to remote auth recovery.
- Updated docs (`README.md`, `docs/setup-guide.md`, `docs/troubleshooting.md`) with the CLI-login fallback flow for headless auth recovery.

Assessment update:

- Runtime verification path remains healthy; immediate blocker is still session authentication state.
- Trust boundary is clearer for unattended runs: auth timeouts now distinguish "logged out" from "headless UI not visibly rendered," and provide a credential-based non-UI recovery path.

## 2026-02-28 (13:11-13:13 UTC, live DGX: unattended credential-based auth recovery path)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=90 ./scripts/90-remote-dgx-stable-check.sh`
  - run still fails fast at auth gate with `exit 7` (`Steam session unauthenticated`), confirming launch path remains blocked by login state.
- `DGX_PASS=... AUTO_REAUTH_ON_AUTH_FAILURE=1 REAUTH_LOGIN_WAIT_SECONDS=30 MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - remote auth recovery path executed and timed out with deterministic `exit 2` when no credentials/guard code were supplied.
  - auth-failure evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131220Z/output/steam-debug-20260228T131255Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T131220Z/output/steam-debug-20260228T131255Z.png`

Repo hardening in this pass:

- Updated `scripts/58-ensure-steam-auth.sh`:
  - added optional credential-form automation via `STEAM_USERNAME`/`STEAM_PASSWORD`,
  - retained optional `STEAM_GUARD_CODE` typing,
  - supports `AUTH_AUTO_FILL` and `AUTH_SUBMIT_LOGIN` toggles for controlled login automation.
- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - forwards `STEAM_USERNAME`, `STEAM_PASSWORD`, `AUTH_AUTO_FILL`, and `AUTH_SUBMIT_LOGIN` into remote auth recovery.
- Updated docs:
  - `README.md`, `docs/setup-guide.md`, and `docs/troubleshooting.md` now document unattended credential+guard re-auth usage.

Assessment update:

- MSFS runtime path remains validated; current blocker remains Steam authentication state.
- Remote automation now supports full unattended re-auth when credentials and (if required) Steam Guard code are provided.

## 2026-02-28 (13:07-13:10 UTC, live DGX: remote auth-recovery evidence hardening)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=90 ./scripts/90-remote-dgx-stable-check.sh`
  - run reached auth gate and exited with `exit 7` (`Steam session unauthenticated`).
  - remote evidence synced locally under:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130706Z/output/`
- `DGX_PASS=... AUTO_REAUTH_ON_AUTH_FAILURE=1 REAUTH_LOGIN_WAIT_SECONDS=20 ... ./scripts/90-remote-dgx-stable-check.sh`
  - remote re-auth timed out (`exit 2`) as expected in an unauthenticated session without Steam Guard code.
  - re-auth failure now emits `steam-debug-*.log/.png` and syncs evidence locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130939Z/output/steam-debug-20260228T131003Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130939Z/output/steam-debug-20260228T131003Z.png`

Repo hardening in this pass:

- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - added `AUTH_DEBUG_ON_REAUTH_FAILURE` (default `1`),
  - ensures remote `output/` exists before auth-gate checks,
  - captures `11-debug-steam-window-state.sh` diagnostics when `58-ensure-steam-auth.sh` fails,
  - preserves non-zero auth-recovery exit code while still enabling evidence fetch.
- Updated `scripts/11-debug-steam-window-state.sh`:
  - now auto-resolves active display using `lib-display.sh` when `DISPLAY_NUM` is not set.

Assessment update:

- Current launch blocker remains Steam auth state (session logged out).
- Remote unattended runs are now more diagnosable because auth-recovery failures always produce synced debug artifacts.

## 2026-02-28 (13:02-13:05 UTC, live DGX: auth-gate diagnostics hardening + UI-signal trust fix)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - run reached auth gate and exited deterministically with `exit 7` (`Steam session unauthenticated`).
  - remote evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130420Z/output/auth-state-2537590-20260228T130422Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130420Z/output/steam-debug-20260228T130422Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130420Z/output/steam-debug-20260228T130422Z.png`
- Re-ran after auth-detector patch:
  - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130448Z/output/auth-state-2537590-20260228T130450Z.log`
  - auth status now reports `unauthenticated` (not misleading `ui-only evidence`) when no visible Steam window exists.
- Verified remote fatal-policy override behavior:
  - `DGX_PASS=... ALLOW_UI_AUTH_FALLBACK=1 FATAL_EXIT_CODES='' MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=60 ./scripts/90-remote-dgx-stable-check.sh`
  - retry runner now shows `Fatal exit codes:` (empty) and exits with summary code `1` instead of hard-failing immediately with code `7`.

Repo hardening in this pass:

- Updated `scripts/54-launch-and-capture-evidence.sh`:
  - on auth-gate failure, now auto-runs `scripts/11-debug-steam-window-state.sh` (default `AUTH_DEBUG_ON_FAILURE=1`),
  - records debug artifact paths directly inside `auth-state-*.log`.
- Tightened `scripts/lib-steam-auth.sh` UI fallback:
  - requires visible Steam-related windows before using UI evidence,
  - treats visible `Sign in to Steam`/`Steam Guard` dialogs as unauthenticated,
  - avoids false `ui-only evidence` reports when no window is visible.
- Updated docs:
  - `README.md` documents new auth-debug artifact capture.
  - `docs/troubleshooting.md` includes auth-debug outputs for exit-code `7` triage.
  - `README.md` now clarifies that `FATAL_EXIT_CODES=''` is honored as an explicit empty list.

Assessment update:

- Launch reliability remains blocked by real Steam logout/auth drift in current DGX session.
- Auth failures now carry deterministic UI/process evidence, improving remote recovery speed and reducing trust-boundary ambiguity.

## 2026-02-28 (12:59-13:05 UTC, live DGX: remote orchestrator policy passthrough hardening)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1`
  - trailing `KEY=VALUE` overrides are now accepted and applied.
  - run reached remote auth gate and exited deterministically with `exit 7` (`Steam session unauthenticated`), with evidence synced locally.
- `DGX_PASS=... ALLOW_UI_AUTH_FALLBACK=1 FATAL_EXIT_CODES=7 ./scripts/90-remote-dgx-stable-check.sh MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 WAIT_SECONDS=60`
  - remote runner consumed forwarded auth/retry policy and proceeded past auth gate to launch dispatch.
  - launch dispatch still not accepted in that session (`GameAction`/`StartSession` counters unchanged), verifier result: `no MSFS launch process detected after 60s`.
  - remote evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130020Z/output/dispatch-2537590-20260228T130022Z.log`
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T130020Z/output/verify-launch-2537590-20260228T130022Z.log`

Repo hardening in this pass:

- Updated `scripts/90-remote-dgx-stable-check.sh`:
  - accepts positional `KEY=VALUE` overrides for safer operator UX,
  - forwards `ALLOW_UI_AUTH_FALLBACK` to both `58-ensure-steam-auth.sh` and remote verification runners,
  - forwards `FATAL_EXIT_CODES` to remote verification runners so auth failures can be policy-tuned during recovery windows.
- Updated docs:
  - `README.md` now documents positional override support and remote auth/fatal policy passthrough.
  - `docs/troubleshooting.md` adds remote auth-gate examples, including temporary UI-fallback mode.

Assessment update:

- Runtime path remains healthy; current blocker remains Steam account auth state (`steamid=0`).
- Remote orchestration is now more controllable for unattended and semi-interactive recovery workflows, and launch acceptance failures are captured with deterministic, synced evidence.

## 2026-02-28 (12:52-12:57 UTC, live DGX: remote auth-recovery path added)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 STRICT_MIN_STABLE_SECONDS=60 STRICT_MAX_ATTEMPTS=2 STRICT_RECOVER_BETWEEN_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - baseline exited early with `RESULT: Steam session unauthenticated; launch skipped.`
  - remote evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T125249Z/output/auth-state-2537590-20260228T125251Z.log`

Repo hardening in this pass:

- Added `scripts/58-ensure-steam-auth.sh`:
  - ensures headless Steam stack is up,
  - checks existing auth state,
  - optionally types `STEAM_GUARD_CODE` via `xdotool`,
  - waits for authenticated session with bounded timeout.
- Extended `scripts/90-remote-dgx-stable-check.sh`:
  - `AUTO_REAUTH_ON_AUTH_FAILURE=1` runs remote auth recovery before stability verification
  - `STEAM_GUARD_CODE` and `REAUTH_LOGIN_WAIT_SECONDS` are passed through for unattended retries.
  - evidence fetch now handles pre-artifact exits cleanly (no failing `scp` when remote `output/` is absent).
- Tightened `scripts/lib-steam-auth.sh` trust boundary:
  - auth now requires strong Steam session evidence (`steamid` from process/log),
  - UI-only signal is explicitly treated as unauthenticated by default,
  - optional override remains available via `ALLOW_UI_AUTH_FALLBACK=1`.
- Updated README quick-start/examples and script index for the new auth gate.

Assessment update:

- Runtime verification path remains healthy; active blocker is Steam auth state.
- New remote auth gate closes the operational gap between "detected logged out" and "can resume unattended once code is available."
- Verified behavior with `REAUTH_LOGIN_WAIT_SECONDS=10`: run now fails deterministically at auth gate (`exit 2`) and exits cleanly.

## 2026-02-28 (12:38-12:51 UTC, live DGX: auth-drift root cause + fail-fast gating)

Live checks on `spark-de79` from this checkout:

- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 STRICT_MIN_STABLE_SECONDS=60 STRICT_MAX_ATTEMPTS=3 STRICT_RECOVER_BETWEEN_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - baseline failed with `RESULT: no MSFS launch process detected after 120s`
  - dispatch logs show repeat `failed to write launch URI to steam pipe within timeout`
- `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=2 RECOVER_BETWEEN_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - both attempts failed with no launch accepted
  - inter-attempt runtime recovery executed correctly
- Direct DGX `connection_log.txt` inspection identified root cause:
  - Steam session logged off at `2026-02-28 12:21:21 UTC`
  - state remained logged off (`ConnectionDisconnected() not auto reconnecting due to user initiated logoff`)

Repo hardening in this pass:

- Updated `scripts/19-dispatch-via-steam-pipe.sh`:
  - added bounded pipe-write retries (`PIPE_WRITE_RETRIES`, default `2`)
  - added optional inline timeout recovery (`PIPE_WRITE_RECOVER_ON_TIMEOUT=1`)
  - added optional URI fallback dispatch (`URI_FALLBACK_ON_PIPE_FAILURE=1`) while still requiring `GameAction`/`StartSession` evidence
- Updated `scripts/54-launch-and-capture-evidence.sh`:
  - added explicit Steam auth gate using `lib-steam-auth.sh`
  - writes `output/auth-state-*.log`
  - returns exit code `7` when unauthenticated
- Updated `scripts/55-run-until-stable-runtime.sh`:
  - added `FATAL_EXIT_CODES` (default `7`)
  - exits immediately on non-retryable auth failure instead of consuming retries

Validation:

- Re-ran remote proof check after patch:
  - `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=2 RECOVER_BETWEEN_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - now fails fast in attempt 1 with explicit auth diagnosis:
    - `RESULT: Steam session unauthenticated; launch skipped.`
    - `RESULT: non-retryable failure encountered (exit code 7)`
  - remote evidence synced locally:
    - `output/remote-runs/msfs-on-dgx-spark-run-20260228T125123Z/output/auth-state-2537590-20260228T125124Z.log`

Assessment update:

- Local-run proof remains established historically (multiple prior 30s stable-window passes).
- Current blocker is no longer ambiguous runtime behavior; it is explicit Steam auth drift and requires re-login/Steam Guard on DGX before launch verification can resume.

## 2026-02-28 (12:14-12:18 UTC, live DGX: strict-60 boundary confirmation + retry-recovery hardening)

Live staged check on `spark-de79` from this checkout:

- Command:
  - `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 STRICT_MIN_STABLE_SECONDS=60 STRICT_MAX_ATTEMPTS=2 ./scripts/90-remote-dgx-stable-check.sh`
- Baseline gate passed on attempt 1 (`>=30s` stable runtime).
- Strict gate failed on both attempts with consistent transient runtime:
  - `Strong runtime lifetime: ~35s (<60s)`
- Remote evidence:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T121438Z/output/verify-launch-2537590-20260228T121532Z.log`
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T121438Z/output/verify-launch-2537590-20260228T121640Z.log`
- Additional follow-up validations:
  - `...run-20260228T121928Z`: strict-recovery path executed (`steam-runtime-recover-...log` present), strict gate still failed.
  - `...run-20260228T123240Z`: recovery now triggers on `verify exit code: 2` and remote evidence sync completes cleanly.

Repo hardening in this pass:

- Added `scripts/57-recover-steam-runtime.sh`:
  - stops Steam/webhelper/pressure-vessel tree,
  - optionally moves `steamrt64/pv-runtime` and `steamrt64/var/tmp-*` aside,
  - relaunches `snap run steam -silent` in a single namespace,
  - waits for `steam.pipe` restoration and records a recovery log.
- Extended retry/staged/remote runners:
  - `scripts/55-run-until-stable-runtime.sh` now supports optional inter-attempt recovery:
    - `RECOVER_BETWEEN_ATTEMPTS=1`
    - `RECOVER_ON_EXIT_CODES` (default `2,3,4`)
  - `scripts/56-run-staged-stability-check.sh` now supports strict-only recovery toggle:
    - `STRICT_RECOVER_BETWEEN_ATTEMPTS=1`
  - `scripts/90-remote-dgx-stable-check.sh` now propagates recovery controls to remote runs.
- Follow-up fix from live test:
  - recovery backups are now stored under `steamrt64/recovery-backups/` (not `output/`) to keep remote evidence sync deterministic.
  - default `RECOVER_ON_EXIT_CODES` expanded to `2,3,4` so retry recovery also runs on `no launch observed`.
- Updated README with remote strict-recovery example and script index entries for `56`, `57`, and `90`.

Assessment update:

- Baseline local-run proof remains reproducible.
- Strict 60s stability remains the active boundary, but retries can now be configured to rebuild runtime state between attempts instead of reusing potentially contaminated namespaces.

## 2026-02-28 (12:03-12:09 UTC, live DGX: staged stability gating + fresh reproducibility)

Live validation on `spark-de79` with this checkout:

- Re-ran remote clean-check baseline with updated scripts:
  - `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 ./scripts/90-remote-dgx-stable-check.sh`
  - Result: success on attempt 1 (`verify exit code: 0`)
  - Remote run dir: `/home/th0rgal/msfs-on-dgx-spark-run-20260228T120630Z`
- Ran new staged reliability gate:
  - `DGX_PASS=... MIN_STABLE_SECONDS=30 MAX_ATTEMPTS=1 STRICT_MIN_STABLE_SECONDS=45 STRICT_MAX_ATTEMPTS=2 ./scripts/90-remote-dgx-stable-check.sh`
  - Baseline stage passed (30s stable window, attempt 1)
  - Strict stage failed after 2 attempts with consistent transient runtime (`~35s`, `<45s`)
  - Remote run dir: `/home/th0rgal/msfs-on-dgx-spark-run-20260228T120732Z`

Repo hardening in this pass:

- Added `scripts/56-run-staged-stability-check.sh`:
  - Stage 1 proves baseline local-run health (`BASELINE_MIN_STABLE_SECONDS`, `BASELINE_MAX_ATTEMPTS`)
  - Stage 2 probes higher confidence stability (`STRICT_MIN_STABLE_SECONDS`, `STRICT_MAX_ATTEMPTS`)
  - Returns explicit boundary: baseline pass + strict fail (`exit 3`) instead of conflating outcomes
- Extended `scripts/90-remote-dgx-stable-check.sh`:
  - supports optional staged mode when `STRICT_MIN_STABLE_SECONDS` is set
  - preserves existing behavior when strict mode is unset
  - always fetches remote `output/` evidence even when remote verification exits non-zero
    (validated with strict-gate failure run: `/home/th0rgal/msfs-on-dgx-spark-run-20260228T121143Z` copied locally)
- Updated README/setup guidance to document staged remote checks and trust-boundary interpretation.

Assessment update:

- \"MSFS can run locally on DGX Spark\" remains reproducibly true at 30s stability.
- Long-window stability remains the active reliability gap, now tracked by an explicit strict gate.

## 2026-02-28 (11:56-11:58 UTC, live DGX: fresh proof run + remote sync hardening)

Live reproducibility check on `spark-de79` from this checkout:

- Ran `scripts/90-remote-dgx-stable-check.sh` with stricter target:
  - `MIN_STABLE_SECONDS=30`
  - `MAX_ATTEMPTS=1`
- Result: success on attempt 1 (`verify exit code: 0`).
- Post-patch re-run of the same command also succeeded on attempt 1:
  - remote run dir: `/home/th0rgal/msfs-on-dgx-spark-run-20260228T115854Z`
  - verify log: `/home/th0rgal/msfs-on-dgx-spark-run-20260228T115854Z/output/verify-launch-2537590-20260228T115856Z.log`
- Remote evidence:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T115633Z/output/dispatch-2537590-20260228T115636Z.log`
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T115633Z/output/verify-launch-2537590-20260228T115636Z.log`
- Local synced evidence:
  - `output/remote-runs/msfs-on-dgx-spark-run-20260228T115633Z/output/`

Repo hardening in this pass:

- Updated `scripts/90-remote-dgx-stable-check.sh` packaging to exclude local artifact/cache directories (`output/`, `.venv`, `venv`, `node_modules`) during sync tar creation.
- This keeps remote validation runs faster and more deterministic while preserving the same execution path on DGX.

## 2026-02-28 (11:52-11:54 UTC, live DGX: stricter reproducibility + local evidence sync)

Live validation on `spark-de79` from this workspace with stricter stability criteria:

- Verified device health (`aarch64`, `NVIDIA GB10`, driver `580.95.05`).
- Ran remote reproducibility check twice at `MIN_STABLE_SECONDS=30`:
  - first run: `MAX_ATTEMPTS=3` -> success on attempt 1
  - second run (post-script patch): `MAX_ATTEMPTS=1` -> success on attempt 1
- Remote evidence from the patched run:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T115343Z/output/dispatch-2537590-20260228T115355Z.log`
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T115343Z/output/verify-launch-2537590-20260228T115355Z.log`

Repo hardening:

- Improved `scripts/90-remote-dgx-stable-check.sh`:
  - resolves and prints the concrete remote run directory before execution,
  - adds `FETCH_EVIDENCE=1` (default) to copy remote `output/` bundle into local:
    - `output/remote-runs/<run-dir>/output`
  - keeps passwordless behavior unchanged and still supports `DGX_PASS` + `sshpass`.

Assessment update:

- "MSFS can run locally on DGX Spark" remains reproducible and now has a tighter default operational proof point (30s stable-runtime target validated in this pass) plus automatic local evidence retrieval.

## 2026-02-28 (11:50 UTC)

Live reproducibility check on `spark-de79` using a fresh synced checkout:

- Verified SSH/device status (`Linux aarch64`, driver `580.95.05`, GPU `NVIDIA GB10`).
- Synced local repo snapshot to a clean remote run dir:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T114851Z`
- Ran:
  - `MIN_STABLE_SECONDS=20 MAX_ATTEMPTS=2 WAIT_SECONDS=120 ./scripts/55-run-until-stable-runtime.sh`
- Result:
  - `verify exit code: 0`
  - `RESULT: stable runtime achieved on attempt 1`
- Artifacts:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T114851Z/output/retry-attempt-2537590-20260228T114856Z-a1.log`
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T114851Z/output/verify-launch-2537590-20260228T114856Z.log`
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T114851Z/output/dispatch-2537590-20260228T114856Z.log`

Repo hardening:

- Added `scripts/90-remote-dgx-stable-check.sh` so any local checkout can:
  1. package and upload itself to DGX,
  2. run stable-runtime verification remotely, and
  3. print remote evidence paths.

## 2026-02-28 (11:46 UTC)

Live validation on `spark-de79` after hardening script display selection:

- Added `scripts/lib-display.sh` with resilient display resolution:
  - uses `DISPLAY_NUM` override when provided
  - falls back to `00-select-msfs-display.sh` when available
  - otherwise auto-detects active displays (`:2`, `:1`, `:0`, `:3`) and finally active `Xvfb`
- Wired the helper into core entrypoints:
  - `scripts/05-resume-headless-msfs.sh`
  - `scripts/06-verify-msfs-state.sh`
  - `scripts/07-await-login-and-install.sh`
  - `scripts/08-finalize-auth-and-run-msfs.sh`
  - `scripts/09-verify-msfs-launch.sh`
  - `scripts/54-launch-and-capture-evidence.sh`

Why this matters:

- Launch/evidence scripts no longer hard-fail when `00-select-msfs-display.sh` is missing in older checkouts or ad-hoc runtime copies.
- This removed the immediate blocker observed on host (`No such file or directory` on the display helper) and restored unattended launch verification.

Fresh runtime evidence from this pass:

- `MSFS_APPID=2537590 WAIT_SECONDS=60 MIN_STABLE_SECONDS=20 ./scripts/54-launch-and-capture-evidence.sh`
- Exit code: `0`
- Verifier output: `RESULT: MSFS reached stable runtime (>=20s)`
- Strong process evidence included:
  - `.../Proton - Experimental/.../wine64 c:\\windows\\system32\\steam.exe .../MSFS2024/FlightSimulator2024.exe`
  - `Z:\\...\\MSFS2024\\FlightSimulator2024.exe`
- Artifacts:
  - `output/dispatch-2537590-20260228T114630Z.log`
  - `output/verify-launch-2537590-20260228T114630Z.log`
  - `output/content-state-2537590-20260228T114630Z.log`
  - `output/compat-state-2537590-20260228T114630Z.log`

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

## 2026-02-28 (preflight hardening pass)

Added a tracked runtime preflight repair path to improve first-frame reliability on DGX Spark:

- New `scripts/53-preflight-runtime-repair.sh` to apply the recurring fixes before launch:
  - installs host `pv-adverb` FEX wrapper when missing
  - syncs pressure-vessel Vulkan override manifests into `/usr/lib/pressure-vessel/overrides/share/vulkan`
  - repairs MSFS 2024 package bootstrap paths and `UserCfg.opt` to canonical `MSFS2024/Packages`
  - enforces hardened per-app launch options to disable problematic imported Vulkan layers in pressure-vessel
- Wired preflight into `scripts/08-finalize-auth-and-run-msfs.sh` so each one-shot run applies repairs automatically.

Goal of this pass:

- Convert previously manual/experimental recovery steps into a repeatable, tracked launch path for DGX runs.

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

## 2026-02-27 (23:19-23:29 UTC, clean Valve+SLR/seccomp check and NVIDIA-only ICD retries)

This cycle targeted two untried causes:

1. Residual GE contamination / wrapper contamination in Valve Experimental path.
2. Wrong ICD/device path inside pressure-vessel causing DX12 device creation failure.

What was tried:

- Added `scripts/32-test-clean-valve-slr0-seccomp.sh` to run a clean-cycle test:
  - restore pristine Valve `Proton - Experimental/proton`
  - set local launch options (`STEAM_LINUX_RUNTIME=0`, `WINE_DISABLE_SECCOMP=1`, Proton log)
  - dispatch via `steam.pipe` and capture state.
- Added `scripts/33-wrap-valve-exp-nvidia-icd.sh` to force for MSFS only:
  - NVIDIA-only ICD JSON (`/tmp/nvidia-only-icd.json`)
  - NVIDIA-only library dir (`/tmp/nvlibs64` symlink set)
  - `VK_ICD_FILENAMES` / `VK_DRIVER_FILES` and Proton logging.
- Added one more wrapper variant in the same script to test reduced vkd3d requirements:
  - `VKD3D_FEATURE_LEVEL=12_0`
  - `VKD3D_CONFIG=nodxr`
  - explicit ray-tracing extension disables.

Key findings:

- In clean Valve path, compat prefix is now consistently true Valve Experimental (`.../steamapps/common/Proton - Experimental/proton`) and not GE.
- Localconfig launch options are still not reliably applied in this headless path; wrapper-based env injection remains the reliable method.
- NVIDIA-only ICD wrapper did change runtime behavior materially:
  - Proton log now consistently reports `Found device: NVIDIA Tegra NVIDIA GB10 (NVIDIA 580.95.5)`.
  - Failure code changed from prior `0x80070057` path to `D3D12CreateDevice failed with error code 80004005`.
- Root failure remains unchanged at the device-init layer:
  - `vkd3d_create_vk_device: Failed to create Vulkan device, vr -3`.
  - Even with `VKD3D_CONFIG=nodxr` and reduced extension set, device creation still fails.
- Runtime popup still present on Xvfb:
  - `Fatal error: Impossible to create DirectX12 device`
  - `Error 0x80004005 (DXGI Unknown)`.

Assessment update:

- We are now reliably on NVIDIA adapter selection in Proton and have ruled out a large chunk of previous compat contamination.
- Remaining blocker is lower-level Vulkan device creation under vkd3d on this ARM+FEX+Steam Runtime stack (`vr -3`), not dispatch/auth/tool selection.

Artifacts:

- `output/clean-valve-slr0-seccomp-20260227T231948Z.log`
- `output/nvidia-icd-wrapper-cycle-20260227T232418Z.log`
- `output/manual-check-20260227T232154Z.png`
- `output/manual-check-20260227T232628Z.png`
- `output/manual-check-20260227T232926Z.png`
- `output/steam-2537590.log`

## 2026-02-27 (23:43-23:51 UTC, present_id/present_wait + hard no-overlay native tests)

This cycle targeted two untried likely causes of the DX12 device-init failure:

1. `vkd3d` Vulkan device creation instability related to present extensions (`VK_KHR_present_id` / `VK_KHR_present_wait`).
2. Steam overlay injection (`gameoverlayrenderer.so`) in the native FEX + pressure-vessel path.

What was tried:

- Added `scripts/34-test-vkd3d-presentid-disable.sh`:
  - wraps Valve Proton Experimental,
  - applies `VKD3D_CONFIG=nodxr`, `VKD3D_FEATURE_LEVEL=12_0`,
  - disables `VK_KHR_present_id`, `VK_KHR_present_wait`, `VK_NVX_binary_import`, `VK_NVX_image_view_handle`,
  - launches via `steam.pipe` after native FEX Steam startup.
- Added `scripts/35-test-native-no-overlay.sh`:
  - temporarily moves both overlay renderer `.so` files out of place,
  - strips `LD_PRELOAD` in Proton wrapper,
  - relaunches and captures Xvfb screenshot state,
  - restores overlay files on exit.

Results:

- Dispatch/session creation remained reliable (`GameAction` and `StartSession` advanced in both tests).
- Fatal startup popup still reproduced in both runs (captured on Xvfb):
  - `Impossible to create DirectX12 device`
  - `Error 0x80004005 (DXGI Unknown)` in present-extension test screenshot.
  - `Error 0x80070057 (DXGI Unknown)` in hard no-overlay test screenshot.
- No fresh Asobo crash report was generated in this window; behavior remained pre-frame/device-init failure.

Artifacts:

- `output/vkd3d-presentid-disable-cycle-20260227T234345Z.log`
- `output/vkd3d-presentid-disable-cycle-20260227T234611Z.log`
- `output/native-xvfb3-msfs-20260227T234846Z.png`
- `output/native-no-overlay-cycle-20260227T234939Z.log`
- `output/native-no-overlay-20260227T234939Z.png`

Assessment update:

- Disabling `present_id/present_wait` did not clear DX12 init failure on this stack.
- Hard overlay disable + `LD_PRELOAD` stripping did not clear DX12 init failure either.
- Remaining blocker is still low-level DXGI/D3D12 device creation under ARM+FEX+Proton runtime on this environment.

## 2026-02-28 (00:09-00:13 UTC, sniper entrypoint pass-through A/B)

New untried hypothesis:
- `vkd3d` failure could be caused by Steam Linux Runtime (sniper/pressure-vessel) containerization around Proton.

What was tried:
- Added `scripts/36-test-sniper-entrypoint-bypass.sh`.
- Temporarily replaced `SteamLinuxRuntime_sniper/_v2-entry-point` with a pass-through wrapper for this run only (restored on exit).
- Re-launched via native FEX Steam + `steam.pipe` dispatch.

What changed:
- For the game path, `srt-bwrap`/`pv-adverb` were bypassed; Proton launched directly under FEX for MSFS.
- A fresh running-session crash marker remained pre-frame:
  - `Where="CrashReport_Z::Init"`
  - `FrameCount=0`
  - `LastStates="<no global flow>@"`
  - latest observed `TimeUTC=2026-02-28T00:10:46Z`
- Fatal popup still present in screenshot:
  - `Impossible to create DirectX12 device`
  - `0x80070057 (DXGI Unknown)`

Artifacts:
- `output/sniper-entrypoint-bypass-cycle-20260228T000953Z.log`
- `output/sniper-entrypoint-bypass-20260228T000953Z.png`

Assessment update:
- Pressure-vessel containerization for the game process is not the primary blocker.
- Failure remains at pre-frame DX12/DXGI init on this stack.

## 2026-02-28 (00:15-00:18 UTC, FEX hypervisor-bit hide retest)

New untried hypothesis:
- Early init/DRM may react to emulation fingerprinting (`hypervisor` CPUID bit and mixed CPU identity in crash reports).

What was tried:
- Updated `scripts/27-launch-native-fex-steam-on-snap-home.sh` to launch Steam with:
  - `FEX_HIDEHYPERVISORBIT=1`
- Added `scripts/37-test-hide-hypervisor-runtime.sh` to validate flag behavior and run full launch cycle.
- Also updated `scripts/26-enable-userns-and-fex-thunks.sh` to persist current FEX config shape with `HideHypervisorBit` key.

Validation:
- `FEX_HIDEHYPERVISORBIT=1 FEXBash ... /proc/cpuinfo` removes `hypervisor` flag as expected.
- Launch dispatch remained accepted and app process stayed alive through the observation window.
- No newer crash file replaced the latest running-session crash marker (`TimeUTC=2026-02-28T00:10:46Z`).
- Live screenshot still shows same fatal dialog:
  - `Impossible to create DirectX12 device`
  - `0x80070057 (DXGI Unknown)`

Artifacts:
- `output/hide-hypervisor-cycle-20260228T001533Z.log`
- `output/hide-hypervisor-20260228T001533Z.png`
- `output/hide-hypervisor-postcheck-20260228T001802Z.png`

Assessment update:
- Hiding CPUID hypervisor bit did not clear DX12 device creation failure.
- Remaining blocker is still runtime/platform compatibility at DXGI/D3D12 init under ARM+FEX+Proton.

## 2026-02-28 (00:32-00:44 UTC, NVIDIA X display path with virtual monitor)

New hypothesis tested:
- Prior runs were predominantly on Xvfb (`:1`/`:3`) with llvmpipe; MSFS might require a real GPU-backed X display + monitor target for DXGI device init.

What was tried:
- Verified display topology and rendering paths:
  - `:0` and a custom `:2` Xorg use NVIDIA GL (`OpenGL renderer: NVIDIA Tegra NVIDIA GB10`), while `:1`/`:3` are llvmpipe.
  - `:0` had `Monitors: 0` (no active output).
- Started dedicated NVIDIA Xorg on `:2` and created a virtual monitor object:
  - `DISPLAY=:2 xrandr --setmonitor HEADLESS 1920/520x1080/320+0+0 none`
- Ran a clean launch cycle on `DISPLAY=:2` after hard-killing stale `2537590` processes and forcing DX11 launch args via Proton wrapper.

Result:
- Launch dispatch/session creation remains reliable.
- Fresh running-session crash marker still reproduces at init:
  - `Where="CrashReport_Z::Init"`
  - `FrameCount=0`
  - `CmdLine=["-dx11","-FastLaunch"]`
  - `TimeUTC=2026-02-28T00:43:32Z`
- MSFS process tree can stay alive for minutes, but it remains in the same pre-frame init failure state.

Conclusion from this cycle:
- Moving from llvmpipe/Xvfb to NVIDIA X server with a virtual monitor did not clear the boot failure.
- Blocker remains pre-frame runtime/init compatibility on ARM+FEX+Proton.

Artifacts:
- `output/display0-cycle-20260228T003232Z.log`
- `output/display2-headlessmon-cycle-20260228T003905Z.log`
- `output/display2-cleanrun-20260228T004259Z.log`
- `output/steam-2537590.log`

Repo updates:
- Added `scripts/38-test-display2-headless-monitor-cycle.sh`.

## 2026-02-28 (01:00-01:03 UTC, display :2 + attempted SLR=0)

New hypothesis tested:
- If we disable Steam Linux Runtime (`STEAM_LINUX_RUNTIME=0`) on the NVIDIA-backed display path, the game may avoid the failing runtime/container combination.

What was tried:
- Added `scripts/39-test-display2-slr0-d3d12.sh`.
- Ran native FEX Steam on `DISPLAY=:2`, restored pristine Proton Experimental, and injected launch options via localconfig:
  - `STEAM_LINUX_RUNTIME=0 PROTON_LOG=1 ... %command% -FastLaunch`
- Dispatched launch via `steam.pipe` and captured process/compat state and running-session crash marker.

Result:
- Dispatch accepted (`GameAction` and `StartSession` increased).
- Steam still launched with sniper + pressure-vessel in effective command prefix (`waitforexitandrun` path unchanged).
- `PROTON_LOG` did not materialize in this cycle, and app cmdline in running-session stayed empty.
- Crash signature unchanged:
  - `Where="CrashReport_Z::Init"`
  - `FrameCount=0`
  - `Cpu="GenuineIntel"`, `Brand="Cortex-X925"`
  - `TimeUTC=2026-02-28T01:02:02Z`

Artifacts:
- `output/display2-slr0-d3d12-cycle-20260228T010049Z.log`
- `output/display2-slr0-d3d12-20260228T010049Z.png`

Assessment update:
- localconfig LaunchOptions are not a reliable control plane in this session for runtime selection/args.
- Effective launch path remains sniper/containerized regardless of attempted `SLR=0` launch options.

## 2026-02-28 (01:05-01:08 UTC, sniper-entrypoint-bypass retest on display :2)

New hypothesis tested:
- Re-running the sniper-entrypoint bypass on NVIDIA display `:2` may differ from prior `:3` cycles and clear boot init.

What was tried:
- Re-ran `scripts/36-test-sniper-entrypoint-bypass.sh` with `DISPLAY_NUM=:2`.
- Verified launcher dispatch and observed live process tree.

Result:
- Dispatch accepted, but runtime remained containerized (`srt-bwrap`/`pv-adverb` still present in game process tree).
- No evidence of bypass altering effective runtime topology for MSFS launch.
- The game remained in the same pre-frame init failure mode (no end-to-end boot achieved).

Assessment update:
- On this stack, entrypoint wrapper bypass does not remove pressure-vessel from the actual MSFS launch chain.
- The blocker remains runtime/platform compatibility before first frame.

## 2026-02-28 (source inspection: FEX CPUID override limits)

What was checked:
- Inspected current FEX source (`FEXCore/Source/Interface/Core/CPUID.cpp`) to verify whether brand/vendor can be overridden through config/env.

Finding:
- `FEX_CPUFEATUREREGISTERS` only maps to ARM ID-register feature parsing (`isar*`, `pfr*`, `midr`, etc.) and does **not** provide a direct x86 brand/vendor override hook.
- CPUID brand string is derived from `PerCPUData.ProductName` populated from host MIDR mapping, so full Intel/AMD brand spoofing is not configurable via current exposed FEX options.

Assessment update:
- "Full CPUID brand/vendor spoofing" is not currently achievable in this environment using exposed FEX runtime config alone.

## 2026-02-28 (02:15-02:35 UTC, CachyOS retest and layout patch)

What was tried:
- Added `scripts/43-test-cachyos-cleanprefix-display2.sh` and `scripts/44-test-cachyos-cleanprefix-nowrapper.sh` for clean-prefix CachyOS cycles on `DISPLAY=:2`.
- Added `scripts/45-fix-cachyos-layout-and-test.sh` to patch ARM package layout mismatches in `proton-cachyos-10.0-20260207-slr-arm64`:
  - `files/share/default_pfx -> default_pfx_arm64`
  - `files/bin -> bin-arm64`
  - `files/lib64 -> lib`
- Added `scripts/46-direct-cachyos-run-cycle.sh` for direct Proton invocation outside Steam dispatch for deeper logging.

Key findings:
- Before layout patch, CachyOS failed almost immediately with:
  - `Proton: Default prefix is missing, something is very wrong.`
- After layout patch, the prefix initializes successfully and this error disappears in later runs.
- Despite that fix, Steam-dispatched launches still exit in ~3-4 seconds and `AppData/Roaming/Microsoft Flight Simulator 2024` is not populated.
- Direct manual `proton waitforexitandrun FlightSimulator2024.exe` reaches deeper runtime stages and stays alive longer, but screenshot shows a Wine assertion dialog:
  - `Assertion failed!`
  - `File: steamclient_main.c`
  - `Expression: "!status"`

Artifacts:
- `output/cachyos-cleanprefix-display2-cycle-20260228T021633Z.log`
- `output/cachyos-cleanprefix-nowrapper-cycle-20260228T022212Z.log`
- `output/cachyos-layoutfix-cycle-20260228T022557Z.log`
- `output/direct-cachyos-run-20260228T023049Z.log`
- `output/direct-cachyos-run-20260228T023049Z.png`

Assessment update:
- There are at least two independent blockers in this ARM+FEX+CachyOS path:
  1. CachyOS ARM layout mismatch (partially fixed with symlinks), and
  2. Steam client runtime/assertion failure (`steamclient_main.c`, `!status`) during/after deeper initialization.
- End-to-end boot to first frame is still not achieved.

## 2026-02-28 (02:43-02:55 UTC, launcher-service/vulkan-layer controls + clean-prefix revalidation)

New hypotheses tested:

1. Force Steam runtime path selection and Vulkan-layer behavior via LaunchOptions/env:
   - `STEAM_COMPAT_LAUNCHER_SERVICE=proton`
   - `PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0`
   - `PRESSURE_VESSEL_REMOVE_GAME_OVERLAY=1`
2. Clear runtime contamination by restoring real Valve `Proton - Experimental` and re-running with a clean prefix.
3. Hard-force pressure-vessel env by wrapping sniper `_v2-entry-point` (instead of relying on LaunchOptions propagation).

What was added:

- `scripts/47-test-launcher-service-proton-vk-layers-off.sh`
- `scripts/48-test-valve-exp-cleanprefix-display2.sh`
- `scripts/49-test-sniper-entrypoint-force-vk-layer-off.sh`

Key results:

- `STEAM_COMPAT_LAUNCHER_SERVICE=proton` in launch options did **not** change effective launcher chain.
  - Compat logs still show `SteamLinuxRuntime_sniper/_v2-entry-point` + pressure-vessel command prefixes for tool `1493710`.
- Forcing `PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0` (both launch options and `_v2-entry-point` wrapper) did **not** eliminate repeated pressure-vessel Vulkan layer import errors.
  - `pressure-vessel-wrap ... Internal error: ... is not in /usr/lib/pressure-vessel/overrides/share/vulkan/...` persisted.
- Restoring real Valve Experimental changed tool path back from CachyOS and one run reached longer process lifetime, but still failed pre-frame.
  - Running session remained in init state (`Where="CrashReport_Z::Init"`, `FrameCount=0`, `LastStates="<no global flow>@"`, latest observed around `2026-02-28T02:48:53Z`).
- Clean-prefix revalidation did not produce end-to-end boot; short-run exits and install-script evaluator churn remained.
- New risk discovered: runtime tool churn can contaminate prefixes across Proton variants (seen as `Prefix has an invalid version?!` before clean-prefix reset).

Artifacts:

- `output/launchsvc-proton-vklayersoff-cycle-20260228T024344Z.log`
- `output/launchsvc-proton-vklayersoff-20260228T024344Z.png`
- `output/valve-exp-cleanprefix-display2-cycle-20260228T025059Z.log`
- `output/valve-exp-cleanprefix-display2-20260228T025059Z.png`
- `output/sniper-entrypoint-vklayeroff-cycle-20260228T025433Z.log`
- `output/sniper-entrypoint-vklayeroff-20260228T025433Z.png`

Assessment update:

- These untried control-plane fixes did not unblock startup.
- Remaining blocker is still runtime/platform compatibility in this ARM+FEX+Steam Runtime stack before first frame, not Steam dispatch/auth.

## 2026-02-28 (03:03 UTC, strict Vulkan-loader layer-disable cycle script)

New untried hypothesis prepared:

- Previous layer-disable attempts used `VK_LOADER_LAYERS_DISABLE='*'`, which may be ignored by the Vulkan loader.
- A stricter loader-level disable path may suppress pressure-vessel Vulkan layer import faults and allow D3D12 device creation to progress.

What was added:

- `scripts/50-test-valve-exp-vkloader-strict-layer-disable.sh`
  - clean-prefix Valve Experimental cycle on `DISPLAY=:2`
  - launch options include:
    - `VK_LOADER_LAYERS_DISABLE=~implicit~`
    - `DISABLE_VK_LAYER_VALVE_steam_overlay_1=1`
    - `DISABLE_VK_LAYER_MESA_device_select=1`
    - `VK_LAYER_PATH=` and `VK_ADD_LAYER_PATH=`
    - `PRESSURE_VESSEL_IMPORT_VULKAN_LAYERS=0`
    - `PRESSURE_VESSEL_REMOVE_GAME_OVERLAY=1`

Execution status in this workspace:

- Could not run the cycle here because no Steam state/runtime tree exists at:
  - `/root/snap/steam/common/.local/share/Steam`
- Script exits early with:
  - `ERROR: Steam dir not found: /root/snap/steam/common/.local/share/Steam`
- A broader search in `/home`, `/root`, and `/workspaces` found no `.local/share/Steam` directory on this machine.

Assessment update:

- The strict layer-disable experiment is now scripted and ready, but runtime validation is blocked in this environment.
- It must be executed on `spark-de79` (or equivalent host with Steam state present) to determine if DX12 init behavior changes.

## 2026-02-28 (05:58 UTC, dispatch hardening + single-namespace recovery cycle)

New likely fix path addressed:

- The latest blocker sequence shows Steam launch-control breakage before MSFS runtime init:
  - intermittent/blocked `steam.pipe` writes,
  - webhelper/bootstrap instability,
  - stale mixed runtime namespaces.
- Most likely untried remediation is a strict single-runtime startup path (`snap run steam`) with runtime-root rebuild before dispatch.

Changes made:

- Hardened `scripts/19-dispatch-via-steam-pipe.sh`:
  - added `PIPE_WRITE_TIMEOUT_SECONDS` (default `3`) so writes to `steam.pipe` cannot hang indefinitely,
  - emits a focused process snapshot on timeout.
- Added `scripts/51-test-single-namespace-runtime-rebuild-dispatch.sh`:
  - kills existing Steam/webhelper/pressure-vessel tree,
  - non-destructively moves `steamrt64/pv-runtime` and `steamrt64/var/tmp-*` aside,
  - relaunches Steam strictly through `snap run steam -silent` in one namespace,
  - waits for pipe restoration, dispatches via script `19`, and captures auth/dispatch/webhelper evidence.

Execution in this workspace:

- Script run attempted with explicit repo/output overrides.
- This machine does not have Steam Snap state at expected path, so cycle exits early:
  - `ERROR: Steam dir not found: /root/snap/steam/common/.local/share/Steam`

Assessment update:

- The next most likely fix has now been encoded as a reproducible cycle.
- End-to-end validation remains blocked in this workspace and must run on `spark-de79` (or an equivalent host that has active Steam Snap state and logs).

## 2026-02-28 (10:49-10:55 UTC, live DGX retest + dispatch log-path hardening)

Live validation on `spark-de79` against the current runtime state:

- Re-ran latest package/bootstrap trace flow (`scripts/53-trace-msfs-package-probes-and-retest.sh` in remote working copy).
- Bootstrap confirms MSFS 2024 package content is present under canonical tree (`markers=260`) and symlink bridge/UserCfg path rewrites are applied.
- Dispatch is currently blocked upstream of game launch due to Steam runtime/webhelper instability in this session:
  - repeated `bwrap: execvp /usr/lib/pressure-vessel/from-host/libexec/steam-runtime-tools-0/pv-adverb: No such file or directory`
  - no new `StartSession` accepted after this loop begins.

Repo hardening applied here:

- Updated `scripts/19-dispatch-via-steam-pipe.sh` to avoid false negatives on newer Steam builds:
  - auto-selects freshest active console log (`console-linux.txt` vs `console_log.txt`),
  - supports optional positional launch URI override,
  - keeps compat-log-based acceptance checks even if console log path rotated.

Why this matters:

- Prior script behavior could report `RESULT: no launch session accepted` even when Steam had moved to `console-linux.txt`, masking real runtime state.
- Current retest output now reflects actual launch acceptance state instead of stale-log artifacts.

Current highest-priority blocker:

- pressure-vessel webhelper startup is stuck on missing `pv-adverb` execution path in runtime context, preventing reliable dispatch consumption and making launch attempts nondeterministic.

## 2026-02-28 (10:56-11:01 UTC, live DGX: pv-adverb shim validation + finalize hardening)

Live DGX validation on `spark-de79` confirmed and improved the current launch path:

- Reproduced the active webhelper failure loop in `webhelper-linux.txt`:
  - `bwrap: execvp /usr/lib/pressure-vessel/from-host/libexec/steam-runtime-tools-0/pv-adverb: No such file or directory`
- Verified that this path can be recovered by providing a host-side `pv-adverb` wrapper and re-testing under Steam's `_v2-entry-point`.
- After shimmed `pv-adverb` recovery, webhelper startup progressed (no repeated `execvp ... pv-adverb` loop), and Steam resumed accepting pipe dispatches for `AppID 2537590`.
- Confirmed fresh launch acceptance via `scripts/19-dispatch-via-steam-pipe.sh`:
  - `StartSession` count increased (`before=158`, `after=160`)
  - `AppID 2537590 state changed : Fully Installed,App Running`

Repo updates from this pass:

- Added `scripts/52-install-pvadverb-fex-wrapper.sh`:
  - installs `/usr/lib/pressure-vessel/from-host/libexec/steam-runtime-tools-0/pv-adverb` as a host wrapper running x86 helper through `FEXInterpreter`,
  - keeps backup of any previous host shim.
- Hardened `scripts/08-finalize-auth-and-run-msfs.sh`:
  - supports `ALLOW_OFFLINE_LAUNCH_IF_INSTALLED=1` (default) to continue when Steam auth detection is flaky but manifest is fully downloaded,
  - skips install URI step if manifest already indicates full download,
  - prefers pipe dispatch (`scripts/19-dispatch-via-steam-pipe.sh`) for launch to avoid fragile URI dispatch.

Current blocker after this pass:

- End-to-end "first frame" MSFS stability is still constrained by runtime/graphics init compatibility on ARM+FEX+Proton.
- However, launch control path reliability improved: install state persists, webhelper loop is recoverable, and dispatch/session creation is again deterministic.

## 2026-02-28 (11:11-11:14 UTC, live DGX: stable-runtime verification hardening)

Live retest on `spark-de79` with current scripts:

- Install/auth path remains healthy for MSFS 2024 (`AppID 2537590`):
  - manifest present and fully downloaded (`BytesDownloaded == BytesToDownload`)
  - Steam session authenticated in UI and launch dispatch accepted.
- Existing launch verification was too optimistic: it could report success on short-lived wrapper processes.

Repo hardening applied:

- `scripts/09-verify-msfs-launch.sh`
  - now distinguishes wrapper-only launch signals from strong runtime signals,
  - requires a configurable stability window (`MIN_STABLE_SECONDS`, default 30s),
  - returns explicit `transient launch` failure when processes exit before stability.
- `scripts/08-finalize-auth-and-run-msfs.sh`
  - passes `LAUNCH_MIN_STABLE_SECONDS` through to launch verification,
  - updates step numbering and failure messaging to reflect stable-runtime criteria.

Live validation result after patch (`LAUNCH_MIN_STABLE_SECONDS=20`):

- Launch reached wrapper/runtime startup but exited before stable runtime.
- New verifier correctly reported:
  - `RESULT: transient launch only; processes exited before stability window`
  - `Wrapper-only lifetime: ~5s`

Assessment update:

- The launch-control path is reproducible; the blocker is now explicitly measured as a pre-stability runtime exit, not a false positive "running" state.

## 2026-02-28 (11:17-11:23 UTC, GPU-display defaulting + dx11 decontamination pass)

Live DGX validation on `spark-de79` with a fresh isolated checkout:

- Confirmed display topology at runtime:
  - `:2` is NVIDIA-backed (`OpenGL renderer: NVIDIA Tegra NVIDIA GB10/PCIe`)
  - `:1`/`:3` are llvmpipe/Xvfb.
- Added `scripts/00-select-msfs-display.sh` and wired default display selection into:
  - `scripts/05-resume-headless-msfs.sh`
  - `scripts/06-verify-msfs-state.sh`
  - `scripts/08-finalize-auth-and-run-msfs.sh`
  - `scripts/09-verify-msfs-launch.sh`
- Hardened preflight (`scripts/53-preflight-runtime-repair.sh`) to restore pristine Proton entrypoints when earlier wrapper experiments injected forced flags (`-dx11`, `PROTON_USE_WINED3D`, etc.).
- Re-ran finalize flow live:
  - Effective launch no longer includes forced `-dx11` for AppID `2537590`.
  - Verification captured strong runtime processes for MSFS 2024.
  - One run reached stable runtime at `MIN_STABLE_SECONDS=10` (success).
  - A stricter run with `MIN_STABLE_SECONDS=30` reached ~25s strong runtime lifetime before exit.

Current state after this pass:

- Launch path now defaults to GPU-backed display and avoids stale DX11 wrapper contamination.
- Runtime behavior improved from short wrapper-only launches to measurable strong runtime windows (10-25s in this pass), but first-frame long-stability proof is still pending under current ARM+FEX+Proton stack.

## 2026-02-28 (11:24-11:28 UTC, auth-detection hardening + live stable-runtime pass)

Live DGX validation on `spark-de79` identified and fixed a reliability gap in launch orchestration:

- `scripts/08-finalize-auth-and-run-msfs.sh` could incorrectly fall back to offline mode when `steamwebhelper` reported `-steamid=0` despite a logged-in Steam session.
- Added shared auth helper `scripts/lib-steam-auth.sh` and wired it into:
  - `scripts/06-verify-msfs-state.sh`
  - `scripts/07-await-login-and-install.sh`
  - `scripts/08-finalize-auth-and-run-msfs.sh`
- Auth detection now uses three sources in order:
  1. non-zero `steamwebhelper -steamid`
  2. latest `logs/connection_log.txt` state (`[Logged On] [U:1:<id>]`)
  3. UI fallback (`xdotool` Steam window/sign-in prompt check)

Live result after patch deployment:

- Finalize flow on `DISPLAY=:2` reports authenticated session directly (`steamid=391443739`) without offline fallback.
- Launch verification reached stable runtime with default pipeline and installed MSFS 2024:
  - `RESULT: MSFS reached stable runtime (>=20s)`
  - strong runtime process evidence included `FlightSimulator2024.exe`.
- State verifier now reports:
  - `Steam auth: authenticated (connection-log steamid=391443739)`
  - `GPU display active on :2 (NVIDIA GL)`

Assessment update:

- Local DGX launch path is now reproducible with authenticated detection and measurable stable runtime.
- Remaining work is extending stability window and confirming first-frame/interactive handoff consistency.

## 2026-02-28 (11:29-11:35 UTC, install-state correction + crash-boundary evidence pass)

Live DGX recheck on `spark-de79` corrected stale assumptions and captured a new launch evidence bundle:

- Install state is confirmed healthy for MSFS 2024 (`AppID 2537590`):
  - `appmanifest_2537590.acf` is present under Snap Steam root.
  - `BytesDownloaded == BytesToDownload` (`7261863936`), `StateFlags=4` (fully installed).
- Launch dispatch path remains reproducible:
  - `scripts/19-dispatch-via-steam-pipe.sh` increments `StartSession` for `2537590`.
  - `content_log` repeatedly shows `App Running` transitions for `2537590`.
- Runtime still exits early under stricter stability criteria:
  - `scripts/09-verify-msfs-launch.sh` with `MIN_STABLE_SECONDS=45` reports transient runtime.
  - Strong process lifetime observed: ~35s (`wine64 ... FlightSimulator2024.exe`) before exit.
- Latest crash signature remains consistent:
  - `AsoboReport-Crash` reports `SEH 0xC0000005`.
  - Last state remains `MainState:BOOT SubState:BOOT_INIT`.

Repo hardening added in this pass:

- New script: `scripts/54-launch-and-capture-evidence.sh`
  - runs preflight repair,
  - dispatches launch via Steam pipe,
  - runs stable-runtime verification,
  - snapshots `content_log` / `compat_log` excerpts,
  - copies latest crash artifacts (`crashdata`, Bifrost log, AsoboReport) into `output/`.

Assessment update:

- The old "manifest missing / install not queued" blocker is closed.
- The current trust boundary is now explicit: local launch is reproducible, but runtime is not yet stable past BOOT_INIT under strict (45s) criteria.

## 2026-02-28 (11:38-11:41 UTC, clean-clone validation + reliability hardening)

Fresh DGX validation was run from a clean clone (`~/msfs-on-dgx-spark-run`) to avoid contamination from the long-running experimental tree:

- `scripts/54-launch-and-capture-evidence.sh` with `MIN_STABLE_SECONDS=45` reproduced launch dispatch and strong runtime process startup, then exited before strict stability:
  - `RESULT: transient launch only`
  - `Strong runtime lifetime: ~35s (<45s)`
- The same path with `MIN_STABLE_SECONDS=20` succeeded (`verify exit code: 0`), confirming reproducible local launch into a measurable stable runtime window.

Repo hardening in this pass:

- Fixed crash artifact capture bug in `scripts/54-launch-and-capture-evidence.sh`:
  - corrected `AsoboReport-Crash.txt` path handling (previous escaping prevented copy in some runs)
  - added optional UTF-16LE -> UTF-8 decode output for `crashdata.txt` (`crashdata-...utf8.txt`) when `iconv` is available
- Added `scripts/55-run-until-stable-runtime.sh`:
  - repeats launch+capture cycles up to `MAX_ATTEMPTS`
  - exits on first stable-runtime success
  - emits per-attempt logs and verifier summaries for easier reliability tracking

Current trust-boundary status:

- "Can launch locally" is now operationally reproducible on DGX with a 20s stability target and retry automation.
- Strict first-frame/long-stability (45s+) is still intermittent and remains an active runtime-compatibility tuning task.

## 2026-02-28 (12:00-12:01 UTC, remote clean-run stable verification at 30s)

Live DGX validation on `spark-de79` was executed from local workstation using remote sync/runner orchestration:

- Ran `scripts/90-remote-dgx-stable-check.sh` with:
  - `MIN_STABLE_SECONDS=30`
  - `MAX_ATTEMPTS=2`
  - explicit DGX SSH auth (`DGX_PASS=...`)
- Remote run directory:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T120040Z`
- Attempt 1 succeeded without retries:
  - `RESULT: stable runtime achieved on attempt 1`
  - verifier exit code `0`
- Verify evidence confirms strong runtime process window on GPU display:
  - `DISPLAY=:2`
  - `RESULT: MSFS reached stable runtime (>=30s)`
  - strong process includes `wine64 .../MSFS2024/FlightSimulator2024.exe`

Evidence paths:

- Remote:
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T120040Z/output/verify-launch-2537590-20260228T120042Z.log`
  - `/home/th0rgal/msfs-on-dgx-spark-run-20260228T120040Z/output/retry-attempt-2537590-20260228T120042Z-a1.log`
- Local copied bundle:
  - `output/remote-runs/msfs-on-dgx-spark-run-20260228T120040Z/output/`

Assessment update:

- "Can run locally on DGX Spark" is now reproduced in both direct and remote-clean execution paths with a 30s stability threshold.
- Remaining work is runtime longevity/interactive-frame hardening beyond current stable-launch thresholds.
