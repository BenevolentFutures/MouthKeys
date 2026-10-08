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
| Prototype: three-press shortcut practice | No persisted setting; local `hotkeyPracticeCount` and practice event monitor | Your Dictation Key practice panel and Quick Setup row 4 | Added; listens for the configured non-mouse shortcut while Getting Started is visible, counts press/release cycles, and stops after three completed presses. Once rows 1–3 are ready, the third press completes row 4; practice never sets `playgroundUsed` or claims voice transcription was tested |
| Practice keycap fallback and Reset | Local `countManualPracticePress()` / `resetHotkeyPractice()` | Keycap button and Reset action | Added; clicking the keycap records a practice press; Reset clears and rearms the local drill |
| Change Key or Mode | Existing Preferences destination and `SettingsStore` shortcut/mode controls | Your Dictation Key action | Added; routes to `.preferences`; changing the actual shortcut or mode remains in Settings |
| Playground Start / Stop Recording | `startRecording()` / `stopAndProcessTranscription()` | Test Playground action row | Restyled; retains the existing recording and transcription callbacks; Start marks the existing setup test completion |
| Playground “OR PRESS” shortcut | Configured primary shortcut | Test Playground action row | Added as a shortcut reminder; the actual global shortcut behavior is unchanged |
| Recording / transcript character count | `ASRService.isRunning`; `ASRService.finalText.count` | Playground status line | Restyled; shows Listening while recording or the transcript character count when text exists |
| Parakeet word boost status | `selectedSpeechModel`; `ASRService.wordBoostStatusText` | Playground status line | Restyled; shown for the same Parakeet models |
| Editable transcript | `ASRService.finalText` binding | Playground text editor | Restyled; editing, focus, and transcription state preserved |
| Copy Text | Copies `ASRService.finalText` to `NSPasteboard` | Playground transcript actions | Restyled; same clipboard action and disabled state when empty |
| Clear & Test Again | Sets `ASRService.finalText` to an empty string | Playground transcript actions | Restyled; clear action remains available |
| Inline Datasheet overlay | Production `DatasheetPill`, `DatasheetTraceRow`, `DatasheetFootRow`, `DatasheetPreview`, `DatasheetRail`, and `DatasheetChip` read current shared overlay state | Inline reference below Playground controls | Added; read-only teaching reference; production floating overlay and delivery behavior are untouched |
| Overlay preview, trace, recording square, timer, word count, WPM, target app and mic callouts | Current Datasheet overlay state and `callouts.js` annotations | Inline overlay callout zones | Added with hover zones, dashed frame, leader, square terminus, label and description |
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
| Voice Engine: primary language menu | `selectedAppleSpeechLocale` / current engine language model | Voice Engine language control | Restyle |
| Voice Engine: provider filter menu | `viewModel.providerFilter` | Voice Engine table controls | Restyle |
| Voice Engine: model sort menu | `viewModel.modelSortOption` | Voice Engine table controls | Restyle |
| Voice Engine: model selection row | `SettingsStore.selectedSpeechModel` | Voice Engine model table | Restyle; preserve selected engine |
| Voice Engine: Activate | Existing activation action | Model table row action | Restyle |
| Voice Engine: Download / Cancel | Existing model download and cancellation state | Model table row action and progress states | Restyle; preserve errors/progress |
| Voice Engine: Delete models | Existing model deletion action | Model row/management action | Preserve; do not run during QA |
| Voice Engine: language menu per model | `selectedNemotronLanguage`, `selectedCohereLanguage`, and per-model language binding | Model row language control | Restyle |
| Voice Engine: Open Custom Dictionary | Sidebar route to `.customDictionary` | Voice Engine custom words link | Preserve |
| Voice Engine: remove filler words toggle/list | `viewModel.removeFillerWordsEnabled` and filler-word settings | Filler-word tags/list | Restyle |
| Voice Engine: regional filler-word offer | Existing offer preference and answer callbacks | Filler-word offer | Preserve offer and both choices |
| Custom Dictionary: Import / Export | `importDictionary()` / `exportDictionary()` | Dictionary header actions | Restyle |
| Custom Dictionary: Auto-learn words while typing | `automaticDictionaryLearningEnabled` | Teach Words | Restyle |
| Teach Words: replacement field | `trainingReplacement` | Teach Words form | Restyle |
| Teach Words: training recorder / test action | Existing training recorder state and service | Teach Words form | Preserve recording action |
| Replacement table: add trigger(s) and replacement | `manualTriggerDraft`, `manualReplacement` | First inline table | Move from popover to inline editor |
| Replacement table: add, edit, delete, clear | Existing replacement store and row callbacks | First inline table | Move/restyle; preserve mutation effects |
| Custom Words table: add/edit/delete | Existing vocabulary store and row callbacks | Second inline table | Move/restyle; preserve mutation effects |
| Custom Words Boosting | `vocabBoostingEnabled` | Custom Words section | Restyle |
| Boost term field and priority picker | `boostTermText`, `boostTermStrength` | Custom Words inline table | Restyle |
| Spoken Formatting toggle and start word | `punctuationAutoConvertEnabled`, `punctuationPrefix` | Third inline table | Restyle |
| Formatting action toggles and edit | `formattingActionEnabledBinding(for:)` and action rules | Third inline table | Restyle |
| Formatting phrases/symbol fields, add/save/clear | `punctuationSymbolText` and existing phrase/rule stores | Third inline table | Restyle; preserve rule semantics |
| Formatting reset defaults | Existing reset confirmation and default rules | Third inline table | Preserve confirmation/effect |
| AI Enhancement tabs | Existing provider/advanced-prompt section selection | Providers / Advanced Prompts tabs | Restyle |
| Provider search | `providerSearchText` | Providers tab | Restyle |
| Provider list expand/collapse | `toggleProviderExpansion(item.id)` | Providers table | Restyle |
| Provider/model selection | Existing selected-provider/model bindings and `SearchableModelPicker` | Providers table | Restyle |
| Provider reasoning control | Existing reasoning configuration view model | Provider row action/editor | Restyle |
| Add provider: name, base URL, API key | `newProviderName`, `newProviderBaseURL`, `newProviderApiKey` | Add Provider form | Restyle; preserve keychain write path |
| Provider: test connection, save, cancel | Existing `testAPIConnection`, `saveNewProvider`, cancel callbacks | Provider editor | Restyle |
| Edit provider: name, URL, API key, save/cancel | `editProviderName`, `editProviderBaseURL`, API key editor bindings | Provider editor | Restyle |
| API-key reveal / clear / edit | Existing keychain service and `handleAPIKeyButtonTapped()` | Provider row action/editor | Preserve keychain service; no key edits during QA |
| Provider delete | Existing provider delete confirmation and view-model mutation | Provider row action | Restyle; preserve confirmation |
| Advanced Prompts: add/edit/delete prompt | Existing prompt profile and prompt editor bindings | Advanced Prompts tab | Restyle |
| Advanced Prompts: prompt name/body/model | `draftPromptName`, prompt content and prompt-model picker bindings | Prompt editor | Restyle |
| Advanced Prompts: Reset to Built-in | `resetDefaultPromptOverride(for:)`; available when a default prompt override exists | Prompt editor | Preserve reset and viewer-opening effects |
| Advanced Prompts: mode tabs | `selectedPromptMode` and `SettingsStore.PromptMode.visiblePromptModes` | Advanced Prompts | Preserve per-mode configuration |
| Advanced Prompts: routing scope | `viewModel.promptRoutingScope(for:)` and existing per-mode scope store | Advanced Prompts | Preserve app routing |
| Dictation: Send Custom Prompt Only | `customPromptOnlyToggleRow` and existing custom-prompt selection behavior | Advanced Prompts / Dictate | Preserve routing effect |
| Prompt editor: custom shortcut capture / clear | `promptEditorShortcutDraft` and existing hotkey recorder callbacks | Prompt editor | Preserve capture behavior |
| Prompt editor: provider selection | `promptEditorProviderIDDraft` and prompt configuration callbacks | Prompt editor | Preserve per-prompt provider |
| Prompt Test Mode | `promptTest.isActive`; runs only the draft-prompt preview path | Prompt editor test panel | Preserve; never types into another app |
| Prompt test progress, error and raw/output results | `promptTest.isProcessing`, `lastError`, `lastTranscriptionText`, `lastOutputText` | Prompt editor test panel | Preserve every result state |
| Advanced Prompts: per-app overrides and sync | Existing app prompt binding and linked-mode bindings | Advanced Prompts table | Restyle; preserve routing |
| Feedback: message editor | `feedbackText` | Feedback form | Restyle; preserve editable text |
| Feedback: Include app and macOS version | `includeSystemInfo` | Feedback form | Restyle |
| Feedback: open issue | `openFeedbackIssue` and `MouthKeysLinks.newIssue` | Feedback action | Preserve destination; do not submit during QA |
| About: Fig. 1 and GitHub link | Static grin drawing; GitHub URL | About section | Add per approved design |
| About: FluidVoice credit and support links | `MouthKeysLinks.upstreamRepository`, `MouthKeysLinks.upstreamSponsor`; static attribution text | About section | Preserve both links and attribution |

## D — History, Stats, Command Mode, File Transcription

| Current screen / control | Current binding or effect | New target | Status |
|---|---|---|---|
| History search | `searchQuery` | History list header | Restyle |
| History row selection | `selectedEntryID` | History list | Restyle |
| History copy processed/raw/both | `copyToClipboard` and `combinedText(for:)` | History detail actions | Restyle; preserve copied text selection |
| History audio playback | Existing dictation audio playback action | History detail | Restyle |
| History Export Pair | `exportPair(entry)` | History detail action | Restyle |
| History Reveal Audio | `revealAudio(entry)` | History detail action | Restyle |
| History Delete / Delete Entry | `historyStore.deleteEntry(id:)` | History detail action | Restyle; preserve selection update |
| History Clear All | Existing clear-all confirmation and store mutation | History header action | Restyle; preserve confirmation |
| History empty state / Open Playground | Empty-state route to `.welcome` | Empty-state panel | Restyle; outline grin in lane F |
| Stats date-range picker | `chartDays` | Stats chart control | Restyle |
| Stats WPM edit field | `editingWPM` | Typing-speed KPI cell | Restyle |
| Stats WPM Save / Cancel | Existing user typing WPM setter | Typing-speed KPI cell | Preserve validation and save |
| Stats Reset Everything | Existing destructive reset confirmation | Stats action | Restyle; preserve confirmation |
| Command Mode: New Chat | `service.createNewChat()` | Command Mode header | Restyle |
| Command Mode: chat selector/menu | Existing chat selection/deletion callbacks | Command Mode header | Restyle; preserve selection and confirmation |
| Command Mode: clear/delete history | Existing clear confirmation and chat store | Command Mode header | Restyle; preserve confirmation |
| Command Mode: Confirm Before Execute | `settings.commandModeConfirmBeforeExecute` | Confirm panel | Restyle |
| Command Mode: how-to expander | `showHowTo` | Not-ready/help panel | Restyle |
| Command Mode: prompt field | `inputText` | Composer | Restyle |
| Command Mode: Sync | `settings.commandModeLinkedToGlobal` | Provider/model controls | Restyle |
| Command Mode: provider/model pickers | Existing command-mode provider/model bindings | Provider/model controls | Restyle |
| Command Mode: AI Settings | Routes to AI Enhancement settings | Not-ready/help panel | Preserve route |
| Command Mode: record, Run, cancel pending command | Existing dictation and command service callbacks | Composer actions | Restyle; preserve behavior |
| Command Mode: thinking detail expander | `isThinkingExpanded` | Result detail | Restyle |
| File Transcription: choose file / drag and drop | Existing file picker and `.fileURL` drop handler | Drop zone | Restyle |
| File Transcription: remove selected file | Clears selected file and resets transcription service | File header action | Preserve effect |
| File Transcription: Label speakers | `settings.fileTranscriptionSpeakerLabelsEnabled` | Options zone | Restyle |
| File Transcription: Number of speakers | `settings.fileTranscriptionExpectedSpeakerCount` | Options zone | Restyle |
| File Transcription: Transcribe / Cancel | Existing transcription service state/actions | Primary action and progress | Restyle; preserve progress/errors |
| File Transcription result: Copy / Export | Existing clipboard and export dialog callbacks | Result actions | Restyle |
| File Transcription history: select / Copy / Export / Delete | Existing file history store and selected entry | Recent table and detail | Restyle; preserve mutations |
| File Transcription history: Clear all | Existing confirmation and history store action | Recent table action | Preserve confirmation |

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
