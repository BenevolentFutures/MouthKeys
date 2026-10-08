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

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Microphone permission: Grant Access | `ASRService.requestMicAccess()` | A Microphone permission row | Restyle; preserve system prompt timing |
| Microphone permission: Open Settings | `ASRService.openSystemSettingsForMic()` | A Microphone permission row | Restyle |
| Audio Devices: Refresh | `refreshDevices()`; refreshes the default input/output cache | A Microphone header action | Preserve refresh effect |
| Input Device Priority: drag reorder | `SettingsStore.microphonePriority` | A Microphone table | Move/restyle |
| Input Device Priority: remove | `SettingsStore.microphonePriority` / suppressed microphone set | A Microphone table row action | Move/restyle |
| Input Device Priority: Restore Removed | `restoreRemovedMicrophones(with:)` | A Microphone table action | Move/restyle |
| Prototype: Input device picker | `selectedInputUID` is reconciled from priority order; explicit selection currently uses status-menu `selectMicrophone(_:)` | A Microphone | Add picker using the existing selection action; add no settings key |
| Prototype: live input-level meter | Prototype-only readout; no SettingsStore key or SettingsView binding | A Microphone | Add display only from an existing level stream; do not add capture behavior or change system defaults |
| Output Device picker | `selectedOutputUID`, `SettingsStore.preferredOutputDeviceUID` | A Microphone | Restyle |
| Sensitivity slider | `visualizerNoiseThreshold` | H Overlay | Restyle |
| Sensitivity Reset | Sets `visualizerNoiseThreshold` to `0.4` | H Overlay | Preserve effect |
| Accessibility permission state / Open Settings | `accessibilityEnabled`, `AccessibilityTrustMonitor` | B Hotkeys status row and recovery states | Restyle |
| Accessibility recovery: Relaunch MouthKeys | `restartApp` callback after trusted-but-failed tap | B Hotkeys recovery row | Restyle |
| Accessibility recovery: Reveal in Finder | `revealAppInFinder()` | B Hotkeys recovery actions | Preserve destination |
| Accessibility recovery: Open Applications | `openApplicationsFolder()` | B Hotkeys recovery actions | Preserve destination |
| Shortcut capture state / capture message | `activeShortcutRecordingTarget`, `shortcutRecordingMessage` | B Hotkeys status and `DatasheetHotkeyWell` | Restyle |
| Primary Dictation Shortcuts: Add / Change / Cancel / Remove | `primaryDictationShortcuts` and existing recorder callbacks | B Hotkeys | Preserve recorder and one-shortcut minimum |
| Primary Dictation AI Prompt picker | `dictationPromptSelection(for: .primary)` | B Hotkeys | Restyle |
| Command Mode shortcut and enable toggle | `commandModeShortcut`, `commandModeShortcutEnabled` | B Hotkeys | Restyle |
| Edit Mode shortcut and enable toggle | `rewriteShortcut`, `rewriteShortcutEnabled` | B Hotkeys | Restyle |
| Cancel Recording shortcut | `cancelRecordingShortcut` | B Hotkeys | Restyle |
| Paste Last Transcription shortcut and enable toggle | `pasteLastTranscriptionShortcut`, `pasteLastTranscriptionShortcutEnabled` | B Hotkeys | Restyle |
| Reprocess Last Dictation shortcut and enable toggle | `reprocessLastDictationShortcut`, `reprocessLastDictationShortcutEnabled` | B Hotkeys | Restyle |
| Activation Mode picker | `hotkeyMode`; updates `GlobalHotkeyManager` | B Hotkeys | Restyle |
| Global Hotkey: “Hotkey initializing…” status | `hotkeyManagerInitialized`; `ContentView.preferencesView` passes the state and `SettingsView` renders this branch while accessibility is enabled | B Hotkeys status row | Preserve; style the initializing state |
| Input Device Priority: Move Up | `SettingsStore.moveMicrophonePriority(uid:by: -1)` then `refreshActiveInputSelection()`; also exposed as an accessibility action | A Microphone priority-row actions | Preserve context-menu and accessibility actions, ordering limits, and disabled state |
| Input Device Priority: Move Down | `SettingsStore.moveMicrophonePriority(uid:by: 1)` then `refreshActiveInputSelection()`; also exposed as an accessibility action | A Microphone priority-row actions | Preserve context-menu and accessibility actions, ordering limits, and disabled state |
| Copy to Clipboard | `copyToClipboard` / `SettingsStore.copyTranscriptionToClipboard` | C Dictation | Restyle |
| Text Insertion Mode picker | `SettingsStore.textInsertionMode` | C Dictation | Restyle |
| Return to Starting Field | `SettingsStore.returnDictationToStartingField` | C Dictation | Restyle |
| Q for Question Mark | `SettingsStore.questionMarkShortcutEnabled` | C Dictation | Restyle; added after prototype by PR #57 |
| Spoken Send | `SettingsStore.spokenSendEnabled` | C Dictation | Restyle |
| Spoken Send phrase field | `SettingsStore.spokenSendPhrase` | C Dictation | Restyle |
| Send After a Pause | `SettingsStore.spokenSendImmediatelyEnabled`; baseline settle duration is 0.5 s, prototype copy says 1.5 s | C Dictation | Restyle; preserve baseline timing |
| Send Key picker | `SettingsStore.spokenSendKey`; terminal target still sends Return | C Dictation | Restyle |
| Allow in c11 | No baseline setting after PR #57; terminals always receive Return | No C Dictation control | Removed by decision; prototype predates PR #57 |
| Pause Media During Transcription | `SettingsStore.pauseMediaDuringTranscription` | C Dictation | Restyle |
| Skip Silent Recordings | `SettingsStore.skipSilentRecordingsEnabled` | C Dictation | Restyle |
| Launch at startup | `SettingsStore.setLaunchAtStartup(_:)` | D App | Restyle; do not change during QA |
| Launch at startup registration status | `SettingsStore.launchAtStartupStatusMessage` | D App status text | Preserve actual login-item status |
| Launch at startup error | `SettingsStore.launchAtStartupErrorMessage` | D App error state | Preserve error recovery |
| Show window when launched at login | `SettingsStore.showMainWindowAtLoginLaunch` | D App | Restyle |
| Hide from Dock & App Switcher | `SettingsStore.hideFromDockAndAppSwitcher` | D App | Restyle |
| Self-update statement and Latest release link | Static statement; `MouthKeysLinks.latestRelease` | D App | Preserve link; no updater |
| Transcription Sounds picker | `SettingsStore.transcriptionStartSound`; selecting previews the sound | D App | Restyle; preserve preview effect |
| Volume slider | `SettingsStore.transcriptionSoundVolume`; release previews volume | D App | Restyle; preserve preview effect |
| Analytics Details | `showAnalyticsPrivacy`; telemetry remains hard-off | E History | Restyle; retain no-telemetry statement |
| Save Transcription History | `SettingsStore.saveTranscriptionHistory` | E History | Restyle; preserve usage refresh side effect |
| Save Audio With History | `SettingsStore.saveAudioWithTranscriptionHistory` | E History | Restyle; remains disabled when history is off |
| Weekends Don't Break Streak | `SettingsStore.weekendsDontBreakStreak` | E History | Restyle |
| Audio Storage usage and meter | `audioHistoryUsageBytes`, `audioHistoryUsageFraction()`, `SettingsStore.audioHistoryBudgetGB` | E History | Restyle; preserve live usage display |
| Audio budget field and Apply | `audioHistoryBudgetText`; writes `SettingsStore.audioHistoryBudgetGB` | E History | Restyle; preserve validation/pruning |
| Export Audio | `exportAudioZip()` | E History | Restyle |
| Delete Audio | `deleteSavedAudio()`; deletes saved audio only after confirmation and is disabled at zero usage | E History | Preserve confirmation and disabled state |
| Lowercase First Letter | `SettingsStore.gaavLowercaseFirstLetterEnabled` | F Format | Restyle |
| Remove Trailing Period | `SettingsStore.gaavRemoveTrailingPeriodEnabled` | F Format | Restyle |
| Slash Commands & @ Formatting | `SettingsStore.literalDictationFormattingEnabled` | F Format | Restyle |
| Space Between Dictations | `SettingsStore.continuousDictationSpacingEnabled` | F Format | Restyle |
| Smart Capitalization | `SettingsStore.contextAwareCapitalizationEnabled` | F Format | Restyle |
| AI Enhancement Failures | `SettingsStore.notifyAIProcessingFailures` | G Alerts | Restyle |
| Microphone Changes | `SettingsStore.showMicrophoneChangeAlerts` | G Alerts | Restyle; preserve dismiss/reset side effect |
| Paste Check | `SettingsStore.showPasteCheckAlerts` | G Alerts | Restyle |
| Overlay Position | `SettingsStore.overlayPosition` | H Overlay | Restyle |
| Transcription Preview Length slider | `SettingsStore.transcriptionPreviewCharLimit` | H Overlay | Restyle |
| Overlay Size picker | `SettingsStore.overlaySize` | H Overlay | Restyle |
| Notch Style picker | `SettingsStore.notchPresentationMode` | H Overlay | Restyle |
| Live Preview | `enableStreamingPreview` / `SettingsStore.enableStreamingPreview` | H Overlay | Restyle |
| Bottom Offset slider | `SettingsStore.overlayBottomOffset` | H Overlay | Restyle |
| Backup Export / Import | `exportBackup()` / `importBackup()`; API keys excluded | I Backup | Restyle; preserve document contents and confirmations |
| Show Debug Logs in App | `SettingsStore.enableDebugLogs` | J Debug | Restyle |
| Debug log location/help | `AppStorageLocation.logFolderName` | J Debug | Preserve path and diagnostics wording |
| Reveal Log File | `FileLogger.shared.currentLogFileURL()` and `NSWorkspace.shared.activateFileViewerSelecting` | J Debug action | Preserve Finder destination |
| Prototype: settings recording notice | Output Device is disabled while `asr.isRunning`; microphone-priority edits are disabled while running or starting | Settings status notice; retain those two individual disabled states | Add notice; do not disable every Settings row |

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

Source: `OnboardingFlowView` in `WelcomeView.swift`, `UI/OnboardingTryoutStepView.swift`, `UI/OnboardingAIEnhancementStepView.swift`.

| Current step / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Step rail and navigation | Existing onboarding step state | Six-step rail | Restyle; preserve ordering |
| Welcome / Next | Existing step advance | Welcome with Fig. 1 | Restyle |
| Language selection / all languages / custom language | Existing language selection, filter and picker callbacks | Language step | Restyle |
| Voice Engine selection | `SettingsStore.selectedSpeechModel` and engine language settings | Voice Engine step | Restyle |
| Voice Engine download / cancel / retry | Existing model preparation and download state | Voice Engine step | Preserve all progress/error states |
| Enable Access actions | Existing microphone and Accessibility permission callbacks | Enable Access step | Preserve all permission recovery states |
| Try MouthKeys practice drill | Existing primary shortcut and tryout callbacks | Try MouthKeys step | Restyle; preserve completion |
| Regional filler-word offer: keep / No thanks | Existing offer answer callbacks | Try MouthKeys step | Preserve both answers |
| AI Enhancement suggestions/provider choices | Existing onboarding provider actions | Optional AI Enhancement step | Restyle; preserve configuration effects |
| Back / Next / Finish Setup | Existing step and onboarding completion callbacks | Ruled footer | Restyle; preserve completion gate |

## F — Menu and finish

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| Status menu header | Current menu title/state | Datasheet grin and MouthKeys wordmark | Restyle |
| Status menu: Start Dictation | `toggleDictation` | Status menu | Preserve action |
| Status menu: hotkeys-paused recovery | `resolveHotkeysPaused`; visible while configured hotkeys lack Accessibility trust | Status menu recovery item | Preserve visibility and route |
| Status menu: microphone selection submenu | `selectMicrophone(_:)` from the prioritized available inputs | Microphone submenu | Preserve current-device state and selection |
| Status menu: History | `openHistory` | Status menu | Preserve route |
| Status menu: Copy Last Transcript | `copyLastTranscript(_:)` | Status menu | Preserve availability and clipboard effect |
| Status menu: Custom Dictionary | `openCustomDictionary` | Status menu | Preserve route |
| Status menu: Open MouthKeys | `openMainWindow` | Status menu | Preserve route |
| Status menu: Settings | `openPreferences` | Status menu | Preserve route |
| Status menu: Quit MouthKeys | `NSApplication.terminate(_:)` | Status menu | Preserve action |
| MouthKeys on GitHub | No current item | New status-menu item | Add per approved design |
| Custom Dictionary empty state grin | Existing empty-state condition | Outline grin | Add in lane F |
| History empty state grin | Existing empty-state condition | Outline grin | Add in lane F |
| Legacy `AppTheme` / `ThemedCard` / `ThemedGroupBox` / `GlossyEffects` | Shared app styles used by unconverted code | Remove only when no references remain | Retire after reference audit |
| Real-path install checks | Current Developer ID checklist | `docs/INSTALL-CHECKLIST.md` | Add at lane F; file stays untouched in this phase |

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
| F | Pending |  |
