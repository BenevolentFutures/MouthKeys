# updates.

how people who already have MouthKeys installed get a new release. decided 2026-10-22, not built yet. the build is its own kickoff and follows this page.

until that build ships nothing changes: the app checks for nothing, and people download each release by hand ([RELEASING.md](RELEASING.md)).

## the decision.

- **Sparkle 2** is the updater (the current 2.x line, 2.10.0 at the time of writing, MIT). every update is signed twice: an EdDSA signature over the DMG, checked against the key the installed app carries, and our Developer ID signature on the DMG and on the app inside it. Sparkle accepts an update when the EdDSA check passes, or as a fallback when the DMG's Developer ID signature comes from the installed app's team. the release script keeps the signing team the same, which is what keeps Accessibility.
- **the daily check is on by default**, disclosed in the README and in Settings, with a switch that turns it off.
- **automatic installation is off by default.** a second switch turns it on: the next version then downloads in the background and installs when the app quits.
- **the appcast is a release asset.** every release carries `appcast.xml` beside its DMGs, and the app reads `https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/appcast.xml`.
- **the interface stays light, in Datasheet Mono.** a new version is one line in the menu bar menu and one status in Settings. Sparkle's own window appears only after a click.

what Sparkle beat, one line each:

- *a notify-only check* (one request a day, then open the release page) spends the same privacy and buys far less. the user still drags a 30 MB DMG, and that download is checked only by Gatekeeper, which accepts any notarized app from anyone. Sparkle pins the DMG to our EdDSA key.
- *porting FluidVoice's updater* (this tree still carries an old copy, disabled) means owning an updater. the copy here swaps the bundle without atomicity and keeps rollback copies in the wrong folder. upstream's current one is far better but is 1,500 lines plus tests, FluidVoice-branded, and its only root of trust is the GitHub API over TLS plus a code-signing match.
- *a Homebrew cask* is pull, not push. people must run an upgrade, Homebrew deletes and recopies the bundle rather than swapping it, and the main cask repository wants 75 stars or 30 forks. a personal tap may come later as a complement once Sparkle is in.
- *staying manual* leaves no way to deliver a security fix.

## what the user sees.

- **nothing at first.** no permission dialog on launch. once a day, while the app runs, it fetches the appcast in the background.
- **a new version is a line, not a window.** the menu bar menu gets one row, `Update to 0.1.7…`. in Settings, 05 App Settings, the Updates row's status reads `0.1.7 AVAILABLE` and its **Install** button becomes visible. the grin in the menu bar does not change, nothing turns orange (in Datasheet Mono orange is for what is live, and a waiting update is not), no notification is posted, no window opens.
- **a click on Install or the menu row opens Sparkle's standard update window:** the release notes with Install Update, Remind Me Later and Skip This Version, then a download, then Install and Relaunch. we accept that this window is Aqua for the first release; a custom Datasheet user driver is a later round if it grates.
- **automatic installation on:** the download happens in the background right after the check, the status reads `READY · INSTALLS ON QUIT`, and the next launch is the new version. Sparkle's window never opens on its own: this status is the only surface.
- **while dictating, nothing happens.** see the next section.

### the Settings rows.

in 05 App Settings, where the single Updates link is today, two `DatasheetRow`s with fixed heights (UI never jumps):

| row | label | control | help |
|---|---|---|---|
| 1 | Updates | toggle **Check daily** · text button **Check now** · a mono status slot · **Install** text button in a slot that is always reserved and shown only in the available state (hidden by opacity, never removed) | MouthKeys asks GitHub for the latest release once a day. The request carries your IP address and the app version, like any download. Nothing identifies you. |
| 2 | Install automatically | toggle, indented under row 1 and disabled while Check daily is off (Sparkle disallows automatic downloads then), the way Save Audio With History sits under its parent | Download the next version in the background and install it when you quit MouthKeys. Off: MouthKeys only tells you. |

the status slot is mono 10.5 uppercase with its width reserved for the longest reading, so the row never moves: `CHECKING`, `UP TO DATE · 10:42`, `0.1.7 AVAILABLE`, `READY · INSTALLS ON QUIT`, `CHECK FAILED · 10:42`, `OFF`. times are local. text buttons take the house hover bracket and no underline. both toggles observe the updater's own properties, because Sparkle's update window carries a checkbox that changes the second one. **Check now** runs a background check (`checkForUpdatesInBackground()`), so no Sparkle window appears for "checking" or "up to date"; the status slot says it. **Install** and the menu row call `checkForUpdates(_:)`, which opens Sparkle's window. the installed version already shows in Help and stays there.

## dictation comes first.

Atin dictates into c11 all day with the installed app. the updater must never touch a dictation.

- **the daily check is not gated.** it is one background GET. a check declined through `updater(_:mayPerform:)` is rescheduled a full interval later, so gating it would silence it for a day. the delegate method is not implemented.
- **the reminder and the status are set outside dictation only.** a result that arrives mid-dictation waits until the app has been idle for 10 s before anything on screen changes.
- `updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:)` holds the relaunch after Install and Relaunch until the app has been idle for 10 s. a dictation that starts during the hold finishes first. this is the same rule `scripts/release.sh install` applies from the outside.
- **automatic installation never quits the app.** Sparkle installs after the user quits, and nobody quits mid-dictation. (quitting itself does not wait for a live recording: `shutdownForTermination` stops without transcribing, which is why `release.sh install` waits for idle before it quits anything.)
- the updater runs nothing on the start or stop path and hooks nothing in the overlay.
- the XCTest host never starts the updater (`TestHostQuietMode`), so no test reaches the network or shows a window.

## trust and keys.

Sparkle verifies the DMG before it mounts it (`SUVerifyUpdateBeforeExtraction`). it accepts the download when either check passes:

1. **EdDSA.** the DMG's signature verifies against the public key the installed app carries (`SUPublicEDKey`).
2. **Developer ID, the fallback for key rotation.** the DMG's own code signature verifies and its team matches the installed app's team. `make_dmg` already signs the DMG with the Developer ID identity; that signature is load-bearing from now on.

after extraction Sparkle requires the app inside to be validly code signed and never to drop code signing or its EdDSA key, but it does not compare the new app's signer with the installed one. keeping the signer the same, which is what keeps Accessibility (CLAUDE.md, agent pitfalls), is therefore the release script's job: `ship` signs the app and the DMG with one identity whose team is pinned in the script, the appcast step refuses an app or a DMG signed by any other team, and `install` compares designated requirements on the maintainer's Mac as it does today. a signing team change is never done: it would break Accessibility for every install.

the feed is signed too (`SURequireSignedFeed`), so someone holding only the GitHub account cannot ship an update, post an "informational" update, or change the notes to point at a download elsewhere. they have neither key.

**the EdDSA key.** generated once on the signing Mac with `generate_keys --account mouthkeys`; it lives in that Mac's login keychain beside the Developer ID identity and the notary profile, and `generate_appcast` reads it from there. the public key goes into `Info.plist`. export it once with `generate_keys --account mouthkeys -x <file>` into the maintainer's password manager, then delete the file; a new signing Mac imports it with `generate_keys --account mouthkeys -f <file>` (the account matters: without it the key lands where `--account mouthkeys` cannot find it). the first run of each Sparkle tool asks for keychain access: click Always Allow once, with the screen unlocked, as for notarytool. the private key is never in the repository, never in CI, and never on the build host. losing it is recoverable: generate a new key, ship the new public key in the app and sign the DMG with the new private key; Sparkle accepts that DMG on the Developer ID fallback, checks it against the new key the new app carries, and adopts it.

**Accessibility.** the grant is keyed on bundle ID and signer, not on the folder, and has survived every same-signer swap since 0.1.3. Sparkle's helper, Autoupdate, swaps the bundle with an atomic rename swap when it carries the same team signature as the new app. Sparkle ships Autoupdate ad hoc signed; `release.sh` re-signs every nested piece of Sparkle with our identity, and `verify` checks that Autoupdate's team matches the app's. the old bundle goes to a temporary folder and is deleted, never to the Trash, so no second copy of the bundle ID is left behind. the new app keeps the old one's owner, group and Finder tags, and its quarantine flag is released.

## privacy and disclosure.

**what leaves the Mac.** one HTTPS GET of the appcast every 24 hours while the app runs (and at launch if a day has passed). it carries the IP address and a user agent naming the app and Sparkle versions. no query parameters, no system profile (`SUEnableSystemProfiling` stays off and `feedParametersForUpdater` returns nothing). the DMG is downloaded from GitHub only when the user clicks Install, or in the background when automatic installation is on.

this is the fourth reason the app goes online, and it is written down in four places:

- **README, the "goes online" list.** the lead-in becomes *the app goes online for four things. three are your choice; the fourth is on by default and has a switch:* and a fourth bullet reads *update checks, once a day while the app runs. one request to GitHub for the latest release, carrying your IP address and the app version the way any download does; nothing identifies you. the new version is downloaded only when you click Install, or in the background if you turned on automatic installs, which then install when you quit. switch it off in Settings › App Settings › Updates.*
- **README, the install paragraph**, replacing "the app does not update itself": *from 0.1.6 the app checks for a new version once a day and tells you in the menu bar and in Settings. installing is a couple of clicks, or automatic if you turn that on; your settings, dictionary, history and permissions stay. installs older than 0.1.6 never check: download 0.1.6 once by hand, and that is the last time.*
- **Settings**, the help text in the table above.
- **mouthkeys.com**, the `Updater · Off` placard becomes `Updater · Daily check` with the README's bullet as its line. the sentence about the updater never swapping MouthKeys back to FluidVoice stays true.

(0.1.6 stands for whichever version ships Sparkle first.)

## configuration.

Sparkle comes in through Swift Package Manager (`https://github.com/sparkle-project/Sparkle`, product `Sparkle`), pinned to an exact version like every other dependency. the app is not sandboxed, so no XPC launcher service; Sparkle's helper, its `Updater.app` and its XPC services are left as shipped and get our signature at packaging.

| Info.plist key | value | why |
|---|---|---|
| `SUFeedURL` | `https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/appcast.xml` | the latest published release's appcast. drafts and pre-releases are invisible to it. |
| `SUPublicEDKey` | the public key from `generate_keys --account mouthkeys -p` | the EdDSA leg |
| `SUEnableAutomaticChecks` | `YES` | the daily check is on; Sparkle asks no permission on the second launch |
| `SUVerifyUpdateBeforeExtraction` | `YES` | verify the DMG before mounting it |
| `SURequireSignedFeed` | `YES` | the appcast itself must carry a valid signature |
| `SUAutomaticallyUpdate` | absent (default `NO`) | automatic installation is off until the user turns it on |
| `SUScheduledCheckInterval` | absent (default 86400) | once a day |
| `SUEnableSystemProfiling` | absent (default `NO`) | nothing about the Mac is sent |

in code:

- `SPUStandardUpdaterController(startingUpdater: false, updaterDelegate:userDriverDelegate:)` is created in `AppDelegate` after launch work, never under `TestHostQuietMode` and never in Debug builds. the one-time migration below runs, then `startUpdater()`: a started updater with no last-check date checks at once, so the opt-out must be in place first.
- the two switches bind to `automaticallyChecksForUpdates` and `automaticallyDownloadsUpdates` on the updater, which Sparkle persists itself.
- `updater(_:didFinishUpdateCycleFor:error:)` drives the status slot and the `UPDATE_CHECK` log line; `updater(_:willInstallUpdateOnQuit:immediateInstallationBlock:)` drives `READY · INSTALLS ON QUIT`.
- gentle reminders (`SPUStandardUserDriverDelegate`): `supportsGentleScheduledUpdateReminders` is true, `standardUserDriverShouldHandleShowingScheduledUpdate(_:andInImmediateFocus:)` returns false so a scheduled update never opens a window (this also suppresses Sparkle's one-week "ready to install" alert, which is what we want), `standardUserDriverWillHandleShowingUpdate(_:forUpdate:state:)` sets the reminder when the check was not user-initiated, and `standardUserDriverDidReceiveUserAttention(forUpdate:)` and `standardUserDriverWillFinishUpdateSession()` clear it.
- Debug builds never start the updater: a `.dev` app cannot install a DMG whose app has another bundle ID, and any feed it read would need the production key. a Debug-only default, `MouthKeysDebugUpdateState`, drives the status slot and the menu row for UI work, with no Sparkle and no network.
- one-time migration: the FluidVoice-era defaults `AutoUpdateCheckEnabled`, `LastUpdateCheckDate`, `BetaReleasesEnabled` and the snooze keys may exist in migrated settings. if `AutoUpdateCheckEnabled` is present and false, the first Sparkle build turns the daily check off once; then all of them are removed. the settings backup keeps writing `autoUpdateCheckEnabled` and `betaReleasesEnabled` so older builds can still restore a new backup (the precedent is `transcriptionSoundIndependentVolume`), and restore ignores both so a deleted key is never recreated.

## the release flow.

`scripts/release.sh ship` stays the one command. the additions:

- **preflight** (fails before any long step, with instructions, like the notary profile does today):
  - the Sparkle command line tools of the pinned version. the script downloads `Sparkle-<version>.tar.xz` from Sparkle's GitHub release into `~/Library/Caches/mouthkeys-release/sparkle-<version>/`, checks it against a sha256 written in the script, and refuses a version that differs from the one in `Package.resolved`.
  - the EdDSA key: `generate_keys --account mouthkeys -p` must print the `SUPublicEDKey` in the source `Info.plist` (the build has not happened yet at this point).
  - the signing team: the script pins the release team ID, and `resolve_identity` must find that team's Developer ID identity.
- **appcast**, a new step after `package`, also runnable alone as `scripts/release.sh appcast <dmg> --notes FILE`:
  - checks the packaged app's `SUPublicEDKey` against the keychain's, and the team of the app and of the DMG against the pinned team ID.
  - deletes any old `appcast.xml` in `$DIST_DIR` first (`generate_appcast` merges into an existing feed), stages only `MouthKeys-<version>.dmg` and the notes as `MouthKeys-<version>.md` in an empty folder (`generate_appcast` uses a `.md` named after the archive as release notes), then runs `generate_appcast --account mouthkeys --download-url-prefix https://github.com/BenevolentFutures/MouthKeys/releases/download/v<version>/ --link https://mouthkeys.com --embed-release-notes -o $DIST_DIR/appcast.xml <folder>`. the enclosure names the versioned DMG, so the feed and the bytes it signs stay pinned together.
  - verifies: exactly one item, `sparkle:version` equals `CFBundleVersion`, `sparkle:shortVersionString` equals the version, `sparkle:minimumSystemVersion` is 15.0, the enclosure URL is the expected one, `sign_update --verify --account mouthkeys $DIST_DIR/MouthKeys-<version>.dmg <edSignature>` passes, and `sign_update --verify --account mouthkeys $DIST_DIR/appcast.xml` passes for the feed signature (if `generate_appcast` has not written one, `sign_update --account mouthkeys $DIST_DIR/appcast.xml` adds it first).
  - purges `~/Library/Caches/Sparkle_generate_appcast` afterwards: `generate_appcast` extracts the app there, and a copy of the bundle ID with a newer version than the installed app must not stay on the signing Mac.
- **draft**: three assets, `MouthKeys-<version>.dmg`, `MouthKeys.dmg` and `appcast.xml`.
- **publish**: refuses a draft without `appcast.xml`. after flipping it, fetches `releases/latest/download/appcast.xml` (with the same retries as the DMG), compares it byte for byte with the local file, and checks that the enclosure URL answers 200 after its redirect. the DMG sha256 check stays.
- **install** and `rollback.sh` refuse to quit the app while Sparkle has an update staged for installation on quit (the log shows `UPDATE_INSTALL_ON_QUIT ready` since the app's launch): otherwise Sparkle's install and the script's move would race. the maintainer keeps Install automatically off on his own Mac, which is the default anyway, and gets each release from `ship`, so Sparkle there sees an equal version.

rules that follow:

- `CFBundleVersion` only ever goes up, one per release. Sparkle compares it, not the version string.
- a bad release is fixed by shipping the next version, never by re-uploading assets under a published tag: cached feeds and the signature would disagree, and the version would not move.
- deleting the newest release makes `latest` the previous one. installed apps see a lower version and do nothing. nothing ever downgrades.
- pre-releases never reach the feed. a beta channel, if ever wanted, needs a feed outside `releases/latest`, since each release's appcast carries only its own item and published assets are never changed.
- [RELEASING.md](RELEASING.md) gets the EdDSA key and the keychain prompt in its once section, and the new steps.

## testing.

green tests are not a working updater. three layers, cheapest first:

1. **app-hosted tests, silent and offline.** `TestHostQuietModeTests` asserts the updater is never started in the test host. pure tests cover the idle rule for reminders and relaunch, the status strings, and the one-time migration and backup compatibility. no test starts Sparkle or touches the network.
2. **script test**, on the signing Mac (the key is only there): on a locally packaged, skip-notarize build, `scripts/release.sh appcast` produces an appcast that passes every check above.
3. **lab upgrade test** in a throwaway tart VM on the build host, cloned from the `c11-sandbox-golden` image (never run or modify the golden; stop and delete the clone afterwards). granting Accessibility inside that clone is explicitly allowed: the CLAUDE.md rule protects the maintainer's Mac, not a throwaway guest. the pieces:
   - two Developer ID signed test builds A and B, packaged on the signing Mac into a temporary `MOUTHKEYS_DIST_DIR` that is deleted once the copies are in the guest. three overrides, accepted only with `MOUTHKEYS_SKIP_NOTARIZE=1` and never by `ship`: `MOUTHKEYS_TEST_FEED_URL` (written into `Info.plist` before signing), `MOUTHKEYS_TEST_DOWNLOAD_URL_PREFIX` (replaces the GitHub prefix in the appcast step) and `MOUTHKEYS_TEST_BUILD_VERSION` (sets `CFBundleVersion` and the version string, so A and B differ, package to different DMG names, and both sit below the installed release so LaunchServices never prefers a test copy).
   - the feed is `http://127.0.0.1:<port>/appcast.xml`, served from inside the guest on the loopback interface.
   - install A from its DMG, launch it, grant Accessibility, then use the menu row or Check now. pass means: Sparkle's window, Install and Relaunch, B running from `/Applications/MouthKeys.app`, `codesign --verify --deep --strict` clean, LaunchServices listing no other copy of the bundle ID, `HOTKEY_TAP state=installed`, and A's termination in the log.

then two checks on the maintainer's Mac, in [INSTALL-CHECKLIST.md](INSTALL-CHECKLIST.md):

- **every release, after `publish`:** Settings › App Settings › Updates › Check now reads `UP TO DATE`, and `grep UPDATE_ ~/Library/Logs/MouthKeys/Fluid.log` shows the check. the first time this runs it also proves the feed is read through GitHub's redirect.
- **once, at the second Sparkle release:** after `ship` has installed it and `publish` has run, roll back to the previous version with the backup's `rollback.sh`, open Settings › Updates › Check now, and let Sparkle install the new one. that is the first update delivered end to end, since no release before the first Sparkle build can receive one.

## logging.

one line per event, greppable from the app log:

```
UPDATE_CHECK trigger=scheduled|manual result=up_to_date|available|failed version=<v> reason=<text>
UPDATE_REMINDER shown|cleared|deferred_dictating version=<v>
UPDATE_INSTALL requested|postponed_dictating|proceeding version=<v>
UPDATE_INSTALL_ON_QUIT ready version=<v>
```

Sparkle's own messages are in the unified log: `log show --last 1h --predicate 'subsystem == "org.sparkle-project.Sparkle"'`.

## the bootstrap.

no install older than the first Sparkle release checks for anything, by design, so each of them needs one more manual update. we say so in the first line of that release's notes (*the last update you install by hand. from this version MouthKeys checks once a day and offers the next one.*), in the README install paragraph, and on mouthkeys.com; the Updates row of the old builds already links to the latest release. the install base is a few dozen Macs, so this costs little.

## housekeeping in the same build.

- delete `SimpleUpdater.swift`, `SimpleUpdaterTests` and the two `SimpleUpdater` tests inside `DictationE2ETests`; in `AppDelegate`, `upstreamUpdatesDisabled` with its five update methods, `updateCheckTimer`, the launch-time calls that schedule the checks, and the "Updates Are Managed Locally" alert; the `mxcl/AppUpdater` package and the PromiseKit import it dragged in; the `AutoUpdateCheckEnabled`, `LastUpdateCheckDate`, `BetaReleasesEnabled` and snooze keys after the migration above.
- update CLAUDE.md's first paragraph (the updater line), the README's "what's left out" bullet on the updater (FluidVoice's is gone; MouthKeys uses Sparkle against its own releases), UPSTREAM.md's never-port entry (upstream's updater stays unported; ours is Sparkle), RELEASING.md, INSTALL-CHECKLIST.md (the Updates lines in sections 1 and 2), DESIGN.md §10 (the menu's row list) and `site/index.html`.

## open items for the build.

numbered, with what hangs on each. none changes the decision.

1. **release notes rendering.** Sparkle 2.9 and later render markdown release notes on macOS 12 and later. confirm our notes style (lowercase sentences, headings ending in a period) reads well in Sparkle's window; if not, the appcast step renders them to HTML first.
2. **the loopback test feed.** Sparkle logs a warning for a plain `http` feed but allows it when an EdDSA key is present, and App Transport Security does not apply to loopback. if either assumption fails in the guest, serve the test feed over `https` with a certificate the guest trusts.
3. **Accessibility in the guest.** how the clone grants it decides whether the lab test can prove `HOTKEY_TAP state=installed`; if it cannot, that proof falls to the once-only check on the maintainer's Mac.
4. **feed signing.** whether `generate_appcast` writes the feed signature itself or the appcast step must run `sign_update` on the file. either way the step verifies it.
5. **effort.** one to two agent days including the fresh-context review, plus the lab test. the DMG grows by about 1 MB.
