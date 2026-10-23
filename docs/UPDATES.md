# updates.

how people who already have MouthKeys installed get a new release. decided 2026-10-22, not built yet. the build is its own kickoff and follows this page.

until that build ships nothing changes: the app checks for nothing, and people download each release by hand ([RELEASING.md](RELEASING.md)).

## the decision.

- **Sparkle 2** is the updater (the current 2.x line, 2.10.0 at the time of writing, MIT). every update is signed twice: an EdDSA signature over the DMG, and the Developer ID signature of the app inside it, which Sparkle checks against the app that is already installed.
- **the daily check is on by default**, disclosed in the README and in Settings, with a switch that turns it off.
- **automatic installation is off by default.** a second switch turns it on: the next version then downloads in the background and installs when the app quits.
- **the appcast is a release asset.** every release carries `appcast.xml` beside its DMGs, and the app reads `https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/appcast.xml`.
- **the interface stays light, in Datasheet Mono.** a new version is one line in the menu bar menu and one status in Settings. Sparkle's own window appears only after a click.

what Sparkle beat, one line each:

- *a notify-only check* (one request a day, then open the release page) spends the same privacy for far less. the user still drags a 30 MB DMG, and that download is checked only by Gatekeeper, which accepts any notarized app from anyone. Sparkle pins the new app to our signing team.
- *porting FluidVoice's updater* (this tree still carries an old copy, disabled) means owning an updater. the copy here swaps the bundle without atomicity and keeps rollback copies in the wrong folder. upstream's current one is far better but is 1,500 lines plus tests, FluidVoice-branded, and its only root of trust is the GitHub API over TLS plus a code-signing match.
- *a Homebrew cask* is pull, not push. people must run an upgrade, Homebrew deletes and recopies the bundle rather than swapping it, and the main cask repository wants 75 stars or 30 forks. a personal tap may come later as a complement once Sparkle is in.
- *staying manual* leaves no way to deliver a security fix.

## what the user sees.

- **nothing at first.** no permission dialog on launch. once a day, while the app runs, it fetches the appcast in the background.
- **a new version is a line, not a window.** the menu bar menu gets one row, `Update to 0.1.7…`. in Settings, 05 App Settings, the Updates row's status reads `0.1.7 AVAILABLE` with an **Install** text button. the grin in the menu bar does not change, nothing turns orange (orange marks only what is live), no notification is posted, no window opens.
- **a click opens Sparkle's standard update window:** the release notes, Install and Relaunch, Remind Me Later, Skip This Version. we accept that this window is Aqua for the first release; a custom Datasheet user driver is a later round if it grates.
- **automatic installation on:** the download happens in the background, the status reads `READY · INSTALLS ON QUIT`, and the next launch is the new version. Sparkle's own window only appears if the app has not quit for a week.
- **while dictating, nothing happens.** see the next section.

### the Settings rows.

in 05 App Settings, where the single Updates link is today, two `DatasheetRow`s with fixed heights (UI never jumps):

| row | label | control | help |
|---|---|---|---|
| 1 | Updates | toggle **Check daily** · text button **Check now** · a mono status slot · **Install** text button, present only in the available state | MouthKeys asks GitHub for the latest release once a day. The request carries your IP address and the app version, like any download. Nothing identifies you. |
| 2 | Install automatically | toggle | Download the next version in the background and install it when you quit MouthKeys. Off: MouthKeys only tells you. |

the status slot is mono 10.5 uppercase with its width reserved for the longest reading, so the row never moves: `CHECKING`, `UP TO DATE · 10:42`, `0.1.7 AVAILABLE`, `READY · INSTALLS ON QUIT`, `CHECK FAILED · 10:42`, `OFF`. times are local. text buttons take the house hover bracket and no underline. the installed version already shows in Help and stays there.

## dictation comes first.

Atin dictates into c11 all day with the installed app. the updater must never touch a dictation.

- `updater(_:mayPerform:error:)` returns false while a dictation is live (recording, transcribing or delivering) and for 10 s after it ends. Sparkle retries on its own schedule; nothing is lost.
- `updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:)` holds the relaunch until the app has been idle for 10 s. a dictation that starts during the hold finishes first. this is the same rule `scripts/release.sh install` applies from the outside.
- installing on quit needs nothing extra: quitting already waits for delivery and the history save.
- the updater runs nothing on the start or stop path and hooks nothing in the overlay. the reminder is one published value that Settings and the menu read; it is updated outside dictation only.
- the XCTest host never starts the updater (`TestHostQuietMode`), so no test reaches the network or shows a window.

## trust and keys.

Sparkle accepts an update when either of two checks passes, and we ship both:

1. **EdDSA.** the DMG's signature verifies against the public key the installed app carries (`SUPublicEDKey`). `SUVerifyUpdateBeforeExtraction` is on, so the DMG is verified before it is even mounted.
2. **Developer ID.** the new app's Apple signature verifies and satisfies the installed app's designated requirement: same bundle ID, same team. a renewed certificate in the same team still matches.

so someone holding only the GitHub account cannot ship an update: they have neither key. a signing team change is possible through the EdDSA leg alone, but it would also break Accessibility for every install (CLAUDE.md, agent pitfalls), so it is never done.

**the EdDSA key.** generated once on the signing Mac with `generate_keys --account mouthkeys`; it lives in that Mac's login keychain beside the Developer ID identity and the notary profile, and `generate_appcast` reads it from there. the public key goes into `Info.plist`. export it once with `generate_keys --account mouthkeys -x <file>` into the maintainer's password manager, then delete the file; a new signing Mac imports it with `-f`. the private key is never in the repository, never in CI, and never on the build host. losing it is recoverable: the next update passes on the Developer ID leg, and Sparkle adopts the new public key it carries.

**Accessibility.** the grant is keyed on bundle ID and signer, not on the folder, and has survived every same-signer swap since 0.1.3. Sparkle's helper swaps the bundle atomically (`renameatx_np` with swap) when it carries the same team signature as the new app, which `release.sh` gives it by re-signing every nested piece of Sparkle with our identity. the old bundle goes to a temporary folder and is deleted, never to the Trash, so no second copy of the bundle ID is left behind. the new app keeps the old one's owner, group and Finder tags, and its quarantine flag is released.

## privacy and disclosure.

**what leaves the Mac.** one HTTPS GET of the appcast every 24 hours while the app runs (and at launch if a day has passed). it carries the IP address and a user agent naming the app and Sparkle versions. no query parameters, no system profile (`SUEnableSystemProfiling` stays off and `feedParametersForUpdater` returns nothing). the DMG is downloaded from GitHub only when the user clicks Install, or in the background when automatic installation is on.

this is the fourth reason the app goes online, and it is written down in four places:

- **README, the "goes online" list**, a fourth bullet: *update checks, once a day while the app runs. one request to GitHub for the latest release, carrying your IP address and the app version the way any download does; nothing identifies you. the download itself happens only when you click Install, or when you quit if you turned on automatic installs. switch it off in Settings › App Settings › Updates.*
- **README, the install paragraph**, replacing "the app does not update itself": *from 0.1.6 the app checks for a new version once a day and tells you in the menu bar and in Settings. installing is one click, or automatic if you turn that on; your settings, dictionary and history stay. installs older than 0.1.6 never check: download 0.1.6 once by hand, and that is the last time.*
- **Settings**, the help text in the table above.
- **mouthkeys.com**, the `Updater · Off` placard becomes `Updater · Daily check` with the README's bullet as its line. the sentence about the updater never swapping MouthKeys back to FluidVoice stays true.

(0.1.6 stands for whichever version ships Sparkle first.)

## configuration.

Sparkle comes in through Swift Package Manager (`https://github.com/sparkle-project/Sparkle`, product `Sparkle`), pinned to an exact version like every other dependency. the app is not sandboxed, so no XPC launcher service; Sparkle's helper, its `Updater.app` and its XPC services are left as shipped and get our signature at packaging.

| Info.plist key | value | why |
|---|---|---|
| `SUFeedURL` | `https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/appcast.xml` | the latest published release's appcast. drafts and pre-releases are invisible to it. |
| `SUPublicEDKey` | the public key from `generate_keys -p` | the EdDSA leg |
| `SUEnableAutomaticChecks` | `YES` | the daily check is on; Sparkle asks no permission on the second launch |
| `SUVerifyUpdateBeforeExtraction` | `YES` | verify the DMG before mounting it |
| `SUAutomaticallyUpdate` | absent (default `NO`) | automatic installation is off until the user turns it on |
| `SUScheduledCheckInterval` | absent (default 86400) | once a day |
| `SUEnableSystemProfiling` | absent (default `NO`) | nothing about the Mac is sent |

in code:

- `SPUStandardUpdaterController(startingUpdater:updaterDelegate:userDriverDelegate:)` is created in `AppDelegate` after launch work, never under `TestHostQuietMode`. in Debug builds it starts only when the `.dev` default `MouthKeysDebugUpdateFeedURL` is set, and `feedURLStringForUpdater` returns that URL; in Release the delegate returns nil and `SUFeedURL` rules.
- the two switches bind to `automaticallyChecksForUpdates` and `automaticallyDownloadsUpdates` on the updater, which Sparkle persists itself.
- gentle reminders (`SPUStandardUserDriverDelegate`): `supportsGentleScheduledUpdateReminders` is true, `standardUserDriverShouldHandleShowingScheduledUpdate(_:andInImmediateFocus:)` returns false so a scheduled update never opens a window, `standardUserDriverWillHandleShowingUpdate(_:forUpdate:state:)` sets the reminder when the check was not user-initiated, and `standardUserDriverDidReceiveUserAttention(forUpdate:)` and `standardUserDriverWillFinishUpdateSession()` clear it. Check now, the menu row and Install all call `checkForUpdates(_:)`, which brings Sparkle's window in focus.
- one-time migration: the FluidVoice-era default `AutoUpdateCheckEnabled` may exist in migrated settings. if it is present and false, the first Sparkle build turns the daily check off once, then removes it along with `LastUpdateCheckDate` and the snooze keys. the settings backup payload keeps decoding older files that still carry the field.

## the release flow.

`scripts/release.sh ship` stays the one command. the additions:

- **preflight** (fails before any long step, with instructions, like the notary profile does today):
  - the Sparkle command line tools of the pinned version. the script downloads `Sparkle-<version>.tar.xz` from Sparkle's GitHub release into `~/Library/Caches/mouthkeys-release/sparkle-<version>/`, checks it against a sha256 written in the script, and refuses a version that differs from the one in `Package.resolved`.
  - the EdDSA key: `generate_keys --account mouthkeys -p` must print the `SUPublicEDKey` of the built app.
- **appcast**, a new step after `package`, also runnable alone as `scripts/release.sh appcast <dmg> --notes FILE`: a staging folder holds only `MouthKeys-<version>.dmg` and the notes as `MouthKeys-<version>.md` (`generate_appcast` picks up a `.md` with the archive's name as release notes), then `generate_appcast --account mouthkeys --download-url-prefix https://github.com/BenevolentFutures/MouthKeys/releases/download/v<version>/ --link https://mouthkeys.com --embed-release-notes -o dist/appcast.xml <folder>`. the enclosure names the versioned DMG, so the feed and the bytes it signs stay pinned together. then verify: exactly one item, `sparkle:version` equals `CFBundleVersion`, `sparkle:shortVersionString` equals the version, `sparkle:minimumSystemVersion` is 15.0, the enclosure URL is the expected one, and `sign_update --verify dist/MouthKeys-<version>.dmg <edSignature>` passes.
- **draft**: three assets, `MouthKeys-<version>.dmg`, `MouthKeys.dmg` and `appcast.xml`.
- **publish**: refuses a draft without `appcast.xml`. after flipping it, fetches `releases/latest/download/appcast.xml` (with the same retries as the DMG), compares it byte for byte with the local file, and checks that the enclosure URL answers 200 after its redirect. the DMG sha256 check stays.
- **install** is unchanged. the maintainer's own Mac gets each release from `ship`, so Sparkle there sees an equal version.

rules that follow:

- `CFBundleVersion` only ever goes up, one per release. Sparkle compares it, not the version string.
- a bad release is fixed by shipping the next version, never by re-uploading assets under a published tag: cached feeds and the signature would disagree, and the version would not move.
- deleting the newest release makes `latest` the previous one. installed apps see a lower version and do nothing. nothing ever downgrades.
- pre-releases never reach the feed. a beta channel, if ever wanted, is a `sparkle:channel` in the same feed, not a second URL.
- [RELEASING.md](RELEASING.md) gets the EdDSA key in its once section and the new steps.

## testing.

green tests are not a working updater. three layers, cheapest first:

1. **app-hosted tests, silent and offline.** `TestHostQuietModeTests` asserts the updater is never started in the test host. pure tests cover the dictation guard decision, the status strings, and the one-time migration. no test starts Sparkle or touches the network.
2. **script test.** on a locally packaged, skip-notarize build, `scripts/release.sh appcast` produces an appcast that passes every check above. runs on the build host or locally; needs the key, so it runs on the signing Mac.
3. **lab upgrade test on the build host**, in a throwaway clone of the golden tart VM (never the golden, stop and delete the clone after): two Developer ID signed test builds A and B, A with the lower `CFBundleVersion`, both packaged with `MOUTHKEYS_TEST_FEED_URL=http://127.0.0.1:<port>/appcast.xml`, which `release.sh` writes into `Info.plist` before signing and accepts only with `MOUTHKEYS_SKIP_NOTARIZE=1`, never for `ship`. serve B's appcast and DMG from inside the guest on the loopback interface. install A from its DMG, launch it, grant Accessibility as far as the guest allows, then Check now. pass means: Sparkle's window, Install and Relaunch, B running from `/Applications/MouthKeys.app`, `codesign --verify --deep --strict` clean, LaunchServices listing no other copy of the bundle ID, `HOTKEY_TAP state=installed` where Accessibility was granted, and A's termination in the log. the test builds and their DMGs stay in the guest.

then two checks on the maintainer's Mac, in [INSTALL-CHECKLIST.md](INSTALL-CHECKLIST.md):

- **every release:** Settings › App Settings › Updates › Check now reads `UP TO DATE`, and `grep UPDATE_ ~/Library/Logs/MouthKeys/Fluid.log` shows the check. the first time this runs against a published appcast it also proves the feed is read through GitHub's redirect.
- **once, at the second Sparkle release:** after `ship` has installed it and `publish` has run, roll back to the previous version with the backup's `rollback.sh`, open Settings › Updates › Check now, and let Sparkle install the new one. that is the first update delivered end to end, since no release before the first Sparkle build can receive one.

## logging.

one line per event, greppable from the app log:

```
UPDATE_CHECK trigger=scheduled|manual result=up_to_date|available|refused_dictating|failed version=<v> reason=<text>
UPDATE_REMINDER shown|cleared version=<v>
UPDATE_INSTALL requested|postponed_dictating|proceeding version=<v>
UPDATE_INSTALL_ON_QUIT ready version=<v>
```

Sparkle's own messages go to the unified log; the build records the exact `log show` predicate here.

## the bootstrap.

no install older than the first Sparkle release checks for anything, by design, so each of them needs one more manual update. we say so in the first line of that release's notes (*the last update you install by hand. from this version MouthKeys checks once a day and offers the next one.*), in the README install paragraph, on mouthkeys.com, and in the Settings row's help of the old builds, which already links to the latest release. the install base is a few dozen Macs, so this costs little.

## housekeeping in the same build.

- delete `SimpleUpdater.swift` and `SimpleUpdaterTests`, `AppDelegate.upstreamUpdatesDisabled` with its three methods and the "Updates Are Managed Locally" alert, the `mxcl/AppUpdater` package and the PromiseKit import it dragged in, and the `AutoUpdateCheckEnabled` and `LastUpdateCheckDate` settings keys after the migration above.
- update CLAUDE.md's first paragraph (the updater line), the README's "what's left out" bullet on the updater (FluidVoice's is gone; MouthKeys uses Sparkle against its own releases), UPSTREAM.md's never-port entry (upstream's updater stays unported; ours is Sparkle), RELEASING.md, INSTALL-CHECKLIST.md and `site/index.html`.

## open items for the build.

numbered, with what hangs on each. none changes the decision.

1. **release notes rendering.** Sparkle 2.9 and later render markdown release notes on macOS 12 and later. confirm our notes style (lowercase sentences, headings ending in a period) reads well in Sparkle's window; if not, the appcast step renders them to HTML first.
2. **the loopback test feed.** Sparkle warns on a plain `http` feed but allows it when an EdDSA key is present; App Transport Security does not apply to loopback. if either assumption fails in the guest, serve the test feed over `https` with a certificate the guest trusts.
3. **Accessibility in the guest.** how the clone grants it decides whether the lab test can prove `HOTKEY_TAP state=installed`; if it cannot, that proof falls to the once-only check on the maintainer's Mac.
4. **signed feed.** Sparkle can also sign the appcast itself (`SURequireSignedFeed`). the update is already signed, so a tampered feed can at most offer nothing or something uninstallable. optional, later.
5. **effort.** one to two agent days including the fresh-context review, plus the lab test. the DMG grows by roughly 6 MB.
