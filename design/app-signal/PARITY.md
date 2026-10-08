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
| Sensitivity Reset | Sets `visualizerNoiseThreshold` to `0.4` | H Overlay | Wired; existing binding and effect retained. |
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
| Activation Mode picker | `hotkeyMode`; updates `GlobalHotkeyManager` | B Hotkeys | Wired; existing binding and effect retained. |
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
| Overlay Size picker | `SettingsStore.overlaySize` | H Overlay | Wired; existing binding and effect retained. |
| Notch Style picker | `SettingsStore.notchPresentationMode` | H Overlay | Wired; existing binding and effect retained. |
| Live Preview | `enableStreamingPreview` / `SettingsStore.enableStreamingPreview` | H Overlay | Wired; existing binding and effect retained. |
| Bottom Offset slider | `SettingsStore.overlayBottomOffset` | H Overlay | Wired; existing binding and effect retained. |
| Backup Export / Import | `exportBackup()` / `importBackup()`; API keys excluded | I Backup | Wired; document contents and confirmations retained; API keys stay excluded. |
| Show Debug Logs in App | `SettingsStore.enableDebugLogs` | J Debug | Wired; existing binding and effect retained. |
| Debug log location/help | `AppStorageLocation.logFolderName` | J Debug | Wired; dynamic log folder and diagnostics wording retained. |
| Reveal Log File | `FileLogger.shared.currentLogFileURL()` and `NSWorkspace.shared.activateFileViewerSelecting` | J Debug action | Wired; existing binding and effect retained. |
| Prototype: settings recording notice | Output Device is disabled while `asr.isRunning`; microphone-priority edits are disabled while running or starting | Settings status notice; retain those two individual disabled states | Wired in A and H notes; all other Settings rows remain enabled. |


### A state and evidence notes

- Zone navigation retains the pinned strip but realizes all ten section anchors together before scrolling. Selection follows the explicit tab or microphone navigation request, matching the prototype's tab actions; the added geometry-driven scrollspy was removed by coordinator decision 9. This prevents lazy extent estimates from landing on the wrong section and prevents bottom clamping from replacing the chosen Backup/Debug tab. The prior normal native SwiftUI hang remains an independent unresolved gate until a fresh normal Debug walkthrough proves responsiveness.
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
| Quick Setup step actions and completion state | Existing onboarding/permission state | Four-cell setup readout | Restyle; done collapses, next action remains actionable |
| Welcome title before model readiness | `ASRService` readiness | Getting Started lead | Preserve wording/ordering |
| Microphone status and permission action | `ASRService` authorization and request | Setup status row | Restyle |
| Accessibility status / Open Settings / floating guide | `AccessibilityTrustMonitor` | Permission recovery rows | Restyle |
| “Already switched on?” recovery | Trust monitor result after return from System Settings | Permission recovery row | Preserve |
| Conflicting app-copy Show in Finder list | `ConflictingAppCopyDetector` | Permission recovery row | Preserve paths and Finder action |
| failed_trusted Relaunch MouthKeys | Existing relaunch callback | Permission recovery row | Preserve |
| Grant Access | Existing microphone permission request | Permission recovery row | Preserve |
| Your Dictation Key display and activation mode | `primaryDictationShortcuts`, `hotkeyMode` | Keycap and mode readout | Restyle |
| Prototype addition: three-press hotkey practice drill | No matching baseline practice sequence or completion callback in `WelcomeView.swift` | Your Dictation Key | New prototype interaction; Getting Started lane must wire completion if retained |
| Run Onboarding Again | `resetOnboardingProgress()` and `playgroundUsed = false` | Quick Setup header action | Preserve action and reset effect |
| Editable transcript | `asr.finalText` binding | Playground transcript editor | Preserve edit and transcription state |
| Copy Text | Copies `asr.finalText` to `NSPasteboard` | Playground transcript actions | Preserve copy action |
| Clear & Test Again | Sets `asr.finalText` to the empty string | Playground transcript actions | Preserve clear action |
| Playground microphone picker | Existing selected-input binding and device coordinator | Playground | Restyle; preserve real device selection |
| Playground recording/cancel and inline overlay | Existing `SignalOverlay`/`DatasheetOverlay` state and callbacks | Playground | Preserve overlay and delivery behavior |
| Prototype addition: hover callout zones | No baseline callout view or callback; annotation names and geometry are defined in prototype `callouts.js` | Playground annotations | New prototype annotations; implement in Getting Started lane |
| Open Voice Engine / Settings actions | Existing sidebar routing callbacks | Setup step actions | Preserve destinations |

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
