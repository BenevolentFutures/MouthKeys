# MouthKeys app: Signal build plan

Turns the approved prototype ([`index.html`](index.html), [`DIRECTION.md`](DIRECTION.md)) into the shipping SwiftUI window. Prepared 2026-10-05 against `main` at `dd4cbfae` (0.1.3). The prototype is the binding reference: reproduce it one to one, and change no behavior.

Read first, in order: `CLAUDE.md` (repo rules: never touch the installed app, quiet test host, Atlas for full suites), `design/visual-language/DESIGN.md` (the locked Signal tokens), `DIRECTION.md` (thesis, bracket rule, grid, screens, native mapping, decisions), then this file.

## Ground rules

1. **Restyle only.** Every control in today's window keeps its binding, its `SettingsStore` key and its side effects. A control may move (Settings zones, inline tables instead of popovers); none may disappear except the Accent Color picker (decision 1). The parity checklist below proves it.
2. **States the prototype never drew still ship.** Permission recovery on Getting Started (Open Settings, the floating guide, "Already switched on?", `ConflictingAppCopyDetector`'s Show in Finder list, the `failed_trusted` Relaunch MouthKeys button, Grant Access), "Settings are disabled during active recording", hotkey initializing, model download progress and errors, the regional filler-word offer (added after the prototype, `c6190877`, `f712eaa9`, `03b457b8`), and the overlay microphone picker (`340d9ca0`). Style each in Signal with the nearest prototype pattern: a ruled banner, a row with a status square, an orange "needs you" step.
3. **The live recording overlay, the menu bar mark and text delivery are untouched** (decision 8). They are already Signal. The only menu change is the header grin and the new "MouthKeys on GitHub ↗" item.
4. **Tokens come from one place.** Extend `SignalTheme` (`Sources/Fluid/Theme/SignalTheme.swift`) with the window tokens `rule`, `ruleSoft`, `sidebar` and `field` (values in `index.html`'s `:root` and light blocks, lines 39 to 72; `desk` is the prototype's stage, not product). Nothing hardcodes a colour. `AppTheme` stays for code not yet converted and is retired at the end if nothing uses it.
5. **No layout jumps** (global quality bar): fixed-width toggles with reserved ON/OFF, fixed segment cells, fixed readout boxes, constant row counts.
6. **Quiet tests.** New tests render offscreen with `ImageRenderer` (pattern: `SignalOverlayRenderTests` in `Tests/FluidDictationIntegrationTests/DictationE2ETests.swift`, `MOUTHKEYS_RENDER_DIR`). No window on screen, no focus, no sound, no clipboard. New test files need a `project.pbxproj` entry, so prefer adding to an existing test file.

## Where things live today

| Piece | File | Note |
|---|---|---|
| Window shell, sidebar, toolbar, screen switch | `Sources/Fluid/ContentView.swift` (4.7k lines) | `sidebarView` ~L1255, `detailContent` ~L1355, toolbar (Today, Theme, Report) ~L405, `onboardingOnlyView` ~L1387, `preferencesView` ~L1542 passes ~30 bindings into `SettingsView` |
| Sidebar items | `enum SidebarItem` in `ContentView.swift` ~L97 | `.rewriteMode` exists but has no row; keep it unrouted |
| Settings | `Sources/Fluid/UI/SettingsView.swift` (2.7k) | Shortcuts ~L459, options ~L609, `microphonePrioritySection` ~L2113, filler words editor ~L2543 |
| Getting Started | `welcomeView` in `ContentView.swift` ~L1414, `Sources/Fluid/UI/WelcomeView.swift` (3k), `Theme/Components/SetupComponents.swift` | Quick Setup and the permission flows |
| First-run wizard | `OnboardingFlowView` in `WelcomeView.swift` ~L614, `UI/OnboardingTryoutStepView.swift`, `UI/OnboardingAIEnhancementStepView.swift`, `Theme/Components/OnboardingComponents.swift` | Gated by `settings.shouldShowOnboarding` |
| Voice Engine | `VoiceEngineSettingsScreen`, `UI/AISettingsView+SpeechRecognition.swift` | |
| Custom Dictionary | `UI/CustomDictionaryView.swift` (3.7k) | popovers become inline tables (decision 3) |
| Command Mode / File Transcription | `Views/CommandModeView.swift`, `UI/MeetingTranscriptionView.swift` | |
| History / Stats | `UI/TranscriptionHistoryView.swift`, `UI/StatsView.swift` | |
| AI Enhancement | `UI/AISettingsView+AIConfiguration.swift`, `+AdvancedSettings.swift`, `UI/AISettings/AIEnhancementSettingsViewModel.swift` | restyle only, the unsupported note stays verbatim |
| Feedback | `UI/FeedbackView.swift` | adds About with Fig. 1 and the GitHub link |
| Status menu | `Services/MenuBarManager.swift` | header grin, GitHub item |
| Signal primitives that exist | `Theme/SignalPrimitives.swift` (`SignalBracketShape`, hover bracket, `SignalPrimaryButtonStyle`, `SignalTextButtonStyle`, `SignalMonoLabel`), `Theme/SignalChip.swift`, `Views/Signal/*` (overlay, `SignalMenuBarMark`) | reuse; do not fork |
| Grin geometry | `scripts/make_app_icon.swift`, `Views/Signal/SignalMenuBarMark.swift` | `SignalGrin` must match number for number |

## Phases

Each phase lands as one or more PRs that leave `main` shippable. Phases 0 and 1 go first, one after the other; phases 2 to 6 then run as parallel lanes in their own worktrees, because each owns separate files. `ContentView.swift` is the one shared hot spot: only phase 1 restructures it; later lanes touch only the one `detailContent` case they own.

**0. Foundations** (one PR). Window tokens in `SignalTheme`. A `Theme/SignalWindow/` folder (app sources are a synchronized folder, so no project edits) with: `SignalSheetHeader` (placard, title, lede, rule), `SignalSection` (zone letter, title, rule to the edge), `SignalRow` (label, help, trailing control, bottom rule, `.indent` leader), `SignalToggleStyle`, `SignalSegmented`, `SignalPicker` (a `Menu` with a field-box label), `SignalSlider`, `SignalHotkeyWell` (wraps the existing recorder), `SignalTableRow` with hover and selection inversion, `SignalMeter`, `SignalStatusSquare` (ink, orange, outline), `SignalBracketed(rest:)`, `SignalEmptyState`, and `SignalGrin` (Canvas, three detail tiers by pixel width, `jaw` input). Render test: a gallery of every component in both themes against `shots/`.

**1. Window chrome** (one PR). Hidden title bar plus the 40 pt title strip (Today, Theme, Report; traffic lights stay the system's). Sidebar becomes a `ScrollView` of `SignalNavRow`: the bare `00 Getting Started` row on top, then Configure, Use, Activity, Advanced, Help (Feedback only), numbered 01 to 09. Corner stamp bottom-left: grin, MOUTHKEYS wordmark and version, engine / input / hotkey cells, GITHUB ↗. ⌘0 to ⌘9 jump to the screens (our assumption; the prototype's bare digits would fire while typing in a field). Remove the Accent Color picker and its uses. Screens keep their old bodies for now.

**2. Settings** (lane A). One sheet, zones A Microphone, B Hotkeys, C Dictation, D App, E History, F Format, G Alerts, H Overlay, I Backup, J Debug, in that order (decision 10), with the sticky zone strip. Every existing control rewired into `SignalRow`s. Hardest lane: run the parity checklist control by control.

**3. Getting Started** (lane B). Quick Setup with the 4-cell readout and its states (done collapses, DO THIS NOW in ink with the action bracketed at rest, later steps outlined), "Welcome to MouthKeys" before any model, all permission recovery states from rule 2. Your Dictation Key: keycap of the real primary shortcut and mode, the 3-press practice drill (it can complete the hotkey step). Playground: the real `SignalOverlay` hosted inline, plus the hover callouts (dashed orange zones, leader, terminus, label; `callouts.js` has names and lines).

**4. Content screens** (lanes C and D, split as you like). Voice Engine (preview panel, spec strip, model table, filler-word tags). Custom Dictionary (Teach Words with readiness meter, three inline tables). History (list and detail, delivery Pasted / NOT PASTED, actions Copy, Audio, Export Pair, Delete; empty state). Stats (KPI cells, bars with today in orange, milestones, tables). Command Mode (not-ready banner, confirm panel). File Transcription (drop zone, options, progress, result, recent table; header "File Transcription"). AI Enhancement (Providers and Advanced Prompts as tabs). Feedback (About with Fig. 1, GitHub).

**5. First-run wizard** (lane E). Step rail, ruled content, ruled footer: Welcome (Fig. 1), Language, Voice Engine, Enable Access, Try MouthKeys (keep the regional filler offer), Finish Setup.

**6. Menu and finish** (lane F, small). Status menu header grin and "MouthKeys on GitHub ↗". Outline grins in the two empty states. Retire dead `AppTheme`, `ThemedCard`, `ThemedGroupBox`, `GlossyEffects` code once nothing references it. Add the real-path checks to `docs/INSTALL-CHECKLIST.md`.

## Validation loop per lane

1. Inner loop on Hyperion: incremental Debug build, the lane's render test with `-only-testing:`. Copy DerivedData into a new worktree with `/bin/cp -c -R` (APFS clone) so the first build is incremental.
2. Compare: offscreen renders of each screen in dark and light, side by side with `shots/` (see `scripts/compose_render_compare.py` for the pattern). Missing or different elements are bugs unless the parity checklist or rule 2 explains them. Controls backed by AppKit can render blank in `ImageRenderer`; check those in the running Debug build instead.
3. Full suite before the PR: on Atlas, never Hyperion (`/atlas-jobs`; memory: ad-hoc signing, a git bundle, about 35 s for 648 tests).
4. Real app, once per lane: launch the Debug build (`MouthKeys Debug.app`, `.dev` identity) from a c11 shell after moving its shortcuts off Atin's keys (CLAUDE.md, Validate), look at the screen and click through it. One agent at a time drives the screen; confine to a verified display; quit the Debug build when done.
5. Fresh-context review, then merge. No release and no install: Atin installs (Developer ID path in `docs/INSTALL-CHECKLIST.md`) and runs the checklist.

## Parity checklist (lane A writes it, every lane extends it)

`design/app-signal/PARITY.md`: one line per control in today's window: old screen and label, `SettingsStore` key or binding, new zone or screen, status (moved, restyled, removed by decision). Seed it from `SettingsView.swift`, `ContentView.swift`'s `preferencesView` bindings and each screen file. A 2026-10-05 label diff found every Settings row in the prototype except messages and states (covered by rule 2) and the Accent Color picker (removed by decision).

## Risks

- `ContentView.swift` merge conflicts across lanes: phase 1 lands first, and lanes touch only their own `detailContent` case.
- `NavigationSplitView` with a custom sidebar can fight sidebar collapse and minimum widths; keep the 220 to 300 width range and the 800 × 500 minimum window.
- Shortcut recorder and capture monitor live in `ContentView` state; `SignalHotkeyWell` wraps the existing recorder rather than reimplementing capture.
- SF Mono: use `.monospaced()` design fonts as the overlay does; the prototype screenshots were taken in Safari with SF Mono.

## Open with Atin

Decisions the build assumes; any can change before it starts:

1. ⌘0 to ⌘9 for screen jumps (above).
2. Round 2 items never reviewed (decision 6): the grin is tileless and themed (it prints ink on white in light mode), the stamp sits bottom-left, and outline grins appear only in the two empty states. Built as prototyped.
3. Command Mode shows its honest "not ready" banner for a straight-dictation user.
