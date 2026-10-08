//
//  SettingsView.swift
//  fluid
//
//  App preferences and audio device settings
//

import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private enum SettingsZone: String, CaseIterable, Identifiable {
        case microphone
        case hotkeys
        case dictation
        case app
        case history
        case format
        case alerts
        case overlay
        case backup
        case debug

        var id: String { self.rawValue }
        var anchor: String { "settings-zone-\(self.rawValue)" }
        var stripAnchor: String { "settings-zone-tab-\(self.rawValue)" }

        var letter: String {
            switch self {
            case .microphone: "A"
            case .hotkeys: "B"
            case .dictation: "C"
            case .app: "D"
            case .history: "E"
            case .format: "F"
            case .alerts: "G"
            case .overlay: "H"
            case .backup: "I"
            case .debug: "J"
            }
        }

        var title: String {
            switch self {
            case .microphone: "Microphone"
            case .hotkeys: "Hotkeys"
            case .dictation: "Dictation"
            case .app: "App"
            case .history: "History & Privacy"
            case .format: "Text Formatting"
            case .alerts: "Notifications"
            case .overlay: "Overlay"
            case .backup: "Backup & Restore"
            case .debug: "Debug"
            }
        }

        var shortLabel: String {
            switch self {
            case .microphone: "MIC"
            case .hotkeys: "HOTKEYS"
            case .dictation: "DICT."
            case .app: "APP"
            case .history: "HISTORY"
            case .format: "FORMAT"
            case .alerts: "ALERTS"
            case .overlay: "OVERLAY"
            case .backup: "BACKUP"
            case .debug: "DEBUG"
            }
        }
    }

    private struct ShortcutRowContent {
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
    }

    @EnvironmentObject var appServices: AppServices
    private var asr: ASRService {
        self.appServices.asr
    }

    @Environment(\.theme) private var theme
    @Environment(\.datasheetPalette) private var datasheetPalette
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var permissionMonitor = AccessibilityTrustMonitor.shared
    @ObservedObject private var overlayModel = DatasheetOverlayModel.shared
    @ObservedObject var microphonePreferenceCoordinator: MicrophonePreferenceCoordinator
    @Binding var appear: Bool
    @Binding var visualizerNoiseThreshold: Double
    @Binding var selectedInputUID: String
    @Binding var selectedOutputUID: String
    @Binding var inputDevices: [AudioDevice.Device]
    @Binding var outputDevices: [AudioDevice.Device]
    @Binding var accessibilityEnabled: Bool
    @Binding var primaryDictationShortcuts: [HotkeyShortcut]
    @Binding var activeShortcutRecordingTarget: ShortcutRecordingTarget?
    @Binding var shortcutRecordingMessage: String?
    @Binding var commandModeShortcut: HotkeyShortcut?
    @Binding var rewriteShortcut: HotkeyShortcut
    @Binding var cancelRecordingShortcut: HotkeyShortcut
    @Binding var pasteLastTranscriptionShortcut: HotkeyShortcut?
    @Binding var reprocessLastDictationShortcut: HotkeyShortcut?
    @Binding var commandModeShortcutEnabled: Bool
    @Binding var rewriteShortcutEnabled: Bool
    @Binding var pasteLastTranscriptionShortcutEnabled: Bool
    @Binding var reprocessLastDictationShortcutEnabled: Bool
    @Binding var hotkeyManagerInitialized: Bool
    @Binding var hotkeyMode: HotkeyActivationMode
    @Binding var enableStreamingPreview: Bool
    @Binding var copyToClipboard: Bool

    // CRITICAL FIX: Cache default device names to avoid CoreAudio calls during view body evaluation.
    // Querying AudioDevice.getDefaultInputDevice() in the view body triggers HALSystem::InitializeShell()
    // which races with SwiftUI's AttributeGraph metadata processing and causes EXC_BAD_ACCESS crashes.
    @State private var cachedDefaultInputUID: String = ""
    @State private var cachedDefaultOutputName: String = ""

    @State private var showAnalyticsPrivacy: Bool = false
    @State private var audioHistoryBudgetText: String = Self.audioBudgetText(for: SettingsStore.shared.audioHistoryBudgetGB)
    @State private var audioHistoryUsageBytes: Int64 = DictationAudioHistoryStore.shared.audioUsageBytes()
    @State private var draggedMicrophoneUID: String?
    @State private var hoveredMicrophoneUID: String?
    @State private var inputAudioLevel: CGFloat = 0
    @State private var selectedSettingsZone: SettingsZone = .microphone
    @State private var lastSettingsScrollRequest = 0

    let hotkeyManager: GlobalHotkeyManager?
    let menuBarManager: MenuBarManager
    let startRecording: () -> Void
    let refreshDevices: () -> Void
    let openAccessibilitySettings: () -> Void
    let restartApp: () -> Void
    let revealAppInFinder: () -> Void
    let openApplicationsFolder: () -> Void
    let microphoneSettingsScrollRequest: Int

    private var isRecordingAnyShortcut: Bool {
        self.activeShortcutRecordingTarget != nil
    }

    private func isRecording(_ target: ShortcutRecordingTarget) -> Bool {
        self.activeShortcutRecordingTarget == target
    }

    private var appDisplayName: String {
        Bundle.main.fluidAppDisplayName
    }

    private var launchAtStartupBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtStartupEnabled },
            set: { self.settings.setLaunchAtStartup($0) }
        )
    }

    private func dictationPromptSelectionBinding(for slot: SettingsStore.DictationShortcutSlot) -> Binding<String> {
        Binding(
            get: {
                switch self.settings.dictationPromptSelection(for: slot) {
                case .off:
                    return "__OFF__"
                case .default:
                    return "__DEFAULT__"
                case let .profile(id):
                    return id
                }
            },
            set: { newValue in
                switch newValue {
                case "__OFF__":
                    self.settings.setDictationPromptSelection(.off, for: slot)
                case "__DEFAULT__":
                    self.settings.setDictationPromptSelection(.default, for: slot)
                default:
                    self.settings.setDictationPromptSelection(.profile(newValue), for: slot)
                }
            }
        )
    }

    @ViewBuilder
    private func dictationPromptPicker(for slot: SettingsStore.DictationShortcutSlot) -> some View {
        let profiles = self.settings.promptProfiles(for: .dictate)
        let selection = self.dictationPromptSelectionBinding(for: slot)
        let value: String = switch selection.wrappedValue {
        case "__OFF__": "Off"
        case "__DEFAULT__": "Default"
        default: profiles.first(where: { $0.id == selection.wrappedValue }).map { $0.name.isEmpty ? "Untitled" : $0.name } ?? "Select prompt"
        }
        DatasheetRow(label: "AI Prompt", help: "Choose which dictation prompt profile this shortcut uses.", control: {
            DatasheetPicker(title: "Dictation AI Prompt", value: value, minimumWidth: 230) {
                Button {
                    selection.wrappedValue = "__OFF__"
                } label: {
                    if selection.wrappedValue == "__OFF__" { Label("Off", systemImage: "checkmark") }
                    else { Text("Off") }
                }
                Button {
                    selection.wrappedValue = "__DEFAULT__"
                } label: {
                    if selection.wrappedValue == "__DEFAULT__" { Label("Default", systemImage: "checkmark") }
                    else { Text("Default") }
                }
                ForEach(profiles) { profile in
                    let name = profile.name.isEmpty ? "Untitled" : profile.name
                    Button {
                        selection.wrappedValue = profile.id
                    } label: {
                        if selection.wrappedValue == profile.id { Label(name, systemImage: "checkmark") }
                        else { Text(name) }
                    }
                }
            }
        })
    }

    var body: some View {
        self.settingsManagedContent
    }

    private var settingsManagedContent: AnyView {
        var content = AnyView(self.settingsScrollBody)
        content = AnyView(content.sheet(isPresented: self.$showAnalyticsPrivacy) {
            AnalyticsPrivacyView()
                .frame(minWidth: 520, minHeight: 520)
                .appTheme(self.theme)
        })
        content = AnyView(content.onAppear { self.initializeSettings() })
        content = AnyView(content.onReceive(self.asr.audioLevelPublisher) { level in
            self.inputAudioLevel = (self.asr.isRunning || self.asr.isStarting) ? min(max(level, 0), 1) : 0
        })
        content = AnyView(content.onChange(of: self.asr.isRunning) { _, isRunning in
            if !isRunning { self.inputAudioLevel = 0 }
        })
        content = AnyView(content.onChange(of: self.asr.isStarting) { _, isStarting in
            if !isStarting && !self.asr.isRunning { self.inputAudioLevel = 0 }
        })
        content = AnyView(content.onDisappear { self.inputAudioLevel = 0 })
        content = AnyView(content.onChange(of: self.inputDevices) { _, devices in
            self.inputDevicesDidChange(devices)
        })
        content = AnyView(content.onChange(of: self.selectedOutputUID) { oldUID, newUID in
            self.outputSelectionDidChange(from: oldUID, to: newUID)
        })
        content = AnyView(content.onChange(of: self.outputDevices) { _, devices in
            self.outputDevicesDidChange(devices)
        })
        content = AnyView(content.onChange(of: self.visualizerNoiseThreshold) { _, value in
            SettingsStore.shared.visualizerNoiseThreshold = value
        })
        content = AnyView(content.onChange(of: self.hotkeyMode) { _, mode in
            SettingsStore.shared.hotkeyMode = mode
            self.hotkeyManager?.setHotkeyMode(mode)
        })
        content = AnyView(content.onChange(of: self.copyToClipboard) { _, enabled in
            SettingsStore.shared.copyTranscriptionToClipboard = enabled
        })
        content = AnyView(content.onChange(of: self.enableStreamingPreview) { _, enabled in
            SettingsStore.shared.enableStreamingPreview = enabled
        })
        return content
    }

    private var settingsScrollBody: AnyView {
        AnyView(ScrollViewReader { proxy in
            self.settingsScrollContent(scrollProxy: proxy)
        })
    }

    private func settingsScrollContent(scrollProxy: ScrollViewProxy) -> AnyView {
        let zoneStack = VStack(alignment: .leading, spacing: 0) {
            DatasheetSheetHeader(placard: "01 / Configure", title: "Settings", lede: "Changes apply as you make them.") {
                HStack(spacing: 8) {
                    DatasheetStatusSquare(kind: .ink)
                    Text("SAVED")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(self.datasheetPalette.text2)
                }
                .frame(height: 32)
                .accessibilityLabel("Settings are saved automatically")
            }

            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    // Realize the ten anchors together so scrollTo uses their final
                    // extents rather than estimates for unloaded lazy sections.
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(SettingsZone.allCases) { zone in
                            self.settingsZoneContent(zone)
                                // Section headings already have 34 pt of top spacing.
                                // Reserve the rest of the pinned strip, including a
                                // legacy horizontal scroller, above each heading.
                                .padding(.top, 24)
                                .id(zone.anchor)
                        }
                    }
                } header: {
                    self.settingsZoneStrip(scrollProxy: scrollProxy)
                }
            }
        }
        .frame(maxWidth: 900, alignment: .leading)
        .padding(.horizontal, 40)
        .padding(.top, 32)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity, alignment: .top)

        let scroll = ScrollView(.vertical) { zoneStack }
            .coordinateSpace(name: "settings-scroll")
            .scrollIndicators(.visible)
        let appeared = AnyView(scroll.onAppear {
            self.lastSettingsScrollRequest = self.microphoneSettingsScrollRequest
            if self.microphoneSettingsScrollRequest > 0 {
                DispatchQueue.main.async {
                    scrollProxy.scrollTo(SettingsZone.microphone.anchor, anchor: .top)
                }
            }
        })
        return AnyView(appeared.onChange(of: self.microphoneSettingsScrollRequest) { _, request in
            guard request > 0, request != self.lastSettingsScrollRequest else { return }
            self.lastSettingsScrollRequest = request
            self.selectedSettingsZone = .microphone
            withAnimation(self.accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(SettingsZone.microphone.anchor, anchor: .top)
            }
        })
    }

    private func initializeSettings() {
        Task { @MainActor in
            await AudioStartupGate.shared.scheduleOpenAfterInitialUISettled()
            await AudioStartupGate.shared.waitUntilOpen()

            self.refreshDevices()

            if !self.inputDevices.isEmpty {
                let defaultInput = AudioDevice.getDefaultInputDevice()
                self.cachedDefaultInputUID = defaultInput?.uid ?? ""
                if let selectedInput = self.appServices.microphonePreferenceCoordinator
                    .reconcileMicrophoneSelection(
                        availableInputs: self.inputDevices,
                        defaultInputUID: self.cachedDefaultInputUID
                    )
                {
                    self.selectedInputUID = selectedInput.uid
                }
            }

            if !self.outputDevices.isEmpty {
                let outputValid = self.outputDevices.contains { $0.uid == self.selectedOutputUID }
                if !outputValid || self.selectedOutputUID.isEmpty {
                    if let prefUID = SettingsStore.shared.preferredOutputDeviceUID,
                       self.outputDevices.contains(where: { $0.uid == prefUID })
                    {
                        self.selectedOutputUID = prefUID
                    } else if let defaultUID = AudioDevice.getDefaultOutputDevice()?.uid,
                              self.outputDevices.contains(where: { $0.uid == defaultUID })
                    {
                        self.selectedOutputUID = defaultUID
                    } else {
                        self.selectedOutputUID = self.outputDevices.first?.uid ?? ""
                    }
                }
            }

            let defaultInput = AudioDevice.getDefaultInputDevice()
            self.cachedDefaultInputUID = defaultInput?.uid ?? ""
            self.cachedDefaultOutputName = AudioDevice.getDefaultOutputDevice()?.name ?? ""
            self.settings.refreshLaunchAtStartupStatus(clearError: true, logMismatch: false)
            self.refreshAudioHistoryUsage()
        }
    }

    private func inputDevicesDidChange(_ devices: [AudioDevice.Device]) {
        let defaultInput = AudioDevice.getDefaultInputDevice()
        self.cachedDefaultInputUID = defaultInput?.uid ?? ""
        guard !devices.isEmpty else { return }
        if let selectedInput = self.appServices.microphonePreferenceCoordinator
            .reconcileMicrophoneSelection(availableInputs: devices, defaultInputUID: self.cachedDefaultInputUID)
        {
            self.selectedInputUID = selectedInput.uid
        }
    }

    private func outputSelectionDidChange(from oldUID: String, to newUID: String) {
        guard !newUID.isEmpty else { return }
        if self.asr.isRunning {
            DebugLogger.shared.warning("Cannot change output device during recording", source: "SettingsView")
            self.selectedOutputUID = oldUID
            return
        }
        SettingsStore.shared.preferredOutputDeviceUID = newUID
        _ = AudioDevice.setDefaultOutputDevice(uid: newUID)
    }

    private func outputDevicesDidChange(_ devices: [AudioDevice.Device]) {
        self.cachedDefaultOutputName = AudioDevice.getDefaultOutputDevice()?.name ?? ""
        guard !devices.isEmpty else { return }
        guard !devices.contains(where: { $0.uid == self.selectedOutputUID }) else { return }
        if let prefUID = SettingsStore.shared.preferredOutputDeviceUID,
           devices.contains(where: { $0.uid == prefUID })
        {
            self.selectedOutputUID = prefUID
        } else if let defaultUID = AudioDevice.getDefaultOutputDevice()?.uid,
                  devices.contains(where: { $0.uid == defaultUID })
        {
            self.selectedOutputUID = defaultUID
        } else {
            self.selectedOutputUID = devices.first?.uid ?? ""
        }
    }


    private func exportBackup() {
        Task { await self.performBackupExport() }
    }

    private func performBackupExport() async {
        do {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = BackupService.shared.suggestedFilename()

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let document = await BackupService.shared.makeBackupDocument()
            let data = try BackupService.shared.encode(document)
            try data.write(to: url, options: .atomic)

            self.presentInfoAlert(
                title: "Backup Exported",
                message: "Saved your MouthKeys backup to:\n\(url.path)"
            )
        } catch {
            self.presentErrorAlert(
                title: "Backup Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importBackup() {
        Task { await self.performBackupImport() }
    }

    private func performBackupImport() async {
        do {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.json]

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let data = try Data(contentsOf: url)
            let document = try BackupService.shared.decode(data)

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let confirm = NSAlert()
            confirm.messageText = "Import this backup?"
            confirm.informativeText = """
            This replaces your current settings, prompt profiles, and stats history.

            Exported: \(formatter.string(from: document.exportedAt))
            API keys are not included and will not be changed.
            """
            confirm.alertStyle = .warning
            confirm.addButton(withTitle: "Import")
            confirm.addButton(withTitle: "Cancel")

            guard confirm.runModal() == .alertFirstButtonReturn else { return }

            try await BackupService.shared.restore(document)
            self.syncLocalSettingsAfterBackupRestore()

            self.presentInfoAlert(
                title: "Backup Imported",
                message: "Your settings, prompt profiles, and stats were restored successfully."
            )
        } catch {
            self.presentErrorAlert(
                title: "Backup Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func syncLocalSettingsAfterBackupRestore() {
        self.refreshAudioHistoryUsage()
    }

    private func refreshAudioHistoryUsage() {
        self.audioHistoryUsageBytes = DictationAudioHistoryStore.shared.audioUsageBytes()
        self.audioHistoryBudgetText = Self.audioBudgetText(for: SettingsStore.shared.audioHistoryBudgetGB)
    }

    private func applyAudioHistoryBudget() {
        let normalized = self.audioHistoryBudgetText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else {
            self.presentErrorAlert(title: "Invalid Budget", message: "Enter a positive number of GB.")
            self.refreshAudioHistoryUsage()
            return
        }

        let newBudget = max(0.1, value)
        let newBudgetBytes = DictationAudioHistoryStore.bytes(forGigabytes: newBudget)
        if self.audioHistoryUsageBytes > newBudgetBytes {
            let confirm = NSAlert()
            confirm.messageText = "Prune saved audio?"
            confirm.informativeText = """
            This budget is below current audio usage. MouthKeys will delete the oldest saved audio first and keep transcript history.
            """
            confirm.alertStyle = .warning
            confirm.addButton(withTitle: "Apply and Prune")
            confirm.addButton(withTitle: "Cancel")
            guard confirm.runModal() == .alertFirstButtonReturn else {
                self.refreshAudioHistoryUsage()
                return
            }
        }

        SettingsStore.shared.audioHistoryBudgetGB = newBudget
        let pruned = TranscriptionHistoryStore.shared.pruneAudioToBudget()
        self.refreshAudioHistoryUsage()
        if pruned > 0 {
            self.presentInfoAlert(title: "Audio Pruned", message: "Deleted oldest saved audio from \(pruned) history entries.")
        }
    }

    private func deleteSavedAudio() {
        let confirm = NSAlert()
        confirm.messageText = "Delete saved audio?"
        confirm.informativeText = "This removes saved dictation audio only. Transcript history stays intact."
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Delete Audio")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let removed = TranscriptionHistoryStore.shared.deleteAllSavedAudio()
        self.refreshAudioHistoryUsage()
        self.presentInfoAlert(title: "Audio Deleted", message: "Removed audio from \(removed) history entries.")
    }

    private func exportAudioZip() {
        do {
            guard TranscriptionHistoryStore.shared.entries.contains(where: {
                DictationAudioHistoryStore.shared.audioFileExists(for: $0)
            }) else {
                throw DictationAudioHistoryError.noAudioEntries
            }

            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = DictationAudioHistoryStore.shared.suggestedAudioExportFilename()

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try DictationAudioHistoryStore.shared.exportAudioArchive(
                entries: TranscriptionHistoryStore.shared.entries,
                to: url
            )
            self.presentInfoAlert(title: "Audio Export Saved", message: "Saved your dictation audio export to:\n\(url.path)")
        } catch {
            self.presentErrorAlert(title: "Audio Export Failed", message: error.localizedDescription)
        }
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Helper Views

    private static func audioBudgetText(for value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private var pausedShortcutsDetail: String {
        let shortcuts = self.primaryDictationShortcuts.map(\.displayString).filter { !$0.isEmpty }
        guard !shortcuts.isEmpty else {
            return "Global hotkeys start as soon as macOS confirms access."
        }
        return "Your shortcuts are saved (\(shortcuts.joined(separator: ", "))) and resume as soon as macOS confirms access."
    }

    @ViewBuilder
    private func shortcutRow(
        content: ShortcutRowContent,
        shortcut: HotkeyShortcut?,
        isRecording: Bool,
        isAnyRecordingActive: Bool,
        recordingMessage: String? = nil,
        isEnabled: Binding<Bool>? = nil,
        requiresShortcutToEnable: Bool = false,
        onChangePressed: @escaping () -> Void,
        onRemovePressed: (() -> Void)? = nil
    ) -> some View {
        let enabledValue = isEnabled?.wrappedValue ?? true
        let hasShortcut = shortcut != nil
        let enableToggleDisabled = isAnyRecordingActive || (requiresShortcutToEnable && !hasShortcut)
        let shortcutWell = DatasheetHotkeyWell {
            Text(isRecording ? "PRESS SHORTCUT…" : (shortcut?.displayString ?? "NOT SET"))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(isRecording ? self.datasheetPalette.accent : self.datasheetPalette.text)
                .lineLimit(1)
        }
        .frame(width: 180)
        let shortcutActions = HStack(spacing: 4) {
            self.sheetAction(isRecording ? "Cancel" : "Change", icon: isRecording ? "xmark" : "pencil") {
                if isRecording {
                    self.shortcutRecordingMessage = nil
                    self.activeShortcutRecordingTarget = nil
                } else {
                    onChangePressed()
                }
            }
            .disabled(!isRecording && (isAnyRecordingActive || (!enabledValue && hasShortcut)))

            if let onRemovePressed {
                self.sheetAction("Remove", icon: "minus", action: onRemovePressed)
                    .disabled(!hasShortcut || isAnyRecordingActive)
            }
        }
        DatasheetRow(label: content.title, help: content.description, dimmed: !enabledValue, control: {
            VStack(alignment: .trailing, spacing: 6) {
                if let isEnabled {
                    Toggle(content.title, isOn: isEnabled)
                        .labelsHidden()
                        .toggleStyle(DatasheetToggleStyle())
                        .disabled(enableToggleDisabled)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        shortcutWell
                        shortcutActions
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .trailing, spacing: 4) {
                        shortcutWell
                        shortcutActions
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                if isRecording, let recordingMessage, !recordingMessage.isEmpty {
                    Text(recordingMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(self.datasheetPalette.accent)
                }
            }
            .opacity(enabledValue ? 1 : 0.72)
        })
    }
}

// Microphone priority controls preserve MouthKeys selection without changing the macOS default.
private extension SettingsView {
    var isMicrophonePriorityEditingDisabled: Bool {
        self.asr.isRunning || self.asr.isStarting
    }

    func refreshActiveInputSelection() {
        // Reuse the existing off-main hardware refresh so the green active
        // indicator and next capture resolve from live Core Audio.
        self.refreshDevices()
    }

    func removeMicrophonePriorityEntry(_ entry: SettingsStore.MicrophonePriorityEntry) {
        self.hoveredMicrophoneUID = nil
        self.settings.removeMicrophoneFromPriority(uid: entry.uid)
        self.refreshActiveInputSelection()
    }

    var selectedInputDevice: AudioDevice.Device? {
        guard let confirmedUID = self.microphonePreferenceCoordinator.confirmedActiveInputUID else {
            return nil
        }
        return self.inputDevices.first { $0.uid == confirmedUID }
    }

}

private extension SettingsView {
    private func settingsZoneContent(_ zone: SettingsZone) -> AnyView {
        switch zone {
        case .microphone: AnyView(self.microphoneSettingsZone)
        case .hotkeys: AnyView(self.hotkeysSettingsZone)
        case .dictation: AnyView(self.dictationSettingsZone)
        case .app: AnyView(self.appSettingsZone)
        case .history: AnyView(self.historySettingsZone)
        case .format: AnyView(self.formatSettingsZone)
        case .alerts: AnyView(self.alertSettingsZone)
        case .overlay: AnyView(self.overlaySettingsZone)
        case .backup: AnyView(self.backupSettingsZone)
        case .debug: AnyView(self.debugSettingsZone)
        }
    }

    func settingsZoneStrip(scrollProxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(SettingsZone.allCases) { zone in
                    let isSelected = self.selectedSettingsZone == zone
                    DatasheetBracketed(rest: false) {
                        Button {
                            self.selectedSettingsZone = zone
                            withAnimation(self.accessibilityReduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                scrollProxy.scrollTo(zone.anchor, anchor: .top)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Text(zone.letter)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                Text(zone.shortLabel)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .tracking(0.3)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .foregroundStyle(isSelected ? self.datasheetPalette.invForeground : self.datasheetPalette.text2)
                            .frame(width: 90, height: 40)
                            .background(isSelected ? self.datasheetPalette.invBackground : self.datasheetPalette.sidebar)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(zone.letter), \(zone.title)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollIndicators(.hidden)
        .background(self.datasheetPalette.sidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(self.datasheetPalette.ruleSoft).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.datasheetPalette.rule).frame(height: 1)
        }
    }

    func sheetToggleRow(
        _ title: String,
        help: String,
        isOn: Binding<Bool>,
        indent: Bool = false,
        disabled: Bool = false,
        showsBottomRule: Bool = true
    ) -> some View {
        DatasheetRow(label: title, help: help, indent: indent, dimmed: disabled, showsBottomRule: showsBottomRule) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(DatasheetToggleStyle())
                .disabled(disabled)
        }
    }

    func sheetField(
        _ title: String,
        placeholder: String,
        text: Binding<String>,
        width: CGFloat = 230
    ) -> some View {
        DatasheetBracketed(rest: false) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(self.datasheetPalette.text)
                .padding(.horizontal, 10)
                .frame(width: width, height: 32)
                .background(self.datasheetPalette.field)
                .overlay { Rectangle().strokeBorder(self.datasheetPalette.edge, lineWidth: 1) }
                .accessibilityLabel(title)
        }
    }

    func sheetAction(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let icon {
                Label(title, systemImage: icon)
            } else {
                Text(title)
            }
        }
        .buttonStyle(DatasheetTextButtonStyle())
        .padding(.horizontal, 8)
    }

    func sheetPrimaryAction(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if let icon {
                Label(title, systemImage: icon)
            } else {
                Text(title)
            }
        }
        .buttonStyle(DatasheetPrimaryButtonStyle())
    }

    func settingsHelpPanel(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(self.datasheetPalette.text2)
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 10) {
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.datasheetPalette.text2)
                    Text(.init(line))
                        .font(.system(size: 13))
                        .foregroundStyle(self.datasheetPalette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.datasheetPalette.sidebar)
        .overlay { Rectangle().strokeBorder(self.datasheetPalette.edge, lineWidth: 1) }
    }

    var microphoneSettingsZone: some View {
        DatasheetSection(
            letter: "A",
            title: "Microphone",
            trailing: self.asr.isRunning ? "RECORDING" : nil,
            note: self.asr.isRunning ? "During a recording, output selection is unavailable and microphone priority is locked." : nil
        ) {
            VStack(spacing: 0) {
                self.inputDeviceSettingsRow

                DatasheetRow(
                    label: "Microphone Access",
                    help: self.microphonePermissionSummary,
                    control: {
                        HStack(spacing: 10) {
                            DatasheetStatusSquare(kind: self.asr.micStatus == .authorized ? .ink : .orange)
                            Text(self.microphonePermissionStatus)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(self.datasheetPalette.text2)
                            if self.asr.micStatus == .notDetermined {
                                self.sheetPrimaryAction("Grant Access", icon: "mic.fill") { self.asr.requestMicAccess() }
                            } else if self.asr.micStatus == .denied {
                                self.sheetPrimaryAction("Open Settings", icon: "gear") { self.asr.openSystemSettingsForMic() }
                            }
                        }
                    }
                )

                if self.asr.micStatus != .authorized {
                    self.settingsHelpPanel(
                        title: "How to enable microphone access",
                        lines: self.asr.micStatus == .notDetermined
                            ? ["Choose **Grant Access** above.", "Respond to the system permission prompt."]
                            : [
                                "Choose **Open Settings** above.",
                                "Find **\(self.appDisplayName)** in the microphone list.",
                                "Turn on microphone access for MouthKeys.",
                            ]
                    )
                    .padding(.vertical, 8)
                }

                self.settingsMicrophonePriorityTable
                    .padding(.vertical, 8)

                DatasheetRow(
                    label: "Output Device",
                    help: "Choose where recording cues and other MouthKeys audio play. Unavailable while recording.",
                    showsBottomRule: false,
                    control: { self.outputDevicePicker }
                )
            }
        }
    }

    func refreshSettingsAudioDevices() {
        self.refreshDevices()
        let defaultInput = AudioDevice.getDefaultInputDevice()
        self.cachedDefaultInputUID = defaultInput?.uid ?? ""
        self.cachedDefaultOutputName = AudioDevice.getDefaultOutputDevice()?.name ?? ""
    }

    var microphonePermissionStatus: String {
        switch self.asr.micStatus {
        case .authorized: "AUTHORIZED"
        case .denied: "DENIED"
        case .notDetermined: "NOT DETERMINED"
        case .restricted: "RESTRICTED"
        @unknown default: "UNKNOWN"
        }
    }

    var microphonePermissionSummary: String {
        self.asr.micStatus == .authorized
            ? "MouthKeys can request microphone capture when you dictate."
            : "Microphone access is required to record dictation."
    }

    private var inputDeviceSettingsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                self.inputDeviceSettingsLabel
                    .frame(minWidth: 180, idealWidth: 180, maxWidth: .infinity, alignment: .leading)
                self.inputDeviceSettingsControls
            }
            VStack(alignment: .leading, spacing: 12) {
                self.inputDeviceSettingsLabel
                self.inputDeviceSettingsControls
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.datasheetPalette.ruleSoft).frame(height: 1)
        }
    }

    private var inputDeviceSettingsLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Input Device")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(self.datasheetPalette.text)
            Text("Choose the microphone MouthKeys should use and watch its level during active capture. The meter is empty while inactive; it is not a readiness check. This changes MouthKeys priority, not the macOS default input.")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(2)
                .foregroundStyle(self.datasheetPalette.text2)
                .frame(maxWidth: 470, alignment: .leading)
        }
    }

    private var inputDeviceSettingsControls: some View {
        let value = Int((self.inputAudioLevel * 16).rounded())
        return HStack(spacing: 12) {
            self.inputDevicePicker
            DatasheetMeter(value: value, count: 16, segmentWidth: 4, segmentHeight: 14, accentLastFilled: true)
                .accessibilityLabel("Input level from active capture")
                .accessibilityValue(self.inputAudioLevel == 0 ? "No current level" : "\(value) of 16")
        }
    }

    var settingsPrimaryDictationShortcutsList: some View {
        let addTarget = ShortcutRecordingTarget.primaryDictation(.add)
        let isAdding = self.isRecording(addTarget)
        return VStack(spacing: 0) {
            ForEach(Array(self.primaryDictationShortcuts.enumerated()), id: \.offset) { index, shortcut in
                let target = ShortcutRecordingTarget.primaryDictation(.replace(index))
                let isRecording = self.isRecording(target)
                let shortcutWell = DatasheetHotkeyWell {
                    Text(isRecording ? "PRESS SHORTCUT…" : shortcut.displayString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isRecording ? self.datasheetPalette.accent : self.datasheetPalette.text)
                        .lineLimit(1)
                }
                .frame(width: 174)
                let shortcutActions = HStack(spacing: 4) {
                    self.sheetAction(isRecording ? "Cancel" : "Change", icon: isRecording ? "xmark" : "pencil") {
                        if isRecording {
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = nil
                        } else {
                            DebugLogger.shared.debug("Starting to record replacement primary dictation shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = target
                        }
                    }
                    .disabled(!isRecording && self.isRecordingAnyShortcut)
                    self.sheetAction("Remove", icon: "minus") {
                        guard self.primaryDictationShortcuts.count > 1,
                              self.primaryDictationShortcuts.indices.contains(index)
                        else { return }
                        self.primaryDictationShortcuts.remove(at: index)
                    }
                    .disabled(self.primaryDictationShortcuts.count <= 1 || self.isRecordingAnyShortcut)
                }
                DatasheetRow(
                    label: "Dictation Shortcut \(index + 1)",
                    help: isRecording ? (self.shortcutRecordingMessage ?? "Press the new shortcut combination now.") : "Use a keyboard shortcut, auxiliary mouse button, or modified click.",
                    control: {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 4) {
                                shortcutWell
                                shortcutActions
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            VStack(alignment: .trailing, spacing: 4) {
                                shortcutWell
                                shortcutActions
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                )
            }

            if isAdding {
                DatasheetRow(
                    label: "New Dictation Shortcut",
                    help: self.shortcutRecordingMessage ?? "Press the new shortcut combination now.",
                    indent: true,
                    control: {
                        DatasheetHotkeyWell {
                            Text("PRESS SHORTCUT…")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(self.datasheetPalette.accent)
                        }
                    }
                )
            }

            DatasheetRow(
                label: "Primary Shortcut List",
                help: "At least one primary dictation shortcut must remain.",
                showsBottomRule: false,
                control: {
                    self.sheetAction(isAdding ? "Cancel Add" : "Add Shortcut", icon: isAdding ? "xmark" : "plus") {
                        if isAdding {
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = nil
                        } else {
                            DebugLogger.shared.debug("Starting to record new primary dictation shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = addTarget
                        }
                    }
                    .disabled(!isAdding && self.isRecordingAnyShortcut)
                }
            )
        }
    }

    var settingsMicrophonePriorityTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("PRIORITY ORDER")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(self.datasheetPalette.text)
                Rectangle().fill(self.datasheetPalette.ruleSoft).frame(height: 1)
                if !self.settings.suppressedMicrophoneUIDs.isEmpty {
                    self.sheetAction("Restore Removed", icon: "arrow.uturn.backward") {
                        self.settings.restoreRemovedMicrophones(with: self.inputDevices)
                        self.refreshActiveInputSelection()
                    }
                    .disabled(self.isMicrophonePriorityEditingDisabled)
                }
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Color.clear
                        .frame(width: 18, height: 1)
                        .accessibilityHidden(true)
                    Text("#")
                        .frame(width: 26, alignment: .trailing)
                    Text("INPUT DEVICE PRIORITY")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                    Text("STATE")
                        .frame(width: 96, alignment: .leading)
                    self.sheetAction("Refresh", icon: "arrow.clockwise") { self.refreshSettingsAudioDevices() }
                        .help("Refresh the available microphone and output device lists.")
                        .accessibilityLabel("Refresh audio devices")
                }
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(self.datasheetPalette.text2)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(self.datasheetPalette.ruleSoft).frame(height: 1)
                }

                if self.settings.microphonePriority.isEmpty {
                    HStack(spacing: 8) {
                        DatasheetStatusSquare(kind: .outline)
                        Text(self.inputDevices.isEmpty ? "No microphones available" : "No microphones in priority")
                            .font(.system(size: 13))
                            .foregroundStyle(self.datasheetPalette.text2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                } else {
                    ForEach(Array(self.settings.microphonePriority.enumerated()), id: \.element.uid) { index, entry in
                        self.settingsMicrophonePriorityRow(entry, rank: index + 1)
                        if index < self.settings.microphonePriority.count - 1 {
                            Rectangle().fill(self.datasheetPalette.ruleSoft).frame(height: 1)
                        }
                    }
                }
            }
            .background(self.datasheetPalette.surface)
            .overlay { Rectangle().strokeBorder(self.datasheetPalette.edge, lineWidth: 1) }

            Text("MouthKeys tries microphones from top to bottom. Drag to reorder. Unavailable devices keep their place. This order does not change the macOS input.")
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(self.datasheetPalette.text2)
                .fixedSize(horizontal: false, vertical: true)
            if self.selectedInputDevice?.isBluetooth == true {
                HStack(alignment: .top, spacing: 8) {
                    DatasheetStatusSquare(kind: .orange)
                    Text("Bluetooth microphone mode can reduce headphone playback quality. Prefer a wired, USB, or display microphone when available.")
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundStyle(self.datasheetPalette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    func settingsMicrophonePriorityRow(
        _ entry: SettingsStore.MicrophonePriorityEntry,
        rank: Int
    ) -> some View {
        let connectedDevice = self.inputDevices.first { $0.uid == entry.uid }
        let isAvailable = connectedDevice.map { self.microphonePreferenceCoordinator.isInputDeviceAvailable($0) } ?? false
        let isActive = entry.uid == self.microphonePreferenceCoordinator.confirmedActiveInputUID && isAvailable
        let isHovered = self.hoveredMicrophoneUID == entry.uid
        let battery = isActive ? self.overlayModel.micBattery?.percent : nil

        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(self.isMicrophonePriorityEditingDisabled ? self.datasheetPalette.textDim : self.datasheetPalette.text2)
                .frame(width: 18, height: 32)
                .contentShape(Rectangle())
                .onDrag {
                    self.draggedMicrophoneUID = entry.uid
                    return NSItemProvider(object: entry.uid as NSString)
                } preview: {
                    Rectangle()
                        .fill(self.datasheetPalette.field)
                        .overlay { Rectangle().strokeBorder(self.datasheetPalette.edge, lineWidth: 1) }
                        .overlay {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(self.datasheetPalette.text)
                        }
                        .frame(width: 36, height: 36)
                }
                .allowsHitTesting(!self.isMicrophonePriorityEditingDisabled)
                .accessibilityHidden(true)

            Text(String(format: "%02d", rank))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(self.datasheetPalette.text2)
                .frame(width: 26, alignment: .trailing)
                .monospacedDigit()

            Text(entry.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isAvailable ? self.datasheetPalette.text : self.datasheetPalette.textDim)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                DatasheetStatusSquare(kind: isActive ? .orange : (isAvailable ? .ink : .outline))
                Text(isActive ? "ACTIVE" : (isAvailable ? "STANDBY" : "UNAVAILABLE"))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(self.datasheetPalette.text2)
                    .frame(width: 84, alignment: .leading)
                    .lineLimit(1)
            }

            Text(battery.map { "\($0)% BATT" } ?? "— BATT")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.2)
                .foregroundStyle(self.datasheetPalette.text2)
                .frame(width: 66, alignment: .trailing)
                .monospacedDigit()

            Group {
                if isHovered {
                    Button(role: .destructive) {
                        self.removeMicrophonePriorityEntry(entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(self.datasheetPalette.text)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(self.isMicrophonePriorityEditingDisabled)
                    .help("Remove \(entry.name) from microphone priority")
                    .accessibilityLabel("Remove \(entry.name)")
                } else {
                    Color.clear.frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 50)
        .contentShape(Rectangle())
        .opacity(isAvailable ? 1 : 0.68)
        .onHover { hovering in
            let animation: Animation? = self.accessibilityReduceMotion ? nil : .easeOut(duration: 0.12)
            withAnimation(animation) {
                if hovering { self.hoveredMicrophoneUID = entry.uid }
                else if self.hoveredMicrophoneUID == entry.uid { self.hoveredMicrophoneUID = nil }
            }
        }
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: MicrophonePriorityDropDelegate(
                targetUID: entry.uid,
                settings: self.settings,
                draggedUID: self.$draggedMicrophoneUID,
                reorderAnimation: self.accessibilityReduceMotion ? nil : .easeInOut(duration: 0.16),
                onDropCompleted: self.refreshActiveInputSelection
            )
        )
        .contextMenu {
            Button("Move Up") {
                self.settings.moveMicrophonePriority(uid: entry.uid, by: -1)
                self.refreshActiveInputSelection()
            }
            .disabled(self.isMicrophonePriorityEditingDisabled || rank == 1)
            Button("Move Down") {
                self.settings.moveMicrophonePriority(uid: entry.uid, by: 1)
                self.refreshActiveInputSelection()
            }
            .disabled(self.isMicrophonePriorityEditingDisabled || rank == self.settings.microphonePriority.count)
            Divider()
            Button("Remove from Priority", role: .destructive) { self.removeMicrophonePriorityEntry(entry) }
                .disabled(self.isMicrophonePriorityEditingDisabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Priority \(rank), \(entry.name)")
        .accessibilityValue(isActive ? "Active" : (isAvailable ? "Available" : "Unavailable"))
        .accessibilityAction(named: "Move up") {
            guard !self.isMicrophonePriorityEditingDisabled, rank > 1 else { return }
            self.settings.moveMicrophonePriority(uid: entry.uid, by: -1)
            self.refreshActiveInputSelection()
        }
        .accessibilityAction(named: "Move down") {
            guard !self.isMicrophonePriorityEditingDisabled, rank < self.settings.microphonePriority.count else { return }
            self.settings.moveMicrophonePriority(uid: entry.uid, by: 1)
            self.refreshActiveInputSelection()
        }
        .accessibilityAction(named: "Remove from priority") {
            guard !self.isMicrophonePriorityEditingDisabled else { return }
            self.removeMicrophonePriorityEntry(entry)
        }
    }

    var inputDevicePicker: some View {
        let availableDevices = self.inputDevices.filter {
            self.microphonePreferenceCoordinator.isInputDeviceAvailable($0)
        }
        let selectedDevice = availableDevices.first { $0.uid == self.selectedInputUID }
        return DatasheetPicker(
            title: "Input Device",
            value: selectedDevice?.name ?? (availableDevices.isEmpty ? "No microphones" : "Select microphone"),
            minimumWidth: 230
        ) {
            if availableDevices.isEmpty {
                Button("No microphones available") {}.disabled(true)
            } else {
                ForEach(availableDevices, id: \.uid) { device in
                    Button {
                        self.selectedInputUID = device.uid
                        self.microphonePreferenceCoordinator.pick(device, source: "settings")
                    } label: {
                        if device.uid == self.selectedInputUID {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            }
        }
    }

    var outputDevicePicker: some View {
        let selectedDevice = self.outputDevices.first { $0.uid == self.selectedOutputUID }
        let isSystemDefault = selectedDevice.map { $0.name == self.cachedDefaultOutputName } ?? false
        let value = selectedDevice?.name ?? (self.outputDevices.isEmpty ? "Loading…" : "Select output")
        return DatasheetPicker(
            title: "Output Device",
            value: value,
            detail: isSystemDefault ? "SYSTEM DEFAULT" : nil,
            minimumWidth: 230
        ) {
            if self.outputDevices.isEmpty {
                Button("Loading…") {}.disabled(true)
            } else {
                ForEach(self.outputDevices, id: \.uid) { device in
                    Button {
                        self.selectedOutputUID = device.uid
                    } label: {
                        if device.uid == self.selectedOutputUID {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            }
        }
        .disabled(self.asr.isRunning)
    }

    var hotkeysSettingsZone: some View {
        DatasheetSection(letter: "B", title: "Hotkeys", note: "Configure shortcuts and recover Accessibility access. Changes apply as you make them.") {
            VStack(spacing: 0) {
                DatasheetRow(
                    label: "Accessibility",
                    help: self.accessibilityEnabled ? "Global hotkeys can use the Accessibility event tap." : AccessibilityHintPolicy.pausedSummary,
                    control: {
                        HStack(spacing: 9) {
                            DatasheetStatusSquare(kind: self.accessibilityEnabled ? .ink : .orange)
                            Text(self.accessibilityEnabled ? "ENABLED" : "PAUSED")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(0.5)
                                .foregroundStyle(self.datasheetPalette.text2)
                            if !self.accessibilityEnabled {
                                self.sheetPrimaryAction("Open Settings", icon: "gear") { self.openAccessibilitySettings() }
                            }
                        }
                    }
                )

                if !self.accessibilityEnabled {
                    DatasheetRow(label: "Saved shortcuts", help: self.pausedShortcutsDetail) { EmptyView() }
                    self.settingsHelpPanel(
                        title: "Follow these steps to enable Accessibility",
                        lines: [
                            "Choose **Open Settings** above.",
                            "In Accessibility, click the **+** button.",
                            "Select **\(self.appDisplayName)**. Use Reveal in Finder if it is missing.",
                            "Click **Open**, then turn on MouthKeys in the list.",
                        ]
                    )
                    .padding(.vertical, 8)
                    self.accessibilityRecoveryPanel
                    HStack(spacing: 4) {
                        self.sheetAction("Reveal in Finder", icon: "folder") { self.revealAppInFinder() }
                        self.sheetAction("Open Applications", icon: "square.grid.2x2") { self.openApplicationsFolder() }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                } else {
                    DatasheetRow(
                        label: "Hotkey Status",
                        help: self.isRecordingAnyShortcut ? "Press the new key combination now." : "",
                        showsBottomRule: false,
                        control: {
                            HStack(spacing: 8) {
                                DatasheetStatusSquare(kind: self.isRecordingAnyShortcut ? .orange : (self.hotkeyManagerInitialized ? .ink : .outline))
                                Text(self.isRecordingAnyShortcut ? "RECORDING" : (self.hotkeyManagerInitialized ? "ACTIVE" : (self.permissionMonitor.hotkeyTapState == .failedTrusted ? "PAUSED" : "INITIALIZING")))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundStyle(self.datasheetPalette.text2)
                            }
                        }
                    )
                    if self.isRecordingAnyShortcut {
                        self.settingsHelpPanel(title: "Shortcut capture", lines: [self.shortcutRecordingMessage ?? "Press your new hotkey combination now."])
                            .padding(.bottom, 8)
                    } else if !self.hotkeyManagerInitialized,
                              self.permissionMonitor.hotkeyTapState != .failedTrusted,
                              self.permissionMonitor.hint != .relaunch {
                        DatasheetRow(label: "Hotkey initialization", help: "MouthKeys is waiting for the Accessibility event tap to become available.") { ProgressView().controlSize(.small) }
                    }
                    self.accessibilityRecoveryPanel
                }

                if self.accessibilityEnabled {
                    DatasheetRow(
                        label: "Primary Dictation Shortcuts",
                        help: "Use any keyboard shortcut, auxiliary mouse button, or modified click.",
                        control: { EmptyView() }
                    )
                    self.settingsPrimaryDictationShortcutsList
                    self.dictationPromptPicker(for: .primary)

                    self.shortcutRow(
                        content: .init(icon: "terminal.fill", iconColor: .secondary, title: "Command Mode", description: "Execute voice commands"),
                        shortcut: self.commandModeShortcut,
                        isRecording: self.isRecording(.command),
                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                        recordingMessage: self.isRecording(.command) ? self.shortcutRecordingMessage : nil,
                        isEnabled: self.$commandModeShortcutEnabled,
                        requiresShortcutToEnable: true,
                        onChangePressed: {
                            DebugLogger.shared.debug("Starting to record new command mode shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = .command
                        },
                        onRemovePressed: {
                            if self.activeShortcutRecordingTarget == .command {
                                self.shortcutRecordingMessage = nil
                                self.activeShortcutRecordingTarget = nil
                            }
                            self.commandModeShortcut = nil
                            self.commandModeShortcutEnabled = false
                        }
                    )
                    self.shortcutRow(
                        content: .init(icon: "pencil.and.outline", iconColor: .secondary, title: "Edit Mode", description: "Select text and speak how to edit, or generate new content"),
                        shortcut: self.rewriteShortcut,
                        isRecording: self.isRecording(.edit),
                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                        recordingMessage: self.isRecording(.edit) ? self.shortcutRecordingMessage : nil,
                        isEnabled: self.$rewriteShortcutEnabled,
                        onChangePressed: {
                            DebugLogger.shared.debug("Starting to record new write mode shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = .edit
                        }
                    )
                    self.shortcutRow(
                        content: .init(icon: "xmark.circle.fill", iconColor: .secondary, title: "Cancel Recording", description: "Cancel the current recording or dismiss the active recording overlay"),
                        shortcut: self.cancelRecordingShortcut,
                        isRecording: self.isRecording(.cancel),
                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                        recordingMessage: self.isRecording(.cancel) ? self.shortcutRecordingMessage : nil,
                        onChangePressed: {
                            DebugLogger.shared.debug("Starting to record new cancel shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = .cancel
                        }
                    )
                    self.shortcutRow(
                        content: .init(icon: "arrow.down.doc", iconColor: .secondary, title: "Paste Last Transcription", description: "Re-insert your most recent transcription without using the clipboard"),
                        shortcut: self.pasteLastTranscriptionShortcut,
                        isRecording: self.isRecording(.pasteLast),
                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                        recordingMessage: self.isRecording(.pasteLast) ? self.shortcutRecordingMessage : nil,
                        isEnabled: self.$pasteLastTranscriptionShortcutEnabled,
                        requiresShortcutToEnable: true,
                        onChangePressed: {
                            DebugLogger.shared.debug("Starting to record paste last transcription shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = .pasteLast
                        },
                        onRemovePressed: {
                            if self.activeShortcutRecordingTarget == .pasteLast {
                                self.shortcutRecordingMessage = nil
                                self.activeShortcutRecordingTarget = nil
                            }
                            self.pasteLastTranscriptionShortcut = nil
                            self.pasteLastTranscriptionShortcutEnabled = false
                        }
                    )
                    self.shortcutRow(
                        content: .init(icon: "arrow.clockwise", iconColor: .secondary, title: "Reprocess Last Dictation", description: "Re-run your most recent dictation through the current AI settings"),
                        shortcut: self.reprocessLastDictationShortcut,
                        isRecording: self.isRecording(.reprocessLast),
                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                        recordingMessage: self.isRecording(.reprocessLast) ? self.shortcutRecordingMessage : nil,
                        isEnabled: self.$reprocessLastDictationShortcutEnabled,
                        requiresShortcutToEnable: true,
                        onChangePressed: {
                            DebugLogger.shared.debug("Starting to record new reprocess last dictation shortcut", source: "SettingsView")
                            self.shortcutRecordingMessage = nil
                            self.activeShortcutRecordingTarget = .reprocessLast
                        },
                        onRemovePressed: {
                            if self.activeShortcutRecordingTarget == .reprocessLast {
                                self.shortcutRecordingMessage = nil
                                self.activeShortcutRecordingTarget = nil
                            }
                            self.reprocessLastDictationShortcut = nil
                            self.reprocessLastDictationShortcutEnabled = false
                        }
                    )

                    DatasheetRow(
                        label: "Activation Mode",
                        help: self.hotkeyMode.description,
                        showsBottomRule: false,
                        control: {
                            DatasheetSegmented(
                                selection: self.$hotkeyMode,
                                choices: HotkeyActivationMode.allCases.map {
                                    .init(value: $0, title: $0 == .automatic ? "BOTH" : $0.displayName)
                                },
                                cellWidth: 70
                            )
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    var accessibilityRecoveryPanel: some View {
        switch self.permissionMonitor.hint {
        case .none:
            EmptyView()
        case .staleGrant:
            self.settingsRecoveryCard(
                title: AccessibilityHintPolicy.staleGrantHeadline,
                message: AccessibilityHintPolicy.staleGrantBody,
                primaryTitle: "Open Accessibility Settings",
                primaryAction: { self.permissionMonitor.openAccessibilitySettings() }
            )
        case .conflictingCopies:
            self.settingsRecoveryCard(
                title: AccessibilityHintPolicy.conflictingCopiesHeadline,
                message: AccessibilityHintPolicy.conflictingCopiesBody,
                paths: self.permissionMonitor.conflictingCopies.prefix(3).map { ConflictingAppCopyDetector.displayPath($0) },
                primaryTitle: "Show in Finder",
                primaryAction: { NSWorkspace.shared.activateFileViewerSelecting(Array(self.permissionMonitor.conflictingCopies.prefix(3))) },
                secondaryTitle: "Open Accessibility Settings",
                secondaryAction: { self.permissionMonitor.openAccessibilitySettings() }
            )
        case .relaunch:
            self.settingsRecoveryCard(
                title: AccessibilityHintPolicy.relaunchHeadline,
                message: AccessibilityHintPolicy.relaunchBody,
                primaryTitle: "Relaunch MouthKeys",
                primaryAction: self.restartApp
            )
        }
    }

    func settingsRecoveryCard(
        title: String,
        message: String,
        paths: [String] = [],
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(self.datasheetPalette.text)
            ForEach(paths, id: \.self) { path in
                Text(path)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.datasheetPalette.text2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(self.datasheetPalette.text2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                self.sheetPrimaryAction(primaryTitle, action: primaryAction)
                if let secondaryTitle, let secondaryAction {
                    self.sheetAction(secondaryTitle, action: secondaryAction)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.datasheetPalette.sidebar)
        .overlay { Rectangle().strokeBorder(self.datasheetPalette.edge, lineWidth: 1) }
        .padding(.vertical, 8)
    }

    var dictationSettingsZone: some View {
        DatasheetSection(letter: "C", title: "Dictation", note: "Controls for text delivery and spoken commands.") {
            VStack(spacing: 0) {
                self.sheetToggleRow(
                    "Copy to Clipboard",
                    help: "Automatically copy transcribed text to clipboard as a backup.",
                    isOn: self.$copyToClipboard
                )
                DatasheetRow(
                    label: "Text Insertion Mode",
                    help: SettingsStore.shared.textInsertionMode.description,
                    control: {
                        let selection = Binding(
                            get: { SettingsStore.shared.textInsertionMode },
                            set: { SettingsStore.shared.textInsertionMode = $0 }
                        )
                        DatasheetPicker(title: "Text Insertion Mode", value: selection.wrappedValue.displayName, minimumWidth: 230) {
                            ForEach(SettingsStore.TextInsertionMode.allCases) { mode in
                                Button {
                                    selection.wrappedValue = mode
                                } label: {
                                    if mode == selection.wrappedValue { Label(mode.displayName, systemImage: "checkmark") }
                                    else { Text(mode.displayName) }
                                }
                            }
                        }
                    }
                )
                self.sheetToggleRow(
                    "Return to Starting Field",
                    help: "Paste dictation into the field where you started recording, even if you switch apps. When off, it lands where your cursor is when you stop.",
                    isOn: Binding(
                        get: { self.settings.returnDictationToStartingField },
                        set: { self.settings.returnDictationToStartingField = $0 }
                    )
                )
                self.sheetToggleRow(
                    "Q for Question Mark",
                    help: "Say “Q” as the last word, or “Q Q” anywhere, to type a question mark. Say “\(self.settings.punctuationDictionaryPrefix) Q” to type the letter.",
                    isOn: Binding(
                        get: { self.settings.questionMarkShortcutEnabled },
                        set: { self.settings.questionMarkShortcutEnabled = $0 }
                    )
                )
                self.spokenSendSettingsDatasheet
                self.sheetToggleRow(
                    "Skip Silent Recordings",
                    help: "Avoid transcription when a recording up to four seconds contains only clear silence. Disabled by default to preserve quiet speech.",
                    isOn: Binding(
                        get: { self.settings.skipSilentRecordingsEnabled },
                        set: { self.settings.skipSilentRecordingsEnabled = $0 }
                    )
                )
                self.sheetToggleRow(
                    "Pause Media During Transcription",
                    help: "Automatically pause currently playing audio/video when transcription starts. Resumes only if MouthKeys paused it.",
                    isOn: Binding(
                        get: { self.settings.pauseMediaDuringTranscription },
                        set: { self.settings.pauseMediaDuringTranscription = $0 }
                    ),
                    showsBottomRule: false
                )
            }
        }
    }

    var spokenSendSettingsDatasheet: some View {
        Group {
            self.sheetToggleRow(
                "Spoken Send",
                help: "End a dictation with a phrase and MouthKeys presses Return after the text lands.",
                isOn: Binding(
                    get: { self.settings.spokenSendEnabled },
                    set: { self.settings.spokenSendEnabled = $0 }
                )
            )
            if self.settings.spokenSendEnabled {
                DatasheetRow(
                    label: "Send Phrase",
                    help: "Say it last. Say “literal \(self.settings.spokenSendPhrase)” to type it instead.",
                    indent: true,
                    control: {
                        self.sheetField(
                            "Spoken Send phrase",
                            placeholder: "send it",
                            text: Binding(
                                get: { self.settings.spokenSendPhrase },
                                set: { self.settings.spokenSendPhrase = $0 }
                            ),
                            width: 210
                        )
                    }
                )
                self.sheetToggleRow(
                    "Send After a Pause",
                    help: "Once the phrase ends what you said, stop listening after half a second of quiet and send. Keep talking, or click the plane on the overlay, to cancel. Not while you hold the dictation key: letting go ends it.",
                    isOn: Binding(
                        get: { self.settings.spokenSendImmediatelyEnabled },
                        set: { self.settings.spokenSendImmediatelyEnabled = $0 }
                    ),
                    indent: true
                )
                DatasheetRow(
                    label: "Send Key",
                    help: "The key MouthKeys sends with. Terminals always get Return.",
                    indent: true,
                    showsBottomRule: false,
                    control: {
                        let selection = Binding(
                            get: { self.settings.spokenSendKey },
                            set: { self.settings.spokenSendKey = $0 }
                        )
                        DatasheetPicker(title: "Spoken Send key", value: selection.wrappedValue.displayName, minimumWidth: 210) {
                            ForEach(SettingsStore.SpokenSendKey.allCases) { key in
                                Button {
                                    selection.wrappedValue = key
                                } label: {
                                    if key == selection.wrappedValue { Label(key.displayName, systemImage: "checkmark") }
                                    else { Text(key.displayName) }
                                }
                            }
                        }
                    }
                )
            }
        }
    }

    var appSettingsZone: some View {
        DatasheetSection(letter: "D", title: "App", note: "Startup, window presence, and local sound cues.") {
            VStack(spacing: 0) {
                self.sheetToggleRow(
                    "Launch at startup",
                    help: "Automatically start MouthKeys when you log in.",
                    isOn: self.launchAtStartupBinding
                )
                if !self.settings.launchAtStartupStatusMessage.isEmpty {
                    DatasheetRow(label: "Startup status", help: self.settings.launchAtStartupStatusMessage, indent: true) { EmptyView() }
                }
                if let error = self.settings.launchAtStartupErrorMessage, !error.isEmpty {
                    DatasheetRow(label: "Startup issue", help: error, indent: true) {
                        DatasheetStatusSquare(kind: .orange)
                    }
                }
                self.sheetToggleRow(
                    "Show window when launched at login",
                    help: "When off, MouthKeys starts silently in the menu bar at login. Opening the app yourself always shows the window.",
                    isOn: Binding(
                        get: { self.settings.showMainWindowAtLoginLaunch },
                        set: { self.settings.showMainWindowAtLoginLaunch = $0 }
                    )
                )
                self.sheetToggleRow(
                    "Hide from Dock & App Switcher",
                    help: "Keep MouthKeys in the menu bar only. May require an app restart to take effect.",
                    isOn: Binding(
                        get: { self.settings.hideFromDockAndAppSwitcher },
                        set: { self.settings.hideFromDockAndAppSwitcher = $0 }
                    )
                )
                DatasheetRow(
                    label: "Transcription Sounds",
                    help: "Choose a sound cue for recording. Some cues include an end sound.",
                    control: {
                        let selected = SettingsStore.shared.transcriptionStartSound
                        let soundPicker = DatasheetPicker(title: "Transcription Sounds", value: selected.displayName, minimumWidth: 190) {
                            ForEach(SettingsStore.TranscriptionStartSound.allCases) { option in
                                Button {
                                    SettingsStore.shared.transcriptionStartSound = option
                                    TranscriptionSoundPlayer.shared.playPreview(sound: option)
                                } label: {
                                    if option == selected { Label(option.displayName, systemImage: "checkmark") }
                                    else { Text(option.displayName) }
                                }
                            }
                        }
                        let previewAction = self.sheetAction("Preview", icon: "play.fill") {
                            TranscriptionSoundPlayer.shared.playPreview(sound: SettingsStore.shared.transcriptionStartSound)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 4) {
                                soundPicker
                                previewAction
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            VStack(alignment: .trailing, spacing: 4) {
                                soundPicker
                                previewAction
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                )
                if SettingsStore.shared.transcriptionStartSound != .none {
                    DatasheetRow(
                        label: "Volume",
                        help: "Adjust the recording sound cue volume. Release the slider to preview it.",
                        control: {
                            let volume = Binding(
                                get: { Double(SettingsStore.shared.transcriptionSoundVolume) },
                                set: { SettingsStore.shared.transcriptionSoundVolume = Float($0) }
                            )
                            DatasheetSlider(value: volume, in: 0...1, step: 0.05, label: "Transcription sound volume", width: 180, readout: { String(format: "%.0f%%", $0 * 100) })
                                .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
                                    TranscriptionSoundPlayer.shared.playPreviewAtVolume(SettingsStore.shared.transcriptionSoundVolume)
                                })
                        }
                    )
                }
                DatasheetRow(
                    label: "Updates",
                    help: "MouthKeys does not update itself. Download new releases from GitHub.",
                    showsBottomRule: false,
                    control: { Link("Latest release", destination: MouthKeysLinks.latestRelease).buttonStyle(DatasheetTextButtonStyle()) }
                )
            }
        }
    }

    var historySettingsZone: some View {
        DatasheetSection(letter: "E", title: "History & Privacy", note: "History and saved audio stay on this Mac. MouthKeys sends no analytics or telemetry.") {
            VStack(spacing: 0) {
                self.sheetToggleRow(
                    "Save Transcription History",
                    help: "Save transcriptions for stats tracking. Disable for privacy.",
                    isOn: Binding(
                        get: { self.settings.saveTranscriptionHistory },
                        set: {
                            self.settings.saveTranscriptionHistory = $0
                            self.refreshAudioHistoryUsage()
                        }
                    )
                )
                self.sheetToggleRow(
                    "Save Audio With History",
                    help: "Store actual microphone audio locally with dictation history. A recording whose transcription timed out is kept until you reprocess it or your next dictation replaces it.",
                    isOn: Binding(
                        get: { self.settings.saveAudioWithTranscriptionHistory },
                        set: {
                            self.settings.saveAudioWithTranscriptionHistory = $0
                            self.refreshAudioHistoryUsage()
                        }
                    ),
                    indent: true,
                    disabled: !self.settings.saveTranscriptionHistory
                )

                if self.settings.saveTranscriptionHistory && self.settings.saveAudioWithTranscriptionHistory {
                    DatasheetRow(
                        label: "Audio Storage",
                        help: "\(DictationAudioHistoryStore.formattedGigabytes(self.audioHistoryUsageBytes)) / \(Self.audioBudgetText(for: self.settings.audioHistoryBudgetGB)) GB budget",
                        indent: true,
                        control: { self.audioHistoryUsageMeter }
                    )
                    DatasheetRow(
                        label: "Audio Budget",
                        help: "Lowering the budget below current use asks before pruning the oldest saved audio.",
                        indent: true,
                        control: {
                            HStack(spacing: 6) {
                                self.sheetField("Audio history budget", placeholder: "4", text: self.$audioHistoryBudgetText, width: 90)
                                Text("GB")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(self.datasheetPalette.text2)
                                self.sheetPrimaryAction("Apply") { self.applyAudioHistoryBudget() }
                            }
                        }
                    )
                    DatasheetRow(
                        label: "Export Audio",
                        help: "Create a ZIP with manifest.jsonl and WAV audio.",
                        indent: true,
                        control: { self.sheetAction("Export ZIP", icon: "square.and.arrow.up") { self.exportAudioZip() } }
                    )
                    DatasheetRow(
                        label: "Delete Audio",
                        help: "Delete saved audio only. Transcript history stays intact.",
                        indent: true,
                        showsBottomRule: false,
                        control: {
                            self.sheetAction("Delete Audio", icon: "trash") { self.deleteSavedAudio() }
                                .disabled(self.audioHistoryUsageBytes <= 0)
                        }
                    )
                }

                self.sheetToggleRow(
                    "Weekends Don't Break Streak",
                    help: "Skip Saturday and Sunday when calculating usage streaks.",
                    isOn: Binding(
                        get: { self.settings.weekendsDontBreakStreak },
                        set: { self.settings.weekendsDontBreakStreak = $0 }
                    ),
                    showsBottomRule: false
                )

                DatasheetRow(
                    label: "Analytics",
                    help: "MouthKeys sends no analytics or telemetry.",
                    showsBottomRule: false,
                    control: { self.sheetAction("Details") { self.showAnalyticsPrivacy = true } }
                )
            }
        }
    }

    var audioHistoryUsageMeter: some View {
        let budget = max(1, self.settings.audioHistoryBudgetBytes)
        let value = min(12, max(0, Int((Double(self.audioHistoryUsageBytes) / Double(budget) * 12).rounded())))
        return DatasheetMeter(value: value, count: 12, segmentWidth: 8, segmentHeight: 12)
            .accessibilityLabel("Saved audio storage")
            .accessibilityValue("\(DictationAudioHistoryStore.formattedGigabytes(self.audioHistoryUsageBytes)) GB of \(Self.audioBudgetText(for: self.settings.audioHistoryBudgetGB)) GB")
    }

    var formatSettingsZone: some View {
        DatasheetSection(letter: "F", title: "Text Formatting") {
            VStack(spacing: 0) {
                self.sheetToggleRow("Lowercase First Letter", help: "Start each transcription with a lowercase letter.", isOn: Binding(get: { self.settings.gaavLowercaseFirstLetterEnabled }, set: { self.settings.gaavLowercaseFirstLetterEnabled = $0 }))
                self.sheetToggleRow("Remove Trailing Period", help: "Drop a final period from transcriptions.", isOn: Binding(get: { self.settings.gaavRemoveTrailingPeriodEnabled }, set: { self.settings.gaavRemoveTrailingPeriodEnabled = $0 }))
                self.sheetToggleRow("Slash Commands & @ Formatting", help: "Convert spoken slash commands and supported @ mentions into symbols.", isOn: Binding(get: { self.settings.literalDictationFormattingEnabled }, set: { self.settings.literalDictationFormattingEnabled = $0 }))
                self.sheetToggleRow("Space Between Dictations", help: "Add spacing when consecutive dictations are joined.", isOn: Binding(get: { self.settings.continuousDictationSpacingEnabled }, set: { self.settings.continuousDictationSpacingEnabled = $0 }))
                self.sheetToggleRow("Smart Capitalization", help: "Use text before the cursor to choose uppercase or lowercase.", isOn: Binding(get: { self.settings.contextAwareCapitalizationEnabled }, set: { self.settings.contextAwareCapitalizationEnabled = $0 }), showsBottomRule: false)
            }
        }
    }

    var alertSettingsZone: some View {
        DatasheetSection(letter: "G", title: "Notifications") {
            VStack(spacing: 0) {
                self.sheetToggleRow("AI Enhancement Failures", help: "Notify when AI Enhancement fails and raw transcription is typed.", isOn: Binding(get: { self.settings.notifyAIProcessingFailures }, set: { self.settings.notifyAIProcessingFailures = $0 }))
                self.sheetToggleRow(
                    "Microphone Changes",
                    help: "Show an alert when MouthKeys changes or loses its microphone.",
                    isOn: Binding(
                        get: { self.settings.showMicrophoneChangeAlerts },
                        set: { enabled in
                            self.settings.showMicrophoneChangeAlerts = enabled
                            if !enabled { MicrophoneChangeOverlayController.shared.hide() }
                        }
                    )
                )
                self.sheetToggleRow("Paste Check", help: "Show a card when MouthKeys can't confirm that pasted text landed. Failures it can see for certain always show a card.", isOn: Binding(get: { self.settings.showPasteCheckAlerts }, set: { self.settings.showPasteCheckAlerts = $0 }), showsBottomRule: false)
            }
        }
    }

    private var sensitivitySettingsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 24) {
                self.sensitivitySettingsLabel
                    .frame(minWidth: 180, idealWidth: 180, maxWidth: .infinity, alignment: .leading)
                self.sensitivitySettingsControls
            }
            VStack(alignment: .leading, spacing: 12) {
                self.sensitivitySettingsLabel
                self.sensitivitySettingsControls
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.datasheetPalette.ruleSoft).frame(height: 1)
        }
    }

    private var sensitivitySettingsLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Sensitivity")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(self.datasheetPalette.text)
            Text("Control how sensitive the audio visualizer is to sound input.")
                .font(.system(size: 13, weight: .regular))
                .lineSpacing(2)
                .foregroundStyle(self.datasheetPalette.text2)
                .frame(maxWidth: 470, alignment: .leading)
        }
    }

    private var sensitivitySettingsControls: some View {
        HStack(spacing: 12) {
            Text("MORE")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(self.datasheetPalette.text2)
            DatasheetSlider(value: self.$visualizerNoiseThreshold, in: 0.01...0.8, step: 0.01, label: "Visualizer sensitivity", width: 150, readout: { String(format: "%.2f", $0) })
            Text("LESS")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(self.datasheetPalette.text2)
            self.sheetAction("Reset") {
                self.visualizerNoiseThreshold = 0.4
                SettingsStore.shared.visualizerNoiseThreshold = self.visualizerNoiseThreshold
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    var overlaySettingsZone: some View {
        DatasheetSection(letter: "H", title: "Overlay", note: self.asr.isRunning ? "Only the existing output-device and microphone-priority restrictions apply during a recording." : nil) {
            VStack(spacing: 0) {
                self.sensitivitySettingsRow
                DatasheetRow(
                    label: "Overlay Position",
                    help: "Where the recording indicator appears on screen.",
                    control: {
                        DatasheetSegmented(
                            selection: self.$settings.overlayPosition,
                            choices: SettingsStore.OverlayPosition.allCases.map { .init(value: $0, title: $0 == .top ? "TOP" : "BOTTOM") },
                            cellWidth: 82
                        )
                    }
                )
                DatasheetRow(
                    label: "Transcription Preview Length",
                    help: "How many recent characters appear in the notch or pill preview.",
                    control: {
                        let previewLength = Binding(
                            get: { Double(self.settings.transcriptionPreviewCharLimit) },
                            set: { self.settings.transcriptionPreviewCharLimit = Int($0.rounded()) }
                        )
                        DatasheetSlider(
                            value: previewLength,
                            in: Double(SettingsStore.transcriptionPreviewCharLimitRange.lowerBound)...Double(SettingsStore.transcriptionPreviewCharLimitRange.upperBound),
                            step: Double(SettingsStore.transcriptionPreviewCharLimitStep),
                            label: "Transcription preview length",
                            width: 190,
                            readout: { "\(Int($0.rounded())) CHARS" }
                        )
                    }
                )

                if self.settings.overlayPosition == .bottom {
                    DatasheetRow(
                        label: "Overlay Size",
                        help: "How large the recording indicator appears.",
                        control: {
                            DatasheetSegmented(
                                selection: self.$settings.overlaySize,
                                choices: SettingsStore.OverlaySize.allCases.map { .init(value: $0, title: $0.displayName) },
                                cellWidth: 64
                            )
                        }
                    )
                } else {
                    DatasheetRow(
                        label: "Notch Style",
                        help: "Choose the regular notch or the compact layout.",
                        control: {
                            DatasheetPicker(title: "Notch Style", value: self.settings.notchPresentationMode.displayName, minimumWidth: 210) {
                                ForEach(SettingsStore.NotchPresentationMode.allCases, id: \.self) { mode in
                                    Button {
                                        self.settings.notchPresentationMode = mode
                                    } label: {
                                        if mode == self.settings.notchPresentationMode { Label(mode.displayName, systemImage: "checkmark") }
                                        else { Text(mode.displayName) }
                                    }
                                }
                            }
                        }
                    )
                }

                self.sheetToggleRow(
                    "Live Preview",
                    help: "Show transcription text in the overlay while you speak.",
                    isOn: self.$enableStreamingPreview,
                    showsBottomRule: self.settings.overlayPosition != .bottom
                )
                if self.settings.overlayPosition == .bottom {
                    DatasheetRow(
                        label: "Bottom Offset",
                        help: "Distance from the bottom of the screen.",
                        showsBottomRule: false,
                        control: {
                            let offset = Binding(get: { self.settings.overlayBottomOffset }, set: { self.settings.overlayBottomOffset = $0 })
                            DatasheetSlider(value: offset, in: 20...500, step: 1, label: "Bottom overlay offset", width: 190, readout: { "\(Int($0)) PX" })
                        }
                    )
                }
            }
        }
    }

    var backupSettingsZone: some View {
        DatasheetSection(letter: "I", title: "Backup & Restore", note: "Export or import settings, prompt profiles, history, and stats. API keys are excluded.") {
            VStack(spacing: 0) {
                DatasheetRow(
                    label: "Settings, prompt profiles, history and stats",
                    help: "Export a JSON backup of supported MouthKeys data or replace current settings, prompt profiles, and stats history. API keys are excluded and will not be changed.",
                    control: {
                        HStack(spacing: 4) {
                            self.sheetAction("Export", icon: "square.and.arrow.up") { self.exportBackup() }
                            self.sheetAction("Import", icon: "square.and.arrow.down") { self.importBackup() }
                        }
                    }
                )
            }
        }
    }

    var debugSettingsZone: some View {
        DatasheetSection(letter: "J", title: "Debug", note: "File logs are always collected for diagnostics.") {
            VStack(spacing: 0) {
                self.sheetToggleRow(
                    "Show Debug Logs in App",
                    help: "Show detailed file logs inside MouthKeys.",
                    isOn: Binding(get: { self.settings.enableDebugLogs }, set: { self.settings.enableDebugLogs = $0 })
                )
                DatasheetRow(
                    label: "Log File",
                    help: "Crash diagnostics are written to Library/Logs/\(AppStorageLocation.logFolderName)/Fluid.log by default.",
                    showsBottomRule: false,
                    control: {
                        self.sheetAction("Reveal Log File", icon: "doc.richtext") {
                            let url = FileLogger.shared.currentLogFileURL()
                            if FileManager.default.fileExists(atPath: url.path) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } else {
                                DebugLogger.shared.info("Log file not found at \(url.path)", source: "SettingsView")
                            }
                        }
                    }
                )
            }
        }
    }
}

private struct MicrophonePriorityDropDelegate: DropDelegate {
    let targetUID: String
    let settings: SettingsStore
    @Binding var draggedUID: String?
    let reorderAnimation: Animation?
    let onDropCompleted: () -> Void

    func validateDrop(info _: DropInfo) -> Bool {
        self.draggedUID != nil
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedUID = self.draggedUID,
              draggedUID != self.targetUID
        else { return }

        let entries = self.settings.microphonePriority
        guard let sourceIndex = entries.firstIndex(where: { $0.uid == draggedUID }),
              let targetIndex = entries.firstIndex(where: { $0.uid == self.targetUID })
        else { return }

        withAnimation(self.reorderAnimation) {
            self.settings.reorderMicrophonePriority(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        self.draggedUID = nil
        self.onDropCompleted()
        return true
    }
}

// MARK: - Filler Words Editor

struct FillerWordsEditor: View {
    @State private var fillerWords: [String] = SettingsStore.shared.fillerWords
    @State private var newWord: String = ""
    @State private var regionalOfferAnswered: Bool = SettingsStore.shared.regionalFillerOfferAnswered
    @Environment(\.datasheetPalette) private var palette
    private let renderingRegionalOffer: Bool

    init(renderingRegionalOffer: Bool = false) {
        self.renderingRegionalOffer = renderingRegionalOffer
        guard renderingRegionalOffer else { return }
        self._fillerWords = State(initialValue: ["um", "uh", "eh"])
        self._regionalOfferAnswered = State(initialValue: false)
    }

    private var regionalOffer: RegionalFillerOffer? {
        let locale = self.renderingRegionalOffer ? Locale(identifier: "en_CA") : .current
        let timeZone = self.renderingRegionalOffer
            ? TimeZone(identifier: "America/Toronto") ?? .current
            : .current
        return RegionalFillerOffer.offer(
            fillerWords: self.fillerWords,
            answered: self.regionalOfferAnswered,
            locale: locale,
            timeZone: timeZone
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let offer = self.regionalOffer {
                self.regionalOfferBanner(offer)
            }

            Text("WORDS TO REMOVE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.55)
                .foregroundStyle(self.palette.text2)

            FlowLayout(spacing: 6) {
                ForEach(self.fillerWords, id: \.self) { word in
                    HStack(spacing: 4) {
                        Text(word)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(self.palette.text)
                        Button {
                            self.removeWord(word)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(self.palette.text2)
                                .frame(width: 18, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(word)")
                    }
                    .padding(.leading, 9)
                    .padding(.trailing, 2)
                    .frame(height: 28)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
            }

            HStack(spacing: 8) {
                TextField("Add word", text: self.$newWord)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(self.palette.text)
                    .padding(.horizontal, 9)
                    .frame(width: 132, height: 30)
                    .background(self.palette.field)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    .onSubmit { self.addWord() }

                Button("Add") { self.addWord() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.palette.text)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    .buttonStyle(.plain)
                    .disabled(self.newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(self.newWord.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                Spacer()

                Button("Reset") {
                    self.fillerWords = SettingsStore.defaultFillerWords
                    SettingsStore.shared.fillerWords = self.fillerWords
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private func addWord() {
        let word = self.newWord.trimmingCharacters(in: .whitespaces).lowercased()
        guard !word.isEmpty, !self.fillerWords.contains(word) else { return }
        self.fillerWords.append(word)
        SettingsStore.shared.fillerWords = self.fillerWords
        self.newWord = ""
    }

    private func removeWord(_ word: String) {
        self.fillerWords.removeAll { $0 == word }
        SettingsStore.shared.fillerWords = self.fillerWords
    }

    private func regionalOfferBanner(_ offer: RegionalFillerOffer) -> some View {
        HStack(alignment: .top, spacing: 10) {
            DatasheetStatusSquare(kind: .orange)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(offer.emoji)
                    Text(offer.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button(offer.keepTitle) { self.answerRegionalOffer(offer, keep: true) }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(self.palette.invForeground)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(self.palette.invBackground)
                        .buttonStyle(.plain)

                    Button("No thanks") { self.answerRegionalOffer(offer, keep: false) }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                        .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.accent, lineWidth: 1) }
    }

    private func answerRegionalOffer(_ offer: RegionalFillerOffer, keep: Bool) {
        self.fillerWords = offer.answer(keep: keep, surface: "settings")
        self.regionalOfferAnswered = true
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    struct Cache {
        var sizes: [CGSize] = []
        var positions: [CGPoint] = []
        var containerSize: CGSize = .zero
        var lastWidth: CGFloat = 0
    }

    var spacing: CGFloat = 8

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: Array(repeating: .zero, count: subviews.count))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        self.arrangeSubviews(proposal: proposal, subviews: subviews, cache: &cache)
        return cache.containerSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        self.arrangeSubviews(proposal: proposal, subviews: subviews, cache: &cache)
        for (index, position) in cache.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let proposedWidth = proposal.width ?? 0
        let maxWidth = proposedWidth > 0 ? proposedWidth : 260
        let needsLayout = cache.positions.count != subviews.count || cache.lastWidth != maxWidth

        if needsLayout {
            cache.positions = []
            cache.positions.reserveCapacity(subviews.count)
            cache.sizes = Array(repeating: .zero, count: subviews.count)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size: CGSize
            if needsLayout {
                size = subviews[index].sizeThatFits(.unspecified)
                cache.sizes[index] = size
            } else {
                size = cache.sizes[index]
            }

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            if needsLayout {
                cache.positions.append(CGPoint(x: x, y: y))
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + self.spacing
        }

        cache.containerSize = CGSize(width: maxWidth, height: y + rowHeight)
        cache.lastWidth = maxWidth
    }
}
