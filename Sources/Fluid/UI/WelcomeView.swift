//
//  WelcomeView.swift
//  fluid
//
//  Welcome and setup guide view
//

import AppKit
import AVFoundation
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appServices: AppServices
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var permissionMonitor = AccessibilityTrustMonitor.shared
    @Environment(\.datasheetPalette) private var palette

    private var asr: ASRService { self.appServices.asr }

    @Binding var selectedSidebarItem: SidebarItem?
    @Binding var playgroundUsed: Bool
    var isTranscriptionFocused: FocusState<Bool>.Binding

    let accessibilityEnabled: Bool
    let stopAndProcessTranscription: () async -> Void
    let startRecording: () -> Void
    let openAccessibilitySettings: () -> Void
    let restartApp: () -> Void

    @State private var voicePractice = DatasheetVoicePractice()
    @State private var isWelcomeVisible = false
    @State private var practiceGateLease = DatasheetQuickSetupPracticeGateLease()
    @State private var practiceTimeoutTask: Task<Void, Never>?

    private let practiceSectionID = "welcome-practice-section"
    private let playgroundSectionID = "welcome-playground-section"
    /// How long the drill waits for a stopped dictation to report back before offering a retry.
    private let practiceResultTimeout: Duration = .seconds(30)

    private var isModelReady: Bool {
        self.asr.isAsrReady || self.asr.modelsExistOnDisk
    }

    private var primaryShortcut: String {
        self.settings.primaryDictationShortcuts.first?.displayString ?? "Not set"
    }

    private var quickSetupProgress: DatasheetQuickSetupProgress {
        DatasheetQuickSetupProgress(
            modelReady: self.isModelReady,
            microphoneAuthorized: self.asr.micStatus == .authorized,
            accessibilityEnabled: self.accessibilityEnabled,
            playgroundValidated: self.playgroundUsed
        )
    }

    private var completedSetupCount: Int {
        self.quickSetupProgress.completedCount
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DatasheetSheetHeader(
                        placard: "00 / START",
                        title: self.isModelReady ? "Getting Started" : "Welcome to MouthKeys",
                        lede: "Talk anywhere. MouthKeys types for you."
                    ) {
                        Button {
                            self.settings.resetOnboardingProgress()
                            self.playgroundUsed = false
                            self.resetVoicePractice()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("RUN ONBOARDING AGAIN")
                            }
                        }
                        .buttonStyle(DatasheetTextButtonStyle())
                    }

                    DatasheetQuickSetupReadout(
                        steps: self.setupSteps(proxy: proxy),
                        completedCount: self.completedSetupCount,
                        readyShortcut: self.primaryShortcut,
                        recoveryHint: self.permissionMonitor.hint,
                        conflictingCopies: self.permissionMonitor.conflictingCopies,
                        openAccessibilitySettings: { self.permissionMonitor.openAccessibilitySettings() },
                        relaunch: self.restartApp
                    )

                    DatasheetWelcomeSectionHeader(
                        title: "Your Dictation Key",
                        trailing: "\(self.primaryShortcut) · \(self.settings.hotkeyMode.displayName)"
                    )
                    .padding(.top, 34)

                    DatasheetKeyPracticeReadout(
                        shortcut: self.primaryShortcut,
                        mode: self.settings.hotkeyMode,
                        practice: self.voicePractice,
                        liveWords: self.asr.partialTranscription,
                        canRecord: self.canPracticeRecord,
                        pressKey: self.togglePracticeRecording,
                        reset: self.resetVoicePractice,
                        changeShortcut: { self.selectedSidebarItem = .preferences }
                    )
                    .id(self.practiceSectionID)

                    DatasheetWelcomeSectionHeader(title: "Test Playground", trailing: "The overlay you will see")
                        .padding(.top, 34)

                    VStack(alignment: .leading, spacing: 0) {
                        self.playgroundActionRow

                        TextEditor(text: Binding(
                            get: { self.asr.finalText },
                            set: { self.asr.finalText = $0 }
                        ))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(self.palette.text)
                        .focused(self.isTranscriptionFocused)
                        .frame(height: 220)
                        .padding(16)
                        .scrollContentBackground(.hidden)
                        .background(self.palette.field)
                        .overlay(alignment: .topLeading) {
                            if self.asr.finalText.isEmpty {
                                Text(self.asr.isRunning ? "Listening… Speak now." : "Press record or your hotkey to begin")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(self.palette.text2)
                                    .padding(.top, 32)
                                    .padding(.leading, 32)
                                    .allowsHitTesting(false)
                            }
                        }
                        .overlay(Rectangle().stroke(self.asr.isRunning ? self.palette.accent : self.palette.edge, lineWidth: 1))

                        HStack(spacing: 18) {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(self.asr.finalText, forType: .string)
                            } label: {
                                Label("COPY TEXT", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(DatasheetTextButtonStyle())
                            .disabled(self.asr.finalText.isEmpty)

                            Button("CLEAR & TEST AGAIN") {
                                self.asr.finalText = ""
                            }
                            .buttonStyle(DatasheetTextButtonStyle())

                            Spacer()
                            DatasheetMonoLabel(text: "Speak, stop, and the text lands here", color: self.palette.text2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
                    }
                    .background(self.palette.surface)
                    .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))
                    .id(self.playgroundSectionID)

                    DatasheetInlineOverlayPreview(
                        fallbackText: self.asr.partialTranscription.isEmpty
                            ? self.asr.finalText
                            : self.asr.partialTranscription
                    )
                    .frame(height: 288)
                    .padding(.top, 14)
                    .background(self.palette.field)
                    .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))

                }
                .padding(.horizontal, 28)
                .padding(.top, 26)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .onAppear {
                self.isWelcomeVisible = true
                self.updatePracticeGate()
                Task { @MainActor in
                    await AudioStartupGate.shared.scheduleOpenAfterInitialUISettled()
                    await AudioStartupGate.shared.waitUntilOpen()
                    self.asr.micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                    await self.asr.checkIfModelsExistAsync()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                self.updatePracticeGate()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                self.updatePracticeGate()
            }
            .onReceive(NotificationCenter.default.publisher(for: .datasheetPracticeDictationFinished)) { _ in
                self.finishPracticeDictation()
            }
            .onChange(of: self.asr.isRunning) { _, isRunning in
                self.practiceRecordingChanged(isRunning: isRunning)
            }
            .onDisappear {
                self.isWelcomeVisible = false
                self.updatePracticeGate()
                self.practiceTimeoutTask?.cancel()
            }
        }
    }

    private var playgroundActionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                self.playgroundRecordingButton
                self.playgroundShortcutPrompt
                self.playgroundShortcutReadout
                Spacer(minLength: 8)
                self.playgroundStatusReadout
            }
            // Reserve the same wide layout for idle, recording and transcript states.
            .frame(minWidth: 620)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    self.playgroundRecordingButton
                        .fixedSize(horizontal: true, vertical: false)
                    self.playgroundShortcutPrompt
                    self.playgroundShortcutReadout
                    Spacer(minLength: 0)
                }
                self.playgroundStatusReadout
                    .frame(maxWidth: .infinity, minHeight: 15, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }
    }

    private var playgroundRecordingButton: some View {
        Button {
            if self.asr.isRunning {
                Task { await self.stopAndProcessTranscription() }
            } else {
                self.startRecording()
                self.markSetupTested()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: self.asr.isRunning ? "stop.fill" : "mic.fill")
                Text(self.asr.isRunning ? "STOP RECORDING" : "START RECORDING")
            }
            .frame(minWidth: 160)
        }
        .buttonStyle(DatasheetPrimaryButtonStyle())
        .disabled(!self.asr.isAsrReady && !self.asr.isRunning)
    }

    private var playgroundShortcutPrompt: some View {
        DatasheetMonoLabel(text: "OR PRESS", color: self.palette.text2)
    }

    private var playgroundShortcutReadout: some View {
        Text(self.primaryShortcut.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(self.palette.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(self.palette.field)
            .overlay(Rectangle().stroke(self.palette.edge, lineWidth: 1))
    }

    private var playgroundStatusReadout: some View {
        HStack(spacing: 12) {
            if self.asr.isRunning {
                HStack(spacing: 7) {
                    DatasheetStatusSquare(kind: .orange)
                    DatasheetMonoLabel(text: "Listening", color: self.palette.accent)
                }
            } else if !self.asr.finalText.isEmpty {
                DatasheetMonoLabel(text: "\(self.asr.finalText.count) Characters", color: self.palette.text2)
            }
            self.wordBoostReadout
        }
    }

    private var wordBoostReadout: some View {
        Group {
            if self.settings.selectedSpeechModel == .parakeetTDT || self.settings.selectedSpeechModel == .parakeetTDTv2 {
                HStack(spacing: 8) {
                    DatasheetStatusSquare(kind: .ink)
                    Text(self.asr.wordBoostStatusText.uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.35)
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func setupSteps(proxy: ScrollViewProxy) -> [DatasheetSetupStep] {
        let progress = self.quickSetupProgress
        let completion = progress.completedSteps
        let current = progress.currentIndex

        func status(_ index: Int) -> DatasheetSetupStepStatus {
            if completion[index] { return .complete }
            return index == current ? .current : .later
        }

        let modelTitle = self.isModelReady ? "Voice Model Ready" : "Download Voice Model"
        let modelDetail = self.asr.isAsrReady
            ? "Speech recognition model is loaded and ready"
            : (self.asr.modelsExistOnDisk ? "Model downloaded, will load when needed" : "Download the AI model for offline voice transcription (~500MB)")

        let microphoneTitle = self.asr.micStatus == .authorized
            ? "Microphone Permission Granted"
            : "Grant Microphone Permission"
        let microphoneActionTitle = self.asr.micStatus == .notDetermined ? "Grant Access" : "Open Settings"

        let testStopInstruction = self.settings.hotkeyMode == .hold ? "let go" : "press it again"

        return [
            DatasheetSetupStep(
                number: 1,
                title: modelTitle,
                detail: modelDetail,
                completedTitle: "Voice Model Ready",
                completedDetail: "\(self.settings.selectedSpeechModel.displayName) · \(self.asr.isAsrReady ? "loaded" : "ready")",
                actionTitle: "Go to Voice Engine",
                actionSymbol: "arrow.down",
                status: status(0),
                action: { self.selectedSidebarItem = .voiceEngine }
            ),
            DatasheetSetupStep(
                number: 2,
                title: microphoneTitle,
                detail: self.asr.micStatus == .authorized
                    ? "MouthKeys has access to your microphone"
                    : "Allow MouthKeys to access your microphone for voice input",
                completedTitle: "Microphone Permission Granted",
                completedDetail: "Access granted",
                actionTitle: microphoneActionTitle,
                actionSymbol: "mic",
                status: status(1),
                action: {
                    if self.asr.micStatus == .notDetermined {
                        self.asr.requestMicAccess()
                    } else if self.asr.micStatus == .denied {
                        self.asr.openSystemSettingsForMic()
                    }
                }
            ),
            DatasheetSetupStep(
                number: 3,
                title: self.accessibilityEnabled ? "Accessibility Access Enabled" : "Enable Accessibility Access",
                detail: self.accessibilityEnabled
                    ? "Accessibility permission granted for typing into apps"
                    : "Drag \(Bundle.main.fluidAppDisplayName) into the Accessibility apps list as shown",
                completedTitle: "Accessibility Access Enabled",
                completedDetail: "Typing into apps",
                actionTitle: "Open Settings",
                actionSymbol: "hand.raised",
                status: status(2),
                action: self.openAccessibilitySettings
            ),
            DatasheetSetupStep(
                number: 4,
                title: progress.voiceValidated ? "Setup Tested Successfully" : "Try Your Dictation Key",
                detail: progress.voiceValidated
                    ? "You’ve successfully tested voice transcription"
                    : "Press \(self.primaryShortcut), say something, then \(testStopInstruction)",
                completedTitle: "Setup Tested Successfully",
                completedDetail: "Voice transcription",
                actionTitle: "Go to Practice",
                actionSymbol: "arrow.down",
                status: status(3),
                action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(self.practiceSectionID, anchor: .top)
                    }
                }
            ),
        ]
    }

    private func markSetupTested() {
        self.playgroundUsed = true
        self.settings.playgroundUsed = true
    }

    private var canPracticeRecord: Bool {
        self.isModelReady && self.asr.micStatus == .authorized
    }

    /// Practice routes dictation into the drill only while Getting Started is open and in front.
    private func updatePracticeGate() {
        self.practiceGateLease.update(
            isVisible: self.isWelcomeVisible && !TestHostQuietMode.isActive,
            applicationIsActive: NSApp.isActive
        )
    }

    /// The keycap stands in for the key: one click starts, the next stops.
    private func togglePracticeRecording() {
        if self.asr.isRunning {
            Task { await self.stopAndProcessTranscription() }
        } else if !self.asr.isStarting, self.canPracticeRecord {
            self.startRecording()
        }
    }

    private func practiceRecordingChanged(isRunning: Bool) {
        if isRunning, self.practiceGateLease.isArmed {
            // Each try starts clean, so the drill and the Playground show only this dictation.
            self.asr.finalText = ""
        }
        self.voicePractice.recordingChanged(isRunning: isRunning)
        self.practiceTimeoutTask?.cancel()
        guard self.voicePractice.stage == .transcribing else { return }
        let timeout = self.practiceResultTimeout
        self.practiceTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self.voicePractice.transcriptionTimedOut()
        }
    }

    private func finishPracticeDictation() {
        self.practiceTimeoutTask?.cancel()
        self.voicePractice.dictationFinished(text: self.asr.finalText)
        if self.voicePractice.heardText != nil {
            self.markSetupTested()
        }
    }

    private func resetVoicePractice() {
        self.practiceTimeoutTask?.cancel()
        self.voicePractice.reset()
    }
}

struct OnboardingFlowView: View {
    @EnvironmentObject var appServices: AppServices
    @Environment(\.datasheetPalette) private var palette
    @ObservedObject private var permissionMonitor = AccessibilityTrustMonitor.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var asr: ASRService {
        self.appServices.asr
    }

    @ObservedObject private var settings = SettingsStore.shared

    @Binding var currentStep: Int
    let accessibilityEnabled: Bool
    let accessibilitySetupInProgress: Bool
    let markAISkipped: () -> Void
    let finishOnboardingAtGettingStarted: () -> Void
    let openAccessibilitySettings: () -> Void
    let restartApp: () -> Void
    let menuBarManager: MenuBarManager
    @Binding var activeShortcutRecordingTarget: ShortcutRecordingTarget?
    @Binding var shortcutRecordingMessage: String?
    let theme: AppTheme

    @State private var selectedLanguageID = SettingsStore.shared.onboardingSelectedLanguageID
    @State private var selectedModelRouteID: String?
    @State private var hoveredLanguageID: String?
    @State private var hoveredModelRouteID: String?
    @State private var hoveredModelActionButtonID: String?
    @State private var hoveredPermissionButtonID: String?
    @State private var onboardingInputDevices: [AudioDevice.Device] = []
    @State private var selectedOnboardingInputUID = ""
    @State private var previewedOnboardingInputUID: String?
    @State private var onboardingMicrophoneLevel: CGFloat = 0
    @State private var lastOnboardingMicrophoneLevelUpdate: TimeInterval = 0
    @State private var microphonePreviewTask: Task<Void, Never>?
    @State private var microphonePreviewGeneration: UInt64 = 0
    @State private var onboardingMicrophoneRefreshGeneration: UInt64 = 0
    @State private var isOnboardingFlowVisible = false
    @State private var hoveredFooterButton: OnboardingFooterButton?
    @State private var isShowingAllLanguages = false
    @State private var isShowingOtherModelRoutes = false
    @State private var preparingModelRouteID: String?
    @State private var uninstallingModelRouteID: String?
    @State private var modelPreparationTask: Task<Void, Never>?
    @State private var languageSearchText = ""
    @FocusState private var isLanguageSearchFocused: Bool
    @State private var hasPlayedLandingWelcomeSound = false
    @State private var landingGlowCenter = UnitPoint(x: 0.5, y: 0.18)
    @State private var lastLandingGlowLocation = CGPoint(x: -1000, y: -1000)
    private let landingGlowMovementThreshold: CGFloat = 24

    private enum OnboardingFooterButton {
        case back
        case skip
        case next
    }

    private enum OnboardingPillButtonTone {
        case primary
        case secondary
        case destructive
    }

    private struct OnboardingPillButtonConfiguration {
        let title: String
        let systemImage: String?
        let tone: OnboardingPillButtonTone
        let width: CGFloat?
        let height: CGFloat
        let fontSize: CGFloat
        let iconSize: CGFloat
        let isHovered: Bool
        let isEnabled: Bool
    }

    private enum Step: Int, CaseIterable {
        case landing = 0
        case language = 1
        case voiceModel = 2
        case permissions = 3
        case playground = 4

        var analyticsStep: AnalyticsOnboardingStep {
            switch self {
            case .landing: .welcome
            case .language: .language
            case .voiceModel: .voiceModel
            case .permissions: .permissions
            case .playground: .playground
            }
        }

        var title: String {
            switch self {
            case .landing:
                return "Welcome"
            case .language:
                return "Language"
            case .voiceModel:
                return "Voice Engine"
            case .permissions:
                return "Enable Access"
            case .playground:
                return "Try MouthKeys"
            }
        }

        var subtitle: String {
            switch self {
            case .landing:
                return "Talk anywhere. MouthKeys types for you."
            case .language:
                return "Pick the language you speak most."
            case .voiceModel:
                return "Choose the best local engine for your language."
            case .permissions:
                return "Allow MouthKeys to listen and type into other apps."
            case .playground:
                return "Use your dictation shortcut once before finishing setup."
            }
        }
    }

    private var step: Step {
        // A stored step past the end comes from the retired AI step; land on the last step.
        Step(rawValue: self.currentStep) ?? (self.currentStep >= Step.allCases.count ? .playground : .voiceModel)
    }

    private var progressValue: Double {
        Double(self.step.rawValue) / Double(Step.allCases.count - 1)
    }

    private var compactProgressValue: Double {
        Double(self.step.rawValue + 1) / Double(Step.allCases.count)
    }

    private var popularOnboardingLanguages: [VoiceEngineLanguage] {
        VoiceEngineLanguageCatalog.popularLanguages()
    }

    private var selectedOnboardingLanguage: VoiceEngineLanguage {
        VoiceEngineLanguageCatalog.language(id: self.selectedLanguageID)
            ?? VoiceEngineLanguageCatalog.language(id: "en")
            ?? VoiceEngineLanguage(id: "en", displayName: "English", aliases: [], isPopular: true)
    }

    private var searchedOnboardingLanguages: [VoiceEngineLanguage] {
        VoiceEngineLanguageCatalog.searchableLanguages(query: self.languageSearchText)
    }

    private var selectedLanguageRoutes: [VoiceEngineLanguageRoute] {
        VoiceEngineLanguageCatalog.routes(for: self.selectedOnboardingLanguage)
    }

    private var selectedOnboardingRoute: VoiceEngineLanguageRoute? {
        if let selectedModelRouteID,
           let selectedRoute = self.selectedLanguageRoutes.first(where: { $0.id == selectedModelRouteID })
        {
            return selectedRoute
        }

        if let selectedRoute = self.selectedLanguageRoutes.first(where: { self.isRouteSelectedInSettings($0) }) {
            return selectedRoute
        }

        return self.selectedLanguageRoutes.first
    }

    private var primaryDisplayedModelRoute: VoiceEngineLanguageRoute? {
        self.selectedLanguageRoutes.first
    }

    private var defaultDisplayedModelRoutes: [VoiceEngineLanguageRoute] {
        var routes: [VoiceEngineLanguageRoute] = []
        if let primaryDisplayedModelRoute {
            routes.append(primaryDisplayedModelRoute)
        }
        if let builtInRoute = self.defaultBuiltInModelRoute,
           !routes.contains(where: { $0.id == builtInRoute.id })
        {
            routes.append(builtInRoute)
        }
        return routes
    }

    private var defaultBuiltInModelRoute: VoiceEngineLanguageRoute? {
        guard self.selectedOnboardingLanguage.id == "en" else {
            return nil
        }

        return self.selectedLanguageRoutes.first { route in
            switch route.model {
            case .appleSpeech, .appleSpeechAnalyzer:
                return true
            default:
                return false
            }
        }
    }

    private var otherModelRoutes: [VoiceEngineLanguageRoute] {
        let defaultRouteIDs = Set(self.defaultDisplayedModelRoutes.map(\.id))
        return self.selectedLanguageRoutes.filter { !defaultRouteIDs.contains($0.id) }
    }

    private var recommendedOnboardingModel: SettingsStore.SpeechModel {
        self.selectedOnboardingRoute?.model ?? SettingsStore.SpeechModel.defaultModel
    }

    private var recommendedModelReasonText: String {
        "Recommended for \(self.selectedOnboardingLanguage.displayName). You can see more options if needed."
    }

    private var isRecommendedModelDownloaded: Bool {
        self.isOnboardingModelDownloaded(self.recommendedOnboardingModel)
    }

    private var isPreparingRecommendedModel: Bool {
        self.isPreparingOnboardingModel(self.recommendedOnboardingModel)
    }

    private var isRecommendedModelReady: Bool {
        self.isOnboardingModelReady(self.recommendedOnboardingModel)
    }

    private var isVoiceModelReady: Bool {
        guard let route = self.selectedOnboardingRoute else {
            return false
        }
        return self.isOnboardingRouteReady(route)
    }

    private var isModelPreparationInProgress: Bool {
        guard self.step == .voiceModel else {
            return false
        }
        return self.preparingModelRouteID != nil
            || self.asr.hasActiveModelPreparation
            || self.asr.isCancellingModelPreparation
            || self.asr.isDownloadingModel
            || (self.asr.isLoadingModel && !self.asr.isAsrReady)
    }

    private var isMicrophoneReady: Bool {
        self.asr.micStatus == .authorized
    }

    private var isAccessibilityReady: Bool {
        self.accessibilityEnabled
    }

    private var isPermissionsReady: Bool {
        self.isMicrophoneReady && self.isAccessibilityReady
    }

    private var isPlaygroundReady: Bool {
        self.settings.onboardingPlaygroundValidated || self.settings.onboardingPlaygroundSkipped
    }

    private var onboardingShortcutDisplay: String {
        let display = self.settings.primaryDictationShortcutDisplayString.trimmingCharacters(in: .whitespacesAndNewlines)
        return display.isEmpty ? "your shortcut" : display
    }

    private var isRecordingAnyShortcut: Bool {
        self.activeShortcutRecordingTarget != nil
    }

    private var isRecordingPrimaryShortcut: Bool {
        self.activeShortcutRecordingTarget?.isPrimaryDictation == true
    }

    private var canContinue: Bool {
        guard !self.isModelPreparationInProgress else {
            return false
        }

        switch self.step {
        case .landing:
            return true
        case .language:
            return !self.selectedLanguageRoutes.isEmpty
        case .voiceModel:
            return self.isVoiceModelReady
        case .permissions:
            return self.isPermissionsReady
        case .playground:
            return self.isPlaygroundReady && !self.asr.isRunning && !self.isRecordingAnyShortcut
        }
    }

    private var primaryButtonTitle: String {
        switch self.step {
        case .landing:
            return "Next"
        case .language:
            return "Continue"
        case .playground:
            return "Finish Setup"
        default:
            return "Continue"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            self.wizardHeader

            HStack(spacing: 0) {
                self.stepRail
                    .frame(width: 240)

                Rectangle()
                    .fill(self.palette.rule)
                    .frame(width: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("\(String(format: "%02d", self.step.rawValue + 1)) / \(self.step.title.uppercased())")
                            .font(DatasheetTheme.Typography.tableLabel.font)
                            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
                            .foregroundStyle(self.palette.text2)

                        self.stepContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 860, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(self.palette.surface)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            self.wizardFooter
        }
        .background(self.palette.surface.ignoresSafeArea())
        .datasheetPalette()
        .onAppear {
            self.isOnboardingFlowVisible = true
            self.syncOnboardingSelectionFromSettings()
            self.playLandingWelcomeSoundIfNeeded()
            self.refreshOnboardingMicrophoneAuthorization(checkModels: true)
            let origin = self.settings.analyticsOnboardingOrigin
            AnalyticsService.shared.recordOnboardingStarted(origin: origin)
            AnalyticsService.shared.recordOnboardingStepViewed(self.step.analyticsStep, origin: origin)
        }
        .onChange(of: self.currentStep) { _, _ in
            if self.step != .voiceModel {
                self.cancelOnboardingModelPreparation()
            }
            if self.step == .permissions, self.isMicrophoneReady {
                self.refreshOnboardingMicrophones(startPreview: true)
            } else {
                self.stopOnboardingMicrophonePreview()
            }
            self.playLandingWelcomeSoundIfNeeded()
            AnalyticsService.shared.recordOnboardingStepViewed(
                self.step.analyticsStep,
                origin: self.settings.analyticsOnboardingOrigin
            )
        }
        .onChange(of: self.isMicrophoneReady) { _, isReady in
            guard self.step == .permissions else { return }
            if isReady {
                self.refreshOnboardingMicrophones(startPreview: true)
            } else {
                self.stopOnboardingMicrophonePreview()
            }
        }
        .onChange(of: self.asr.isStarting) { _, isStarting in
            guard self.isOnboardingFlowVisible,
                  self.step == .permissions,
                  self.isMicrophoneReady
            else { return }
            if isStarting {
                self.suspendOnboardingMicrophonePreviewForDictation()
            }
        }
        .onChange(of: self.asr.audioCaptureStateSettledTick) { _, _ in
            guard self.isOnboardingFlowVisible,
                  self.step == .permissions,
                  self.isMicrophoneReady
            else { return }
            if self.asr.isRunning || self.asr.isStarting {
                self.suspendOnboardingMicrophonePreviewForDictation()
            } else {
                self.refreshOnboardingMicrophones(startPreview: true)
            }
        }
        .onDisappear {
            self.isOnboardingFlowVisible = false
            self.onboardingMicrophoneRefreshGeneration &+= 1
            self.cancelOnboardingModelPreparation()
            self.stopOnboardingMicrophonePreview()
        }
        .onReceive(self.asr.audioLevelPublisher) { level in
            guard self.step == .permissions,
                  self.isMicrophoneReady,
                  self.asr.isMicrophonePreviewActive,
                  self.asr.isRunning == false,
                  self.asr.isStarting == false
            else { return }
            let now = ProcessInfo.processInfo.systemUptime
            guard level == 0 || now - self.lastOnboardingMicrophoneLevelUpdate >= 0.05 else {
                return
            }
            self.lastOnboardingMicrophoneLevelUpdate = now
            self.onboardingMicrophoneLevel = level
        }
        .onChange(of: self.appServices.audioObserver.changeTick) { _, _ in
            guard self.step == .permissions, self.isMicrophoneReady else { return }
            self.refreshOnboardingMicrophones(startPreview: true)
        }
        .onChange(of: self.appServices.audioObserver.inputAvailabilityTick) { _, _ in
            guard self.step == .permissions, self.isMicrophoneReady else { return }
            self.refreshOnboardingMicrophones(startPreview: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            self.syncOnboardingSelectionFromSettings()
            self.refreshOnboardingMicrophoneAuthorization()
        }
    }

    private var wizardHeader: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 240)

            Rectangle()
                .fill(self.palette.rule)
                .frame(width: 1)

            HStack(spacing: 8) {
                Text("SETUP")
                    .foregroundStyle(self.palette.text2)

                Text("/")
                    .foregroundStyle(self.palette.text2)

                Text(self.step.title.uppercased())
                    .foregroundStyle(self.palette.text)

                Spacer(minLength: 8)

                Button {
                    self.skipPlayground()
                } label: {
                    Text("Skip setup")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.canSkipSetup ? self.palette.text : self.palette.text2.opacity(0.45))
                        .frame(width: 104, height: 39)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!self.canSkipSetup)
                .datasheetHoverBracket()
                .accessibilityLabel("Skip setup")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .padding(.leading, 18)
            .padding(.trailing, 0)
        }
        .frame(height: 40)
        .background(self.palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
    }

    private var stepRail: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Step.allCases, id: \.rawValue) { item in
                    let isCurrent = item == self.step
                    let isComplete = item.rawValue < self.step.rawValue
                    let foreground = isCurrent ? self.palette.invForeground : self.palette.text

                    HStack(spacing: 10) {
                        Text(String(format: "%02d", item.rawValue + 1))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(width: 24, alignment: .leading)

                        Text(item.title)
                            .font(.system(size: 12, weight: isCurrent ? .medium : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Spacer(minLength: 2)

                        Text(isComplete ? "DONE" : (isCurrent ? "NOW" : ""))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.3)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .foregroundStyle(isCurrent ? foreground : self.palette.text2)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(isCurrent ? self.palette.invBackground : Color.clear)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(item.rawValue + 1), \(item.title)\(isComplete ? ", done" : (isCurrent ? ", current step" : ""))")
                }
            }
            .padding(.top, 22)

            Spacer(minLength: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("MOUTHKEYS")
                Text("STRAIGHT VOICE TO TEXT")
                Text("LOCAL · NO TELEMETRY")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(0.45)
            .foregroundStyle(self.palette.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxHeight: .infinity)
        .background(self.palette.sidebar)
    }

    private var wizardFooter: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("STEP")
                Text(String(format: "%02d", self.step.rawValue + 1))
                    .foregroundStyle(self.palette.text)
                Text("OF")
                Text(String(format: "%02d", Step.allCases.count))
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(self.palette.text2)
            .padding(.leading, 18)
            .frame(width: 240, alignment: .leading)

            Rectangle()
                .fill(self.palette.rule)
                .frame(width: 1)

            HStack(spacing: 12) {
                if self.step != .landing {
                    Button {
                        self.goBack()
                    } label: {
                        Text("← Back")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(self.palette.text)
                            .frame(width: 88, height: 32)
                            .background(self.palette.surface)
                            .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.canNavigateBack)
                    .opacity(self.canNavigateBack ? 1 : 0.45)
                    .keyboardShortcut(.cancelAction)
                    .datasheetHoverBracket()
                } else {
                    Color.clear.frame(width: 88, height: 32)
                }

                Spacer(minLength: 12)

                DatasheetBracketed(rest: self.canContinue) {
                    Button {
                        self.handlePrimaryAction()
                    } label: {
                        Text(self.primaryButtonTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(self.palette.invForeground)
                            .lineLimit(1)
                            .frame(width: 160, height: 44)
                            .background(self.palette.invBackground)
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.canContinue)
                    .opacity(self.canContinue ? 1 : 0.45)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel(self.primaryButtonTitle)
                }
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 72)
        .background(self.palette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
    }

    private var canSkipSetup: Bool {
        self.step == .playground && !self.asr.isRunning && !self.isRecordingAnyShortcut
    }

    private var canNavigateBack: Bool {
        !self.isModelPreparationInProgress && !self.asr.isRunning && !self.isRecordingAnyShortcut
    }

    @ViewBuilder
    private var stepContent: some View {
        switch self.step {
        case .landing:
            self.landingStep
        case .language:
            self.datasheetLanguageStep
        case .voiceModel:
            self.datasheetVoiceModelStep
        case .permissions:
            self.datasheetPermissionsStep
        case .playground:
            self.datasheetPlaygroundStep
        }
    }

    private var landingStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingFigureOne()
                .frame(height: 215)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text("Just speak.\nWe'll handle the rest.")
                    .font(.system(size: 36, weight: .semibold))
                    .tracking(-0.5)
                    .lineSpacing(-1)
                    .foregroundStyle(self.palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Accurate. Fast. Private. Free. Talk anywhere. MouthKeys types for you.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(self.palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 640, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pageHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .tracking(-0.25)
                .foregroundStyle(self.palette.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(self.palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }

    private var datasheetLanguageStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            self.pageHeading(
                title: "What language will you speak most?",
                subtitle: "We'll show the best voice engines for it."
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(minimum: 88), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(self.popularOnboardingLanguages) { language in
                    self.datasheetLanguageChoiceCard(for: language)
                }
                self.datasheetOtherLanguageCard
            }

            if self.isShowingAllLanguages {
                self.datasheetAllLanguagesPicker
                    .transition(.opacity)
            }

            Text("You can change this later in Voice Engine settings.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(self.palette.text2)
                .padding(.top, 2)
        }
        .frame(maxWidth: 700, alignment: .leading)
    }

    private func datasheetLanguageChoiceCard(for language: VoiceEngineLanguage) -> some View {
        let isSelected = self.selectedLanguageID == language.id

        return DatasheetBracketed(rest: isSelected) {
            Button {
                self.selectOnboardingLanguage(language)
            } label: {
                HStack(spacing: 8) {
                    Text(language.popularDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 2)

                    self.languageSelectionMark(isSelected: isSelected)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .background(self.palette.field)
                .overlay(Rectangle().stroke(isSelected ? self.palette.rule : self.palette.ruleSoft, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(language.displayName)
            .accessibilityValue(isSelected ? "Selected" : "")
        }
        .onHover { self.setHoveredLanguage($0 ? language.id : nil) }
    }

    private var datasheetOtherLanguageCard: some View {
        let isSelected = !self.selectedOnboardingLanguage.isPopular

        return DatasheetBracketed(rest: isSelected || self.isShowingAllLanguages) {
            Button {
                self.toggleAllLanguagesPicker()
            } label: {
                HStack(spacing: 8) {
                    Text(isSelected ? self.selectedOnboardingLanguage.displayName : "Other…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Spacer(minLength: 2)

                    if isSelected {
                        self.languageSelectionMark(isSelected: true)
                    } else {
                        Text("99")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(self.palette.text2)
                    }
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .background(self.palette.field)
                .overlay(Rectangle().stroke(isSelected ? self.palette.rule : self.palette.ruleSoft, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected ? self.selectedOnboardingLanguage.displayName : "Other languages")
            .accessibilityValue(self.isShowingAllLanguages ? "Expanded" : "")
        }
        .onHover { self.setHoveredLanguage($0 ? "other" : nil) }
    }

    private func languageSelectionMark(isSelected: Bool) -> some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? self.palette.invBackground : self.palette.field)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(self.palette.invForeground)
            } else {
                Rectangle()
                    .strokeBorder(self.palette.ruleSoft, lineWidth: 1)
            }
        }
        .frame(width: 17, height: 17)
        .accessibilityHidden(true)
    }

    private var datasheetAllLanguagesPicker: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Search all languages", text: self.$languageSearchText)
                    .font(.system(size: 13, weight: .regular))
                    .textFieldStyle(.plain)
                    .focused(self.$isLanguageSearchFocused)
                    .accessibilityLabel("Search all languages")

                Text(String(format: "%02d", self.searchedOnboardingLanguages.count))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 28, alignment: .trailing)
            }
            .foregroundStyle(self.palette.text)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(self.palette.field)
            .overlay(Rectangle().stroke(self.palette.rule, lineWidth: 1))

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(self.searchedOnboardingLanguages) { language in
                        self.datasheetLanguageSearchRow(for: language)
                    }
                }
            }
            .frame(maxHeight: 176)
            .overlay(Rectangle().stroke(self.palette.ruleSoft, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func datasheetLanguageSearchRow(for language: VoiceEngineLanguage) -> some View {
        let isSelected = self.selectedLanguageID == language.id

        return Button {
            self.selectOnboardingLanguage(language)
        } label: {
            HStack(spacing: 10) {
                Text(language.displayName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(self.palette.text)
                Spacer()
                Text(language.id.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(self.palette.text)
                        .frame(width: 16)
                } else {
                    Color.clear.frame(width: 16, height: 12)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(isSelected ? self.palette.chip : self.palette.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
        }
        .accessibilityLabel(language.displayName)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var datasheetVoiceModelStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            self.pageHeading(
                title: "Choose your voice engine",
                subtitle: self.recommendedModelReasonText
            )

            Text(self.selectedOnboardingLanguage.displayName.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(self.palette.text2)

            let defaultRoutes = self.defaultDisplayedModelRoutes
            if !defaultRoutes.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(defaultRoutes) { route in
                        self.datasheetOnboardingRouteCard(for: route)
                    }
                }
                .transaction { $0.animation = nil }
            }

            if !self.otherModelRoutes.isEmpty {
                self.datasheetOtherModelRoutesToggleButton
            }

            if self.isShowingOtherModelRoutes {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 210), spacing: 12, alignment: .top),
                        GridItem(.flexible(minimum: 210), spacing: 12, alignment: .top),
                    ],
                    spacing: 12
                ) {
                    ForEach(self.otherModelRoutes) { route in
                        self.datasheetOnboardingRouteCard(for: route, enablesHover: false)
                    }
                }
                .transaction { $0.animation = nil }
            }

            if self.isModelPreparationInProgress {
                HStack(spacing: 8) {
                    DatasheetStatusSquare(kind: .orange)
                    Text("Initial preparation can take a while to get your Mac ready for near-instant transcription.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(self.palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            Text("You can switch models later in Voice Engine settings.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(self.palette.text2)
                .padding(.top, 2)
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    private var datasheetOtherModelRoutesToggleButton: some View {
        Button {
            self.toggleOtherModelRoutes()
        } label: {
            HStack(spacing: 8) {
                Text(self.isShowingOtherModelRoutes ? "−" : "+")
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                Text(self.isShowingOtherModelRoutes ? "Hide other models" : "Show other models")
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(self.palette.text2)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .datasheetHoverBracket()
        .accessibilityLabel(self.isShowingOtherModelRoutes ? "Hide other models" : "Show other models")
    }

    private func datasheetOnboardingRouteCard(
        for route: VoiceEngineLanguageRoute,
        enablesHover: Bool = true
    ) -> some View {
        let model = route.model
        let isSelected = self.isOnboardingRouteSelected(route)
        let isRouteActiveInSettings = self.isRouteSelectedInSettings(route)
        let isDownloaded = self.isOnboardingModelBundledOrInstalled(model)
            || (isRouteActiveInSettings && (self.asr.isAsrReady || self.asr.modelsExistOnDisk))
        let isPreparing = self.preparingModelRouteID == route.id
            || (isRouteActiveInSettings && (self.asr.isDownloadingModel || (self.asr.isLoadingModel && !self.asr.isAsrReady)))
        let isReady = self.isOnboardingRouteReady(route)
        let isUninstalling = self.uninstallingModelRouteID == route.id
        let actionsBlocked = self.asr.isRunning
            || self.uninstallingModelRouteID != nil
            || self.preparingModelRouteID != nil
            || isPreparing
            || self.isModelPreparationInProgress
        let isBuiltInAppleModel = model == .appleSpeech || model == .appleSpeechAnalyzer
        let modelTooltip = self.onboardingModelTooltip(for: route)

        return DatasheetBracketed(rest: isSelected) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isSelected ? "SELECTED" : "OPTION")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(self.palette.text2)

                        Text(self.onboardingModelTitle(for: model))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(self.palette.text)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }

                    Spacer(minLength: 2)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(self.palette.text2)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                            .help(modelTooltip)
                            .accessibilityLabel(modelTooltip)

                        DatasheetStatusSquare(kind: isReady ? .ink : (isPreparing ? .orange : .outline))
                            .padding(.top, 3)
                    }
                }
                .frame(minHeight: 38, alignment: .top)

                HStack(spacing: 6) {
                    Text("\(self.onboardingModelSubtitle(for: model)) · \(model.downloadSize)")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    if let badgeText = route.badgeText {
                        Text(badgeText.uppercased())
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .tracking(0.2)
                            .foregroundStyle(self.palette.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                }

                VStack(spacing: 5) {
                    self.datasheetModelMetricRow(fillPercent: model.speedPercent, label: "SPEED")
                    self.datasheetModelMetricRow(fillPercent: model.accuracyPercent, label: "ACCURACY")
                }

                ZStack(alignment: .topLeading) {
                    if isPreparing || isUninstalling {
                        if self.asr.isDownloadingModel,
                           self.asr.modelPreparationPhase == .downloading,
                           let progress = self.asr.downloadProgress
                        {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(self.asr.modelPreparationStatusText.uppercased())
                                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                                        .tracking(0.3)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text("\(Int((progress * 100).rounded()))%")
                                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                                        .frame(width: 34, alignment: .trailing)
                                }
                                ProgressView(value: progress)
                                    .tint(self.palette.accent)
                                    .frame(height: 8)
                            }
                            .foregroundStyle(self.palette.text2)
                        } else {
                            HStack(spacing: 7) {
                                ProgressView().controlSize(.small).fixedSize()
                                Text(self.asr.isCancellingModelPreparation
                                    ? "Cancelling…"
                                    : (isUninstalling ? "Deleting…" : self.asr.modelPreparationStatusText))
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(self.palette.text2)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .frame(height: 16)
                        }
                    }
                }
                .frame(height: 33, alignment: .topLeading)

                HStack(spacing: 8) {
                    if isPreparing {
                        self.datasheetModelActionButton(
                            id: "\(route.id)-cancel",
                            title: self.asr.isCancellingModelPreparation ? "Cancelling…" : "Cancel",
                            systemImage: "xmark",
                            width: 104,
                            isDisabled: self.asr.isCancellingModelPreparation
                        ) {
                            self.cancelOnboardingModelPreparation()
                        }
                    } else if isDownloaded, isBuiltInAppleModel {
                        self.datasheetModelActionButton(
                            id: "\(route.id)-activate",
                            title: self.onboardingModelActionButtonTitle(isPreparing: false, isDownloaded: true, isReady: isReady),
                            systemImage: isReady ? "checkmark" : "bolt.fill",
                            width: nil,
                            isDisabled: actionsBlocked || isReady
                        ) {
                            self.prepareOnboardingRoute(route)
                        }
                    } else if isDownloaded {
                        self.datasheetModelActionButton(
                            id: "\(route.id)-activate",
                            title: self.onboardingModelActionButtonTitle(isPreparing: false, isDownloaded: true, isReady: isReady),
                            systemImage: isReady ? "checkmark" : "bolt.fill",
                            width: 116,
                            isDisabled: actionsBlocked || isReady
                        ) {
                            self.prepareOnboardingRoute(route)
                        }

                        self.datasheetModelActionButton(
                            id: "\(route.id)-uninstall",
                            title: "Delete",
                            systemImage: "trash",
                            width: 88,
                            isSecondary: true,
                            isDisabled: actionsBlocked
                        ) {
                            self.uninstallOnboardingRoute(route)
                        }
                    } else {
                        self.datasheetModelActionButton(
                            id: "\(route.id)-download-activate",
                            title: self.onboardingModelActionButtonTitle(isPreparing: false, isDownloaded: false, isReady: false),
                            systemImage: "arrow.down.circle",
                            width: nil,
                            isDisabled: actionsBlocked
                        ) {
                            self.prepareOnboardingRoute(route)
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 200, alignment: .topLeading)
            .background(self.palette.surface)
            .overlay(Rectangle().stroke(isSelected ? self.palette.rule : self.palette.ruleSoft, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !actionsBlocked else { return }
                self.selectOnboardingRoute(route)
            }
            .onHover { hovering in
                guard enablesHover else { return }
                self.setHoveredModelRoute(hovering ? route.id : nil)
            }
        }
    }

    private func datasheetModelMetricRow(fillPercent: Double, label: String) -> some View {
        let clamped = min(max(fillPercent, 0), 1)

        return HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(self.palette.text2)
                .frame(width: 58, alignment: .leading)

            DatasheetMeter(value: Int((clamped * 10).rounded()), count: 10, segmentWidth: 5, segmentHeight: 8)

            Spacer(minLength: 2)

            Text("\(Int((clamped * 100).rounded()))%")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .frame(width: 34, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .frame(height: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(Int((clamped * 100).rounded())) percent")
    }

    private func datasheetModelActionButton(
        id: String,
        title: String,
        systemImage: String,
        width: CGFloat?,
        isSecondary: Bool = false,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = self.hoveredModelActionButtonID == id && !isDisabled
        let foreground = isSecondary ? self.palette.text : self.palette.invForeground
        let background = isSecondary ? self.palette.surface : self.palette.invBackground

        return Button {
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 8)
                .frame(width: width, height: 30)
                .frame(maxWidth: width == nil ? .infinity : nil)
                .background(background)
                .overlay(Rectangle().stroke(isSecondary ? self.palette.ruleSoft : background, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .datasheetBracket(.chip, visible: isHovered)
        .onHover { hovering in
            self.setHoveredModelActionButton(hovering && !isDisabled ? id : nil)
        }
        .accessibilityLabel(title)
    }

    private var datasheetPermissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            self.pageHeading(
                title: "Let MouthKeys listen and type",
                subtitle: "Two quick permissions make dictation work anywhere."
            )

            VStack(spacing: 0) {
                self.datasheetPermissionRow(
                    systemImage: "mic",
                    title: self.isMicrophoneReady ? "Microphone access allowed" : "Allow microphone",
                    subtitle: self.isMicrophoneReady
                        ? "Choose the microphone you want MouthKeys to use."
                        : "macOS will ask once. Click Allow to start dictating.",
                    isReady: self.isMicrophoneReady,
                    statusTitle: self.isMicrophoneReady ? "Ready" : "Needed",
                    actionTitle: self.microphoneActionButtonTitle,
                    action: self.handleMicrophoneAction
                )

                if self.isMicrophoneReady {
                    OnboardingMicrophoneSetupPanel(
                        devices: self.orderedOnboardingInputDevices,
                        selectedUID: self.selectedOnboardingInputUID,
                        level: self.onboardingMicrophoneLevel,
                        errorMessage: self.asr.microphonePreviewError,
                        onSelect: { self.selectOnboardingMicrophone(uid: $0) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Rectangle().fill(self.palette.rule).frame(height: 1)

                self.datasheetPermissionRow(
                    systemImage: "keyboard",
                    title: self.accessibilityPermissionTitle,
                    subtitle: self.accessibilityPermissionSubtitle,
                    isReady: self.isAccessibilityReady,
                    statusTitle: self.accessibilityPermissionStatusTitle,
                    actionTitle: self.accessibilityPermissionActionTitle,
                    action: self.openAccessibilitySettings
                )

                if self.permissionMonitor.hint != .none {
                    OnboardingDatasheetRecoveryHintView(
                        hint: self.permissionMonitor.hint,
                        conflictingCopies: self.permissionMonitor.conflictingCopies,
                        openAccessibilitySettings: { self.permissionMonitor.openAccessibilitySettings() },
                        relaunch: self.restartApp
                    )
                } else if !self.isAccessibilityReady {
                    Text("Already enabled it? MouthKeys will update when macOS confirms access.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(self.palette.text2)
                        .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    private func datasheetPermissionRow(
        systemImage: String,
        title: String,
        subtitle: String,
        isReady: Bool,
        statusTitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(isReady ? self.palette.invBackground : self.palette.field)
                Image(systemName: isReady ? "checkmark" : systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isReady ? self.palette.invForeground : self.palette.text)
            }
            .frame(width: 48, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(self.palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                DatasheetStatusSquare(kind: isReady ? .ink : .orange, size: 5)
                Text(statusTitle.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(self.palette.text2)
            }
            .frame(width: 82, alignment: .trailing)

            if !isReady {
                Button(action: action) {
                    Label(actionTitle, systemImage: ["Open Settings", "Show Guide"].contains(actionTitle) ? "arrow.up.right" : "hand.tap")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.invForeground)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .frame(width: 128, height: 34)
                        .background(self.palette.invBackground)
                }
                .buttonStyle(.plain)
                .datasheetHoverBracket()
            } else {
                Color.clear.frame(width: 128, height: 34)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var datasheetPlaygroundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            self.pageHeading(
                title: "MouthKeys is ready.",
                subtitle: "Now let's try it out. Press once to start. Press again to stop."
            )

            OnboardingTryoutStepView(
                finalText: Binding(
                    get: { self.asr.finalText },
                    set: { self.asr.finalText = $0 }
                ),
                language: self.selectedOnboardingLanguage,
                shortcutDisplay: self.onboardingShortcutDisplay,
                isReady: self.isPlaygroundReady,
                isRunning: self.asr.isRunning,
                isRecordingShortcut: self.isRecordingPrimaryShortcut,
                shortcutRecordingMessage: self.isRecordingPrimaryShortcut ? self.shortcutRecordingMessage : nil,
                onToggleShortcut: self.togglePrimaryShortcutRecording
            )
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    private func updateLandingGlow(location: CGPoint, in size: CGSize) {
        guard !self.reduceMotion else { return }
        guard location.x.isFinite, location.y.isFinite, size.width > 0, size.height > 0 else { return }

        let dx = location.x - self.lastLandingGlowLocation.x
        let dy = location.y - self.lastLandingGlowLocation.y
        guard (dx * dx) + (dy * dy) > (self.landingGlowMovementThreshold * self.landingGlowMovementThreshold) else { return }

        self.lastLandingGlowLocation = location
        let normalizedX = min(max(location.x / size.width, 0), 1)
        let normalizedY = min(max(location.y / size.height, 0), 1)

        withAnimation(.easeOut(duration: 0.22)) {
            self.landingGlowCenter = UnitPoint(x: normalizedX, y: normalizedY)
        }
    }

    private func resetLandingGlow() {
        guard !self.reduceMotion else { return }
        self.lastLandingGlowLocation = CGPoint(x: -1000, y: -1000)

        withAnimation(.easeOut(duration: 0.35)) {
            self.landingGlowCenter = UnitPoint(x: 0.5, y: 0.18)
        }
    }

    private func playLandingWelcomeSoundIfNeeded() {
        guard self.step == .landing, !self.hasPlayedLandingWelcomeSound else { return }
        Task { @MainActor in
            await AudioStartupGate.shared.scheduleOpenAfterInitialUISettled()
            await AudioStartupGate.shared.waitUntilOpen()
            guard self.isOnboardingFlowVisible,
                  self.step == .landing,
                  self.hasPlayedLandingWelcomeSound == false
            else { return }
            self.hasPlayedLandingWelcomeSound = true
            OnboardingSoundPlayer.shared.playWelcomeSound()
        }
    }

    private var languageStep: some View {
        GeometryReader { proxy in
            ZStack {
                FluidOnboardingLandingBackdrop(glowCenter: self.landingGlowCenter)

                VStack(spacing: 0) {
                    FluidOnboardingCompactProgress(value: self.compactProgressValue)
                        .padding(.top, 28)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            FluidOnboardingCompactAppIconMark(size: 66)
                                .padding(.bottom, 22)

                            Text("What language will\nyou speak most?")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.bottom, 18)

                            Text("We'll show the best voice engines for it.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.62))
                                .padding(.bottom, 26)

                            LazyVGrid(
                                columns: [
                                    GridItem(.fixed(166), spacing: 16),
                                    GridItem(.fixed(166), spacing: 16),
                                    GridItem(.fixed(166), spacing: 16),
                                ],
                                spacing: 16
                            ) {
                                ForEach(self.popularOnboardingLanguages) { language in
                                    self.languageChoiceCard(for: language)
                                }

                                self.otherLanguageCard
                            }
                            .frame(width: 530)

                            if self.isShowingAllLanguages {
                                self.allLanguagesPicker
                                    .padding(.top, 18)
                            }

                            Text("You can change this later in Voice Engine settings.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.44))
                                .padding(.top, 18)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                        .padding(.bottom, 12)
                    }

                    self.cinematicFooter(
                        continueTitle: "Continue",
                        canContinue: self.canContinue
                    ) {
                        self.handlePrimaryAction()
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                FluidOnboardingLandingHoverTracker(
                    onMove: { location, size in
                        self.updateLandingGlow(location: location, in: size)
                    },
                    onExit: {
                        self.resetLandingGlow()
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityHidden(true)
            }
        }
    }

    private func languageChoiceCard(for language: VoiceEngineLanguage) -> some View {
        let isSelected = self.selectedLanguageID == language.id
        let isHovered = self.hoveredLanguageID == language.id
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        let cardFillOpacity = isSelected
            ? (isHovered ? 0.15 : 0.075)
            : (isHovered ? 0.10 : 0.04)
        let borderColor = isSelected
            ? FluidOnboardingLandingColors.blue.opacity(isHovered ? 1 : 0.92)
            : (isHovered ? FluidOnboardingLandingColors.blue.opacity(0.58) : Color.white.opacity(0.10))
        let borderWidth: CGFloat = isSelected
            ? (isHovered ? 1.8 : 1.4)
            : (isHovered ? 1.2 : 1)
        let shadowColor = isSelected
            ? FluidOnboardingLandingColors.blue.opacity(isHovered ? 0.36 : 0.18)
            : FluidOnboardingLandingColors.blue.opacity(isHovered ? 0.18 : 0)
        let shadowRadius: CGFloat = isSelected
            ? (isHovered ? 24 : 18)
            : (isHovered ? 20 : 14)

        return Button {
            self.selectOnboardingLanguage(language)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? FluidOnboardingLandingColors.blue : Color.white.opacity(0.72))
                    .frame(width: 22)

                Text(language.popularDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FluidOnboardingLandingColors.blue)
                }
            }
            .padding(.horizontal, 15)
            .frame(width: 166, height: 58)
            .background(
                shape
                    .fill(Color.white.opacity(cardFillOpacity))
                    .overlay(
                        shape.stroke(
                            borderColor,
                            lineWidth: borderWidth
                        )
                    )
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 0)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered in
            if isHovered {
                self.setHoveredLanguage(language.id)
            } else if self.hoveredLanguageID == language.id {
                self.setHoveredLanguage(nil)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    self.selectOnboardingLanguage(language)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(language.displayName)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private var otherLanguageCard: some View {
        let isSelected = !self.selectedOnboardingLanguage.isPopular
        let isHovered = self.hoveredLanguageID == "other"
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        let fillOpacity = isSelected
            ? (isHovered ? 0.15 : 0.075)
            : (isHovered ? 0.10 : 0.04)
        let borderColor = isSelected
            ? FluidOnboardingLandingColors.blue.opacity(isHovered ? 1 : 0.92)
            : (isHovered ? FluidOnboardingLandingColors.blue.opacity(0.58) : Color.white.opacity(self.isShowingAllLanguages ? 0.16 : 0.10))
        let shadowColor = isSelected
            ? FluidOnboardingLandingColors.blue.opacity(isHovered ? 0.36 : 0.18)
            : FluidOnboardingLandingColors.blue.opacity(isHovered ? 0.18 : 0)

        return Button {
            self.toggleAllLanguagesPicker()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? FluidOnboardingLandingColors.blue : Color.white.opacity(self.isShowingAllLanguages ? 0.78 : 0.72))
                    .frame(width: 22)

                Text(isSelected ? self.selectedOnboardingLanguage.displayName : "Other")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Spacer(minLength: 0)

                Image(systemName: self.isShowingAllLanguages ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.46))
            }
            .padding(.horizontal, 15)
            .frame(width: 166, height: 58)
            .background(
                shape
                    .fill(Color.white.opacity(fillOpacity))
                    .overlay(
                        shape.stroke(
                            borderColor,
                            lineWidth: isSelected ? 1.4 : 1
                        )
                    )
            )
            .shadow(color: shadowColor, radius: isSelected ? (isHovered ? 24 : 18) : 20, x: 0, y: 0)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered in
            self.setHoveredLanguage(isHovered ? "other" : nil)
        }
        .accessibilityLabel("Other languages")
        .accessibilityValue(self.isShowingAllLanguages ? "Expanded" : "Collapsed")
    }

    private var allLanguagesPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.48))

                TextField(
                    "",
                    text: self.$languageSearchText,
                    prompt: Text("Search supported languages")
                        .foregroundStyle(Color.white.opacity(0.42))
                )
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .focused(self.$isLanguageSearchFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(width: 530, height: 38)
            .contentShape(Rectangle())
            .onTapGesture {
                self.isLanguageSearchFocused = true
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 6) {
                    ForEach(self.searchedOnboardingLanguages) { language in
                        self.languageSearchRow(for: language)
                    }
                }
                .padding(8)
            }
            .frame(width: 530, height: 156)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private func languageSearchRow(for language: VoiceEngineLanguage) -> some View {
        let isSelected = self.selectedLanguageID == language.id

        return Button {
            self.selectOnboardingLanguage(language)
        } label: {
            HStack(spacing: 10) {
                Text(language.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(FluidOnboardingLandingColors.blue)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? FluidOnboardingLandingColors.blue.opacity(0.14) : Color.white.opacity(0.045))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func cinematicFooter(
        continueTitle: String,
        canContinue: Bool,
        continueAction: @escaping () -> Void,
        skipTitle: String? = nil,
        canSkip: Bool = false,
        skipAction: (() -> Void)? = nil
    ) -> some View {
        let canNavigateBack = !self.isModelPreparationInProgress && !self.asr.isRunning && !self.isRecordingAnyShortcut

        return HStack {
            self.cinematicFooterButton(
                title: "Back",
                kind: .back,
                isEnabled: canNavigateBack
            ) {
                self.goBack()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if let skipTitle, let skipAction {
                self.cinematicFooterButton(
                    title: skipTitle,
                    kind: .skip,
                    isEnabled: canSkip
                ) {
                    skipAction()
                }
            }

            self.cinematicFooterButton(
                title: continueTitle,
                kind: .next,
                isEnabled: canContinue
            ) {
                continueAction()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 24)
    }

    private func cinematicFooterButton(
        title: String,
        kind: OnboardingFooterButton,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isPrimary = kind == .next
        let isHovered = self.hoveredFooterButton == kind && isEnabled

        return self.onboardingPillButton(
            configuration: OnboardingPillButtonConfiguration(
                title: title,
                systemImage: nil,
                tone: isPrimary ? .primary : .secondary,
                width: 132,
                height: 48,
                fontSize: 16,
                iconSize: 14,
                isHovered: isHovered,
                isEnabled: isEnabled
            ),
            action: action
        ) { isHovered in
            self.setHoveredFooterButton(isHovered ? kind : nil)
        }
        .accessibilityLabel(title)
    }

    private func setHoveredFooterButton(_ button: OnboardingFooterButton?) {
        guard self.hoveredFooterButton != button else { return }
        if self.reduceMotion {
            self.hoveredFooterButton = button
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                self.hoveredFooterButton = button
            }
        }
    }

    private func setHoveredLanguage(_ languageID: String?) {
        guard self.hoveredLanguageID != languageID else { return }
        if self.reduceMotion {
            self.hoveredLanguageID = languageID
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                self.hoveredLanguageID = languageID
            }
        }
    }

    private func toggleAllLanguagesPicker() {
        if self.isShowingAllLanguages {
            self.isShowingAllLanguages = false
            self.isLanguageSearchFocused = false
            self.languageSearchText = ""
        } else {
            self.isShowingAllLanguages = true
            self.isLanguageSearchFocused = true
        }
    }

    private func selectOnboardingLanguage(_ language: VoiceEngineLanguage) {
        guard self.selectedLanguageID != language.id else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.selectedLanguageID = language.id
            self.settings.onboardingSelectedLanguageID = language.id
            self.selectedModelRouteID = VoiceEngineLanguageCatalog.routes(for: language).first?.id
            self.isShowingOtherModelRoutes = false
            self.isLanguageSearchFocused = false
            if language.isPopular {
                self.isShowingAllLanguages = false
                self.languageSearchText = ""
            }
            self.resetTryoutValidationForSetupChange()
        }
    }

    private func syncOnboardingSelectionFromSettings() {
        let allRoutes = VoiceEngineLanguageCatalog.allLanguages()
            .flatMap { VoiceEngineLanguageCatalog.routes(for: $0) }

        let storedLanguageID = self.settings.onboardingSelectedLanguageID
        let storedLanguageRoutes = VoiceEngineLanguageCatalog.routes(forLanguageID: storedLanguageID)
        let route = storedLanguageRoutes.first { route in
            self.isRouteModelAndLanguageSettingsSelected(route)
        } ?? storedLanguageRoutes.first ?? allRoutes.first { route in
            self.isRouteModelAndLanguageSettingsSelected(route)
        }

        guard let route else {
            if self.selectedModelRouteID == nil {
                self.selectedModelRouteID = self.selectedLanguageRoutes.first?.id
            }
            return
        }

        guard self.selectedLanguageID != route.language.id || self.selectedModelRouteID != route.id else {
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.selectedLanguageID = route.language.id
            self.selectedModelRouteID = route.id
            self.isShowingOtherModelRoutes = false
            self.languageSearchText = ""
            self.isLanguageSearchFocused = false
        }
    }

    private var voiceModelStep: some View {
        GeometryReader { proxy in
            ZStack {
                FluidOnboardingLandingBackdrop(glowCenter: self.landingGlowCenter)

                VStack(spacing: 0) {
                    FluidOnboardingCompactProgress(value: self.compactProgressValue)
                        .padding(.top, 28)

                    ScrollView(.vertical, showsIndicators: self.isShowingOtherModelRoutes) {
                        VStack(spacing: 0) {
                            FluidOnboardingCompactAppIconMark(size: 66)
                                .padding(.bottom, 22)

                            Text("Choose your\nvoice engine")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 16)

                            Text(self.recommendedModelReasonText)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.62))
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 14)

                            Text(self.selectedOnboardingLanguage.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(FluidOnboardingLandingColors.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(FluidOnboardingLandingColors.blue.opacity(0.12))
                                        .overlay(Capsule().stroke(FluidOnboardingLandingColors.blue.opacity(0.24), lineWidth: 1))
                                )
                                .padding(.bottom, 18)

                            VStack(spacing: 10) {
                                let defaultRoutes = self.defaultDisplayedModelRoutes
                                if defaultRoutes.count == 1, let route = defaultRoutes.first {
                                    self.onboardingRouteCard(for: route)
                                } else if !defaultRoutes.isEmpty {
                                    HStack(spacing: 16) {
                                        ForEach(defaultRoutes) { route in
                                            self.onboardingRouteCard(for: route)
                                        }
                                    }
                                }

                                if !self.otherModelRoutes.isEmpty {
                                    self.otherModelRoutesToggleButton
                                }

                                if self.isShowingOtherModelRoutes {
                                    LazyVGrid(
                                        columns: [
                                            GridItem(.fixed(292), spacing: 16, alignment: .top),
                                            GridItem(.fixed(292), spacing: 16, alignment: .top),
                                        ],
                                        spacing: 16
                                    ) {
                                        ForEach(self.otherModelRoutes) { route in
                                            self.onboardingRouteCard(for: route, enablesHover: false)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                            .frame(width: 608)

                            if self.isModelPreparationInProgress {
                                Label("Initial preparation can take a while to get your Mac ready for near-instant transcription.", systemImage: "clock.arrow.circlepath")
                                    .font(self.theme.typography.captionStrong)
                                    .foregroundStyle(Color.white.opacity(0.58))
                                    .labelStyle(.titleAndIcon)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.86)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                                    )
                                    .padding(.top, 14)
                            }

                            Text("You can switch models later in Voice Engine settings.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.44))
                                .padding(.top, self.isModelPreparationInProgress ? 8 : 18)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                        .padding(.bottom, 12)
                    }

                    self.cinematicFooter(
                        continueTitle: "Continue",
                        canContinue: self.canContinue
                    ) {
                        self.handlePrimaryAction()
                    }
                }

                FluidOnboardingLandingHoverTracker(
                    onMove: { location, size in
                        self.updateLandingGlow(location: location, in: size)
                    },
                    onExit: {
                        self.resetLandingGlow()
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityHidden(true)
            }
        }
    }

    private var permissionsStep: some View {
        GeometryReader { proxy in
            ZStack {
                FluidOnboardingLandingBackdrop(glowCenter: self.landingGlowCenter)

                VStack(spacing: 0) {
                    FluidOnboardingCompactProgress(value: self.compactProgressValue)
                        .padding(.top, 28)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            FluidOnboardingCompactAppIconMark(size: 66)
                                .padding(.bottom, 22)

                            Text("Let MouthKeys\nlisten and type")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.bottom, 16)

                            Text("Two quick permissions make dictation work anywhere.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.62))
                                .padding(.bottom, 28)

                            VStack(spacing: 14) {
                                self.permissionRow(
                                    stepNumber: 1,
                                    title: self.isMicrophoneReady ? "Microphone access allowed" : "Allow microphone",
                                    subtitle: self.isMicrophoneReady
                                        ? "Choose the microphone you want MouthKeys to use."
                                        : "macOS will ask once. Click Allow to start dictating.",
                                    systemImage: "mic.fill",
                                    isReady: self.isMicrophoneReady,
                                    actionTitle: self.microphoneActionButtonTitle
                                ) {
                                    self.handleMicrophoneAction()
                                }

                                if self.isMicrophoneReady {
                                    OnboardingMicrophoneSetupPanel(
                                        devices: self.orderedOnboardingInputDevices,
                                        selectedUID: self.selectedOnboardingInputUID,
                                        level: self.onboardingMicrophoneLevel,
                                        errorMessage: self.asr.microphonePreviewError,
                                        onSelect: { self.selectOnboardingMicrophone(uid: $0) }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                self.permissionRow(
                                    stepNumber: 2,
                                    title: self.accessibilityPermissionTitle,
                                    subtitle: self.accessibilityPermissionSubtitle,
                                    systemImage: "keyboard.fill",
                                    isReady: self.isAccessibilityReady,
                                    statusTitle: self.accessibilityPermissionStatusTitle,
                                    actionTitle: self.accessibilityPermissionActionTitle
                                ) {
                                    self.openAccessibilitySettings()
                                }

                                if self.permissionMonitor.hint != .none {
                                    AccessibilityRecoveryHintView(
                                        hint: self.permissionMonitor.hint,
                                        conflictingCopies: self.permissionMonitor.conflictingCopies,
                                        tone: .onDark,
                                        openAccessibilitySettings: { self.permissionMonitor.openAccessibilitySettings() },
                                        relaunch: self.restartApp
                                    )
                                    .padding(.top, 2)
                                } else if !self.isAccessibilityReady {
                                    Text("Already enabled it? MouthKeys will update when macOS confirms access.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.42))
                                        .padding(.top, 2)
                                }
                            }
                            .frame(width: 560)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 34)
                        .padding(.bottom, 12)
                    }

                    self.cinematicFooter(
                        continueTitle: "Continue",
                        canContinue: self.canContinue
                    ) {
                        self.handlePrimaryAction()
                    }
                }

                FluidOnboardingLandingHoverTracker(
                    onMove: { location, size in
                        self.updateLandingGlow(location: location, in: size)
                    },
                    onExit: {
                        self.resetLandingGlow()
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityHidden(true)
            }
        }
    }

    private var playgroundStep: some View {
        GeometryReader { proxy in
            ZStack {
                FluidOnboardingLandingBackdrop(glowCenter: self.landingGlowCenter)

                VStack(spacing: 0) {
                    FluidOnboardingCompactProgress(value: self.compactProgressValue)
                        .padding(.top, 28)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            FluidOnboardingCompactAppIconMark(size: 66)
                                .padding(.bottom, 22)

                            Text("MouthKeys is ready.")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.74)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 14)

                            Text("Now let's try it out.")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.62))
                                .padding(.bottom, 28)

                            OnboardingTryoutStepView(
                                finalText: Binding(
                                    get: { self.asr.finalText },
                                    set: { self.asr.finalText = $0 }
                                ),
                                language: self.selectedOnboardingLanguage,
                                shortcutDisplay: self.onboardingShortcutDisplay,
                                isReady: self.isPlaygroundReady,
                                isRunning: self.asr.isRunning,
                                isRecordingShortcut: self.isRecordingPrimaryShortcut,
                                shortcutRecordingMessage: self.isRecordingPrimaryShortcut ? self.shortcutRecordingMessage : nil,
                                onToggleShortcut: self.togglePrimaryShortcutRecording
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 34)
                        .padding(.bottom, 12)
                    }

                    self.cinematicFooter(
                        continueTitle: self.primaryButtonTitle,
                        canContinue: self.canContinue,
                        continueAction: {
                            self.handlePrimaryAction()
                        },
                        skipTitle: "Skip",
                        canSkip: !self.asr.isRunning && !self.isRecordingAnyShortcut,
                        skipAction: {
                            self.settings.onboardingPlaygroundSkipped = true
                            self.finishSetup(outcome: .skipped)
                        }
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                FluidOnboardingLandingHoverTracker(
                    onMove: { location, size in
                        self.updateLandingGlow(location: location, in: size)
                    },
                    onExit: {
                        self.resetLandingGlow()
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityHidden(true)
            }
        }
    }

    private var microphoneActionButtonTitle: String {
        switch self.asr.micStatus {
        case .notDetermined:
            return "Allow"
        case .denied, .restricted:
            return "Open Settings"
        default:
            return "Allow"
        }
    }

    private var accessibilityPermissionTitle: String {
        if self.isAccessibilityReady {
            return "Typing access is ready"
        }
        return self.accessibilitySetupInProgress ? "Finish Accessibility Access" : "Enable Accessibility Access"
    }

    private var accessibilityPermissionSubtitle: String {
        if self.isAccessibilityReady {
            return "\(self.appDisplayName) can place text into the app you're using."
        }
        if self.accessibilitySetupInProgress {
            return "Use the floating guide to drag \(self.appDisplayName) into the Accessibility apps list."
        }
        return "Open Settings, then use the floating guide to add \(self.appDisplayName)."
    }

    private var appDisplayName: String {
        Bundle.main.fluidAppDisplayName
    }

    private var accessibilityPermissionStatusTitle: String {
        if self.isAccessibilityReady {
            return "Ready"
        }
        return self.accessibilitySetupInProgress ? "In Settings" : "Needed"
    }

    private var accessibilityPermissionActionTitle: String {
        self.accessibilitySetupInProgress ? "Show Guide" : "Open Settings"
    }

    private var otherModelRoutesToggleButton: some View {
        Button {
            self.toggleOtherModelRoutes()
        } label: {
            HStack(spacing: 6) {
                Text(self.isShowingOtherModelRoutes ? "Hide other models" : "Show other models")

                Image(systemName: self.isShowingOtherModelRoutes ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.62))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.025))
                    .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 1))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(self.isShowingOtherModelRoutes ? "Hide other models" : "Show other models")
    }

    private func toggleOtherModelRoutes() {
        self.isShowingOtherModelRoutes.toggle()
    }

    private func isOnboardingModelSelected(_ model: SettingsStore.SpeechModel) -> Bool {
        self.settings.selectedSpeechModel == model
    }

    private func isOnboardingModelReady(_ model: SettingsStore.SpeechModel) -> Bool {
        self.isOnboardingModelSelected(model) && self.asr.isAsrReady
    }

    private func isOnboardingRouteReady(_ route: VoiceEngineLanguageRoute) -> Bool {
        self.isRouteSelectedInSettings(route) && self.asr.isAsrReady
    }

    private func isOnboardingModelDownloaded(_ model: SettingsStore.SpeechModel) -> Bool {
        self.isOnboardingModelBundledOrInstalled(model) || (self.isOnboardingModelSelected(model) && (self.asr.isAsrReady || self.asr.modelsExistOnDisk))
    }

    private func isOnboardingModelBundledOrInstalled(_ model: SettingsStore.SpeechModel) -> Bool {
        model.isInstalled
    }

    private func isPreparingOnboardingModel(_ model: SettingsStore.SpeechModel) -> Bool {
        self.isOnboardingModelSelected(model) && (self.asr.isDownloadingModel || (self.asr.isLoadingModel && !self.asr.isAsrReady))
    }

    private func onboardingModelActionButtonTitle(isPreparing: Bool, isDownloaded: Bool, isReady: Bool) -> String {
        if isPreparing {
            return self.asr.isLoadingModel ? "Loading..." : "Downloading..."
        }
        if isReady {
            return "Active now"
        }
        if isDownloaded {
            return "Activate"
        }
        return "Download & Activate"
    }

    private func prepareOnboardingRoute(_ route: VoiceEngineLanguageRoute) {
        guard !self.asr.isRunning, !self.isModelPreparationInProgress, self.uninstallingModelRouteID == nil else { return }

        self.modelPreparationTask?.cancel()
        self.preparingModelRouteID = route.id
        self.selectOnboardingRoute(route)

        self.modelPreparationTask = Task { @MainActor in
            defer {
                self.preparingModelRouteID = nil
                self.modelPreparationTask = nil
            }

            do {
                try await self.asr.ensureAsrReady(source: .onboarding)
            } catch is CancellationError {
                DebugLogger.shared.info("Cancelled onboarding voice model setup for \(route.model.displayName)", source: "OnboardingFlowView")
            } catch {
                DebugLogger.shared.error("Failed to prepare onboarding voice model \(route.model.displayName): \(error)", source: "OnboardingFlowView")
                // Surface the failure in the UI instead of only logging it, so the user
                // isn't stuck at a disabled button. The shared ContentView alert (bound to
                // asr.showError) presents this during onboarding. See #355.
                self.asr.errorTitle = "Voice Model Setup Failed"
                self.asr.errorMessage = error.localizedDescription
                self.asr.showError = true
            }
            guard !Task.isCancelled else { return }
            await self.asr.checkIfModelsExistAsync()
        }
    }

    private func cancelOnboardingModelPreparation() {
        self.modelPreparationTask?.cancel()
        self.asr.cancelModelPreparation()
    }

    private func uninstallOnboardingRoute(_ route: VoiceEngineLanguageRoute) {
        guard !self.asr.isRunning, !self.isModelPreparationInProgress, self.uninstallingModelRouteID == nil else { return }

        self.uninstallingModelRouteID = route.id

        Task { @MainActor in
            defer {
                self.uninstallingModelRouteID = nil
            }

            do {
                try await self.asr.clearModelCache(for: route.model)
                await self.asr.checkIfModelsExistAsync()
            } catch {
                DebugLogger.shared.error("Failed to delete onboarding voice model \(route.model.displayName): \(error)", source: "OnboardingFlowView")
                self.asr.errorTitle = "Model Delete Failed"
                self.asr.errorMessage = error.localizedDescription
                self.asr.showError = true
            }
        }
    }

    private func onboardingRouteCard(
        for route: VoiceEngineLanguageRoute,
        enablesHover: Bool = true
    ) -> some View {
        let model = route.model
        let isSelected = self.isOnboardingRouteSelected(route)
        let isHovered = enablesHover && self.hoveredModelRouteID == route.id
        let isRouteActiveInSettings = self.isRouteSelectedInSettings(route)
        let isDownloaded = self.isOnboardingModelBundledOrInstalled(model) || (isRouteActiveInSettings && (self.asr.isAsrReady || self.asr.modelsExistOnDisk))
        let isPreparing = self.preparingModelRouteID == route.id || (isRouteActiveInSettings && (self.asr.isDownloadingModel || (self.asr.isLoadingModel && !self.asr.isAsrReady)))
        let isReady = self.isOnboardingRouteReady(route)
        let isUninstalling = self.uninstallingModelRouteID == route.id
        let areModelActionsBlocked = self.asr.isRunning || self.uninstallingModelRouteID != nil || self.preparingModelRouteID != nil || isPreparing || self.isModelPreparationInProgress
        let isBuiltInAppleModel = model == .appleSpeech || model == .appleSpeechAnalyzer
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let cardFill = isHovered
            ? Color(red: 0.042, green: 0.052, blue: 0.074)
            : Color(red: 0.030, green: 0.038, blue: 0.056)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(self.onboardingModelTitle(for: model))
                    .font(self.theme.typography.sectionTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image(systemName: "info.circle")
                    .font(self.theme.typography.sectionTitle)
                    .foregroundStyle(Color.white.opacity(0.58))
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                    .help(self.onboardingModelTooltip(for: route))
                    .accessibilityLabel(self.onboardingModelTooltip(for: route))
            }
            .frame(height: 38, alignment: .top)

            self.onboardingModelMetadataRow(badgeText: route.badgeText)

            self.onboardingModelFeaturePanel(for: model)

            Spacer(minLength: 0)

            Divider()
                .overlay(Color.white.opacity(0.10))

            HStack(spacing: 10) {
                Image(systemName: "internaldrive")
                    .font(self.theme.typography.sectionTitle)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(width: 22)

                Text("Download size")
                    .font(self.theme.typography.bodySmallStrong)
                    .foregroundStyle(Color.white.opacity(0.62))

                Spacer()

                Text(model.downloadSize)
                    .font(self.theme.typography.bodySmallStrong)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }

            if isPreparing || isUninstalling {
                HStack(spacing: 8) {
                    self.onboardingModelPreparationStatus(isUninstalling: isUninstalling)

                    if isPreparing {
                        self.onboardingModelActionButton(
                            id: "\(route.id)-cancel",
                            title: self.asr.isCancellingModelPreparation ? "Cancelling…" : "Cancel",
                            systemImage: "xmark",
                            tone: .secondary,
                            width: 104,
                            isDisabled: self.asr.isCancellingModelPreparation
                        ) {
                            self.cancelOnboardingModelPreparation()
                        }
                    }
                }
                .frame(height: 42, alignment: .center)
            } else if isDownloaded, isBuiltInAppleModel {
                self.onboardingModelActionButton(
                    id: "\(route.id)-activate",
                    title: self.onboardingModelActionButtonTitle(isPreparing: false, isDownloaded: true, isReady: isReady),
                    systemImage: isReady ? "checkmark" : "bolt.fill",
                    tone: .primary,
                    width: nil,
                    isDisabled: areModelActionsBlocked || isReady
                ) {
                    self.prepareOnboardingRoute(route)
                }
            } else if isDownloaded {
                HStack(spacing: 8) {
                    self.onboardingModelActionButton(
                        id: "\(route.id)-activate",
                        title: self.onboardingModelActionButtonTitle(isPreparing: false, isDownloaded: true, isReady: isReady),
                        systemImage: isReady ? "checkmark" : "bolt.fill",
                        tone: .primary,
                        width: 124,
                        isDisabled: areModelActionsBlocked || isReady
                    ) {
                        self.prepareOnboardingRoute(route)
                    }

                    self.onboardingModelActionButton(
                        id: "\(route.id)-uninstall",
                        title: "Delete",
                        systemImage: "trash",
                        tone: .destructive,
                        width: 124,
                        isDisabled: areModelActionsBlocked
                    ) {
                        self.uninstallOnboardingRoute(route)
                    }
                }
            } else {
                self.onboardingModelActionButton(
                    id: "\(route.id)-download-activate",
                    title: self.onboardingModelActionButtonTitle(isPreparing: false, isDownloaded: false, isReady: false),
                    systemImage: "arrow.down.circle.fill",
                    tone: .primary,
                    width: nil,
                    isDisabled: areModelActionsBlocked
                ) {
                    self.prepareOnboardingRoute(route)
                }
            }
        }
        .padding(16)
        .frame(width: 292, height: 292, alignment: .topLeading)
        .background(
            shape
                .fill(cardFill)
                .overlay(
                    shape.stroke(
                        isSelected
                            ? FluidOnboardingLandingColors.blue.opacity(isHovered ? 0.92 : 0.78)
                            : (isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.10)),
                        lineWidth: isSelected ? 1.4 : 1
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.34), radius: isHovered ? 20 : 14, x: 0, y: isHovered ? 12 : 8)
        .contentShape(shape)
        .onTapGesture {
            guard !areModelActionsBlocked else { return }
            self.selectOnboardingRoute(route)
        }
        .onHover { isHovered in
            guard enablesHover else { return }
            self.setHoveredModelRoute(isHovered ? route.id : nil)
        }
    }

    private func onboardingModelFeaturePanel(for model: SettingsStore.SpeechModel) -> some View {
        VStack(spacing: 10) {
            self.onboardingModelMetricRow(
                fillPercent: model.speedPercent,
                color: .yellow,
                secondaryColor: .orange,
                icon: "bolt.fill",
                label: "Speed"
            )

            self.onboardingModelMetricRow(
                fillPercent: model.accuracyPercent,
                color: Color.fluidGreen,
                secondaryColor: .cyan,
                icon: "target",
                label: "Accuracy"
            )
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Speed \(Int(model.speedPercent * 100)) percent. Accuracy \(Int(model.accuracyPercent * 100)) percent.")
    }

    private func onboardingModelPreparationStatus(isUninstalling: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if self.asr.isCancellingModelPreparation {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .fixedSize()

                    Text("Cancelling...")
                        .font(self.theme.typography.captionStrong)
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            } else if self.asr.isDownloadingModel,
                      self.asr.modelPreparationPhase == .downloading,
                      let progress = self.asr.downloadProgress
            {
                ProgressView(value: progress)
                    .tint(FluidOnboardingLandingColors.blue)

                HStack(spacing: 6) {
                    Text(self.asr.modelPreparationStatusText)
                        .font(self.theme.typography.captionStrong)
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .fixedSize()

                    Text(
                        isUninstalling
                            ? "Deleting..."
                            : self.asr.modelPreparationStatusText
                    )
                    .font(self.theme.typography.captionStrong)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func onboardingModelMetadataRow(badgeText: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let badgeText {
                Label(badgeText, systemImage: "checkmark.seal.fill")
                    .font(self.theme.typography.badge)
                    .foregroundStyle(Color.green.opacity(0.92))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .frame(height: badgeText == nil ? 0 : 18, alignment: .leading)
    }

    private func onboardingModelMetricRow(
        fillPercent: Double,
        color: Color,
        secondaryColor: Color,
        icon: String,
        label: String
    ) -> some View {
        let clampedFill = min(max(fillPercent, 0), 1)

        return HStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(self.theme.typography.captionStrong)
                    .foregroundStyle(color)

                Text(label)
                    .font(self.theme.typography.captionStrong)
                    .foregroundStyle(Color.white.opacity(0.66))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: 86, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.075))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * CGFloat(clampedFill)))
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.24),
                                            Color.clear,
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                }
            }
            .frame(height: 9)

            Text("\(Int(fillPercent * 100))%")
                .font(self.theme.typography.bodySmallStrong)
                .foregroundStyle(fillPercent > 0 ? color : Color.white.opacity(0.48))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .contentTransition(.numericText())
                .frame(width: 46, alignment: .trailing)
        }
        .frame(height: 18)
    }

    private func onboardingModelActionButton(
        id: String,
        title: String,
        systemImage: String,
        tone: OnboardingPillButtonTone = .primary,
        width: CGFloat?,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isHovered = self.hoveredModelActionButtonID == id && !isDisabled

        return self.onboardingPillButton(
            configuration: OnboardingPillButtonConfiguration(
                title: title,
                systemImage: systemImage,
                tone: tone,
                width: width,
                height: 36,
                fontSize: 12,
                iconSize: 14,
                isHovered: isHovered,
                isEnabled: !isDisabled
            ),
            action: action
        ) { isHovered in
            self.setHoveredModelActionButton(isHovered ? id : nil)
        }
    }

    private func onboardingPillButton(
        configuration: OnboardingPillButtonConfiguration,
        action: @escaping () -> Void,
        onHover: @escaping (Bool) -> Void
    ) -> some View {
        let shape = Capsule()
        let accentColor: Color = configuration.tone == .destructive ? .red : FluidOnboardingLandingColors.blue
        let isFilledTone = configuration.tone == .primary || configuration.tone == .destructive
        let fillColor: Color = {
            switch configuration.tone {
            case .primary, .destructive:
                return accentColor.opacity(configuration.isEnabled ? 1 : 0.34)
            case .secondary:
                return Color.white.opacity(configuration.isEnabled ? (configuration.isHovered ? 0.11 : 0.07) : 0.045)
            }
        }()
        let borderColor: Color = {
            switch configuration.tone {
            case .primary, .destructive:
                return Color.white.opacity(configuration.isHovered && configuration.isEnabled ? 0.30 : 0)
            case .secondary:
                return configuration.isHovered && configuration.isEnabled ? FluidOnboardingLandingColors.blue.opacity(0.30) : Color.white.opacity(0.07)
            }
        }()
        let foregroundOpacity: Double = configuration.isEnabled ? (isFilledTone ? 1.0 : (configuration.isHovered ? 0.94 : 0.78)) : 0.42
        let shadowOpacity: Double = {
            guard configuration.isEnabled else { return 0 }
            switch configuration.tone {
            case .primary, .destructive:
                return configuration.isHovered ? 0.56 : 0.26
            case .secondary:
                return configuration.isHovered ? 0.08 : 0
            }
        }()
        let ringOpacity: Double = configuration.isHovered && configuration.isEnabled ? 0.50 : 0

        return Button {
            action()
        } label: {
            HStack(spacing: configuration.systemImage == nil ? 0 : 8) {
                if let systemImage = configuration.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: configuration.iconSize, weight: .bold))
                }

                Text(configuration.title)
                    .font(.system(size: configuration.fontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(.white.opacity(foregroundOpacity))
            .frame(width: configuration.width, height: configuration.height)
            .frame(maxWidth: configuration.width == nil ? .infinity : nil)
            .background(
                shape
                    .fill(fillColor)
                    .overlay(shape.fill(Color.white.opacity(isFilledTone && configuration.isHovered && configuration.isEnabled ? 0.10 : 0)))
                    .overlay(shape.stroke(borderColor, lineWidth: configuration.isHovered && configuration.isEnabled ? 1.2 : 1))
                    .overlay(
                        shape
                            .stroke(accentColor.opacity(ringOpacity), lineWidth: configuration.isHovered && configuration.isEnabled ? 1.4 : 1)
                            .padding(-2)
                    )
                    .shadow(color: accentColor.opacity(shadowOpacity), radius: configuration.isHovered && configuration.isEnabled ? 16 : 9, x: 0, y: configuration.isHovered && configuration.isEnabled ? 6 : 3)
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .contentShape(shape)
        .disabled(!configuration.isEnabled)
        .onHover { isHovered in
            onHover(isHovered && configuration.isEnabled)
        }
    }

    private func onboardingModelTooltip(for route: VoiceEngineLanguageRoute) -> String {
        let model = route.model
        return "\(self.onboardingModelSubtitle(for: model)) - \(model.downloadSize)\n\(model.cardDescription)"
    }

    private func onboardingModelTitle(for model: SettingsStore.SpeechModel) -> String {
        model.humanReadableName
    }

    private func onboardingModelSubtitle(for model: SettingsStore.SpeechModel) -> String {
        switch model {
        case .parakeetTDT:
            return "Parakeet v3"
        case .parakeetTDTv2:
            return "Parakeet v2"
        case .parakeetRealtime:
            return "Parakeet Flash"
        case .cohereTranscribeSixBit:
            return "Cohere"
        case .nemotronStreaming:
            return "Nemotron Streaming"
        case .nemotronOffline:
            return "Nemotron Offline"
        case .whisperTiny, .whisperBase, .whisperSmall, .whisperMedium, .whisperLarge:
            return "Whisper"
        default:
            return model.displayName
        }
    }

    private func permissionRow(
        stepNumber: Int,
        title: String,
        subtitle: String,
        systemImage: String,
        isReady: Bool,
        statusTitle: String? = nil,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let resolvedStatusTitle = statusTitle ?? (isReady ? "Ready" : "Needed")

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isReady ? Color.green.opacity(0.16) : FluidOnboardingLandingColors.blue.opacity(0.12))
                    .frame(width: 46, height: 46)

                if isReady {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.green.opacity(0.92))
                } else {
                    VStack(spacing: 1) {
                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .bold))

                        Text("\(stepNumber)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(FluidOnboardingLandingColors.blue)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(resolvedStatusTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isReady ? Color.green.opacity(0.92) : FluidOnboardingLandingColors.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill((isReady ? Color.green : FluidOnboardingLandingColors.blue).opacity(0.12))
                        )
                }

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer()

            if !isReady {
                let actionIcon = ["Open Settings", "Show Guide"].contains(actionTitle) ? "arrow.up.right" : "hand.tap.fill"
                let buttonID = "permission-\(stepNumber)"

                self.onboardingPillButton(
                    configuration: OnboardingPillButtonConfiguration(
                        title: actionTitle,
                        systemImage: actionIcon,
                        tone: .primary,
                        width: 132,
                        height: 36,
                        fontSize: 12,
                        iconSize: 10,
                        isHovered: self.hoveredPermissionButtonID == buttonID,
                        isEnabled: true
                    ),
                    action: action
                ) { isHovered in
                    self.setHoveredPermissionButton(isHovered ? buttonID : nil)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 88)
        .background(
            shape
                .fill(Color.white.opacity(isReady ? 0.045 : 0.070))
                .overlay(
                    shape.stroke(
                        isReady ? Color.green.opacity(0.18) : FluidOnboardingLandingColors.blue.opacity(0.26),
                        lineWidth: 1
                    )
                )
        )
    }

    private func isRouteModelAndLanguageSettingsSelected(_ route: VoiceEngineLanguageRoute) -> Bool {
        guard route.model == self.settings.selectedSpeechModel else {
            return false
        }

        switch route.binding {
        case .automatic, .whisper:
            return true
        case let .appleSpeech(localeIdentifier):
            return self.settings.selectedAppleSpeechLocaleIdentifier == localeIdentifier
        case let .cohere(language):
            return self.settings.selectedCohereLanguage == language
        case let .nemotron(language):
            return self.settings.selectedNemotronLanguage == language
        }
    }

    private func selectOnboardingRoute(_ route: VoiceEngineLanguageRoute) {
        let oldModel = self.settings.selectedSpeechModel
        let oldAppleSpeechLocaleIdentifier = self.settings.selectedAppleSpeechLocaleIdentifier
        let oldCohereLanguage = self.settings.selectedCohereLanguage
        let oldNemotronLanguage = self.settings.selectedNemotronLanguage

        self.selectedModelRouteID = route.id
        VoiceEngineLanguageCatalog.apply(route, to: self.settings)

        let languageChanged: Bool
        switch route.binding {
        case .automatic, .whisper:
            languageChanged = false
        case .appleSpeech:
            languageChanged = oldAppleSpeechLocaleIdentifier != self.settings.selectedAppleSpeechLocaleIdentifier
        case .cohere:
            languageChanged = oldCohereLanguage != self.settings.selectedCohereLanguage
        case .nemotron:
            languageChanged = oldNemotronLanguage != self.settings.selectedNemotronLanguage
        }

        if oldModel != self.settings.selectedSpeechModel || languageChanged {
            self.resetTryoutValidationForSetupChange()
            self.asr.resetTranscriptionProvider()
        }
    }

    private func setHoveredModelRoute(_ routeID: String?) {
        guard self.hoveredModelRouteID != routeID else { return }
        if self.reduceMotion {
            self.hoveredModelRouteID = routeID
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                self.hoveredModelRouteID = routeID
            }
        }
    }

    private func setHoveredModelActionButton(_ buttonID: String?) {
        guard self.hoveredModelActionButtonID != buttonID else { return }
        if self.reduceMotion {
            self.hoveredModelActionButtonID = buttonID
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                self.hoveredModelActionButtonID = buttonID
            }
        }
    }

    private func setHoveredPermissionButton(_ buttonID: String?) {
        guard self.hoveredPermissionButtonID != buttonID else { return }
        if self.reduceMotion {
            self.hoveredPermissionButtonID = buttonID
        } else {
            withAnimation(.easeOut(duration: 0.14)) {
                self.hoveredPermissionButtonID = buttonID
            }
        }
    }

    private func togglePrimaryShortcutRecording() {
        guard !self.asr.isRunning else { return }
        if self.isRecordingPrimaryShortcut {
            self.activeShortcutRecordingTarget = nil
            self.shortcutRecordingMessage = nil
        } else {
            self.shortcutRecordingMessage = nil
            self.activeShortcutRecordingTarget = .primaryDictation(.replace(0))
        }
    }

    private func resetTryoutValidationForSetupChange() {
        self.settings.onboardingPlaygroundValidated = false
        self.settings.onboardingPlaygroundSkipped = false
        self.settings.playgroundUsed = false
        self.asr.finalText = ""
    }

    private func handleMicrophoneAction() {
        if self.asr.micStatus == .notDetermined {
            self.asr.requestMicAccess()
        } else {
            self.asr.openSystemSettingsForMic()
        }
    }

    private func skipPlayground() {
        guard self.canSkipSetup else { return }
        self.settings.onboardingPlaygroundSkipped = true
        self.finishSetup(outcome: .skipped)
    }

    private func goBack() {
        self.activeShortcutRecordingTarget = nil
        self.shortcutRecordingMessage = nil
        self.currentStep = max(0, self.step.rawValue - 1)
    }

    private func goNext(outcome: AnalyticsOnboardingOutcome = .continued) {
        self.completeCurrentStep(outcome: outcome)
        self.activeShortcutRecordingTarget = nil
        self.shortcutRecordingMessage = nil
        self.currentStep = min(Step.allCases.count - 1, self.currentStep + 1)
    }

    private func handlePrimaryAction() {
        guard !self.isModelPreparationInProgress else {
            return
        }

        if self.step == .language, let route = self.selectedOnboardingRoute {
            self.selectOnboardingRoute(route)
        }

        if self.step == .playground {
            guard self.canContinue else { return }
            self.finishSetup(outcome: .completed)
            return
        }
        self.goNext()
    }

    /// The playground is the last step. MouthKeys is straight voice to text, so setup
    /// never asks about AI; it records the choice as skipped unless a provider is already set.
    private func finishSetup(outcome: AnalyticsOnboardingOutcome) {
        if !DictationAIPostProcessingGate.isProviderConfigured() {
            self.markAISkipped()
        }
        let origin = self.settings.analyticsOnboardingOrigin
        self.finishOnboardingAtGettingStarted()
        self.completeCurrentStep(
            outcome: outcome,
            origin: origin,
            completesFlow: self.settings.onboardingCompleted
        )
    }

    private func completeCurrentStep(
        outcome: AnalyticsOnboardingOutcome,
        origin: AnalyticsOnboardingOrigin? = nil,
        completesFlow: Bool = false
    ) {
        AnalyticsService.shared.recordOnboardingStepCompleted(
            self.step.analyticsStep,
            outcome: outcome,
            origin: origin ?? self.settings.analyticsOnboardingOrigin,
            completesFlow: completesFlow
        )
    }
}

private extension OnboardingFlowView {
    var orderedOnboardingInputDevices: [AudioDevice.Device] {
        let devicesByUID = Dictionary(
            self.onboardingInputDevices.map { ($0.uid, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        var ordered = self.settings.microphonePriority.compactMap { devicesByUID[$0.uid] }
        let knownUIDs = Set(ordered.map(\.uid))
        ordered.append(contentsOf: self.onboardingInputDevices.filter { !knownUIDs.contains($0.uid) })
        return ordered
    }

    func isOnboardingRouteSelected(_ route: VoiceEngineLanguageRoute) -> Bool {
        self.selectedOnboardingRoute?.id == route.id || self.isRouteSelectedInSettings(route)
    }

    func isRouteSelectedInSettings(_ route: VoiceEngineLanguageRoute) -> Bool {
        guard route.model == self.settings.selectedSpeechModel else {
            return false
        }

        switch route.binding {
        case .automatic, .whisper:
            return self.settings.onboardingSelectedLanguageID == route.language.id
        case let .appleSpeech(localeIdentifier):
            return self.settings.selectedAppleSpeechLocaleIdentifier == localeIdentifier
        case let .cohere(language):
            return self.settings.selectedCohereLanguage == language
        case let .nemotron(language):
            return self.settings.selectedNemotronLanguage == language
        }
    }

    func refreshOnboardingMicrophoneAuthorization(checkModels: Bool = false) {
        Task { @MainActor in
            await AudioStartupGate.shared.scheduleOpenAfterInitialUISettled()
            await AudioStartupGate.shared.waitUntilOpen()
            guard self.isOnboardingFlowVisible else { return }

            self.asr.micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            if self.step == .permissions, self.isMicrophoneReady {
                self.refreshOnboardingMicrophones(startPreview: true)
            }
            if checkModels {
                await self.asr.checkIfModelsExistAsync()
            }
        }
    }

    func refreshOnboardingMicrophones(startPreview: Bool) {
        guard self.isOnboardingFlowVisible, !TestHostQuietMode.isActive else { return }
        self.onboardingMicrophoneRefreshGeneration &+= 1
        let generation = self.onboardingMicrophoneRefreshGeneration
        let suppressedUIDs = self.settings.suppressedMicrophoneUIDs

        Task { @MainActor in
            await AudioStartupGate.shared.scheduleOpenAfterInitialUISettled()
            await AudioStartupGate.shared.waitUntilOpen()
            guard generation == self.onboardingMicrophoneRefreshGeneration,
                  self.isOnboardingFlowVisible,
                  self.step == .permissions,
                  self.isMicrophoneReady
            else { return }

            DispatchQueue.global(qos: .userInitiated).async {
                let inputs = AudioDevice.listInputDevicesRefreshingLiveness()
                let defaultInputUID = AudioDevice.getDefaultInputDevice()?.uid
                let usableInputs = inputs.filter { device in
                    suppressedUIDs.contains(device.uid) == false && AudioDevice.isInputDeviceUsable(device)
                }

                DispatchQueue.main.async {
                    guard generation == self.onboardingMicrophoneRefreshGeneration,
                          self.isOnboardingFlowVisible,
                          self.step == .permissions,
                          self.isMicrophoneReady
                    else { return }

                    let selectedInput = self.appServices.microphonePreferenceCoordinator
                        .reconcileMicrophoneSelection(
                            availableInputs: inputs,
                            defaultInputUID: defaultInputUID
                        )
                    self.onboardingInputDevices = usableInputs
                    self.selectedOnboardingInputUID = selectedInput?.uid ?? usableInputs.first?.uid ?? ""

                    if startPreview {
                        self.startOnboardingMicrophonePreviewIfNeeded()
                    }
                }
            }
        }
    }

    func selectOnboardingMicrophone(uid: String) {
        guard let device = self.onboardingInputDevices.first(where: { $0.uid == uid }) else {
            return
        }

        self.settings.recordInputDeviceSelection(device.uid, name: device.name)
        self.selectedOnboardingInputUID = device.uid
        self.onboardingMicrophoneLevel = 0
        self.lastOnboardingMicrophoneLevelUpdate = 0
        self.startOnboardingMicrophonePreviewIfNeeded(forceRestart: true)
    }

    func startOnboardingMicrophonePreviewIfNeeded(forceRestart: Bool = false) {
        guard self.step == .permissions,
              self.isOnboardingFlowVisible,
              self.isMicrophoneReady,
              self.selectedOnboardingInputUID.isEmpty == false
        else { return }
        if forceRestart == false,
           self.previewedOnboardingInputUID == self.selectedOnboardingInputUID,
           self.asr.isMicrophonePreviewActive || self.microphonePreviewTask != nil
        {
            return
        }

        let selectedUID = self.selectedOnboardingInputUID
        self.microphonePreviewGeneration &+= 1
        let generation = self.microphonePreviewGeneration
        self.microphonePreviewTask?.cancel()
        self.previewedOnboardingInputUID = selectedUID
        self.microphonePreviewTask = Task { @MainActor in
            await self.asr.stopMicrophonePreview(retainPreparedCapture: false)
            guard generation == self.microphonePreviewGeneration,
                  Task.isCancelled == false,
                  self.step == .permissions,
                  self.isMicrophoneReady,
                  self.selectedOnboardingInputUID == selectedUID
            else {
                if generation == self.microphonePreviewGeneration {
                    self.microphonePreviewTask = nil
                }
                return
            }

            await self.asr.startMicrophonePreview()
            guard generation == self.microphonePreviewGeneration,
                  Task.isCancelled == false,
                  self.step == .permissions,
                  self.selectedOnboardingInputUID == selectedUID
            else {
                if generation == self.microphonePreviewGeneration {
                    await self.asr.stopMicrophonePreview()
                    self.microphonePreviewTask = nil
                }
                return
            }
            if self.asr.isMicrophonePreviewActive == false {
                self.previewedOnboardingInputUID = nil
            }
            self.microphonePreviewTask = nil
        }
    }

    func stopOnboardingMicrophonePreview() {
        self.microphonePreviewGeneration &+= 1
        let generation = self.microphonePreviewGeneration
        self.microphonePreviewTask?.cancel()
        self.microphonePreviewTask = Task { @MainActor in
            await self.asr.stopMicrophonePreview()
            guard generation == self.microphonePreviewGeneration else { return }
            self.onboardingMicrophoneLevel = 0
            self.lastOnboardingMicrophoneLevelUpdate = 0
            self.previewedOnboardingInputUID = nil
            self.microphonePreviewTask = nil
        }
    }

    func suspendOnboardingMicrophonePreviewForDictation() {
        self.microphonePreviewGeneration &+= 1
        self.microphonePreviewTask?.cancel()
        self.microphonePreviewTask = nil
        self.onboardingMicrophoneLevel = 0
        self.lastOnboardingMicrophoneLevelUpdate = 0
        self.previewedOnboardingInputUID = nil
    }
}

private struct OnboardingMicrophoneSetupPanel: View {
    @Environment(\.datasheetPalette) private var palette

    let devices: [AudioDevice.Device]
    let selectedUID: String
    let level: CGFloat
    let errorMessage: String?
    let onSelect: (String) -> Void

    private var selectedDeviceName: String {
        self.devices.first(where: { $0.uid == self.selectedUID })?.name ?? "Select a microphone"
    }

    private var statusText: String {
        guard let errorMessage = self.errorMessage, !errorMessage.isEmpty else { return "Input level" }
        return errorMessage
    }

    private var hasPreviewError: Bool {
        self.errorMessage?.isEmpty == false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Select your microphone")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.palette.text2)

                Spacer(minLength: 8)

                if self.devices.isEmpty {
                    Text("No microphone available")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.accent)
                } else {
                    DatasheetPicker(title: "Input microphone", value: self.selectedDeviceName, minimumWidth: 248) {
                        ForEach(self.devices) { device in
                            Button {
                                self.onSelect(device.uid)
                            } label: {
                                if device.uid == self.selectedUID {
                                    Label(device.name, systemImage: "checkmark")
                                } else {
                                    Text(device.name)
                                }
                            }
                        }
                    }
                    .accessibilityHint("Moves the selected microphone to first in MouthKeys priority")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 46)

            Rectangle()
                .fill(self.palette.ruleSoft)
                .frame(height: 1)

            HStack(spacing: 12) {
                DatasheetStatusSquare(
                    kind: self.hasPreviewError ? .orange : .ink,
                    size: 5
                )

                Text(self.statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(self.hasPreviewError ? self.palette.accent : self.palette.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer()

                DatasheetMeter(
                    value: Int(ceil(min(max(self.level, 0), 1) * 16)),
                    count: 16,
                    segmentWidth: 5,
                    segmentHeight: 14
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Microphone input level")
                .accessibilityValue("\(Int((self.level * 100).rounded())) percent")

                Text("\(Int((self.level * 100).rounded()))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 34, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
        }
        .frame(maxWidth: .infinity)
        .background(self.palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
    }
}
