# building MouthKeys from source.

you don't need any of this to use MouthKeys. the [DMG](https://github.com/BenevolentFutures/MouthKeys/releases/latest/download/MouthKeys.dmg) is signed, notarized and ready to drag into Applications. this page is for reading the code, changing it, or running a build of your own.

## what you need.

- **a Mac with Apple Silicon.** the default speech engines need it. Intel builds compile, but this fork has not tested them.
- **macOS 15.6 or later**, which Xcode 26 needs. the app itself runs on macOS 15.
- **Xcode 26**, from the App Store. open it once so it installs its components. the Command Line Tools alone are not enough.
- **about 2 GB free.** the clone is about 40 MB; a build with its Swift packages is about 1.5 GB, in the repo's `DerivedData` folder.
- **an Apple Account**, for signing. a free one is fine. you can skip it, at a cost (below).

nothing else: no Homebrew, no package manager. the first build downloads its Swift packages itself.

## 1. clone.

```bash
git clone https://github.com/BenevolentFutures/MouthKeys.git
cd MouthKeys
```

add `--depth 1` if you only want to build and don't need the history.

## 2. set up signing, once.

macOS ties the Microphone and Accessibility permissions to an app's signature. sign every build with the same identity and the permissions survive rebuilds; build unsigned and macOS may ask for Accessibility again after each one.

1. in Xcode › Settings › Accounts, add your Apple Account. a free Personal Team is enough.
2. select the team, click Manage Certificates, and add an **Apple Development** certificate.
3. check: `security find-identity -v -p codesigning` lists an `Apple Development:` identity.

with several teams, pick one with `export MOUTHKEYS_DEVELOPMENT_TEAM=<your 10-character Team ID>`. `build.sh` passes your team at build time, so you never edit the project.

## 3. build and run.

pick one.

### a dev build, beside everything else.

the place to start, and the right build for trying changes.

```bash
./build.sh
open "DerivedData/Build/Products/Debug/MouthKeys Debug.app"
```

`MouthKeys Debug` is a separate app (`com.stage11.mouthkeys.dev`) with its own settings, history and permissions, so it never touches a MouthKeys you downloaded. it asks for Microphone and Accessibility on its first launch. if both apps run at once, give one of them a different hotkey in Settings, or quit one, or both will answer the same key.

the first build takes a few minutes while the Swift packages download; after that, `./build.sh` only rebuilds what changed.

no Apple Account? `./build.sh unsigned` builds the same app without signing.

### your build, as your MouthKeys.

```bash
./build.sh install
```

it builds a signed Release, quits a running MouthKeys, backs up the installed app to `~/Backups/`, puts the new build in `/Applications/MouthKeys.app`, and prints the command to roll back. it needs the signing from step 2. to update later, `git pull` and run it again.

**if your MouthKeys came from the DMG**, the dev build above is the easier road. installing your own build over it changes the app's signature from ours (Developer ID) to yours (Apple Development). macOS keeps showing the Accessibility switch as on, but it no longer matches, and the hotkeys go quiet. to switch for good:

1. run `./build.sh install`. it lists any other copy of MouthKeys signed by someone else (an old download, the Trash, the backup it just made).
2. once you're happy with your build, delete those copies and empty the Trash. a stale copy can make System Settings grant the wrong one.
3. reset the old grant: `tccutil reset Accessibility com.stage11.mouthkeys`.
4. open MouthKeys and grant Microphone and Accessibility when it asks.

going back to the DMG is the same in reverse: drag the downloaded app over yours, then steps 2 to 4. your settings, dictionary and history stay either way; only the permissions are tied to the signature.

## 4. first launch.

grant Microphone, to hear you, and Accessibility, to type into other apps. then pick a speech model; the default, Parakeet TDT v3, is about a 460 MiB download. the README's [first launch](../README.md#first-launch) section has the rest.

## when something goes wrong.

- **"No Apple Development signing identity was found."** step 2, or `./build.sh unsigned`.
- **`xcodebuild` says it requires Xcode.** the Command Line Tools are selected. point it at Xcode: `sudo xcode-select -s /Applications/Xcode.app`.
- **the build sits at `ClangStatCache` and never moves.** kill `clang-stat-cache` and build again. `build.sh` already avoids this; a hand-typed `xcodebuild` needs `SDK_STAT_CACHE_ENABLE=NO`.
- **a warning about `CTranscribe.framework/Versions/Current`.** harmless.
- **the hotkey does nothing, though Accessibility shows on.** almost always a signature mismatch: see *if your MouthKeys came from the DMG* above. the log says which: `grep HOTKEY_TAP ~/Library/Logs/MouthKeys/Fluid.log | tail -1` (for the dev build, `~/Library/Logs/MouthKeys-Dev/Fluid.log`) should end in `state=installed`. `waiting_for_accessibility` means macOS does not trust this copy yet. the app's Accessibility step also names any other copy that is confusing macOS.

## going further.

- tests and pull requests: [CONTRIBUTING.md](../CONTRIBUTING.md).
- the house rules, including how tests must behave: [CLAUDE.md](../CLAUDE.md).
- the app's log: App Settings › Debug › Reveal Log File.
