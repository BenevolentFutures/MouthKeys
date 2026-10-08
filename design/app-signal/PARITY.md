# MouthKeys window parity ledger

Baseline: the current app at `e5e48a4e` (after PR #57), checked against `SettingsView.swift`, `ContentView.swift`, and the screen files listed below. “Restyle” is the required disposition; lane owners mark rows complete after wiring the new view. Controls backed by AppKit may render blank in `ImageRenderer`; those rows still require the real Debug view check under a screen lease.

## Foundations — phase 0

These components have no independent `SettingsStore` binding. The consuming screen supplies the existing binding and side effects.

| Current surface / component | Current binding or effect | New target | Status |
|---|---|---|---|
| `DatasheetTheme` window tokens | `rule`, `ruleSoft`, `sidebar`, `field`; values from prototype `:root` and light theme | Shared window palette | Restyle foundation |
| Sheet header | No binding | `DatasheetSheetHeader` | Foundation |
| Zone heading and trailing label | No binding | `DatasheetSection` | Foundation |
| Setting label, help, indent leader, row rule | Caller-supplied binding/control | `DatasheetRow` | Foundation |
| On/off control | Caller-supplied `Binding<Bool>` | `DatasheetToggleStyle` | Foundation |
| Fixed-cell choice control | Caller-supplied selection binding | `DatasheetSegmented` | Foundation |
| Field-box menu | Caller-supplied menu actions/current value and optional detail | `DatasheetPicker` | Foundation; native 240 × 32 field, stable value width, visible optional detail, and trailing disclosure; native menu remains the action surface |
| Gridded value control and fixed readout | Caller-supplied `Binding<Double>` and range | `DatasheetSlider` | Foundation |
| Shortcut display/capture well | Wrap the existing shortcut recorder and its callbacks | `DatasheetHotkeyWell` | Foundation |
| Selectable table row | Caller-supplied action and selection | `DatasheetTableRow` | Foundation |
| Segmented meter | Caller-supplied value and count | `DatasheetMeter` | Foundation |
| Status marker | Caller-supplied ink, orange, or outline kind | `DatasheetStatusSquare` | Foundation |
| Rest/hover selection bracket | Caller-supplied rest state and hover state | `DatasheetBracketed(rest:)` | Foundation |
| Grid empty state | Caller-supplied title, message, illustration, action | `DatasheetEmptyState` | Foundation |
| Tileless grin | Caller-supplied lower-jaw displacement | `DatasheetGrin(jaw:)`, compact/heavy/full pixel tiers | Foundation |

## Chrome — phase 1

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Sidebar: Getting Started | `selectedSidebarItem = .welcome` | `00 Getting Started` | Wired; real-path pending |
| Sidebar: Settings | `selectedSidebarItem = .preferences` | `01 Settings` | Wired; real-path pending |
| Sidebar: Voice Engine | `selectedSidebarItem = .voiceEngine` | `02 Voice Engine` | Wired; real-path pending |
| Sidebar: Custom Dictionary | `selectedSidebarItem = .customDictionary` | `03 Custom Dictionary` | Wired; real-path pending |
| Sidebar: Command Mode | `selectedSidebarItem = .commandMode` | `04 Command Mode` | Wired; real-path pending |
| Sidebar: File Transcription | `selectedSidebarItem = .meetingTools` | `05 File Transcription` | Wired; real-path pending |
| Sidebar: History | `selectedSidebarItem = .history` | `06 History` | Wired; real-path pending |
| Sidebar: Stats | `selectedSidebarItem = .stats` | `07 Stats` | Wired; real-path pending |
| Sidebar: AI Enhancement | `selectedSidebarItem = .aiEnhancements` | `08 AI Enhancement` | Wired; real-path pending |
| Sidebar: Feedback | `selectedSidebarItem = .feedback` | `09 Feedback` | Wired; real-path pending |
| Sidebar grouping | Existing `SidebarItem` routes; `.rewriteMode` has no row and remains unrouted | Configure, Use, Activity, Advanced, Help groups | Restyle; keep rewrite unrouted |
| Title strip: Today / word count / time saved | `TranscriptionHistoryStore.shared.todaySummary`; routes to `.stats`; preserves WPM calculation and empty state | Fixed 40 pt title strip | Normal Debug Today action opens Stats; empty summary verified. Populated wrapping polish deferred to lane F (PR59-r1 finding 4). |
| Title strip: Theme | `settings.themePreference`; cycles system/light/dark | Fixed theme cell with current effective scheme | Normal Debug preference cycle and both themes verified in both hosts at default/minimum sizes, including collapse/reopen. |
| Title strip: Report | `openIssueReportingPage()` → `MouthKeysLinks.newIssue` | Report cell | Wired to same URL/action; real-path pending |
| Sidebar stamp: version / engine / input / hotkey | Bundle version, `selectedSpeechModel`, reconciled input selection, `primaryDictationShortcutDisplayString` | Bottom-left stamp; jaw follows the existing overlay trace | Normal Debug real values/F19 verified; stamp flush to bottom in both hosts. Normal menu microphone pick updates both windows with unchanged device topology. Wordmark link/jaw amplitude polish deferred to lane F (PR59-r1 findings 5–6). |
| Settings: Accent Color | `settings.accentColorOption` | No new control | Picker removed; stored key retained. Main app accent is Datasheet orange. `AutomaticDictionaryCorrectionOverlay.accent` still reads the stored setting under its separate ownership boundary. |
| Main window shell | WindowGroup and `MenuBarManager.createAndShowMainWindow()` are both main hosts | 40 pt chrome strip; system traffic lights; 1000 × 700 default; 800 × 500 minimum | Both normal hosts verified at both sizes/themes, expanded/collapsed/reopened. Owned native default split items remove the system sidebar glass/insets; Button/state routing and child state/environment remain. Alternate host reached through normal status-menu reopening. |
| Window size and navigation keyboard shortcuts | 800 × 500 minimum; no screen-jump shortcuts | 220–300 pt sidebar, ideal 250 pt; no new shortcut | Native bounds/regression enforce 220–300; initial 250 verified in both hosts, live divider 280 updates the continuous title rule. Prototype number keys stay prototype-only. |
| Bracket follow-up (PR58-r1 finding 4) | Shared `DatasheetBracketed` controls and toggle switch; overlay keeps `.pill` | `.chip` brackets (2 pt gap, 6 pt arms, no drop); toggle bracket covers only its 40 × 20 switch | Wired; overlay defaults and tooth coordinates untouched |
| Grin follow-up (PR58-r1 finding 6) | `DatasheetGrin(jaw:)` in main-window stamp | Viewport crops to tooth bounds plus 1-unit pad and 3-unit jaw travel; tier follows rendered pixels per unit | Wired; jaw travel remains reserved at rest |

### Chrome states omitted by the prototype

- `SidebarItem.rewriteMode` remains an internal selection with no navigation row or new route. Its existing detail behavior and mode-transition side effects are unchanged.
- `settings.shouldShowOnboarding` still selects the current onboarding-only view. The main-window strip and sidebar are shown only after onboarding, and no onboarding screen body is restyled in this phase.
- Status-menu navigation, pending `.aiEnhancements` / `.history` routes, microphone-settings scroll requests, and selection-driven mode transitions continue through their existing handlers.
- The existing detail screens retain all current states and controls while lanes A–F convert them. Phase 1 changes only the shell and its bindings; the prototype's screen content is not used as a substitute for current product state.
- The shell reads the actual history summary, current theme preference, selected speech model, reconciled input device, installed bundle version, and configured dictation shortcuts. Empty history remains an em dash readout; no prototype counts or device names are introduced.
- Native mapping repair: the coordinator approved an owned `NSSplitViewController` with default-behavior items because macOS 26's sidebar-behavior item adds a rounded glass card and insets. The original shell fails the real unordered native geometry regression; the repaired shell passes both native host arrangements, plus state/environment, binding/native collapse synchronization and divider-width reporting. No private-class mutation or global appearance change is used.
- Normal Debug visual proof is retained externally under `datasheet-run/renders/chrome/sol-native/`. Quiet tests and live geometry do not prove microphone capture/delivery: no recording, permission recovery action, provider change, system-device change, login item, or browser submission was exercised in this repair. The installed app remains untouched.

## A — Settings

Source: `Sources/Fluid/UI/SettingsView.swift`; bindings passed by `ContentView.preferencesView`.

Implementation status: all listed controls are wired in the new ten-zone sheet; the incremental Debug build and focused meter render test pass. Dark/light meter artifacts are under `/Users/atin/Projects/MouthKeys-worktrees/datasheet-run/renders/A/`. Native ten-zone screenshots and walkthrough still await the coordinator's serialized screen turn. No permissions, system devices, login item, backup action, shortcut capture, or alerts were exercised.

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Microphone permission: Grant Access | `ASRService.requestMicAccess()` | A Microphone permission row | Wired; existing ASR permission action and timing retained. |
| Microphone permission: Open Settings | `ASRService.openSystemSettingsForMic()` | A Microphone permission row | Wired; existing ASR permission action and timing retained. |
| Audio Devices: Refresh | `refreshDevices()`; refreshes the default input/output cache | A Microphone device-list action | Wired; refreshes device lists and cached default device names. |
| Input Device Priority: drag reorder | `SettingsStore.microphonePriority` | A Microphone table | Wired; existing ordering, removal, restore, and recording gates retained. |
| Input Device Priority: remove | `SettingsStore.microphonePriority` / suppressed microphone set | A Microphone table row action | Wired; existing ordering, removal, restore, and recording gates retained. |
| Input Device Priority: Restore Removed | `restoreRemovedMicrophones(with:)` | A Microphone table action | Wired; existing ordering, removal, restore, and recording gates retained. |
| Prototype: Input device picker | `selectedInputUID` reconciles from priority order; explicit choice calls `MicrophonePreferenceCoordinator.pick(_:source: "settings")` | A Microphone | Wired; uses the existing MouthKeys selection path and adds no setting. |
| Prototype: live input-level meter | `ASRService.audioLevelPublisher`; no SettingsStore key | A Microphone | Wired; actual publisher levels only; neutral at idle and reset on stop/disappear. |
| Output Device picker | `selectedOutputUID`, `SettingsStore.preferredOutputDeviceUID` | A Microphone | Wired; existing preferred-output key and Core Audio effect retained; disabled while recording. |
| Sensitivity slider | `visualizerNoiseThreshold` | H Overlay | Wired; existing binding and effect retained. |
| Sensitivity Reset | Sets `visualizerNoiseThreshold` to `0.4` | H Overlay | Wired; intrinsic control widths retained and the whole sensitivity row reflows below its label at minimum width. Existing binding and effect retained. |
| Accessibility permission state / Open Settings | `accessibilityEnabled`, `AccessibilityTrustMonitor` | B Hotkeys status row and recovery states | Wired; enabled/paused state and recovery hints retained. |
| Accessibility recovery: Relaunch MouthKeys | `restartApp` callback after trusted-but-failed tap | B Hotkeys recovery row | Wired; existing callback and destination retained. |
| Accessibility recovery: Reveal in Finder | `revealAppInFinder()` | B Hotkeys recovery actions | Wired; existing callback and destination retained. |
| Accessibility recovery: Open Applications | `openApplicationsFolder()` | B Hotkeys recovery actions | Wired; existing callback and destination retained. |
| Shortcut capture state / capture message | `activeShortcutRecordingTarget`, `shortcutRecordingMessage` | B Hotkeys status and `DatasheetHotkeyWell` | Wired; existing capture target and message state retained. |
| Primary Dictation Shortcuts: Add / Change / Cancel / Remove | `primaryDictationShortcuts` and existing recorder callbacks | B Hotkeys | Wired; recorder callbacks, add/change/cancel/remove, and one-shortcut minimum retained. |
| Primary Dictation AI Prompt picker | `dictationPromptSelection(for: .primary)` | B Hotkeys | Wired; existing binding and effect retained. |
| Command Mode shortcut and enable toggle | `commandModeShortcut`, `commandModeShortcutEnabled` | B Hotkeys | Wired; existing binding and effect retained. |
| Edit Mode shortcut and enable toggle | `rewriteShortcut`, `rewriteShortcutEnabled` | B Hotkeys | Wired; existing binding and effect retained. |
| Cancel Recording shortcut | `cancelRecordingShortcut` | B Hotkeys | Wired; existing binding and effect retained. |
| Paste Last Transcription shortcut and enable toggle | `pasteLastTranscriptionShortcut`, `pasteLastTranscriptionShortcutEnabled` | B Hotkeys | Wired; existing binding and effect retained. |
| Reprocess Last Dictation shortcut and enable toggle | `reprocessLastDictationShortcut`, `reprocessLastDictationShortcutEnabled` | B Hotkeys | Wired; existing binding and effect retained. |
| Activation Mode picker | `hotkeyMode`; updates `GlobalHotkeyManager` | B Hotkeys segmented Toggle / Hold / Both | Wired; existing enum, binding, persistence and hotkey-manager propagation retained. Both maps to the existing automatic mode. |
| Global Hotkey: “Hotkey initializing…” status | `hotkeyManagerInitialized`; `ContentView.preferencesView` passes the state and `SettingsView` renders this branch while accessibility is enabled | B Hotkeys status row | Wired; initializing state retained. |
| Input Device Priority: Move Up | `SettingsStore.moveMicrophonePriority(uid:by: -1)` then `refreshActiveInputSelection()`; also exposed as an accessibility action | A Microphone priority-row actions | Wired; context-menu and accessibility actions, ordering limits, and disabled state retained. |
| Input Device Priority: Move Down | `SettingsStore.moveMicrophonePriority(uid:by: 1)` then `refreshActiveInputSelection()`; also exposed as an accessibility action | A Microphone priority-row actions | Wired; context-menu and accessibility actions, ordering limits, and disabled state retained. |
| Copy to Clipboard | `copyToClipboard` / `SettingsStore.copyTranscriptionToClipboard` | C Dictation | Wired; existing binding and effect retained. |
| Text Insertion Mode picker | `SettingsStore.textInsertionMode` | C Dictation | Wired; existing binding and effect retained. |
| Return to Starting Field | `SettingsStore.returnDictationToStartingField` | C Dictation | Wired; existing binding and effect retained. |
| Q for Question Mark | `SettingsStore.questionMarkShortcutEnabled` | C Dictation | Wired; retained from PR #57 although absent from the prototype. |
| Spoken Send | `SettingsStore.spokenSendEnabled` | C Dictation | Wired; existing binding and effect retained. |
| Spoken Send phrase field | `SettingsStore.spokenSendPhrase` | C Dictation | Wired; existing binding and effect retained. |
| Send After a Pause | `SettingsStore.spokenSendImmediatelyEnabled`; baseline settle duration is 0.5 s, prototype copy says 1.5 s | C Dictation | Wired; baseline half-second behavior retained. |
| Send Key picker | `SettingsStore.spokenSendKey`; terminal target still sends Return | C Dictation | Wired; existing binding and effect retained. |
| Allow in c11 | No baseline setting after PR #57; terminals always receive Return | No C Dictation control | Removed by decision; prototype predates PR #57 |
| Pause Media During Transcription | `SettingsStore.pauseMediaDuringTranscription` | C Dictation | Wired; existing binding and effect retained. |
| Skip Silent Recordings | `SettingsStore.skipSilentRecordingsEnabled` | C Dictation | Wired; existing binding and effect retained. |
| Launch at startup | `SettingsStore.setLaunchAtStartup(_:)` | D App | Wired; existing binding and effect retained. |
| Launch at startup registration status | `SettingsStore.launchAtStartupStatusMessage` | D App status text | Wired; existing binding and effect retained. |
| Launch at startup error | `SettingsStore.launchAtStartupErrorMessage` | D App error state | Wired; existing binding and effect retained. |
| Show window when launched at login | `SettingsStore.showMainWindowAtLoginLaunch` | D App | Wired; existing binding and effect retained. |
| Hide from Dock & App Switcher | `SettingsStore.hideFromDockAndAppSwitcher` | D App | Wired; existing binding and effect retained. |
| Self-update statement and Latest release link | Static statement; `MouthKeysLinks.latestRelease` | D App | Wired; existing binding and effect retained. |
| Transcription Sounds picker | `SettingsStore.transcriptionStartSound`; selecting previews the sound | D App | Wired; existing binding and effect retained. |
| Volume slider | `SettingsStore.transcriptionSoundVolume`; release previews volume | D App | Wired; existing binding and effect retained. |
| Analytics Details | `showAnalyticsPrivacy`; telemetry remains hard-off | E History | Wired; existing binding and effect retained. |
| Save Transcription History | `SettingsStore.saveTranscriptionHistory` | E History | Wired; existing binding and effect retained. |
| Save Audio With History | `SettingsStore.saveAudioWithTranscriptionHistory` | E History | Wired; storage refresh retained and toggle stays disabled when history is off. |
| Weekends Don't Break Streak | `SettingsStore.weekendsDontBreakStreak` | E History | Wired; existing binding and effect retained. |
| Audio Storage usage and meter | `audioHistoryUsageBytes`, `SettingsStore.audioHistoryBudgetBytes` | E History | Wired; current usage and budget feed the Datasheet meter. |
| Audio budget field and Apply | `audioHistoryBudgetText`; writes `SettingsStore.audioHistoryBudgetGB` | E History | Wired; existing binding and effect retained. |
| Export Audio | `exportAudioZip()` | E History | Wired; existing binding and effect retained. |
| Delete Audio | `deleteSavedAudio()`; deletes saved audio only after confirmation and is disabled at zero usage | E History | Wired; confirmation and zero-usage disabled state retained. |
| Lowercase First Letter | `SettingsStore.gaavLowercaseFirstLetterEnabled` | F Format | Wired; existing binding and effect retained. |
| Remove Trailing Period | `SettingsStore.gaavRemoveTrailingPeriodEnabled` | F Format | Wired; existing binding and effect retained. |
| Slash Commands & @ Formatting | `SettingsStore.literalDictationFormattingEnabled` | F Format | Wired; existing binding and effect retained. |
| Space Between Dictations | `SettingsStore.continuousDictationSpacingEnabled` | F Format | Wired; existing binding and effect retained. |
| Smart Capitalization | `SettingsStore.contextAwareCapitalizationEnabled` | F Format | Wired; existing binding and effect retained. |
| AI Enhancement Failures | `SettingsStore.notifyAIProcessingFailures` | G Alerts | Wired; existing binding and effect retained. |
| Microphone Changes | `SettingsStore.showMicrophoneChangeAlerts` | G Alerts | Wired; disabling also dismisses the current microphone-change overlay. |
| Paste Check | `SettingsStore.showPasteCheckAlerts` | G Alerts | Wired; existing binding and effect retained. |
| Overlay Position | `SettingsStore.overlayPosition` | H Overlay | Wired; existing binding and effect retained. |
| Transcription Preview Length slider | `SettingsStore.transcriptionPreviewCharLimit` | H Overlay | Wired; existing binding and effect retained. |
| Overlay Size picker | `SettingsStore.overlaySize` | H Overlay segmented Pill / Small / Medium / Large | Wired; existing binding and bottom-position condition retained. |
| Notch Style picker | `SettingsStore.notchPresentationMode` | H Overlay | Wired; existing binding and effect retained. |
| Live Preview | `enableStreamingPreview` / `SettingsStore.enableStreamingPreview` | H Overlay | Wired; existing binding and effect retained. |
| Bottom Offset slider | `SettingsStore.overlayBottomOffset` | H Overlay | Wired; existing binding and effect retained. |
| Backup Export / Import | `exportBackup()` / `importBackup()`; API keys excluded | I Backup | Wired; document contents and confirmations retained; API keys stay excluded. |
| Show Debug Logs in App | `SettingsStore.enableDebugLogs` | J Debug | Wired; existing binding and effect retained. |
| Debug log location/help | `AppStorageLocation.logFolderName` | J Debug | Wired; dynamic log folder and diagnostics wording retained. |
| Reveal Log File | `FileLogger.shared.currentLogFileURL()` and `NSWorkspace.shared.activateFileViewerSelecting` | J Debug action | Wired; existing binding and effect retained. |
| Prototype: settings recording notice | Output Device is disabled while `asr.isRunning`; microphone-priority edits are disabled while running or starting | Settings status notice; retain those two individual disabled states | Wired in A and H notes; all other Settings rows remain enabled. |


### A state and evidence notes

- Zone navigation retains the pinned strip but realizes all ten section anchors together before scrolling. Selection follows the explicit tab or microphone navigation request, matching the prototype's tab actions; the added geometry-driven scrollspy was removed by coordinator decision 9. This prevents lazy extent estimates from landing on the wrong section and prevents bottom clamping from replacing the chosen Backup/Debug tab. Each anchor includes 24 additional points above the section's existing 34-point top spacing to expose its heading below the pinned strip, including the native horizontal scroller. No geometry callback changes selection or layout. The original normal native SwiftUI hang remains unexplained; the earlier 44 responsive frames do not establish its cause or resolution.
- PR62 r1 repairs preserve the sensitivity slider's 150-point track, 46-point readout, endpoint labels and complete Reset action. The whole row uses a horizontal layout when its label and controls fit and stacks them at minimum width. Activation Mode and bottom-only Overlay Size use the existing fixed-cell segmented primitive. Exact-head normal validation of these repairs and actual menu dismissal/clean quit remain pending a fresh screen lease. The earlier Input Device menu persisted; later picker open/dismiss results are invalid and the subsequent quit delay remains unresolved.
- The mic meter subscribes to `ASRService.audioLevelPublisher`, shows only received values while capture is active, and resets to neutral when capture stops or is cancelled and when the view disappears. It uses 16 segments at 4 × 14 points with 2 points between segments. The approved optional `DatasheetMeter.accentLastFilled` flag colors only the final filled segment with the palette accent; earlier filled segments remain ink and unfilled segments retain their existing treatment. An empty meter means no current level; it does not report readiness or failure.
- `ASettingsMeterRenderTests` renders the default, live-zero, live-partial, and live-full meter states in both themes without simulating audio input. The default caller stays neutral; zero has no accent; partial and full states accent only the final filled segment. See `datasheet-run/renders/A/manifest.json` and its attached PNGs.
- The input picker calls the same `MicrophonePreferenceCoordinator.pick` path used by the status menu. It changes MouthKeys priority and capture selection, not the macOS default input. Unavailable saved microphones remain in the priority table.
- Recording restrictions remain local: output-device changes are disabled while `asr.isRunning`; microphone priority edits are disabled while `asr.isRunning || asr.isStarting`. Other Settings controls stay enabled.
- Accessibility recovery retains stale-grant, conflicting-copy paths and Finder actions, Relaunch MouthKeys, Open Settings, Reveal in Finder, and Open Applications. Hotkey initializing and shortcut capture messages remain visible.
- Prototype-only `Allow in c11` is not present; current behavior always sends Return to terminals. Q for Question Mark remains in Dictation. Audio-history timeout retention, telemetry-off statement, API-key exclusion, and updater-off statement remain.

## B — Getting Started

Source: `ContentView.welcomeView`, `Sources/Fluid/UI/WelcomeView.swift`, `Theme/Components/SetupComponents.swift`, `UI/OnboardingTryoutStepView.swift`.

| Current screen / control or state | Current binding or effect | New target | Status |
|---|---|---|---|
| Page placard, title and lede | `ASRService.isAsrReady` / `modelsExistOnDisk` | `00 / START` sheet header | Restyled; fresh setup reads “Welcome to MouthKeys”; ready model reads “Getting Started” |
| Header: Run Onboarding Again | `settings.resetOnboardingProgress()` and `playgroundUsed = false` | Header trailing action | Restyled; same reset effects, plus the local shortcut-practice counter resets |
| Quick Setup title and progress readout | Model, microphone, and accessibility readiness plus voice validation or three local shortcut presses after those prerequisites are ready | Quick Setup header | Added four outlined/fill cells, `n/4`, and NOT STARTED / IN PROGRESS / READY; the fourth cell can reflect truthful key practice without persisting Playground validation |
| Quick Setup row title and detail | Model readiness, microphone permission, accessibility trust, local shortcut practice, and `playgroundUsed` | Four numbered setup rows | Restyled; incomplete rows retain their explanatory detail, and completed rows show compact metadata plus DONE; step 4 distinguishes shortcut practice from voice transcription validation |
| Quick Setup current and later row actions | Existing model, microphone, accessibility, and playground callbacks | Current row and later rows | Restyled; current row shows DO THIS NOW and a resting bracketed action, later rows show NEXT and outlined actions; each incomplete row remains clickable and completed rows are disabled |
| Voice Model Ready / Download Voice Model | `ASRService` readiness; action selects `.voiceEngine` | Quick Setup row 1 | Restyled; completed metadata distinguishes the selected model and loaded/ready state; incomplete action routes to Voice Engine |
| Microphone Permission Granted / Grant Microphone Permission | `ASRService.micStatus`; `requestMicAccess()` or `openSystemSettingsForMic()` | Quick Setup row 2 | Restyled; not-determined state offers Grant Access, denied state offers Open Settings, and authorized state shows completion metadata; a system prompt follows only an explicit click |
| Accessibility Access Enabled / Enable Accessibility Access | `accessibilityEnabled`; `openAccessibilitySettings` | Quick Setup row 3 | Restyled; preserves the existing settings and floating-guide path |
| Accessibility: “Already switched on?” | `AccessibilityTrustMonitor.hint == .staleGrant` | Recovery panel directly after row 3 | Restyled; preserves policy copy and Open Accessibility Settings action |
| Accessibility: conflicting app copies | `AccessibilityTrustMonitor.conflictingCopies`; `ConflictingAppCopyDetector.displayPath` | Recovery panel directly after row 3 | Restyled; shows up to three selectable paths; Show in Finder selects those same copies and Open Accessibility Settings remains available |
| Accessibility: Relaunch MouthKeys | `AccessibilityTrustMonitor.hint == .relaunch`; `restartApp` | Recovery panel directly after row 3 | Restyled; Relaunch MouthKeys callback preserved |
| Test Your Setup / Setup Tested Successfully | Local three-press shortcut practice after rows 1–3 are ready, or `playgroundUsed` from the real voice path | Quick Setup row 4 | Three completed key presses can finish this step only after model, microphone, and Accessibility are ready; copy says voice transcription remains untested. Only the existing Playground recording path sets `playgroundUsed`; Go to Playground still scrolls to and focuses the real transcript |
| Your Dictation Key and activation mode | `SettingsStore.primaryDictationShortcuts[0]`; `SettingsStore.hotkeyMode` | Your Dictation Key section header and keycap | Restyled; displays the configured shortcut and activation mode, including the mode description |
| Prototype: three-press shortcut practice | No persisted setting; local `hotkeyPracticeCount` and practice event monitor | Your Dictation Key practice panel and Quick Setup row 4 | Added; listens while Getting Started is active and ASR is idle, requires the complete configured physical modifier chord, retains its release owner, and stops after three completed presses. Before recording starts and while ASR is running or starting, practice releases its own monitor and gate so the primary shortcut retains stop/hold-release routing. Once rows 1–3 are ready, the third release completes row 4; practice never sets `playgroundUsed` or claims voice transcription was tested |
| Practice keycap fallback and Reset | Local `countManualPracticePress()` / `resetHotkeyPractice()` | Keycap button and Reset action | Added; clicking the keycap records an idle practice press; Reset clears and rearms an eligible idle drill. The fixed-size keycap inverts on DOWN, the completed released meter uses accent, and the narrow fallback hint wraps without moving the keycap or actions |
| Change Key or Mode | Existing Preferences destination and `SettingsStore` shortcut/mode controls | Your Dictation Key action | Added; routes to `.preferences`; changing the actual shortcut or mode remains in Settings |
| Playground Start / Stop Recording | `startRecording()` / `stopAndProcessTranscription()` | Test Playground action row | Restyled; retains the existing recording and transcription callbacks; Start marks the existing setup test completion. At narrow widths, status readouts move below the fixed-size recording control and shortcut reminder; the button keeps its frame across idle, recording, and transcript states |
| Playground “OR PRESS” shortcut | Configured primary shortcut | Test Playground action row | Added as a shortcut reminder; the actual global shortcut behavior is unchanged |
| Recording / transcript character count | `ASRService.isRunning`; `ASRService.finalText.count` | Playground status line | Restyled; shows Listening while recording or the transcript character count when text exists |
| Parakeet word boost status | `selectedSpeechModel`; `ASRService.wordBoostStatusText` | Playground status line | Restyled; shown for the same Parakeet models |
| Editable transcript | `ASRService.finalText` binding | Playground text editor | Restyled; editing, focus, and transcription state preserved |
| Copy Text | Copies `ASRService.finalText` to `NSPasteboard` | Playground transcript actions | Restyled; same clipboard action and disabled state when empty |
| Clear & Test Again | Sets `ASRService.finalText` to an empty string | Playground transcript actions | Restyled; clear action remains available |
| Inline Datasheet overlay | Production `DatasheetPill`, `DatasheetTraceRow`, `DatasheetFootRow`, `DatasheetPreview`, `DatasheetRail`, and `DatasheetChip` read current shared overlay state | Inline reference below Playground controls | Added; read-only teaching reference; a single centered fit transform keeps the persisted pill size, rails and all twelve zones within the available inline width. The mic hotspot uses the production battery-label reservation; production floating overlay and delivery behavior are untouched |
| Overlay preview, trace, recording square, timer, word count, WPM, target app and mic callouts | Current Datasheet overlay state and `callouts.js` annotations | Inline overlay callout zones | Added with twelve resting dashed outlines, a solid selected outline, leader, square terminus, label and description; visual and hover frames share the same fit transform |
| History, copy, cancel and reprocess callouts | Live overlay chip semantics; `callouts.js` annotations | Inline overlay callout zones | Added as inert annotations; only the real floating overlay retains those actions |
| How to Use, Command Mode and Edit Mode guide accordions | Local disclosure state and static examples | No new Getting Started control | Removed by the settled direction; Quick Setup, Your Dictation Key and Test Playground remain the three sections |
| Onboarding microphone selector | `selectedOnboardingInputUID` and microphone coordinator inside `OnboardingFlowView` | First-run wizard, not Getting Started | Unchanged; lane B does not alter the lower `OnboardingFlowView` or its input selection |
| Accessibility trust monitor and app-copy detector | `AccessibilityTrustMonitor` refresh and read-only copy detection | Quick Setup recovery panel | Unchanged services; no TCC edits or app-copy deletion |

### Getting Started states omitted by the prototype

- Downloaded-but-not-loaded model, model loading, denied or restricted microphone, “Already switched on?”, conflicting registered app copies, and `failed_trusted` relaunch remain represented by current ASR and permission-monitor state. The prototype does not replace those recovery paths.
- The first-run wizard and its microphone input selection remain in `OnboardingFlowView`; lane B owns only the `WelcomeView` region above it.
- The inline overlay is a teaching reference composed from production Datasheet views. Its chips do not trigger history, clipboard, cancellation, reprocess, or microphone-picker side effects. The real floating overlay continues to own those actions.
- Shortcut practice is local: three presses complete Quick Setup row 4 only after model, microphone, and Accessibility are ready. It does not persist `playgroundUsed` or claim voice transcription was tested; only the existing Playground recording path sets that value.
- The existing primary shortcut’s global hotkey handling, audio capture, transcript delivery, and text insertion are not changed by this lane.

## C — Voice Engine, Custom Dictionary, AI Enhancement, Feedback

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Voice Engine: preview model selection | `viewModel.previewSpeechModel` | Preview panel and model table | Wired; row selection still only previews until Activate |
| Voice Engine: preview description, size, languages, speed, accuracy, runtime | `SettingsStore.SpeechModel` metadata | Preview spec strip | Wired; preserve model-specific values |
| Voice Engine: Cohere supported-language enumeration before download/activation | `SpeechModel.cohereTranscribeSixBit.supportedLanguageCodes` | Wrapping preview metadata below description | Restored; all 14 existing codes remain visible independently of installed/active state; no selection or model operation |
| Voice Engine: provider filter / model sort | `viewModel.providerFilter`, `viewModel.modelSortOption` | Header menus | Wired; preserve sorting/filtering |
| Voice Engine: active and other model tables | `SettingsStore.selectedSpeechModel`, installed-model state | Active Model / Other Models | Wired; selected engine and row order unchanged |
| Voice Engine: Activate | `viewModel.activateSpeechModel(model)` | Model row and preview action | Wired; preserve load/activation side effects |
| Voice Engine: Download / Cancel / progress | `downloadSpeechModel`, `cancelSpeechModelDownload`, ASR preparation progress/status | Model row progress state | Wired; preserve cancellation, phase text, percentage and errors |
| Voice Engine: model preparation state/error | `asr.modelPreparationPhase`, `modelPreparationStatusText`, existing `asr.showError` alert | Row / shared alert | Retained; progress, error and shared-alert states remain wired; no model download run during QA |
| Voice Engine: Delete downloaded model | `viewModel.deleteSpeechModel(model)` | Selected model row action | Retained; deletion not exercised per scope |
| Voice Engine: per-model language selection | `selectedAppleSpeechLocale`, `selectedNemotronLanguage`, `selectedCohereLanguage`, existing model language bindings | Active model row control | Wired; keep each model's existing language binding |
| Voice Engine: Open Custom Dictionary | `.openCustomDictionaryFromVoiceEngine` notification routes to `.customDictionary` | Preview custom words link | Retained; route unchanged |
| Voice Engine: remove filler words toggle and tags | `removeFillerWordsEnabled`, existing filler-word setting and edit callbacks | Remove Filler Words section | Wired; preserve add/remove/reset and saved list |
| Voice Engine: regional filler-word offer | Existing offer preference, exact message, Keep / No thanks callbacks | FillerWordsEditor banner | Wired; preserve exact text and both answers |
| Voice Engine: active recording guard | `asr.isRunning` | Whole Voice Engine content | Retained; controls remain disabled during recording |
| Custom Dictionary: Import / Export | `importDictionary()` / `exportDictionary()` | Header actions | Wired; preserve file panels and transfer behavior |
| Custom Dictionary: Auto-learn | `automaticDictionaryLearningEnabled`; disabling cancels correction tracker | Header toggle | Wired; preserve saved value and cancellation side effect |
| Teach Words: composer mode | `composerMode` | Fixed Train by Voice / Add Manually segments | Wired; preserve disabled state during recording/processing |
| Teach Words: target text and voice matching | `trainingReplacement`, `pronunciationMatchingEnabled`, `handlePronunciationMatchingChange` | Form and Basic / Advanced controls | Wired; preserve model availability and research-preview copy |
| Teach Words: training steps, readiness, final output, heard variants | Existing training state, ASR endpoint and variant callbacks | 3-cell readiness / training panel | Wired; preserve 3/3 logic, remove-variant action, output and progress |
| Teach Words: Start / Stop / Clear / Add Replacement | `toggleAutomaticTraining`, `resetTraining`, `addTrainedReplacement` | Training panel actions | Wired; preserve recorder, clear and save effects |
| Teach Words: duplicate/error states | Existing training status and duplicate-trigger validation | Inline status rows | Retained; error copy and recovery paths remain wired |
| Your Dictionary: replacement table | `SettingsStore.customDictionaryEntries` | Inline table | Moved inline; sort/order and replacement semantics retained |
| Your Dictionary: Add / Edit / Delete / confirmation | `manualTriggerDraft`, `manualReplacement`, `editingEntry`, `deleteEntry`, replacement confirmation | Teach Words / inline table / edit sheet | Moved inline; normalization, whitespace payloads, confirmation, cache invalidation and notifications retained |
| Spoken Formatting: enabled and start word | `punctuationAutoConvertEnabled`, `punctuationPrefix` | Inline Spoken Formatting section | Wired; preserve saved settings and prefix persistence |
| Spoken Formatting: information and examples | `isPunctuationInfoExpanded`, `punctuationPreviewPrefix` | Inline info and Try Saying panels | Wired; preserve copy and state |
| Spoken Formatting: action enable/edit/phrases | `formattingActionEnabledBinding(for:)`, action alias rules, `formattingActionEditor` | Inline action table and editor | Wired; preserve fixed outputs and empty-phrase disabled state |
| Spoken Formatting: punctuation add/edit/delete/clear | `punctuationRules`, `punctuationAliasesText`, `punctuationSymbolText` | Third inline table/editor | Wired; preserve validation and rule meaning |
| Spoken Formatting: Reset All Defaults | Existing reset alert and `resetPunctuationDictionary()` | Inline section | Retained; confirmation and full reset effect unchanged |
| Custom Words: boost enable and rows | `vocabBoostingEnabled`, Parakeet vocabulary store | Inline Custom Words table | Wired; keep rows visible/read-only while boosting is off |
| Custom Words: Add / Edit / Delete / priority | `boostTermText`, `boostTermStrength`, existing term callbacks | Inline editor and table | Retained; weights, duplicate check, mutations and error state unchanged |
| AI Enhancement: Providers / Advanced Prompts tabs | `selectedConfigurationSection` | AI Enhancement header | Wired; preserve tab state and content |
| AI Enhancement: unsupported note | Static unsupported notice and straight-voice-to-text explanation | Under page header | Retained verbatim |
| Providers: help, search, verified / all-provider status | `viewModel.showHelp`, `providerSearchText`, provider connection state | Providers tables | Wired; preserve filtering/status and expansion |
| Provider: select, expand/collapse, model picker/refresh, reasoning | Existing provider/model bindings and reasoning view model | Provider rows/details | Wired; preserve provider selection and fetch/configuration actions |
| Provider: name, URL, API key, reveal/clear/edit | Existing provider draft state and keychain service | Expanded provider details | Wired; preserve keychain behavior; tools never inspect or modify credentials; normal internal lifecycle reads are permitted for look-only QA |
| Provider: verify connection and result/error | `testAPIConnection`, connection status/error and progress | Provider details | Wired; preserve test path; no credentials or external requests during QA |
| Provider: Add Custom / Save / Cancel / Delete | Existing draft callbacks and delete confirmation | Provider editor | Wired; preserve creation, validation and confirmation |
| Advanced Prompts: built-in/custom prompt rows | Prompt selection, `dictationPromptProfiles`, `openDefaultPromptViewer`, `openEditor`, delete confirmation | Advanced Prompts / prompt editor | Wired; preserve selection, add/edit/delete and default viewer |
| Advanced Prompts: All Apps / Selected Apps and App Overrides | `promptRoutingScope(for:)`, app binding store, file picker and linked-mode bindings | Prompt Routing / App Overrides table | Wired; preserve per-mode routing, add/remove and sync behavior |
| Dictation: Send Custom Prompt Only | `viewModel.sendCustomPromptOnly` and setter | Advanced Prompts / Dictate | Retained; routing effect unchanged |
| Prompt editor: name, body, provider, model, shortcut, Reset to Built-in | Existing draft fields, provider/model bindings, shortcut recorder, `resetDefaultPromptOverride` | Prompt editor | Wired; preserve capture, reset and save semantics |
| Prompt editor: Test Mode / progress / error / raw and processed output | `promptTest.isActive`, `isProcessing`, `lastError`, transcript and output | Prompt editor test panel | Retained; all states stay in the editor and output never types into another app |
| Feedback: message and diagnostic metadata toggle | `feedbackText`, `includeSystemInfo`, `systemInfo()` | Feedback form | Wired; preserve exact diagnostic payload and toggle state |
| Feedback: Open GitHub Issue | `openFeedbackIssue` and prefilled `MouthKeysLinks` URL | Feedback action | Retained; destination unchanged; browser handoff and submission not exercised per scope |
| About: Fig. 1 grin, repository link and revision | `DatasheetGrin`, `MouthKeysLinks` repository URL, bundle version | About drawing | Added and wired; actual shared grin primitive and GitHub target |
| About: FluidVoice credit and sponsor links | `MouthKeysLinks.upstreamRepository`, `MouthKeysLinks.upstreamSponsor`; static attribution | About section | Retained; both destinations and credit text unchanged |

Repair checkpoint: Lane C fixtures install the actual screen Views and use an unordered native hosting window, including the normal AI screen ScrollView wrapper. Parent-panel pixel assertions failed with the old extracted Voice/AI fragments and pass with the installed path; fixture lifecycle inputs default to the original production lifecycle. Dictionary fixture state is explicitly synthetic and skips VAD preparation; Feedback and AI initial-state inputs keep their original defaults. Both-theme fixtures cover the two AI tabs, expanded provider controls with empty credential state, download progress, regional filler offer, dictionary training/manual/empty/error states and all inline tables, and empty/populated Feedback including About. These are layout evidence, separate from normal native actions.

Coordinator decision 6 grants only the optional empty letter in `DatasheetSection`: its existing letter block is conditional on nonempty input, with no other primitive changes. C content headings pass an empty letter to match the prototype. Nonempty section/gallery/native picker tests pass; the baseline and conditional-primitive foundation PNGs are byte-identical in both themes. SettingsView outside the top-level FillerWordsEditor and FlowLayout are byte-identical to the merged base.

Selected Voice Engine rows pass their inverted palette explicitly to action labels, progress, native language fields and status controls; the preview action keeps the ordinary palette. The Cohere and three Nemotron variants reuse DatasheetPicker with a 180×32 native field in a stable 280-point action column. Their existing language bindings, menu choices/checkmarks and areSpeechModelActionsBlocked predicate remain intact. Source-extracted complete production-row probes use scalar stand-ins only: the old borderless menu fails all 192 German/longest-label cases; the repaired field passes OCR, native bounds, nine interior hit points and disabled suppression at 469/669/880-point row widths, both themes, selected/ordinary and enabled/blocked. Longest current values are Mandarin Chinese and Norwegian Nynorsk; no model activation or language persistence is exercised. Full model tables in both themes at all three widths show selected Download/Cancel content and disabled neighboring controls. Active/loading/cancelling branch styling is source-audited; actual model operations remain unexercised. The independent parity audit restores baseline cancellation availability (`Cancel` disables only while cancelling) and the active-model language picker's existing blocked state. An attempted hidden-window AX cancellation probe could not expose SwiftUI virtual buttons and was removed; its logs are inconclusive, not a product failure or cancellation proof. No live model download, cancellation, deletion, provider credential edits/tests, voice training or browser submission has been exercised. Native actual-body probes at 549/749-point detail widths exposed truncated headings, specification cells and the Auto-learn label. C-owned adaptive headers, stacked Teach Words panels, responsive specification strips and compact model rows and stacked About figure annotations preserve all values/actions at these widths; wide shared-header appearance stays unchanged. Normal Debug validation at the preceding reviewed head captured 54 frames in both themes at 1000×700 and 800×500, with actual 749/549-point detail widths, covering Voice Engine, Dictionary training/manual tables, AI Providers/Advanced Prompts and Feedback/About. This look-only normal run did not create selected active-language state. The language repair’s exact-build normal runtime receipt is a separate gate; selected-language coverage above is isolated native-row evidence. The isolated real field also passes native AX role/value/label/enabled assertions in 16 inverse-palette cases. The complete ViewThatFits row’s virtual AX tree is unavailable in both old and repaired hidden scratch hosts, so that probe does not establish full-row AX or delete-button hit behavior. Delete action and blocked predicate remain source-identical; no delete is invoked. Default AI onAppear keychain reads are allowed only as part of normal look-only navigation under coordinator decision 5. AI button padding (round-1 P3 finding 2) is deferred to the coordinator’s finish follow-up.

Round-2 Cohere preview repair restores its existing 14 supported language codes below the description, before download or activation. Data-only native probes install the extracted production preview in an activation-prohibited unordered host: old production 0/4, repaired 4/4, enumeration-removed mutation 0/4, restored 4/4 at 469/669-point content widths in both themes. Every code and Download remain readable; no model action runs. The committed regression installs the actual Voice Engine screen body at 549/749-point detail widths and checks every code through native bitmap OCR. Prior selected-language field/action code is byte-identical; its existing geometry/hit/AX evidence remains applicable. Current-head Atlas and normal Debug preview gates are reported separately.

## D — History, Stats, Command Mode, File Transcription

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| History search / clear search / no results | `searchQuery`; `historyStore.search(query:)` | Search field, no-matches state | Restyled; clear-search space stays reserved; normal Debug matrix recorded; relevant state limits below |
| History row selection / day grouping | `selectedEntryID`, entry timestamps | Full-bleed history index | Restyled; normal Debug matrix recorded; relevant state limits below |
| History title facts | app, duration when audio exists, word count, character count | Detail title block | Restyled; normal Debug matrix recorded; relevant state limits below |
| History delivery outcome | No delivery field exists in `TranscriptionHistoryEntry`; never infer from app name, text, or AI state | Neutral outlined `UNKNOWN` with accessible note | Sol decision: record not recorded; prototype Pasted / NOT PASTED capability is unavailable |
| History final / original transcript and AI error | `processedText`, `rawText`, `aiProcessingError`, `wasAIProcessed`, `processingModel` | Detail transcript and secondary facts | Restyled; raw text and failure fallback preserved; normal Debug matrix recorded; relevant state limits below |
| History copy processed / raw / both | `copyToClipboard` and `combinedText(for:)` | Detail Copy action and row context menu | Restyled; preserve copied text selection and existing choices |
| History Reveal Audio / Export Pair | `revealAudio(entry)`, `exportPair(entry)` | Detail actions and row context menu | Restyled; disabled when audio is unavailable |
| History Delete Entry / Clear All | `historyStore.deleteEntry(id:)`; existing destructive clear confirmation | Detail action and index footer | Restyled; preserve selection update and confirmation |
| History empty state / Open Playground | Lane-owned closure sets `selectedSidebarItem = .welcome` in the `.history` detail case | Empty-state panel | Restyled; outline grin remains in lane F |
| Stats today / total words / time saved / streak / session KPIs | Existing `TranscriptionHistoryStore` metrics and `settings.userTypingWPM` | Four KPI cells; today words in Total Words, today sessions in Transcriptions, today saved time in the window title strip | Restyled; real store values retained; KPI footers reserve equal height; streak square follows the binding prototype |
| Stats WPM edit / Save / Cancel | `editingWPM`; existing positive integer validation and `userTypingWPM` setter | Time-saved KPI editor | Restyled; preserve validation and save |
| Stats 7 / 30 day chart and hover details | `chartDays`; `dailyWordCounts(days:)` | Square bar chart and fixed-cell range selector | Restyled; today uses accent; no-data chart state retained |
| Stats milestones / insights / personal records | Existing milestone, aggregate and record store accessors | Milestone grid and ruled tables | Restyled; zero-data fallbacks retained |
| Stats Reset Everything | Existing destructive reset confirmation and `clearAllHistory()` | Stats footer action | Restyled; preserve confirmation |
| Command Mode readiness | `settings.commandModeReadinessIssue` | Fixed status row; issue links to AI Settings | Restyled; ready and not-ready states reserve the same row height |
| Command Mode New Chat / recent chat selector / delete chat | `service.createNewChat()`, `getRecentChats()`, `switchToChat(id:)`, `deleteCurrentChat()` | Header controls and confirmation | Restyled; preserve processing disables and delete confirmation |
| Command Mode Confirm Before Execute | `settings.commandModeConfirmBeforeExecute` | Header toggle and pending command panel | Restyled; pending command remains explicit |
| Command Mode how-to expander / examples | `showHowTo`, current shortcut display | Help row | Restyled; preserves examples and caution |
| Command Mode prompt / Sync / provider / model | `inputText`, `commandModeLinkedToGlobal`, existing provider and model bindings | Two-row composer | Restyled; linked-mode disables the local pickers |
| Command Mode record / Run / cancel pending command | Existing ASR and command service callbacks | Composer actions and confirmation panel | Restyled; preserves recording, readiness gate, confirm, and cancel |
| Command Mode thinking / tool call / output / errors | `Message.thinking`, `toolCall`, tool JSON output and current step | Chat messages and processing status | Restyled; text selection and thinking preference retained |
| File Transcription choose / drag / unsupported drop | Existing `.fileImporter`, `.fileURL` drop handler, `dropErrorMessage` | Drop zone and dismissible unsupported-file message | Restyled; picker and error behavior retained |
| File Transcription selected file / engine / speaker options | `selectedFileURL`, `asrService.activeProviderName`, `fileTranscriptionSpeakerLabelsEnabled`, `fileTranscriptionExpectedSpeakerCount` | File header and options rows | Restyled; video diarization disable and model selection retained |
| File Transcription run / progress / error | Existing `MeetingTranscriptionService` state and `transcribeFile(_:)` | Primary action, progress, dismissible error | Restyled; no new cancel behavior added |
| File Transcription result / fallback notice / speaker segments | Existing result, fallback notice, confidence, timing and segments | Result panel | Restyled; copy/export and selectable text retained |
| File Transcription recent rows / detail / Copy / Export / Delete / Clear all | `FileTranscriptionHistoryStore` and existing confirmation-free clear action | Recent table and selected detail | Restyled; mutations and selection retained |
| Lane D omitted prototype states | History AI failure/raw text, empty/no-result/audio-missing; stats empty chart and WPM editor; command processing/tool output/provider readiness; file errors/fallback/speaker segments/recent selection | Existing per-screen states above | Retained and accounted for; relevant state limits below |

Offscreen render test: `DatasheetLaneDRenderTests` passes for both themes. Its `ImageRenderer` output cannot show native `HSplitView` or the file drop destination; scroll surfaces also render blank in this host. Those files are retained only as test attachments, not visual proof. The normal Debug matrix records all four screens in both themes at 1000×700 and 800×500. Its first pass exposed responsive defects; the repair reflows History actions and metadata, uses a two-column Stats KPI grid below the four-cell minimum width, moves Command Mode header/composer controls onto separate rows with vertical scrolling, and aligns recent-file timestamps under WHEN. Repaired normal captures show readable History actions, Stats KPI headings and Command header controls; a guarded scroll shows File timestamps in the correct column. History search produced NO MATCHES, Clear Search returned the entries, and AI-error selection was observed. No audio or clipboard action was invoked.

`DatasheetLaneDNativeLayoutTests` verifies native narrow/wide action-bar sizing in both themes and audio availability states without ordering a window. `DatasheetLaneDCommandScrollTests` instantiates the real Command Mode body in an unordered native host, measures the outer scroll extent and verifies that native scrolling makes the full composer reachable at default/minimum sizes in both themes. A separate diagnostic comparison found a 738pt document in a 460pt viewport with a 278pt range, and the composer visible at that native limit; the previous layout had no outer page scroll. Live minimum-size composer input routing remains a targeted normal Debug validation item, so these native geometry tests are not a claim of complete live coverage. Provider readiness, command execution, audio-present playback/export, real file processing and full empty/reset/destructive states remain unexercised in the normal walkthrough; existing bindings and service paths are retained and the complete automated suite is a separate gate.

The Command scroll fixture snapshots chat sessions, current chat ID and selected model before constructing any service/view, then restores their original presence, type and value after all native hosts are dismantled. Its synthetic-domain regression covers stale, absent and typed model values, including a throwing render body. Separate actual-view probes with data-only settings/services establish that Sync-off model normalization triggers the write; no operator Debug preferences are seeded for that proof. Production normalization and geometry assertions are unchanged.

## E — First-run wizard

Source: `OnboardingFlowView` in `WelcomeView.swift`, `UI/OnboardingTryoutStepView.swift`, and the recovery states in `Theme/Components/OnboardingComponents.swift`. The approved prototype's five pages are the baseline; native states below remain required even where the screenshots do not show them.

| Existing screen / control | Existing binding, key, or effect | New location | Status |
|---|---|---|---|
| Onboarding step / progress | `currentStep`; `AnalyticsOnboardingStep` completion events | Five-row step rail and page index | Restyled; legacy stored step 5 (retired AI page) resolves to Try MouthKeys |
| Welcome / Next | Advance `currentStep`; onboarding welcome sound/lifecycle remains in the existing handlers | Ruled Welcome page with tileless themed Fig. 1 grin drawing | Restyled |
| Language / popular choices / Other / search | `SettingsStore.onboardingSelectedLanguageID`; `VoiceEngineLanguageCatalog` choices and search | Language page | Restyled; all catalog languages and selection effects retained |
| Voice Engine / recommended and other routes | `SettingsStore.selectedSpeechModel` plus Apple Speech, Cohere, and Nemotron language settings via `VoiceEngineLanguageCatalog.apply` | Voice Engine page | Restyled; route selection still resets tryout validation and provider state when relevant |
| Voice Engine model information / help | `onboardingModelTooltip(for:)` and `SpeechModel.cardDescription` | Info glyph, full hover help, and accessible label on each route card | Restored; includes language, memory, and provider guidance |
| Model Download & Activate / Activate / Active now / Cancel / Delete | Existing ASR preparation, cancellation, installed-model cache deletion, and error alert | Voice Engine route rows | Restyled; download percentage/status, loading/cancelling/deleting, errors, and recording/preparation action locks retained |
| Allow microphone / Open Settings | `ASRService.micStatus`, `requestMicAccess`, `openSystemSettingsForMic` | Enable Access permission row | Restyled; system prompt is invoked only by the existing Allow action; denied/restricted routes to Settings |
| Select your microphone / input level | `SettingsStore.microphonePriority`; live preview, no-device state, level and preview error | Enable Access microphone panel | Restyled; shown after authorization, with device picker, no-device text, fixed meter and error status |
| Enable Accessibility Access / Finish Accessibility Access / Open Settings / Show Guide | Existing accessibility trust binding, setup-in-progress state and `openAccessibilitySettings` callback | Enable Access permission row | Restyled; needed, in-Settings and ready states retained |
| Accessibility recovery hint | `AccessibilityTrustMonitor.hint`; stale-grant Settings action, conflicting-copy paths plus Show in Finder and Settings actions, trusted-failed Relaunch action | Ruled recovery row under Accessibility | Restyled; `.none`, stale grant, conflicting copies, and relaunch states retained |
| Already enabled it? | Existing trust monitor updates on its existing lifecycle | Enable Access help text | Retained when no recovery hint is active |
| Your Dictation Key / Change / Cancel / press-key state | Existing primary-shortcut binding and recording callbacks | Try MouthKeys key panel | Restyled; actual shortcut, capture feedback, cancellation, and shortcut guards retained |
| Dictation practice / final text | `ASRService.finalText`, real running/ready state, selected language | Try MouthKeys editor panel | Restyled; existing test completion gate retained |
| Regional filler offer / keep / No thanks | `RegionalFillerOffer.offer` and `.answer(keep:surface: "onboarding")` | Fixed-height Try MouthKeys offer row | Restyled; both answers and offer eligibility retained |
| Back / Skip setup / Next / Continue / Finish Setup | Existing step navigation, `onboardingPlaygroundSkipped`, completion, analytics, and `markAISkipped` when no provider is configured | Ruled fixed footer and setup header | Restyled; back/continue gates and lifecycle retained; skip remains available only on the final page when not recording; finish still requires a ready model, both permissions, and validated or skipped practice |
| Optional AI Enhancement / provider choices | `UI/OnboardingAIEnhancementStepView` provider effects are not part of the approved five-page prototype or straight voice-to-text setup | No first-run page | Not shown; completion preserves the existing `markAISkipped` side effect when no provider is configured |

Prototype omissions explicitly covered by the native inventory: microphone authorization/error/no-device/level states; Accessibility setup-in-progress and all trust-monitor recovery variants with their actions; model lifecycle, error and recording-lock states; shortcut capture; saved step migration; and footer navigation/skip/finish gates. No existing `SettingsStore` keys or effects are removed.

## F — Menu and finish

Source: the lane-F presentation work below. The menu, screen bindings, and delivery actions stay on their existing paths. Debug build, Atlas suite, and the observer-owned native walkthrough remain separate proof gates.

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Main-window Today words and time | `TranscriptionHistoryStore.todaySummary`; existing Stats navigation | Fixed 208 pt title-strip control with a compact, one-line word count and saved time | Restyled; exact values remain in help and accessibility text; Stats action unchanged |
| Main-window sidebar grin | `DatasheetMenuBarMark.listeningJaw` from the overlay trace | Large Datasheet grin with a 0 / 1.5 / 3 pt jaw | Mapped from the existing menu jaw’s 0 / 1 / 2 states; menu mark geometry is unchanged |
| Main-window MouthKeys wordmark | MouthKeys repository URL | Keyboard-accessible repository action with underline on hover | Wired; hover underline does not change layout |
| Status menu header | Current recording/processing/permission state | Datasheet mark, MOUTHKEYS wordmark, state, and live orange square | Restyled; current state binding retained |
| Status menu: Start Dictation | `toggleDictation` | Status menu | Preserve action |
| Status menu: hotkeys-paused recovery | `resolveHotkeysPaused`; visible while configured hotkeys lack Accessibility trust | Status menu recovery item | Preserve visibility and route |
| Status menu: microphone selection submenu | `selectMicrophone(_:)` from the prioritized available inputs | Microphone submenu | Preserve current-device state and selection |
| Status menu: History | `openHistory` | Status menu | Preserve route |
| Status menu: Copy Last Transcript | `copyLastTranscript(_:)` | Status menu | Preserve availability and clipboard effect |
| Status menu: Custom Dictionary | `openCustomDictionary` | Status menu | Preserve route |
| Status menu: Open MouthKeys | `openMainWindow` | Status menu | Preserve route |
| Status menu: MouthKeys on GitHub | No current item | Repository row after Open MouthKeys | Added; opens the repository URL |
| Status menu: Settings | `openPreferences` | Status menu | Preserve route |
| Status menu: Quit MouthKeys | `NSApplication.terminate(_:)` | Status menu | Preserve action |
| AI settings: fixed-size button chrome | 27 `DatasheetAIButtonStyle` callers | No-padding `.fixed` variant for six 34×34 / 76×34 icon/action controls | Added opt-in at four `AIConfiguration.swift` and two `AdvancedSettings.swift` callers; remaining 21 keep `.padded`; actions and disabled states retained |
| History: selected entry metadata | Entry number, window/context label, and full timestamp | Three reserved 10 pt rows above the transcript | Restyled; selection and transcript actions unchanged |
| History: empty state | Existing empty-history condition and Open Playground action | Quiet outline grin above the placard | Added; Open Playground action retained |
| Stats: lower insights and records | Existing history/store values and row contents | Two 280 pt columns at widths ≥580 pt; stacked tables and wrapped rows below that width | Restyled; 0.7 / 0.65 text scale factors removed; KPI and metric bindings unchanged |
| Command Mode: provider and model selectors | Effective provider/model bindings; Sync-linked disabled state; model availability | Square Datasheet searchable controls | Restyled only for Command Mode; all picker callers keep standard chrome by default; search, bindings, selection, and disabled semantics retained |
| Settings: selected zone | Existing explicit Settings tab selection | Selected tab remains inverted without a resting bracket | Restyled; navigation and selection unchanged |
| Settings: microphone priority and live level | `SettingsStore.microphonePriority`, `MicrophonePreferenceCoordinator.pick`, and `ASRService.audioLevelPublisher` | Picker and meter share a responsive table layout | Restyled; current pick, refresh, reorder, and live meter paths retained |
| Settings: Sensitivity endpoints | Existing `visualizerNoiseThreshold` range and binding | Endpoint labels at 10 pt or larger | Restyled; range and reset value unchanged |
| Settings: Backup Export / Import | Existing export/import handlers | Side-by-side neutral actions | Restyled; both callbacks retained |
| Settings: initialization and hotkey recovery | Hotkey tap state and `AccessibilityTrustMonitor.hint` | Hide initializing row for failed-trusted/relaunch recovery; retain Relaunch action | Restyled; genuine initializing and recording states remain |
| Inline playground rail and preview icons | Existing inline playground buttons | Retained existing square chips; no new button variant | Existing chip presentation retained; live overlay and menu chips unchanged |
| Welcome: Figure 1 grin | Existing onboarding view and controls | Tileless grin with the existing prototype coordinates | Restyled; onboarding actions/defaults unchanged |
| Welcome: practice detail | Existing practice count and readiness | Reserved detail height across zero-to-three presses at the approved 443 pt width | Restyled; press count, status, keycaps, and actions retain position |
| Try MouthKeys: typography and conflict detail | Existing shortcut, accessibility, and provider-conflict state | Mono text ≥10 pt; prose ≥13 pt; fixed height for the full conflict sentence | Restyled; actions and stored values unchanged |
| Custom Dictionary: `No replacements yet` | Existing replacement-empty condition and Teach Words route | Quiet outline grin above the placard | Added only for this state; custom-word and punctuation empty states unchanged |
| Legacy `ThemedGroupBox` | No references in `Sources/Fluid` or `Tests` | Remove dead wrapper | Retired after final zero-reference audit |
| Legacy `GlossyEffects.swift` | `buttonHoverEffect()` remains used by `ContentView` and `RecordingView`; `HoverableGlossyCard` itself has no callers | Keep shared file and live modifier | Retained; no broad theme cleanup |
| Legacy `AppTheme` / `ThemedCard` | Existing app theme and RecordingView callers | Keep shared types | Retained for live callers |
| Real-path install checks | Existing Developer ID checklist and c11 delivery checks | F presentation walkthrough plus Ghostty Reliable Paste pass | Added to `docs/INSTALL-CHECKLIST.md`; no app install or live-runtime proof performed here |

The F screenshots do not replace native proof for real history data, menu actions, Settings persistence, mic routing, searchable provider/model selection, hotkey recovery, or c11/Ghostty delivery. No new keys, service paths, or delivery actions are introduced. The apphost build and full suite run on Atlas; the native walkthrough belongs to the coordinator’s post-F observer rig.

## Change log by lane

| Lane | Commit / PR | Notes |
|---|---|---|
| Foundations | Pending | The table above records the current bindings and target dispositions before screen rewiring. |
| Chrome | Pending |  |
| A | Pending |  |
| B | Pending |  |
| C | Pending |  |
| D | Pending |  |
| E | Pending |  |
| F | Pending | Source inventory and install checks updated; Debug build passed; Atlas suite and native walkthrough remain pending. |
