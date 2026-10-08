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
