# MouthKeys

macOS dictation app, forked from FluidVoice (see `UPSTREAM.md`). The product is **wicked fast voice to text**. Fluid Intelligence is removed, telemetry is hard-off (`AnalyticsConfig.isConfigured` is false), and the upstream updater is off (`AppDelegate.upstreamUpdatesDisabled`). Keep all three that way. An updater of our own, Sparkle 2, is decided and planned in `docs/UPDATES.md`; until that build lands, the app checks for nothing.

Atin dictates into Claude Code in c11 all day with the installed app. Text delivery into c11 and Ghostty (forced Reliable Paste) must never regress.

## Private software, pushed to done

MouthKeys is open source (public repo, mouthkeys.com, a DMG per release), but in practice it is still private software: Atin is its user. The public surface does not make it a released product with live users, so set the autonomy dial to pre-release. Make the calls yourself and push every change all the way through: branch, build, test, a fresh-context review, PR, merge, without stopping to ask. Ask only for what Atin alone can do or decide (a permission prompt, a feel or sound check, a real product fork).

Three things still wait for Atin, and they are about his machine, not the public: installing (below), anything that touches the installed app (below), and `scripts/release.sh publish` (after he has dictated with the new build).

## Identity

| | Installed (Release) | Debug build and test host |
|---|---|---|
| Bundle ID | `com.stage11.mouthkeys` | `com.stage11.mouthkeys.dev` |
| Application Support | `~/Library/Application Support/MouthKeys` | `.../MouthKeys-Dev` |
| Log | `~/Library/Logs/MouthKeys/Fluid.log` | `~/Library/Logs/MouthKeys-Dev/Fluid.log` |

- Earlier identities (`PreviousAppIdentity.newestFirst`): MouthKeys 0.1.0 ran under the app's earlier working identifiers (bundle ID, Application Support folder and settings-key prefix listed in `AppStorageLocation.swift`, the only place they may appear), and before that the app ran as FluidVoice (`com.FluidApp.app`, `Application Support/FluidVoice`). On its first launch the installed app copies the newest earlier identity that has data once (`AppIdentityMigration`, run from `MouthKeysMain` before anything reads a default): every UserDefaults key except that identity's own bookkeeping (its migration markers and Accessibility trust record), then the folder, then the login item. It never writes to the old domain or folder, so the old app still runs from a backup. Check it with `grep IDENTITY_MIGRATION ~/Library/Logs/MouthKeys/Fluid.log`; the markers are `MouthKeysIdentityMigrationDefaults` and `MouthKeysIdentityMigrationFolder` in the new domain. The old data wins on conflict; what it replaces is saved to `~/Backups/mouthkeys-displaced-*` first. A retry that had to set data aside and still failed stops retrying (`MouthKeysIdentityMigrationDefaultsHalted`) and shows an alert before the app opens. Debug builds never migrate. A new bundle ID is a new app to macOS: Microphone and Accessibility are granted once more after the migration.
- Identifiers live in `AppStorageLocation` (and `PreviousAppIdentity` for the old ones). Never hardcode one. The keychain service `com.fluidvoice.provider-api-keys` kept its name on purpose (`KeychainService.serviceName`).
- Model caches in `~/Library/Application Support/FluidAudio` belong to the FluidAudio library, not to a bundle ID, and are shared by every build.
- Install with Atin only, and pick the path by the installed app's signer (`codesign -dvv /Applications/MouthKeys.app 2>&1 | grep -m1 Authority=`). **Developer ID** (Atin's Mac since the 0.1.0 DMG): never `./build.sh install`. A release is `scripts/release.sh ship --notes FILE` (build on Atlas, sign, notarize, draft, install here, then `publish` once Atin has dictated); a packaged app alone goes in with `scripts/release.sh install <app>`, which is "Install over a Developer ID app" in `docs/INSTALL-CHECKLIST.md` as a script (pitfall below). **Apple Development**: `./build.sh install` checks for data already under a new identity (first install only), quits the app (and stops if it will not quit), backs it up to `~/Backups/mouthkeys-<timestamp>/` and verifies the copy, prints the rollback command (`bash ~/Backups/mouthkeys-<timestamp>/rollback.sh`), then copies the new app alongside and swaps it in. Then run `docs/INSTALL-CHECKLIST.md`.
- Never launch a Release product (`./build.sh release`, `DerivedData/.../Release/MouthKeys.app`): it is `com.stage11.mouthkeys`, the installed app's identity, and would write into the installed app's defaults and folder. The migration only runs for the app in `/Applications`.

## Never touch the installed app

- Never touch `/Applications/MouthKeys.app`, quit or relaunch the running app, write `defaults` for `com.stage11.mouthkeys` or any earlier identity's domain, or touch `~/Library/Application Support/MouthKeys` or an earlier identity's folder. Never run `./build.sh install` without Atin.
- Debug builds are isolated by their own bundle ID (own UserDefaults) and folders (table above). Any code that picks an Application Support folder must use `AppStorageLocation.folderName`, and the log folder `AppStorageLocation.logFolderName`.
- Read either log freely.

## Build

```sh
xcodebuild -project Fluid.xcodeproj -scheme Fluid -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData DEVELOPMENT_TEAM="$MOUTHKEYS_DEVELOPMENT_TEAM" SDK_STAT_CACHE_ENABLE=NO build
```

- `MOUTHKEYS_DEVELOPMENT_TEAM` is your own 10-character Apple team ID (the maintainer uses his own; contributors pass theirs). `./build.sh` reads the same variable.
- Always pass `SDK_STAT_CACHE_ENABLE=NO`. On this machine `clang-stat-cache` hangs at 0% CPU on its second run in a DerivedData folder, and the build sits at "ClangStatCache" with no error. If you see that, kill `clang-stat-cache` and re-run with the flag.
- Product: `DerivedData/Build/Products/Debug/MouthKeys Debug.app`. The test module is `MouthKeys_Debug` (`@testable import MouthKeys_Debug`).
- The warning about `CTranscribe.framework/Versions/Current` symlinks is harmless for Debug builds.

## Test

- Same command with `test`. Iterate with `-only-testing:FluidDictationIntegrationTests/<Suite>`, then run the full suite before a PR.
- The test host is `MouthKeys Debug.app`, which launches briefly. Never click through or dismiss a system permission prompt; report it.
- **App-hosted tests must stay invisible and silent on the operator's machine.** Atin works (and dictates with the installed app) while tests run. As the XCTest host the app runs in `TestHostQuietMode`: it never activates, puts no window on screen, has no menu bar item, installs no global monitor or event tap, posts no notification, asks for no permission, and creates no sound player. `TestHostQuietModeTests` guards this. Never add a test or benchmark that shows UI, plays audio, takes focus, types, or touches the clipboard, and batch repeated runs inside one test-host launch.
- Never wait on a real `NSAnimationContext` completion in a test. Window animations evidently tick on the display (a run ended the moment the displays woke), so while the displays sleep the completion never comes and the suite hangs (`DatasheetFloatShadowTests`, 2026-10-01). Step the animated value by hand, and in an async test spell out `completionHandler: nil`: the bare `runAnimationGroup { }` there is the async overload, which awaits completion. Every wait gets a timeout of a few seconds (`fulfillment(of:timeout:)`, or a polled deadline).
- `DirectAudioReliabilityTests.testReadinessGateRearmingCancelsExistingWaiter` was flaky (a test race) until `4474074e`. If it fails again, re-run it alone before calling it a regression.
- App sources are a synchronized folder; test files are listed in `project.pbxproj` by hand. A new test file needs a project entry, so prefer adding to an existing test file.
- swiftlint and swiftformat are not installed. Follow `.swiftlint.yml`, `.swiftformat` and the surrounding code.

## Validate

Green tests are not a working product. Mic capture, Accessibility and real paste into c11 need a check in the running app. When you cannot drive it yourself, hand Atin concrete steps. After every install, Atin runs `docs/INSTALL-CHECKLIST.md`; add a line there when a change needs a real-path check.

Scripted delivery checks (Debug builds only): `defaults write com.stage11.mouthkeys.dev MouthKeysDebugDeliveryTriggers -bool YES`, then post a `com.stage11.mouthkeys.debug.*` distributed notification (see `DeliveryDebugTriggers.swift`). `toggleDictation` and `cancelDictation` drive a dictation without the hotkey; `logOverlayTargets` logs the overlay's mic label and the microphone card in global top-left coordinates, for a real click with `cliclick`. Launched straight from a c11 shell, a Debug build inherits c11's Microphone and Accessibility grants; first move its shortcuts off Atin's keys (its own `.dev` defaults: `PrimaryDictationShortcuts`, `CancelRecordingHotkeyShortcut`) so its event tap never answers his hotkey.

## Website

mouthkeys.com is `site/` (one static page in light Datasheet Mono, the app's visual language, called Signal in code; the grin in `site/grin.js` is ported from `scripts/make_app_icon.swift`). `.github/workflows/pages.yml` deploys it to GitHub Pages on every push to `main` that touches `site/` or `docs/images/`. Preview: `site/assemble.sh <dir>` then serve `<dir>` on localhost. The page reads the latest release from the GitHub API for the version and the DMG link, so a new release needs no site change. DNS lives in the Stage11 Projects Cloudflare account (apex A/AAAA and `www` CNAME to GitHub Pages, DNS only); see `~/Projects/Stage11/code/platform/cloudflare.md`.

## Git and PRs

- `gh repo set-default` is `BenevolentFutures/MouthKeys` (GitHub redirects the repo's earlier URL). The integration branch is `main`.
- Always `gh pr create --repo BenevolentFutures/MouthKeys --base main`. Never open anything against `altic-dev/FluidVoice`.
- Upstream fixes are ported by hand, never merged. Policy, watermark and ledger: `UPSTREAM.md`.

## Agent pitfalls

### `./build.sh install` over the Developer ID app silently kills the hotkeys

**The incident (2026-10-02):** with the Developer ID 0.1.0 build installed, an agent ran `./build.sh install`. It signs with the Apple Development identity: same bundle ID, a different designated requirement. Accessibility still showed switched on, `AXIsProcessTrusted()` was false, and the hotkey retried `Attempt 1 failed` until the install was rolled back.

**The rule:** match the installed app's signer (for a same-ID update; the one install that changes the bundle ID compares the signer only and expects `waiting_for_accessibility` until Accessibility is granted, see the checklist's step 3). Over a Developer ID app, sign the Release build with Developer ID (`scripts/release.sh package`, notarizing optional for a local install), confirm `codesign -d -r-` matches the installed app's line exactly, then swap it in by hand: "Install over a Developer ID app" in `docs/INSTALL-CHECKLIST.md`. After the swap, `grep HOTKEY_TAP ~/Library/Logs/MouthKeys/Fluid.log | tail -1` must say `state=installed`; `waiting_for_accessibility` means the signature does not match, so roll back.

### A new signature leaves a stale Accessibility grant, and other copies of the bundle ID poison it

**The incident (2026-10-02):** Atin replaced an Apple Development-signed build with the Developer ID-signed 0.1.0 DMG (same bundle ID, new signature). MouthKeys showed as switched on in Privacy & Security > Accessibility, yet `AXIsProcessTrusted()` stayed false: onboarding kept saying Open Settings and the hotkeys were silently dead (the old retry logged `Attempt 1 failed` every 0.5 s, forever). Removing the row with − and switching it on again did not help. tccd logged `Failed to match existing code requirement for subject <the app's bundle ID> and service kTCCServiceAccessibility`: other copies with the same bundle ID and a different signer were registered with LaunchServices (an old copy in the Trash, a `~/Library/Caches/com.apple.SwiftUI.Drag-*/` copy, an old DerivedData Release build), and System Settings recorded one of their code requirements when the switch was flipped.

**What the app does now:** `AccessibilityTrustMonitor` re-reads trust every 0.5 s while a permission surface is visible and on every activation; the hotkey tap arms itself the moment trust flips (`HOTKEY_TAP state=waiting_for_accessibility`, then `state=installed`, transitions logged once). Still untrusted 3 s after the user returns from System Settings, the step shows "Already switched on?", and `ConflictingAppCopyDetector` names any registered copy whose designated requirement the running app does not satisfy (`PERMISSION_DIAG conflicting_copies=N paths=...`) with Show in Finder. Trusted but the tap refused after five tries: `state=failed_trusted` and a Relaunch MouthKeys button. It never deletes anything.

**The rules:**
1. Before the first launch of a build with a new signature, delete other copies of `com.stage11.mouthkeys` signed by someone else and empty the Trash. `./build.sh install` lists them after installing (read-only).
2. Diagnose from the log first: `grep -E 'HOTKEY_TAP|ACCESSIBILITY|PERMISSION_DIAG|PERMISSION_HINT' ~/Library/Logs/MouthKeys/Fluid.log`, and tccd's view with `log show --last 10m --predicate 'process == "tccd"' | grep mouthkeys`.
3. Agents never touch TCC (`tccutil`) or delete Atin's copies. Hand him the paths and the steps.

### Every microphone stalls inside Core Audio: restart ContinuityCaptureAgent first

**The incident (2026-11-19, 11:43 to 12:02):** every input (built-in, ATR USB, EMEET, iPhone) stalled for every process, not only MouthKeys. `coreaudiod` logged `HALS_IOContext_Legacy_Impl::StartIOThread: got an error from starting the IO thread, Error: 0x3C` every 14 s, MouthKeys quarantined one mic after another and its hotkey tap timed out. Output still played. Relaunching MouthKeys did not help, and neither did `sudo killall coreaudiod`. Restarting `ContinuityCaptureAgent` (the iPhone Continuity agent, which runs as Atin and survives a `coreaudiod` restart) cleared it at once. The same `0x3C` signature appears in the 2026-09-11 and 2026-09-14 notes in `ASRService` (`directCaptureStartDeadlineNanoseconds`); whether the agent caused those is unproven.

**The cure, in order:**
1. Prove it is system-wide, without touching the installed app: `/usr/bin/log show --last 15m --predicate 'process == "coreaudiod" AND eventMessage CONTAINS "StartIOThread"'`, then a mic probe in your own process, `perl -e 'alarm 20; exec @ARGV' /opt/homebrew/bin/rec -q -n stat trim 0 1` (healthy: a `Length` line within about a second; wedged: it hangs until the alarm). `play -q -n synth 0.3 sine 440 vol 0` checks output silently.
2. Restart the agent, user-level, no sudo: `kill <pid>` with the PID from `pgrep -x ContinuityCaptureAgent`; launchd starts it again. Re-run the probe. Since 0.1.9 Atin can do this himself: two microphones stalling in a row stop the start with a "macOS audio input is stuck" card, and its Restart iPhone mic helper button (one confirm) stops the agent by PID and tries the microphone once. `grep -E 'audio_input_stuck|MIC_HELPER_RESTART' ~/Library/Logs/MouthKeys/Fluid.log` shows what happened.
3. Only if input still hangs, Atin restarts `coreaudiod` himself (`sudo killall coreaudiod`).

Since 0.1.8 MouthKeys never picks an iPhone mic on its own (`MicrophoneTier.automatic`), but the agent can stall input with the phone mic unused.

To rehearse it without a real stall, use a Debug build (never the installed app): `defaults write com.stage11.mouthkeys.dev DirectCaptureDebugStartDelaySeconds -float 4` makes every direct start block past its 1.5 s deadline, so the second microphone brings up the card. The helper's probe obeys the same delay: delete the key before clicking Restart it for the "working again" path, keep it for "still stuck".

### The main thread never waits on Core Audio

**The incident (2026-11-19, 17:58:20):** after a `coreaudiod` restart MouthKeys stayed alive with its main thread blocked forever and its hotkeys dead. The HAL's notification thread, tearing a dead device down, was delivering that device's listener with `dispatch_sync` onto the main queue, while the main thread was removing the same listener, which waits inside Core Audio for every delivery in flight. Input worked again at 18:00:16; MouthKeys stayed stuck until it was relaunched. The hotkey tap waits on main for every key (`DispatchQueue.main.sync`), so any main-thread wait on Core Audio over about a second disables it.

**The rules (0.1.10):**
1. Listeners only through `CoreAudioPropertyListener`. Core Audio delivers to its private `deliveryQueue`, which only hands each notification on with `async`; `remove()` returns at once (the caller's block never starts again) and the removal runs on `CoreAudioHAL.listenerLane`; `add` from main waits at most `CoreAudioHAL.mainThreadDeadline` (200 ms).
2. Synchronous reads only through `AudioDevice` (`CoreAudioHAL.read` for a new one). On main they run on `CoreAudioHAL.readLane`, wait at most 200 ms, then return the last answer; once a waiter has given up, or the running call is past the deadline, they return it at once. Anything a start awaits uses `CoreAudioHAL.readAsync` with a deadline (`ASRService.deviceSnapshotDeadline`, 3 s), and a listing nobody waits for uses `CoreAudioHAL.background`, never `Task.detached` or `DispatchQueue.global()` (a stuck HAL then parks one lane thread, not a pool thread per call). A start whose listing times out shows the "macOS audio input is stuck" card; it goes away when Core Audio answers again.
3. One `coreaudiod` restart is handled once (`AudioHardwareObserver.noteCoreAudioServiceRestarted`, whose ServiceRestarted listener is always on; reports within 2 s are the same restart): device listeners and IDs from the dead server are dropped, system-object listeners are added again before the old ones come off, stalls are forgotten, and `.coreAudioServiceDidRestart` tells `ASRService` and the mic card.
4. Diagnose with `grep -E 'CORE_AUDIO_HAL|CORE_AUDIO_SERVICE_RESTART' ~/Library/Logs/MouthKeys/Fluid.log`: `state=stuck op=...` names a call that has not returned after 2 s, `state=recovered` says when it did, `wait=gave_up` is main or a start giving up on one.
5. Still synchronous on main, and only when the AVAudioEngine fallback ran: its start (`startEngine`, skipped while `CoreAudioHAL.isStuck` or two microphones have stalled), stop and tap removal (`detachAudioEngineForRetirement`, `stopActiveAudioCapture`), and `getCurrentlyBoundInputDevice`'s current-device read. `DirectAudioReliabilityTests.testListenerRemovalDuringASynchronousDeliveryNeverBlocksMain` replays the deadlock against a fake HAL; with the old design it fails.

### Never add or remove a Core Audio listener block from Swift directly

`AudioObjectRemovePropertyListenerBlock` called from Swift returns noErr and removes nothing: Swift imports `AudioObjectPropertyListenerBlock` as a Swift closure and bridges it to a new block on every call, so Remove never matches the block Add was given (proven 2026-11-19 against the same calls in Objective-C, which work). Until 0.1.9 every direct capture left its 11 listeners registered, and one `io_stopped_abnormally` ran 87 old generations' blocks at once. Use `CoreAudioPropertyListener.add(...)` and `remove()`: the C side (`fv_core_audio_listener_add`) keeps the one block Core Audio holds. `DirectAudioReliabilityTests.testCoreAudioPropertyListenerRemovalStopsDelivery` guards it (`coreAudioDeliveryCount` proves Core Audio itself dropped the block).
