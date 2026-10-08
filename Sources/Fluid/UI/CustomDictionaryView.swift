//
//  CustomDictionaryView.swift
//  fluid
//
//  Custom dictionary for correcting commonly misheard words.
//  Created: 2025-12-21
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// This legacy screen still owns several dictionary editors; split them into standalone views incrementally.
// swiftlint:disable:next type_body_length
struct CustomDictionaryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.datasheetPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appServices: AppServices

    @State private var entries: [SettingsStore.CustomDictionaryEntry] = SettingsStore.shared.customDictionaryEntries
    @State private var boostTerms: [ParakeetVocabularyStore.VocabularyConfig.Term] = []
    @State private var editingEntry: SettingsStore.CustomDictionaryEntry?

    @State private var boostStatusMessage = "Add custom words for better Parakeet recognition."
    @State private var boostHasError = false
    @State private var automaticDictionaryLearningEnabled = SettingsStore.shared.automaticDictionaryLearningEnabled
    @State private var vocabBoostingEnabled: Bool = SettingsStore.shared.vocabularyBoostingEnabled
    @State private var isBoostWordEditorPresented = false
    @State private var editingBoostTermIndex: Int?
    @State private var boostTermText = ""
    @State private var boostTermStrength: BoostStrengthPreset = .balanced

    @State private var trainingReplacement = ""
    @State private var trainingVariants: [String] = []
    @State private var pronunciationMatchingEnabled = SettingsStore.shared.pronunciationMatchingEnabled
    @State private var trainingPronunciationEnrollments: [PronunciationEnrollmentCapture] = []
    @State private var trainingSampleCount = 0
    @State private var lastTrainingOutput = ""
    @State private var lastTrainingOutputIsCovered = false
    @State private var consecutiveCoveredCaptures = 0
    @State private var trainingStatusMessage = "Type the correct text."
    @State private var trainingHasError = false
    @State private var isTrainingActive = false
    @State private var isTrainingStarting = false
    @State private var isTrainingRecording = false
    @State private var trainingStopRequestedDuringStart = false
    @State private var isTrainingProcessing = false
    @State private var isAutomaticTrainingEnabled = false
    @State private var isTrainedReplacementButtonHovered = false
    @State private var isTrainedReplacementGlowExpanded = false
    @State private var replacementConfirmation: ReplacementConfirmation?
    @State private var composerMode: DictionaryComposerMode = .train
    @State private var manualTriggerDraft = ""
    @State private var manualReplacement = ""
    @State private var punctuationAutoConvertEnabled = SettingsStore.shared.autoConvertPunctuationEnabled
    @State private var punctuationPrefix = SettingsStore.shared.punctuationDictionaryPrefix
    @State private var punctuationRules = SettingsStore.shared.punctuationDictionaryRules
    @State private var formattingActionRules = SettingsStore.shared.spokenFormattingActionRules
    @State private var editingFormattingAction: SettingsStore.SpokenFormattingAction?
    @State private var formattingActionAliasesText = ""
    @State private var isFormattingResetAlertPresented = false
    @State private var isPunctuationInfoExpanded = false
    @State private var isPunctuationRuleEditorPresented = false
    @State private var editingPunctuationRuleID: UUID?
    @State private var punctuationAliasesText = ""
    @State private var punctuationSymbolText = ""

    init(datasheetRenderFixture: Bool = false) {
        guard datasheetRenderFixture else { return }

        self._entries = State(initialValue: [
            .init(triggers: ["mouth keys", "mouse keys"], replacement: "MouthKeys"),
            .init(triggers: ["c eleven", "see eleven"], replacement: "c11"),
            .init(triggers: ["gregorovitch"], replacement: "Gregorovich"),
        ])
        self._boostTerms = State(initialValue: [
            .init(text: "MouthKeys", weight: 0.8),
            .init(text: "Parakeet", weight: 0.6),
        ])
        self._automaticDictionaryLearningEnabled = State(initialValue: true)
        self._vocabBoostingEnabled = State(initialValue: true)
        self._trainingReplacement = State(initialValue: "Gregorovich")
        self._trainingVariants = State(initialValue: ["Gregorovitch"])
        self._pronunciationMatchingEnabled = State(initialValue: false)
        self._trainingSampleCount = State(initialValue: 2)
        self._lastTrainingOutput = State(initialValue: "Gregorovich")
        self._lastTrainingOutputIsCovered = State(initialValue: true)
        self._consecutiveCoveredCaptures = State(initialValue: 2)
        self._trainingStatusMessage = State(initialValue: "Keep going until the readiness meter reaches 3/3.")
        self._punctuationAutoConvertEnabled = State(initialValue: true)
        self._punctuationPrefix = State(initialValue: SettingsStore.defaultPunctuationDictionaryPrefix)
        self._punctuationRules = State(initialValue: Array(SettingsStore.defaultPunctuationDictionaryRules.prefix(8)))
        self._formattingActionRules = State(initialValue: SettingsStore.defaultSpokenFormattingActionRules)
    }

    private var normalizedTrainingReplacement: String {
        self.trainingReplacement.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activePronunciationMatching: Bool {
        self.pronunciationMatchingEnabled && SettingsStore.shared.selectedSpeechModel.supportsPronunciationMatching
    }

    private var pronunciationMatchingBinding: Binding<Bool> {
        Binding(
            get: { self.activePronunciationMatching },
            set: { self.pronunciationMatchingEnabled = $0 }
        )
    }

    private var trainingTargetReference: String {
        DictionaryTrainingCopy.target(for: self.normalizedTrainingReplacement)
    }

    private var composerModeDetail: String {
        DictionaryTrainingCopy.composerDetail(mode: self.composerMode, target: self.trainingTargetReference)
    }

    private var canUseTrainingRecorderButton: Bool {
        if self.isAutomaticTrainingEnabled {
            return true
        }
        guard !self.trainingStopRequestedDuringStart, !self.isTrainingProcessing else { return false }
        return self.isTrainingRecording || self.canRecordTrainingSample || self.canRetryTrainingAfterMaximum
    }

    private var trainingRecorderIsStop: Bool {
        self.isAutomaticTrainingEnabled || self.isTrainingRecording || self.isTrainingStarting
    }

    private var trainingRecorderButtonTitle: String {
        if self.trainingRecorderIsStop {
            return "Stop"
        }
        return self.canRetryTrainingAfterMaximum ? "Try Again" : "Start"
    }

    private var trainingFinalOutputIsReady: Bool {
        if self.activePronunciationMatching {
            return !self.trainingAlreadyCorrectWithoutReplacement &&
                self.trainingPronunciationEnrollments.count >= CustomDictionaryTrainingMerge.readyCoveredCount
        }
        return !self.trainingAlreadyCorrectWithoutReplacement &&
            self.trainingOutputIsCovered &&
            self.consecutiveCoveredCaptures >= CustomDictionaryTrainingMerge.readyCoveredCount
    }

    private var trainingAlreadyCorrectWithoutReplacement: Bool {
        if self.activePronunciationMatching {
            return self.trainingVariants.isEmpty &&
                !self.lastTrainingOutput.isEmpty &&
                self.lastTrainingOutput.caseInsensitiveCompare(self.normalizedTrainingReplacement) == .orderedSame &&
                self.trainingPronunciationEnrollments.count >= CustomDictionaryTrainingMerge.readyCoveredCount
        }
        return self.trainingVariants.isEmpty &&
            self.trainingOutputIsCovered &&
            !self.lastTrainingOutput.isEmpty &&
            self.lastTrainingOutput.caseInsensitiveCompare(self.normalizedTrainingReplacement) == .orderedSame &&
            self.consecutiveCoveredCaptures >= CustomDictionaryTrainingMerge.readyCoveredCount
    }

    private var trainingReadinessProgress: Int {
        if self.activePronunciationMatching {
            return min(self.trainingPronunciationEnrollments.count, CustomDictionaryTrainingMerge.readyCoveredCount)
        }
        guard !self.trainingAlreadyCorrectWithoutReplacement else {
            return CustomDictionaryTrainingMerge.readyCoveredCount
        }
        guard self.trainingOutputIsCovered else { return 0 }
        return min(self.consecutiveCoveredCaptures, CustomDictionaryTrainingMerge.readyCoveredCount)
    }

    private var trainingOutputIsCovered: Bool {
        if self.activePronunciationMatching {
            return !self.trainingPronunciationEnrollments.isEmpty
        }
        return self.lastTrainingOutputIsCovered
    }

    private var trainingFinalOutputText: String {
        guard !self.lastTrainingOutput.isEmpty else { return "Record to check" }
        return self.trainingOutputIsCovered ? self.normalizedTrainingReplacement : self.lastTrainingOutput
    }

    private var canRecordTrainingSample: Bool {
        !self.normalizedTrainingReplacement.isEmpty &&
            !self.isTrainingProcessing &&
            !self.asr.isRunning &&
            self.trainingSampleCount < CustomDictionaryTrainingMerge.maxSamples
    }

    private var canRetryTrainingAfterMaximum: Bool {
        !self.normalizedTrainingReplacement.isEmpty &&
            !self.trainingFinalOutputIsReady &&
            !self.trainingAlreadyCorrectWithoutReplacement &&
            !self.isTrainingRecording &&
            !self.isTrainingProcessing &&
            !self.asr.isRunning &&
            self.trainingSampleCount >= CustomDictionaryTrainingMerge.maxSamples
    }

    private var canAddTrainedReplacement: Bool {
        !self.normalizedTrainingReplacement.isEmpty &&
            (!self.trainingVariants.isEmpty || !self.trainingPronunciationEnrollments.isEmpty) &&
            !self.isTrainingRecording &&
            !self.isTrainingProcessing &&
            self.trainingFinalOutputIsReady
    }

    private var shouldPulseTrainedReplacementButton: Bool {
        self.shouldEmphasizeTrainedReplacementButton &&
            !self.isTrainedReplacementButtonHovered &&
            !self.reduceMotion
    }

    private var manualTriggers: [String] {
        CustomDictionaryManualEntry.normalizedDraftTriggers(self.manualTriggerDraft)
    }

    private var manualDuplicateTriggers: [String] {
        self.manualTriggers.filter { self.allExistingTriggers().contains($0) }
    }

    private var sanitizedManualReplacement: String {
        CustomDictionaryManualEntry.sanitizedReplacement(self.manualReplacement)
    }

    private var canAddManualReplacement: Bool {
        !self.manualTriggers.isEmpty &&
            !self.sanitizedManualReplacement.isEmpty &&
            self.manualDuplicateTriggers.isEmpty
    }

    private var punctuationEditorTitle: String {
        self.editingPunctuationRuleID == nil ? "Add Rule" : "Edit Rule"
    }

    private var normalizedPunctuationAliases: [String] {
        SettingsStore.PunctuationDictionaryRule.normalizedAliases(
            self.punctuationAliasesText.components(separatedBy: .newlines)
        )
    }

    private var normalizedPunctuationSymbol: String? {
        SettingsStore.PunctuationDictionaryRule.normalizedSymbol(self.punctuationSymbolText)
    }

    private var canSavePunctuationRule: Bool {
        !self.normalizedPunctuationAliases.isEmpty && self.normalizedPunctuationSymbol != nil
    }

    private var punctuationPreviewPrefix: String {
        SettingsStore.normalizedPunctuationDictionaryPrefix(self.punctuationPrefix) ?? SettingsStore.defaultPunctuationDictionaryPrefix
    }

    private var boostEditorTitle: String {
        self.editingBoostTermIndex == nil ? "Add Word" : "Edit Word"
    }

    private var normalizedBoostTermText: String {
        self.boostTermText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isBoostTermDuplicate: Bool {
        self.existingBoostTerms(excludingIndex: self.editingBoostTermIndex)
            .contains(self.normalizedBoostTermText.lowercased())
    }

    private var canSaveBoostTerm: Bool {
        !self.normalizedBoostTermText.isEmpty && !self.isBoostTermDuplicate
    }



    var body: some View {
        self.datasheetScreenContent
        .dismissTextFocusOnBackgroundTap()
        .sheet(item: self.$editingEntry) { entry in
            EditDictionaryEntrySheet(
                entry: entry,
                existingTriggers: self.allExistingTriggers(excluding: entry.id)
            ) { updatedEntry in
                if let index = self.entries.firstIndex(where: { $0.id == updatedEntry.id }) {
                    self.entries[index] = updatedEntry
                    self.saveEntries()
                    Task {
                        if PronunciationProfileEditPolicy.shouldDiscardProfile(
                            previousReplacement: entry.replacement,
                            updatedReplacement: updatedEntry.replacement
                        ) {
                            try? await PronunciationDictionaryStore.shared.delete(dictionaryEntryID: updatedEntry.id)
                        } else {
                            try? await PronunciationDictionaryStore.shared.updateLabel(
                                dictionaryEntryID: updatedEntry.id,
                                label: updatedEntry.replacement
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            self.entries = SettingsStore.shared.customDictionaryEntries
            self.loadBoostTerms()
            self.automaticDictionaryLearningEnabled = SettingsStore.shared.automaticDictionaryLearningEnabled
            self.pronunciationMatchingEnabled = SettingsStore.shared.pronunciationMatchingEnabled
            if !SettingsStore.shared.selectedSpeechModel.supportsPronunciationMatching {
                self.pronunciationMatchingEnabled = false
                SettingsStore.shared.pronunciationMatchingEnabled = false
            }
            self.punctuationAutoConvertEnabled = SettingsStore.shared.autoConvertPunctuationEnabled
            self.formattingActionRules = SettingsStore.shared.spokenFormattingActionRules
        }
        .onReceive(NotificationCenter.default.publisher(for: .parakeetVocabularyDidChange)) { _ in
            self.entries = SettingsStore.shared.customDictionaryEntries
        }
        .onDisappear {
            self.isAutomaticTrainingEnabled = false
            DictionaryTrainingEndpointMonitor.shared.stop()
            self.savePunctuationDictionaryPrefix()
            self.dismissBoostTermEditor()
            guard self.isTrainingRecording else { return }
            Task { @MainActor in
                await self.stopTrainingSample()
            }
        }
    }

    var datasheetScreenContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                self.pageHeader
                self.trainReplacementSection
                self.yourDictionarySection
                self.punctuationDictionarySection
                self.aiPostProcessingSection
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .overlay {
            if let confirmation = self.replacementConfirmation {
                ReplacementConfirmationToast(confirmation: confirmation)
                    .padding(self.theme.metrics.spacing.xl)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Page Header

    private var pageHeader: some View {
        DatasheetSheetHeader(
            placard: "03 / Configure",
            title: "Custom Dictionary",
            lede: "Correct recurring mistakes and teach the voice engine the words you use."
        ) {
            HStack(spacing: self.theme.metrics.spacing.sm) {
                self.automaticLearningToggle
                self.headerAction("Import", icon: "square.and.arrow.down", action: self.importDictionary)
                self.headerAction("Export", icon: "square.and.arrow.up", action: self.exportDictionary)
            }
        }
    }

    private func headerAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(self.palette.text)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var automaticLearningToggle: some View {
        HStack(spacing: 8) {
            Text("Auto-learn")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)
            Toggle("Auto-learn words while typing", isOn: self.$automaticDictionaryLearningEnabled)
                .labelsHidden()
                .toggleStyle(DatasheetToggleStyle())
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        .onChange(of: self.automaticDictionaryLearningEnabled) { _, newValue in
            SettingsStore.shared.automaticDictionaryLearningEnabled = newValue
            if !newValue {
                AutomaticDictionaryCorrectionTracker.shared.cancel()
            }
        }
        .help("Notice corrections to recent dictation and show Train by Voice suggestions.")
    }

    private func settingsIconTile(systemName: String) -> some View {
        ZStack {
            Rectangle()
                .fill(self.palette.surface)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(self.palette.text)
        }
        .frame(width: 34, height: 34)
    }

    // MARK: - Teach Words

    private var trainReplacementSection: some View {
        DatasheetSection(
            letter: "A",
            title: "Teach Words",
            note: "Show MouthKeys the right spelling, by voice or by typing.",
            topSpacing: 0
        ) {
            VStack(alignment: .leading, spacing: 12) {
                self.dictionaryComposerModePicker

                Group {
                    switch self.composerMode {
                    case .train:
                        self.trainReplacementComposer
                    case .manual:
                        self.manualReplacementComposer
                    }
                }
                .frame(minHeight: 315, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dictionaryComposerModePicker: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.sm) {
            self.dictionaryComposerModeSegmented

            Text(self.composerModeDetail)
                .font(.system(size: 12))
                .foregroundStyle(self.palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dictionaryComposerModeSegmented: some View {
        DatasheetSegmented(
            selection: self.$composerMode,
            choices: [
                .init(value: .train, title: "Train by Voice"),
                .init(value: .manual, title: "Add Manually"),
            ],
            cellWidth: 148
        )
        .disabled(self.isTrainingRecording || self.isTrainingProcessing)
        .onChange(of: self.composerMode) { _, mode in
            self.selectComposerMode(mode)
        }
    }

    private var trainReplacementComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                TextField("Type the correct text, e.g. MouthKeys", text: self.$trainingReplacement)
                    .dictionaryInputChrome()
                    .disabled(self.isTrainingRecording || self.isTrainingProcessing)
                    .onChange(of: self.trainingReplacement) { oldValue, newValue in
                        self.handleTrainingReplacementChange(oldValue: oldValue, newValue: newValue)
                    }
                    .frame(maxWidth: .infinity)

                self.voiceMatchingSettingsRow
                    .frame(width: 285, alignment: .topLeading)
            }

            self.trainingRecorderPanel
            self.trainingFooter

            Button {
                Task { await self.addTrainedReplacement() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: self.trainingAlreadyCorrectWithoutReplacement ? "checkmark" : "plus")
                    Text(self.trainedReplacementButtonTitle)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(self.palette.invForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(self.palette.invBackground)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(!self.canAddTrainedReplacement)
            .opacity(self.canAddTrainedReplacement ? 1 : 0.62)
            .overlay(self.trainedReplacementButtonReadyOutline)
            .onHover { self.isTrainedReplacementButtonHovered = $0 }
            .onAppear { self.updateTrainedReplacementGlow() }
            .onChange(of: self.shouldPulseTrainedReplacementButton) { _, _ in
                self.updateTrainedReplacementGlow()
            }
        }
        .task {
            await DictionaryTrainingEndpointMonitor.shared.prepare()
        }
    }

    private var trainedReplacementButtonReadyOutline: some View {
        Rectangle()
            .strokeBorder(self.shouldEmphasizeTrainedReplacementButton ? self.palette.edge : .clear, lineWidth: 1)
            .padding(-3)
            .allowsHitTesting(false)
    }

    private var manualReplacementComposer: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: self.theme.metrics.spacing.md) {
                    self.manualTriggerField
                    self.manualReplacementField
                }

                VStack(alignment: .leading, spacing: self.theme.metrics.spacing.md) {
                    self.manualTriggerField
                    self.manualReplacementField
                }
            }

            if !self.manualDuplicateTriggers.isEmpty {
                HStack(spacing: 7) {
                    DatasheetStatusSquare(kind: .orange)
                    Text("Already used: \(self.manualDuplicateTriggers.joined(separator: ", "))")
                }
                .font(.system(size: 12))
                .foregroundStyle(self.palette.text2)
            }

            if !self.manualTriggers.isEmpty || !self.manualReplacement.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(self.manualTriggers, id: \.self) { trigger in
                        DictionaryPreviewChip(text: trigger)
                    }

                    Image(systemName: "arrow.right")
                        .font(self.theme.typography.caption)
                        .foregroundStyle(self.palette.text2)

                    Text(CustomDictionaryManualEntry.replacementDisplayText(self.sanitizedManualReplacement))
                        .font(self.theme.typography.captionStrong)
                        .foregroundStyle(self.palette.text)
                }
            }

            Spacer(minLength: 0)

            Button {
                self.addManualReplacementIfValid()
            } label: {
                Label("ADD REPLACEMENT", systemImage: "plus")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(self.palette.invForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(self.palette.invBackground)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .disabled(!self.canAddManualReplacement)
            .opacity(self.canAddManualReplacement ? 1 : 0.45)
        }
    }

    private var manualTriggerField: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.sm) {
            Text("When MouthKeys hears")
                .font(self.theme.typography.captionStrong)

            TextField("fluid voice, fluid boys", text: self.$manualTriggerDraft)
                .dictionaryInputChrome()
                .onSubmit { self.addManualReplacementIfValid() }

            Text("Separate different versions with commas. Enter only commas to replace comma punctuation.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.palette.text2)
        }
    }

    private var manualReplacementField: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.sm) {
            Text("Change it to")
                .font(self.theme.typography.captionStrong)
            TextField("MouthKeys", text: self.$manualReplacement)
                .dictionaryInputChrome()
                .onSubmit { self.addManualReplacementIfValid() }
            Text("This is what appears in your transcription.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.palette.text2)
        }
    }

    private var voiceMatchingSettingsRow: some View {
        VoiceMatchingSettingsRow(
            isEnabled: self.pronunciationMatchingBinding,
            isDisabled: self.isTrainingRecording || self.isTrainingProcessing,
            isAdvancedAvailable: SettingsStore.shared.selectedSpeechModel.supportsPronunciationMatching,
            onChange: self.handlePronunciationMatchingChange(enabled:)
        )
    }

    private var trainingRecorderPanel: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 9) {
                Text("TRAINING STEPS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(self.palette.text2)

                if self.trainingAlreadyCorrectWithoutReplacement {
                    Text("\(self.trainingTargetReference) is already recognized correctly.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(self.palette.text)
                } else if self.trainingFinalOutputIsReady {
                    Text(
                        self.activePronunciationMatching
                            ? "Voice profile for \(self.trainingTargetReference) captured 3 times."
                            : "MouthKeys recognized \(self.trainingTargetReference) 3 times in a row."
                    )
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(self.palette.text)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        self.trainingInstruction(number: 1, text: "Type the correct word you want to teach in the box above.")
                        self.trainingInstruction(number: 2, text: "Press Start once.")
                        self.trainingInstruction(
                            number: 3,
                            text: "Say \(self.trainingTargetReference) naturally, then pause. MouthKeys records and listens again automatically."
                        )
                self.trainingInstruction(
                    number: 4,
                    text: self.activePronunciationMatching
                        ? "Repeat 3 times to teach MouthKeys how your voice sounds."
                        : "Keep repeating it until the meter reaches 3/3."
                )
                    }
                }

                if !self.trainingVariants.isEmpty {
                    self.trainingHeardSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(self.palette.ruleSoft)
                .frame(width: 1)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("READINESS")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(self.palette.text2)
                }

                DictionaryTrainingReadinessRing(
                    progress: self.trainingReadinessProgress,
                    total: CustomDictionaryTrainingMerge.readyCoveredCount,
                    isReady: self.trainingFinalOutputIsReady || self.trainingAlreadyCorrectWithoutReplacement
                )

                Text(self.trainingReadinessCaption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.palette.text2)
                    .fixedSize(horizontal: false, vertical: true)

                self.trainingFinalOutputPanel

                Button {
                    Task { await self.toggleAutomaticTraining() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: self.trainingRecorderIsStop ? "stop.fill" : "mic.fill")
                        Text(self.trainingRecorderButtonTitle.uppercased())
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(self.palette.invForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(self.palette.accent)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(!self.canUseTrainingRecorderButton)
                .opacity(self.canUseTrainingRecorderButton ? 1 : 0.45)
            }
            .frame(width: 248, alignment: .topLeading)
        }
        .padding(14)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var trainingReadinessCaption: String {
        DictionaryTrainingCopy.readinessCaption(
            target: self.trainingTargetReference,
            isAlreadyCorrect: self.trainingAlreadyCorrectWithoutReplacement,
            isReady: self.trainingFinalOutputIsReady,
            usesVoiceMatching: self.activePronunciationMatching
        )
    }

    private var trainingHeardSection: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("HEARD")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(self.palette.text2)
                .frame(width: 42, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                ForEach(Array(self.trainingVariants.prefix(5).enumerated()), id: \.element) { index, variant in
                    TrainingVariantChip(number: index + 1, variant: variant) {
                        self.removeTrainingVariant(variant)
                    }
                }

                if self.trainingVariants.count > 5 {
                    Text("+\(self.trainingVariants.count - 5)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(self.palette.text2)
                }
                }
            }
        }
        .padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    private var trainingFinalOutputPanel: some View {
        HStack(alignment: .center, spacing: self.theme.metrics.spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Final output")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.palette.text2)

                Text(self.trainingFinalOutputText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.lastTrainingOutput.isEmpty ? self.palette.text2 : self.palette.text)
                    .lineLimit(1)

                if !self.lastTrainingOutput.isEmpty, self.lastTrainingOutput.caseInsensitiveCompare(self.trainingFinalOutputText) != .orderedSame {
                    Text("Heard: \(self.lastTrainingOutput)")
                        .font(self.theme.typography.caption)
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    @ViewBuilder
    private var trainingFooter: some View {
        if self.trainingHasError || self.isTrainingActive || !self.trainingVariants.isEmpty {
            HStack(spacing: self.theme.metrics.spacing.sm) {
                if self.trainingHasError {
                    HStack(spacing: 7) {
                        DatasheetStatusSquare(kind: .orange)
                        Text(self.trainingStatusMessage)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(self.palette.text2)
                }

                if self.isTrainingActive || !self.trainingVariants.isEmpty || !self.normalizedTrainingReplacement.isEmpty {
                    Spacer()

                    Button("Clear") {
                        self.resetTraining()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(self.palette.text2)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(self.palette.field)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    .disabled(self.isTrainingRecording || self.isTrainingProcessing)
                    .opacity(self.isTrainingRecording || self.isTrainingProcessing ? 0.45 : 1)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Your Dictionary

    private var yourDictionarySection: some View {
        DatasheetSection(
            letter: "B",
            title: "Your Dictionary",
            trailing: "\(self.entries.count) entries",
            note: "Words and phrases MouthKeys will correct automatically."
        ) {
            VStack(spacing: 0) {
                self.replacementTableHeader
                if self.entries.isEmpty {
                    self.dictionaryEmptyState(
                        title: "No replacements yet",
                        detail: "Use Teach Words above to create your first one."
                    )
                } else {
                    self.entriesListView
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var replacementTableHeader: some View {
        HStack(spacing: 10) {
            self.tableHeading("Spoken As").frame(maxWidth: .infinity, alignment: .leading)
            self.tableHeading("→").frame(width: 20, alignment: .center)
            self.tableHeading("Replace With").frame(maxWidth: .infinity, alignment: .leading)
            self.tableHeading("Actions").frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    private func tableHeading(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(self.palette.text2)
            .lineLimit(1)
    }

    private var punctuationDictionarySection: some View {
        DatasheetSection(
            letter: "C",
            title: "Spoken Formatting",
            trailing: "\(SettingsStore.SpokenFormattingAction.allCases.count) actions · \(self.punctuationRules.count) punctuation",
            note: "Use a start word to safely insert formatting actions, punctuation, and symbols."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        withAnimation(self.reduceMotion ? nil : .easeOut(duration: 0.14)) {
                            self.isPunctuationInfoExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                            Text(self.isPunctuationInfoExpanded ? "Hide information" : "About spoken formatting")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About spoken formatting")
                    Spacer()
                }

                if self.isPunctuationInfoExpanded {
                    self.punctuationDictionaryInfoPanel
                }

                self.spokenFormattingStatusRow

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        self.tableHeading("Start Word")
                        Text("Say this first so normal words do not change.")
                            .font(.system(size: 12))
                            .foregroundStyle(self.palette.text2)
                        TextField("literal", text: self.$punctuationPrefix)
                            .dictionaryInputChrome()
                            .onSubmit { self.savePunctuationDictionaryPrefix() }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 6) {
                        self.tableHeading("Try Saying")
                        Text("Examples of what MouthKeys will type.")
                            .font(.system(size: 12))
                            .foregroundStyle(self.palette.text2)
                        self.punctuationTrySayingPreview
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                self.formattingActionsSection
                self.punctuationRulesSection

                HStack {
                    Spacer()
                    Button("Reset All Defaults") {
                        self.isFormattingResetAlertPresented = true
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.palette.text2)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Reset Spoken Formatting?", isPresented: self.$isFormattingResetAlertPresented) {
            Button("Reset All Defaults", role: .destructive) { self.resetPunctuationDictionary() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the start word, formatting action phrases and enabled states, and every punctuation rule with their defaults.")
        }
    }

    private var entriesListView: some View {
        VStack(spacing: 0) {
            ForEach(self.entries) { entry in
                DictionaryEntryRow(
                    entry: entry,
                    onEdit: {
                        self.editingEntry = entry
                    },
                    onDelete: { self.deleteEntry(entry) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Custom Words

    private var aiPostProcessingSection: some View {
        DatasheetSection(
            letter: "D",
            title: "Custom Words",
            trailing: "\(self.boostTerms.count) terms",
            note: "Help the Parakeet voice engine recognize names, products, and uncommon terms."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                DatasheetRow(
                    label: "Vocabulary Boosting",
                    help: "Improve recognition of your custom words when using Parakeet.",
                    showsBottomRule: false
                ) {
                    self.customWordsBoostingToggle
                }

                if self.isBoostWordEditorPresented {
                    self.boostWordEditor
                        .padding(12)
                        .background(self.palette.surface)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }

                HStack {
                    self.tableHeading("Saved Words · Boosted While Enabled")
                    Spacer()
                    Button {
                        self.startAddingBoostTerm()
                    } label: {
                        Label("Add Word", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(self.palette.text)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .disabled(!self.vocabBoostingEnabled || self.isBoostWordEditorPresented)
                    .opacity(self.vocabBoostingEnabled && !self.isBoostWordEditorPresented ? 1 : 0.5)
                }

                self.customWordsTableHeader

                if self.boostTerms.isEmpty {
                    self.dictionaryEmptyState(
                        title: "No custom words yet",
                        detail: "Add a name or term that needs a little extra recognition help."
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(self.boostTerms.enumerated()), id: \.offset) { index, term in
                            BoostTermRow(
                                term: term,
                                isEnabled: self.vocabBoostingEnabled,
                                onEdit: { self.editBoostTerm(at: index) },
                                onDelete: { self.deleteBoostTerm(at: index) }
                            )
                        }
                    }
                }

                if self.boostHasError {
                    HStack(spacing: 8) {
                        DatasheetStatusSquare(kind: .orange)
                        Text(self.boostStatusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(self.palette.text2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var customWordsTableHeader: some View {
        HStack(spacing: 10) {
            self.tableHeading("Word or Phrase").frame(maxWidth: .infinity, alignment: .leading)
            self.tableHeading("Priority").frame(width: 94, alignment: .trailing)
            self.tableHeading("Actions").frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    private var customWordsBoostingToggle: some View {
        Toggle("Custom Words Boosting", isOn: self.$vocabBoostingEnabled)
            .labelsHidden()
            .toggleStyle(DatasheetToggleStyle())
            .onChange(of: self.vocabBoostingEnabled) { _, newValue in
                SettingsStore.shared.vocabularyBoostingEnabled = newValue
            }
            .help("Improve recognition of your custom words when using Parakeet.")
    }

    private var boostWordEditor: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.md) {
            Text(self.boostEditorTitle)
                .font(self.theme.typography.captionStrong)

            VStack(alignment: .leading, spacing: 6) {
                Text("Word or Phrase")
                    .font(self.theme.typography.captionStrong)
                TextField("MouthKeys", text: self.$boostTermText)
                    .font(self.theme.typography.bodySmall)
                    .dictionaryInputChrome()
                    .onSubmit { self.saveBoostTermIfValid() }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Word Priority")
                    .font(self.theme.typography.captionStrong)
                DatasheetSegmented(
                    selection: self.$boostTermStrength,
                    choices: BoostStrengthPreset.allCases.map { .init(value: $0, title: $0.rawValue) },
                    cellWidth: 72
                )
                Text(self.boostTermStrength.hint)
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.theme.palette.secondaryText)
            }

            if self.isBoostTermDuplicate {
                HStack(spacing: 7) {
                    DatasheetStatusSquare(kind: .orange)
                    Text("This word already exists.")
                }
                    .font(self.theme.typography.caption)
                    .foregroundStyle(self.palette.text2)
            }

            HStack {
                Spacer()

                Button("Clear") {
                    self.clearBoostTermFields()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                Spacer()

                Button("Cancel") {
                    self.dismissBoostTermEditor()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                Button("Save Word") {
                    self.saveBoostTermIfValid()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.invForeground)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(self.palette.accent)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                .disabled(!self.canSaveBoostTerm)
                .opacity(self.canSaveBoostTerm ? 1 : 0.45)
            }
        }
        .padding(self.theme.metrics.spacing.md)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var spokenFormattingStatusRow: some View {
        HStack(spacing: self.theme.metrics.spacing.md) {
            DatasheetStatusSquare(kind: self.punctuationAutoConvertEnabled ? .ink : .outline)

            VStack(alignment: .leading, spacing: 2) {
                Text(self.punctuationAutoConvertEnabled ? "Spoken Formatting is On" : "Spoken Formatting is Off")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(self.palette.text)
                Text(
                    self.punctuationAutoConvertEnabled
                        ? "Formatting actions and punctuation will run after the start word."
                        : "Your rules stay saved, but they will not change dictated text."
                )
                .font(.system(size: 12))
                .foregroundStyle(self.palette.text2)
            }

            Spacer()

            Toggle("Spoken Formatting", isOn: self.$punctuationAutoConvertEnabled)
                .labelsHidden()
                .toggleStyle(DatasheetToggleStyle())
                .accessibilityLabel("Spoken Formatting")
                .onChange(of: self.punctuationAutoConvertEnabled) { _, newValue in
                    SettingsStore.shared.autoConvertPunctuationEnabled = newValue
                }
        }
        .padding(12)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var formattingActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                self.tableHeading("Formatting Actions")
                Text("Fixed invisible actions with spoken phrases you can personalize.")
                    .font(.system(size: 12))
                    .foregroundStyle(self.palette.text2)
            }

            VStack(spacing: 0) {
                ForEach(SettingsStore.SpokenFormattingAction.allCases) { action in
                    self.formattingActionRow(action)
                }
            }

            if let action = self.editingFormattingAction {
                self.formattingActionEditor(action)
            }
        }
    }

    private var punctuationRulesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    self.tableHeading("Punctuation")
                    Text("Spoken names that type punctuation or symbols after the start word.")
                        .font(.system(size: 12))
                        .foregroundStyle(self.palette.text2)
                }
                Spacer()
                if !self.isPunctuationRuleEditorPresented {
                    Button {
                        self.startAddingPunctuationRule()
                    } label: {
                        Label("Add Rule", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(self.palette.text)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }

            if self.isPunctuationRuleEditorPresented {
                self.punctuationRuleEditor
            }

            self.punctuationTableHeader

            if self.punctuationRules.isEmpty {
                self.dictionaryEmptyState(
                    title: "No punctuation rules",
                    detail: "Add what you say and what MouthKeys should type."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(self.punctuationRules) { rule in
                        PunctuationDictionaryRuleRow(
                            rule: rule,
                            onEdit: { self.editPunctuationRule(rule) },
                            onDelete: { self.deletePunctuationRule(rule) }
                        )
                    }
                }
            }
        }
    }

    private var punctuationTableHeader: some View {
        HStack(spacing: 10) {
            self.tableHeading("Spoken As").frame(maxWidth: .infinity, alignment: .leading)
            self.tableHeading("→").frame(width: 20, alignment: .center)
            self.tableHeading("Types").frame(width: 60, alignment: .leading)
            self.tableHeading("Actions").frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    private func formattingActionRow(_ action: SettingsStore.SpokenFormattingAction) -> some View {
        let rule = self.formattingActionRule(for: action)
        return HStack(spacing: 12) {
            Text(action.displaySymbol)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(self.palette.text)
                Text(rule.aliases.isEmpty ? "No spoken phrases set" : rule.aliases.joined(separator: ", "))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button("Edit") {
                self.startEditingFormattingAction(action)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(self.palette.text2)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            .buttonStyle(.plain)

            Toggle(action.title, isOn: self.formattingActionEnabledBinding(for: action))
                .labelsHidden()
                .toggleStyle(DatasheetToggleStyle())
                .disabled(rule.aliases.isEmpty)
                .help(rule.aliases.isEmpty ? "Add a spoken phrase before enabling this action." : "Enable \(action.title)")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    private func formattingActionEditor(_ action: SettingsStore.SpokenFormattingAction) -> some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.sm) {
            Text("Edit \(action.title) Phrases")
                .font(self.theme.typography.captionStrong)
            Text("Enter one phrase per line. Clearing every phrase disables this action.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.palette.text2)

            TextEditor(text: self.$formattingActionAliasesText)
                .font(self.theme.typography.bodySmall)
                .frame(minHeight: 68, maxHeight: 92)
                .scrollContentBackground(.hidden)
                .dictionaryInputChrome(minHeight: 68)
                .accessibilityLabel("Spoken phrases for \(action.title)")

            HStack {
                Spacer()
                Button("Cancel") {
                    self.dismissFormattingActionEditor()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                Button("Save Phrases") {
                    self.saveFormattingActionAliases(action)
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.invForeground)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(self.palette.accent)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            }
        }
        .padding(12)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var punctuationDictionaryInfoPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Say the start word first, then a formatting action or punctuation name.")
            Text("When you say \"\(self.punctuationPreviewPrefix) next line\", it starts a new line.")
            Text("When you say \"\(self.punctuationPreviewPrefix) comma\", it types \",\".")
            Text("Add one spoken phrase per line. Formatting actions always keep their fixed output.")
        }
        .font(.system(size: 12))
        .foregroundStyle(self.palette.text2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var punctuationTrySayingPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            self.punctuationExampleText(
                spoken: "\(self.punctuationPreviewPrefix) comma",
                typed: ","
            )
            self.punctuationExampleText(
                spoken: "\(self.punctuationPreviewPrefix) next line",
                typed: "New Line"
            )
        }
        .font(.system(size: 12))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private func punctuationExampleText(spoken: String, typed: String) -> Text {
        Text("When you say ")
            .foregroundStyle(self.palette.text2) +
            Text("\"\(spoken)\"")
            .foregroundStyle(self.palette.accent) +
            Text(", it types ")
            .foregroundStyle(self.palette.text2) +
            Text("\"\(typed)\"")
            .foregroundStyle(self.palette.text)
    }

    private var punctuationRuleEditor: some View {
        VStack(alignment: .leading, spacing: self.theme.metrics.spacing.md) {
            Text(self.punctuationEditorTitle)
                .font(self.theme.typography.captionStrong)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: self.theme.metrics.spacing.md) {
                    self.punctuationAliasesEditor
                    self.punctuationSymbolEditor
                }

                VStack(alignment: .leading, spacing: self.theme.metrics.spacing.md) {
                    self.punctuationAliasesEditor
                    self.punctuationSymbolEditor
                }
            }

            HStack {
                Spacer()

                Button("Clear") {
                    self.clearPunctuationRuleFields()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                Spacer()

                Button("Cancel") {
                    self.dismissPunctuationRuleEditor()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                Button("Save Rule") {
                    self.savePunctuationRuleIfValid()
                }
                .buttonStyle(.plain)
                .foregroundStyle(self.palette.invForeground)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(self.palette.accent)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                .disabled(!self.canSavePunctuationRule)
                .opacity(self.canSavePunctuationRule ? 1 : 0.45)
            }
        }
        .padding(12)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var punctuationAliasesEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What You Say")
                .font(self.theme.typography.captionStrong)
            Text("One way per line, like comma or full stop.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.palette.text2)
            TextEditor(text: self.$punctuationAliasesText)
                .font(self.theme.typography.bodySmall)
                .frame(minHeight: 64, maxHeight: 86)
                .scrollContentBackground(.hidden)
                .dictionaryInputChrome(minHeight: 64)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var punctuationSymbolEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What It Types")
                .font(self.theme.typography.captionStrong)
            TextField(",", text: self.$punctuationSymbolText)
                .font(self.theme.typography.bodySmallStrong)
                .dictionaryInputChrome()
                .frame(width: 92)
            Text("One punctuation symbol, like , or ?.")
                .font(self.theme.typography.caption)
                .foregroundStyle(self.palette.text2)
        }
    }

    private func dictionaryEmptyState(
        title: String,
        detail: String,
        action: (() -> Void)? = nil
    ) -> some View {
        DatasheetEmptyState(
            placard: "00 ENTRIES",
            title: title,
            message: detail,
            actionTitle: action == nil ? nil : "Add",
            action: action
        )
    }

    // MARK: - Actions

    private func saveEntries() {
        SettingsStore.shared.customDictionaryEntries = self.entries
        // Invalidate cached regex patterns so changes take effect immediately
        ASRService.invalidateDictionaryCache()
        NotificationCenter.default.post(name: .parakeetVocabularyDidChange, object: nil)
    }

    private func updateTrainedReplacementGlow() {
        guard self.shouldPulseTrainedReplacementButton else {
            withAnimation(.easeOut(duration: 0.16)) {
                self.isTrainedReplacementGlowExpanded = false
            }
            return
        }

        self.isTrainedReplacementGlowExpanded = false
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            self.isTrainedReplacementGlowExpanded = true
        }
    }

    private func addReplacementEntry(_ entry: SettingsStore.CustomDictionaryEntry) {
        self.entries.insert(entry, at: 0)
        self.saveEntries()
        self.showReplacementConfirmation(
            title: "Replacement added",
            detail: "It is at the top of the list."
        )
    }

    private func selectComposerMode(_ mode: DictionaryComposerMode) {
        guard !self.isTrainingRecording, !self.isTrainingProcessing else { return }
        self.composerMode = mode
    }

    private func addManualReplacementIfValid() {
        guard self.canAddManualReplacement else { return }
        let entry = SettingsStore.CustomDictionaryEntry(
            triggers: self.manualTriggers,
            replacement: self.sanitizedManualReplacement
        )
        self.addReplacementEntry(entry)
        self.manualTriggerDraft = ""
        self.manualReplacement = ""
    }

    private func savePunctuationDictionaryPrefix() {
        SettingsStore.shared.punctuationDictionaryPrefix = self.punctuationPrefix
        self.punctuationPrefix = SettingsStore.shared.punctuationDictionaryPrefix
    }

    private func savePunctuationRules() {
        SettingsStore.shared.punctuationDictionaryRules = self.punctuationRules
        self.punctuationRules = SettingsStore.shared.punctuationDictionaryRules
    }

    private func formattingActionRule(
        for action: SettingsStore.SpokenFormattingAction
    ) -> SettingsStore.SpokenFormattingActionRule {
        self.formattingActionRules.first { $0.action == action }
            ?? SettingsStore.SpokenFormattingActionRule(action: action, aliases: [], isEnabled: false)
    }

    private func formattingActionEnabledBinding(
        for action: SettingsStore.SpokenFormattingAction
    ) -> Binding<Bool> {
        Binding(
            get: { self.formattingActionRule(for: action).isEnabled },
            set: { isEnabled in
                guard let index = self.formattingActionRules.firstIndex(where: { $0.action == action }) else { return }
                self.formattingActionRules[index].isEnabled = isEnabled
                self.saveFormattingActionRules()
            }
        )
    }

    private func startEditingFormattingAction(_ action: SettingsStore.SpokenFormattingAction) {
        self.editingFormattingAction = action
        self.formattingActionAliasesText = self.formattingActionRule(for: action).aliases.joined(separator: "\n")
    }

    private func dismissFormattingActionEditor() {
        self.editingFormattingAction = nil
        self.formattingActionAliasesText = ""
    }

    private func saveFormattingActionAliases(_ action: SettingsStore.SpokenFormattingAction) {
        let aliases = SettingsStore.PunctuationDictionaryRule.normalizedAliases(
            self.formattingActionAliasesText.components(separatedBy: .newlines)
        )
        guard let index = self.formattingActionRules.firstIndex(where: { $0.action == action }) else { return }
        self.formattingActionRules[index] = SettingsStore.SpokenFormattingActionRule(
            action: action,
            aliases: aliases,
            isEnabled: aliases.isEmpty ? false : self.formattingActionRules[index].isEnabled
        )
        self.saveFormattingActionRules()
        self.dismissFormattingActionEditor()
    }

    private func saveFormattingActionRules() {
        SettingsStore.shared.spokenFormattingActionRules = self.formattingActionRules
        self.formattingActionRules = SettingsStore.shared.spokenFormattingActionRules
    }

    private func startAddingPunctuationRule() {
        self.editingPunctuationRuleID = nil
        self.clearPunctuationRuleFields()
        self.isPunctuationRuleEditorPresented = true
    }

    private func savePunctuationRuleIfValid() {
        guard self.canSavePunctuationRule, let symbol = self.normalizedPunctuationSymbol else { return }
        self.savePunctuationDictionaryPrefix()
        let rule = SettingsStore.PunctuationDictionaryRule(
            id: self.editingPunctuationRuleID ?? UUID(),
            aliases: self.normalizedPunctuationAliases,
            symbol: symbol
        )

        if let editingID = self.editingPunctuationRuleID,
           let index = self.punctuationRules.firstIndex(where: { $0.id == editingID })
        {
            self.punctuationRules[index] = rule
        } else {
            self.punctuationRules.insert(rule, at: 0)
        }

        self.savePunctuationRules()
        self.dismissPunctuationRuleEditor()
    }

    private func editPunctuationRule(_ rule: SettingsStore.PunctuationDictionaryRule) {
        self.editingPunctuationRuleID = rule.id
        self.punctuationAliasesText = rule.aliases.joined(separator: "\n")
        self.punctuationSymbolText = rule.symbol
        self.isPunctuationRuleEditorPresented = true
    }

    private func deletePunctuationRule(_ rule: SettingsStore.PunctuationDictionaryRule) {
        self.punctuationRules.removeAll { $0.id == rule.id }
        if self.editingPunctuationRuleID == rule.id {
            self.dismissPunctuationRuleEditor()
        }
        self.savePunctuationRules()
    }

    private func resetPunctuationDictionary() {
        self.punctuationPrefix = SettingsStore.defaultPunctuationDictionaryPrefix
        self.punctuationRules = SettingsStore.defaultPunctuationDictionaryRules
        self.formattingActionRules = SettingsStore.defaultSpokenFormattingActionRules
        self.dismissFormattingActionEditor()
        self.dismissPunctuationRuleEditor()
        self.savePunctuationDictionaryPrefix()
        self.savePunctuationRules()
        self.saveFormattingActionRules()
    }

    private func clearPunctuationRuleFields() {
        self.punctuationAliasesText = ""
        self.punctuationSymbolText = ""
    }

    private func dismissPunctuationRuleEditor() {
        self.editingPunctuationRuleID = nil
        self.clearPunctuationRuleFields()
        self.isPunctuationRuleEditorPresented = false
    }

    private func startAddingBoostTerm() {
        self.editingBoostTermIndex = nil
        self.clearBoostTermFields()
        self.isBoostWordEditorPresented = true
    }

    private func editBoostTerm(at index: Int) {
        guard self.boostTerms.indices.contains(index) else { return }
        let term = self.boostTerms[index]
        self.editingBoostTermIndex = index
        self.boostTermText = term.text
        self.boostTermStrength = BoostStrengthPreset.nearest(for: term.weight ?? BoostStrengthPreset.balanced.weight)
        self.isBoostWordEditorPresented = true
    }

    private func saveBoostTermIfValid() {
        guard self.canSaveBoostTerm else { return }
        let updatedTerm = ParakeetVocabularyStore.VocabularyConfig.Term(
            text: self.normalizedBoostTermText,
            weight: self.boostTermStrength.weight,
            aliases: []
        )

        if let index = self.editingBoostTermIndex,
           self.boostTerms.indices.contains(index)
        {
            self.boostTerms[index] = ParakeetVocabularyStore.VocabularyConfig.Term(
                text: updatedTerm.text,
                weight: updatedTerm.weight,
                aliases: self.boostTerms[index].aliases
            )
        } else {
            self.boostTerms.append(updatedTerm)
        }

        self.saveBoostTerms()
        self.dismissBoostTermEditor()
    }

    private func clearBoostTermFields() {
        self.boostTermText = ""
        self.boostTermStrength = .balanced
    }

    private func dismissBoostTermEditor() {
        self.editingBoostTermIndex = nil
        self.clearBoostTermFields()
        self.isBoostWordEditorPresented = false
    }

    private func toggleAutomaticTraining() async {
        if self.isAutomaticTrainingEnabled {
            self.isAutomaticTrainingEnabled = false
            if self.isTrainingRecording {
                await self.stopTrainingSample()
            }
            return
        }

        if self.canRetryTrainingAfterMaximum {
            self.resetTrainingVerificationAttempts()
        }
        guard self.canRecordTrainingSample else { return }
        self.isAutomaticTrainingEnabled = true
        await self.startTrainingSample()
    }

    private func startTrainingSample() async {
        guard self.isAutomaticTrainingEnabled, self.canRecordTrainingSample else {
            self.isAutomaticTrainingEnabled = false
            return
        }
        self.isTrainingActive = true
        self.trainingHasError = false
        self.trainingStatusMessage = ""
        self.trainingStopRequestedDuringStart = false
        self.isTrainingStarting = true
        self.isTrainingRecording = true

        await self.asr.start(forDictionaryTraining: true)
        self.isTrainingStarting = false
        if !self.asr.isRunning {
            self.isTrainingRecording = false
            self.trainingStopRequestedDuringStart = false
            self.isAutomaticTrainingEnabled = false
            self.trainingHasError = true
            self.trainingStatusMessage = "Couldn't start recording. Check microphone access and try again."
            return
        }

        if self.trainingStopRequestedDuringStart {
            await self.finishTrainingSampleStop()
            return
        }
        DictionaryTrainingEndpointMonitor.shared.start(asr: self.asr) {
            self.handleAutomaticTrainingSpeechEnd()
        }
    }

    private func stopTrainingSample() async {
        DictionaryTrainingEndpointMonitor.shared.stop()
        guard self.isTrainingRecording else { return }
        guard !self.trainingStopRequestedDuringStart else { return }

        guard !self.isTrainingStarting, self.asr.isRunning else {
            self.trainingStopRequestedDuringStart = true
            self.trainingHasError = false
            self.trainingStatusMessage = "Stopping..."
            return
        }

        await self.finishTrainingSampleStop()
    }

    private func handleAutomaticTrainingSpeechEnd() {
        guard self.isAutomaticTrainingEnabled, self.isTrainingRecording else { return }
        Task { await self.stopTrainingSample() }
    }

    private func finishTrainingSampleStop() async {
        guard self.isTrainingRecording else { return }
        DictionaryTrainingEndpointMonitor.shared.stop()
        self.isTrainingRecording = false
        self.isTrainingStarting = false
        self.trainingStopRequestedDuringStart = false
        self.isTrainingProcessing = true
        self.trainingHasError = false
        self.trainingStatusMessage = ""

        let transcript = await self.asr.stop(forDictionaryTraining: true)
        self.isTrainingProcessing = false
        if self.activePronunciationMatching,
           CustomDictionaryTrainingMerge.normalizedTrigger(transcript) != nil,
           let enrollment = self.asr.lastDictionaryTrainingResult?.pronunciationEnrollment
        {
            self.trainingPronunciationEnrollments.append(enrollment)
        }
        self.addTrainingVariant(from: transcript)
        await self.continueAutomaticTrainingIfNeeded()
    }

    private func continueAutomaticTrainingIfNeeded() async {
        guard self.isAutomaticTrainingEnabled,
              !self.trainingFinalOutputIsReady,
              !self.trainingAlreadyCorrectWithoutReplacement,
              self.trainingSampleCount < CustomDictionaryTrainingMerge.maxSamples
        else {
            self.isAutomaticTrainingEnabled = false
            return
        }

        await Task.yield()
        await self.startTrainingSample()
    }

    private func resetTrainingVerificationAttempts() {
        self.trainingSampleCount = 0
        self.lastTrainingOutput = ""
        self.lastTrainingOutputIsCovered = false
        self.consecutiveCoveredCaptures = 0
        self.trainingStatusMessage = ""
        self.trainingHasError = false
    }

    private func addTrainingVariant(from transcript: String) {
        if self.activePronunciationMatching,
           self.asr.lastDictionaryTrainingResult?.pronunciationEnrollment == nil
        {
            self.trainingHasError = true
            self.trainingStatusMessage = "Couldn't capture a voice profile. Try again with one clear word."
            return
        }
        guard let detected = CustomDictionaryTrainingMerge.normalizedTrigger(transcript) else {
            self.lastTrainingOutput = ""
            self.lastTrainingOutputIsCovered = false
            self.consecutiveCoveredCaptures = 0
            self.trainingHasError = true
            self.trainingStatusMessage = "Nothing heard. Try again."
            return
        }

        self.lastTrainingOutput = detected
        self.trainingSampleCount = min(self.trainingSampleCount + 1, CustomDictionaryTrainingMerge.maxSamples)

        if detected.caseInsensitiveCompare(self.normalizedTrainingReplacement) == .orderedSame {
            self.lastTrainingOutputIsCovered = true
            self.consecutiveCoveredCaptures += 1
            self.trainingHasError = false
            if self.consecutiveCoveredCaptures >= CustomDictionaryTrainingMerge.readyCoveredCount {
                self.trainingStatusMessage = self.trainingVariants.isEmpty
                    ? "Looks good already. No replacement needed."
                    : "Looks ready. Add this replacement when you're ready."
            } else {
                self.trainingStatusMessage = "Covered. Try a couple more."
            }
            return
        }

        let wasAlreadyCaptured = self.trainingVariants.contains { $0.caseInsensitiveCompare(detected) == .orderedSame }
        let wasAlreadySaved = self.savedDictionaryCovers(detected)

        if wasAlreadyCaptured || wasAlreadySaved {
            self.lastTrainingOutputIsCovered = true
            self.consecutiveCoveredCaptures += 1
            self.trainingHasError = false
            if self.consecutiveCoveredCaptures >= CustomDictionaryTrainingMerge.readyCoveredCount {
                self.trainingStatusMessage = "Looks ready. Add this replacement when you're ready."
            } else if wasAlreadySaved {
                self.trainingStatusMessage = "Covered by your dictionary."
            } else {
                self.trainingStatusMessage = "Already captured. Try a couple more."
            }
            return
        }

        guard self.trainingVariants.count < CustomDictionaryTrainingMerge.maxSamples else {
            self.lastTrainingOutputIsCovered = false
            self.consecutiveCoveredCaptures = 0
            self.trainingHasError = false
            self.trainingStatusMessage = "Max samples reached. Add it or clear one."
            return
        }

        self.trainingVariants.append(detected)
        self.lastTrainingOutputIsCovered = false
        self.consecutiveCoveredCaptures = 0
        self.trainingHasError = false
        if self.trainingSampleCount >= CustomDictionaryTrainingMerge.maxSamples || self.trainingVariants.count >= CustomDictionaryTrainingMerge.maxSamples {
            self.trainingStatusMessage = "Max samples reached. Add it or clear one."
        } else {
            self.trainingStatusMessage = "New pronunciation captured. Add replacement to cover it."
        }
    }

    private func addTrainedReplacement() async {
        guard self.canAddTrainedReplacement else { return }
        self.isTrainingProcessing = true
        let replacementText = self.normalizedTrainingReplacement
        let updatesExisting = self.entries.contains {
            $0.replacement.caseInsensitiveCompare(replacementText) == .orderedSame
        }
        self.entries = CustomDictionaryTrainingMerge.mergedEntries(
            current: self.entries,
            replacement: replacementText,
            triggers: self.trainingVariants
        )
        let entry = self.entries.first {
            $0.replacement.caseInsensitiveCompare(replacementText) == .orderedSame
        }
        let enrollments = self.trainingPronunciationEnrollments
        if self.activePronunciationMatching, let entry, let modelKey = enrollments.first?.modelKey {
            do {
                try await PronunciationDictionaryStore.shared.upsert(
                    dictionaryEntryID: entry.id,
                    label: replacementText,
                    modelKey: modelKey,
                    enrollments: enrollments
                )
            } catch {
                self.isTrainingProcessing = false
                self.trainingHasError = true
                self.trainingStatusMessage = "Couldn't save the voice profile. Try again."
                DebugLogger.shared.error(
                    "Failed to save pronunciation profile: \(error.localizedDescription)",
                    source: "PronunciationMatching"
                )
                return
            }
        }
        self.saveEntries()
        self.resetTraining()
        self.showReplacementConfirmation(
            title: updatesExisting ? "Replacement updated" : "Recorded",
            detail: updatesExisting ? "Your variants are ready." : "Replacement added at the top."
        )
    }

    private func removeTrainingVariant(_ variant: String) {
        self.trainingVariants.removeAll { $0 == variant }
        self.refreshLastTrainingCoverage()
    }

    private func refreshLastTrainingCoverage() {
        guard !self.lastTrainingOutput.isEmpty else {
            self.lastTrainingOutputIsCovered = false
            self.consecutiveCoveredCaptures = 0
            return
        }

        let matchesReplacement = self.lastTrainingOutput.caseInsensitiveCompare(self.normalizedTrainingReplacement) == .orderedSame
        let isStillCaptured = self.trainingVariants.contains {
            $0.caseInsensitiveCompare(self.lastTrainingOutput) == .orderedSame
        }

        if matchesReplacement || isStillCaptured || self.savedDictionaryCovers(self.lastTrainingOutput) {
            self.lastTrainingOutputIsCovered = true
        } else {
            self.lastTrainingOutputIsCovered = false
            self.consecutiveCoveredCaptures = 0
        }
    }

    private func resetTraining(statusMessage: String = "Type the correct text.") {
        self.isAutomaticTrainingEnabled = false
        DictionaryTrainingEndpointMonitor.shared.stop()
        self.trainingReplacement = ""
        self.trainingVariants = []
        self.trainingPronunciationEnrollments = []
        self.trainingSampleCount = 0
        self.lastTrainingOutput = ""
        self.lastTrainingOutputIsCovered = false
        self.consecutiveCoveredCaptures = 0
        self.trainingStatusMessage = statusMessage
        self.trainingHasError = false
        self.isTrainingActive = false
        self.isTrainingStarting = false
        self.isTrainingRecording = false
        self.trainingStopRequestedDuringStart = false
        self.isTrainingProcessing = false
    }

    private func handleTrainingReplacementChange(oldValue: String, newValue: String) {
        let oldKey = CustomDictionaryTrainingMerge.normalizedReplacement(oldValue).lowercased()
        let newKey = CustomDictionaryTrainingMerge.normalizedReplacement(newValue).lowercased()
        guard oldKey != newKey else { return }

        self.trainingVariants = self.existingTrainingVariants(for: newValue)
        self.trainingPronunciationEnrollments = []
        self.trainingSampleCount = 0
        self.lastTrainingOutput = ""
        self.lastTrainingOutputIsCovered = false
        self.consecutiveCoveredCaptures = 0
        self.isTrainingActive = false
        if newKey.isEmpty {
            self.trainingStatusMessage = "Type the correct text."
        } else if self.trainingVariants.isEmpty {
            self.trainingStatusMessage = ""
        } else {
            self.trainingStatusMessage = "Loaded \(self.trainingVariants.count) saved \(self.trainingVariants.count == 1 ? "capture" : "captures")."
        }
        self.trainingHasError = false
    }

    private func existingTrainingVariants(for replacement: String) -> [String] {
        let replacementText = CustomDictionaryTrainingMerge.normalizedReplacement(replacement)
        guard !replacementText.isEmpty else { return [] }

        let triggers = self.entries
            .filter { $0.replacement.caseInsensitiveCompare(replacementText) == .orderedSame }
            .flatMap(\.triggers)

        return CustomDictionaryTrainingMerge.normalizedTriggers(
            from: triggers,
            intendedReplacement: replacementText
        )
    }

    private func savedDictionaryCovers(_ trigger: String) -> Bool {
        guard let triggerKey = CustomDictionaryTrainingMerge.normalizedTrigger(trigger),
              !self.normalizedTrainingReplacement.isEmpty
        else {
            return false
        }

        return self.entries.contains { entry in
            entry.replacement.caseInsensitiveCompare(self.normalizedTrainingReplacement) == .orderedSame &&
                entry.triggers.contains { savedTrigger in
                    guard let savedKey = CustomDictionaryTrainingMerge.normalizedTrigger(savedTrigger) else { return false }
                    return savedKey == triggerKey
                }
        }
    }

    private func showReplacementConfirmation(title: String, detail: String) {
        let confirmation = ReplacementConfirmation(title: title, detail: detail)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        withAnimation(self.reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.78)) {
            self.replacementConfirmation = confirmation
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_650_000_000)
            guard self.replacementConfirmation?.id == confirmation.id else { return }
            withAnimation(self.reduceMotion ? nil : .easeOut(duration: 0.16)) {
                self.replacementConfirmation = nil
            }
        }
    }

    private func loadBoostTerms() {
        do {
            self.boostTerms = try ParakeetVocabularyStore.shared.loadUserBoostTerms()
            self.boostStatusMessage = "Loaded \(self.boostTerms.count) custom words."
            self.boostHasError = false
        } catch {
            self.boostTerms = []
            self.boostStatusMessage = "Couldn't load custom words: \(error.localizedDescription)"
            self.boostHasError = true
        }
    }

    private func saveBoostTerms() {
        do {
            try ParakeetVocabularyStore.shared.saveUserBoostTerms(self.boostTerms)
            self.boostStatusMessage = "Saved \(self.boostTerms.count) custom words."
            self.boostHasError = false
        } catch {
            self.boostStatusMessage = "Couldn't save custom words: \(error.localizedDescription)"
            self.boostHasError = true
        }
    }

    private func exportDictionary() {
        do {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = DictionaryTransferService.shared.suggestedFilename()

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let document = try DictionaryTransferService.shared.makeExportDocument()
            let data = try DictionaryTransferService.shared.encode(document)
            try data.write(to: url, options: .atomic)

            self.presentInfoAlert(
                title: "Dictionary Exported",
                message: "Saved \(document.replacements.count) replacement rules and \(document.customWords.count) custom words."
            )
        } catch {
            self.presentErrorAlert(title: "Dictionary Export Failed", message: error.localizedDescription)
        }
    }

    private func importDictionary() {
        do {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.json]

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let data = try Data(contentsOf: url)
            let document = try DictionaryTransferService.shared.decode(data)
            guard let mode = self.confirmDictionaryImport(document) else { return }

            let summary = try DictionaryTransferService.shared.restore(document, mode: mode)
            self.entries = SettingsStore.shared.customDictionaryEntries
            self.loadBoostTerms()

            self.presentInfoAlert(
                title: "Dictionary Imported",
                message: "Now using \(summary.replacementCount) replacement rules and \(summary.customWordCount) custom words."
            )
        } catch {
            self.presentErrorAlert(title: "Dictionary Import Failed", message: error.localizedDescription)
        }
    }

    private func confirmDictionaryImport(_ document: DictionaryTransferDocument) -> DictionaryTransferImportMode? {
        let confirm = NSAlert()
        confirm.messageText = "Import this dictionary?"
        confirm.informativeText = """
        Found \(document.replacements.count) replacement rules and \(document.customWords.count) custom words.

        Merge adds them to your current dictionary. Replace clears the current dictionary first.
        """
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Merge")
        confirm.addButton(withTitle: "Replace")
        confirm.addButton(withTitle: "Cancel")

        switch confirm.runModal() {
        case .alertFirstButtonReturn:
            return .merge
        case .alertSecondButtonReturn:
            return .replace
        default:
            return nil
        }
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.runModal()
    }

    private func deleteBoostTerm(at index: Int) {
        guard self.boostTerms.indices.contains(index) else { return }
        self.boostTerms.remove(at: index)
        if self.editingBoostTermIndex == index {
            self.dismissBoostTermEditor()
        } else if let editingIndex = self.editingBoostTermIndex, index < editingIndex {
            self.editingBoostTermIndex = editingIndex - 1
        }
        self.saveBoostTerms()
    }

    private func deleteEntry(_ entry: SettingsStore.CustomDictionaryEntry) {
        self.entries.removeAll { $0.id == entry.id }
        self.saveEntries()
        Task {
            try? await PronunciationDictionaryStore.shared.delete(dictionaryEntryID: entry.id)
        }
    }

    /// Returns all existing trigger words for duplicate detection
    private func allExistingTriggers(excluding entryId: UUID? = nil) -> Set<String> {
        var triggers = Set<String>()
        for entry in self.entries where entry.id != entryId {
            for trigger in entry.triggers {
                triggers.insert(trigger.lowercased())
            }
        }
        return triggers
    }

    private func existingBoostTerms(excludingIndex: Int? = nil) -> Set<String> {
        var terms: Set<String> = []
        for (index, term) in self.boostTerms.enumerated() where index != excludingIndex {
            terms.insert(term.text.lowercased())
        }
        return terms
    }
}

private extension CustomDictionaryView {
    var asr: ASRService { self.appServices.asr }

    var trainedReplacementButtonTitle: String {
        self.trainingAlreadyCorrectWithoutReplacement ? "Nothing to Save" : "Add Replacement"
    }

    var shouldEmphasizeTrainedReplacementButton: Bool {
        self.trainingFinalOutputIsReady && self.canAddTrainedReplacement
    }

    func trainingInstruction(number: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(self.palette.invForeground)
                .frame(width: 20, height: 20, alignment: .center)
                .background(self.palette.invBackground)

            Text(text)
                .font(.system(size: 12))
                .lineSpacing(1)
                .foregroundStyle(self.palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    func handlePronunciationMatchingChange(enabled: Bool) {
        SettingsStore.shared.pronunciationMatchingEnabled = enabled
        self.isAutomaticTrainingEnabled = false
        DictionaryTrainingEndpointMonitor.shared.stop()
        self.trainingVariants = self.existingTrainingVariants(for: self.trainingReplacement)
        self.trainingPronunciationEnrollments = []
        self.resetTrainingVerificationAttempts()
        self.trainingStatusMessage = self.normalizedTrainingReplacement.isEmpty
            ? "Type the correct text."
            : ""
    }
}

private struct VoiceMatchingSettingsRow: View {
    @Binding var isEnabled: Bool

    let isDisabled: Bool
    let isAdvancedAvailable: Bool
    let onChange: (Bool) -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var hoveredMethod: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                self.methodButton(title: "Basic", enabledValue: false)
                self.methodButton(title: "Advanced", enabledValue: true, isResearchPreview: true)
            }

            if self.isEnabled {
                HStack(alignment: .top, spacing: 8) {
                    DatasheetStatusSquare(kind: .outline)
                        .padding(.top, 4)
                    Text("Research Preview: Compares how your voice sounds instead of only the words MouthKeys hears. Results may vary.")
                        .font(.system(size: 11))
                        .foregroundStyle(self.palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if !self.isAdvancedAvailable {
                Text("Advanced voice matching requires Parakeet TDT on Apple Silicon.")
                    .font(.system(size: 11))
                    .foregroundStyle(self.palette.text2)
            }
        }
    }

    private func methodButton(
        title: String,
        enabledValue: Bool,
        isResearchPreview: Bool = false
    ) -> some View {
        let isSelected = self.isEnabled == enabledValue
        let isHovered = self.hoveredMethod == enabledValue
        return Button {
            guard !isSelected else { return }
            self.isEnabled = enabledValue
            self.onChange(enabledValue)
        } label: {
            HStack(spacing: 6) {
                Text(title.uppercased())
                if isResearchPreview { Text("PREVIEW") }
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(isSelected ? self.palette.invForeground : self.palette.text2)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(isSelected ? self.palette.invBackground : (isHovered ? self.palette.field : self.palette.surface))
            .overlay { Rectangle().strokeBorder(isSelected ? self.palette.invBackground : self.palette.edge, lineWidth: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(self.isDisabled || (enabledValue && !self.isAdvancedAvailable))
        .opacity(self.isDisabled || (enabledValue && !self.isAdvancedAvailable) ? 0.55 : 1)
        .onHover { self.hoveredMethod = $0 ? enabledValue : nil }
    }
}

private struct DictionaryInputChrome: ViewModifier {
    let minHeight: CGFloat

    @Environment(\.datasheetPalette) private var palette
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .focused(self.$isFocused)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minHeight: self.minHeight)
            .background(self.palette.field)
            .overlay {
                Rectangle().strokeBorder(
                    self.isFocused ? self.palette.accent : self.palette.edge,
                    lineWidth: self.isFocused ? 2 : 1
                )
            }
            .contentShape(Rectangle())
    }
}

private extension View {
    func dictionaryInputChrome(minHeight: CGFloat = 34) -> some View {
        self.modifier(DictionaryInputChrome(minHeight: minHeight))
    }

    func dismissTextFocusOnBackgroundTap() -> some View {
        self.background(DictionaryFocusDismissMonitor())
    }
}

private struct DictionaryFocusDismissMonitor: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        FocusDismissView()
    }

    func updateNSView(_: NSView, context _: Context) {}

    private final class FocusDismissView: NSView {
        private var eventMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            self.removeEventMonitor()
            guard self.window != nil else { return }

            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let contentView = self.window?.contentView
                let location = contentView?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
                let hitView = contentView?.hitTest(location)
                if !self.isTextInput(hitView) {
                    self.window?.makeFirstResponder(nil)
                }
                return event
            }
        }

        deinit {
            self.removeEventMonitor()
        }

        private func isTextInput(_ view: NSView?) -> Bool {
            var candidate = view
            while let current = candidate {
                if current is NSTextField || current is NSTextView {
                    return true
                }
                candidate = current.superview
            }
            return false
        }

        private func removeEventMonitor() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

private enum DictionaryTrainingCopy {
    static func target(for normalizedTarget: String) -> String {
        normalizedTarget.isEmpty ? "the word" : "“\(normalizedTarget)”"
    }

    static func composerDetail(mode: DictionaryComposerMode, target: String) -> String {
        mode == .train && target != "the word" ? "Teach \(target) by speaking it." : mode.detail
    }

    static func readinessCaption(
        target: String,
        isAlreadyCorrect: Bool,
        isReady: Bool,
        usesVoiceMatching: Bool
    ) -> String {
        if isAlreadyCorrect {
            return "No replacement is needed for \(target)."
        }
        if isReady {
            return usesVoiceMatching
                ? "Ready. MouthKeys learned how \(target) sounds in your voice."
                : "Ready. MouthKeys got \(target) right 3 times in a row."
        }
        return usesVoiceMatching
            ? "Say \(target) 3 times to unlock Add Replacement."
            : "Keep trying until MouthKeys gets \(target) right 3 times in a row."
    }
}

private enum DictionaryComposerMode: CaseIterable, Identifiable {
    case train
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .train:
            return "Train by Voice"
        case .manual:
            return "Add Manually"
        }
    }

    var systemImage: String {
        switch self {
        case .train:
            return "mic.fill"
        case .manual:
            return "keyboard"
        }
    }

    var detail: String {
        switch self {
        case .train:
            return "Teach a word by speaking it."
        case .manual:
            return "Type the misheard text and the spelling you want."
        }
    }
}

enum CustomDictionaryManualEntry {
    static func normalizedTrigger(_ text: String) -> String? {
        let trigger = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trigger.isEmpty ? nil : trigger
    }

    static func normalizedTriggers(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var triggers: [String] = []
        triggers.reserveCapacity(values.count)

        for value in values {
            guard let trigger = self.normalizedTrigger(value), !seen.contains(trigger) else { continue }
            seen.insert(trigger)
            triggers.append(trigger)
        }

        return triggers
    }

    static func normalizedDraftTriggers(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if trimmed.allSatisfy({ $0 == "," || $0.isWhitespace }) {
            return self.normalizedTriggers([trimmed])
        }

        return self.normalizedTriggers(trimmed.split(separator: ",").map(String.init))
    }

    /// A replacement that is entirely whitespace (e.g. a pasted newline or space)
    /// is a deliberate payload — keep it verbatim instead of trimming it to empty.
    static func sanitizedReplacement(_ text: String) -> String {
        SettingsStore.CustomDictionaryEntry.sanitizedReplacement(text)
    }

    /// Whitespace-only replacements render as invisible/blank text, so show
    /// them as symbols (⏎ ␣ ⇥) in previews and entry rows.
    static func replacementDisplayText(_ replacement: String) -> String {
        guard !replacement.isEmpty, replacement.allSatisfy(\.isWhitespace) else { return replacement }
        return replacement.map { character -> String in
            if character.isNewline {
                return "⏎"
            }
            if character == "\t" {
                return "⇥"
            }
            return "␣"
        }.joined()
    }
}

enum PronunciationProfileEditPolicy {
    static func shouldDiscardProfile(previousReplacement: String, updatedReplacement: String) -> Bool {
        previousReplacement.caseInsensitiveCompare(updatedReplacement) != .orderedSame
    }
}

enum CustomDictionaryTrainingMerge {
    static let recommendedSamples = 5
    static let maxSamples = 20
    static let readyCoveredCount = 3

    private static let edgePunctuation = CharacterSet(charactersIn: ".,!?;:\"'“”‘’")

    static func normalizedReplacement(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedTrigger(_ value: String) -> String? {
        let edgeCharacters = CharacterSet.whitespacesAndNewlines.union(self.edgePunctuation)
        let trimmed = value.trimmingCharacters(in: edgeCharacters).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedTriggers(from values: [String], intendedReplacement: String) -> [String] {
        let replacement = self.normalizedReplacement(intendedReplacement)
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(values.count)

        for value in values {
            guard let trigger = self.normalizedTrigger(value),
                  trigger.caseInsensitiveCompare(replacement) != .orderedSame,
                  !seen.contains(trigger)
            else {
                continue
            }
            seen.insert(trigger)
            result.append(trigger)
            if result.count >= self.maxSamples {
                break
            }
        }

        return result
    }

    static func mergedEntries(
        current entries: [SettingsStore.CustomDictionaryEntry],
        replacement: String,
        triggers: [String]
    ) -> [SettingsStore.CustomDictionaryEntry] {
        let replacementText = self.normalizedReplacement(replacement)
        let incomingTriggers = self.normalizedTriggers(from: triggers, intendedReplacement: replacementText)
        guard !replacementText.isEmpty, !incomingTriggers.isEmpty else { return entries }

        let matchingIndex = entries.firstIndex {
            $0.replacement.caseInsensitiveCompare(replacementText) == .orderedSame
        }
        let replacementID = matchingIndex.map { entries[$0].id }
        let storedReplacementText = matchingIndex.map { entries[$0].replacement } ?? replacementText
        let matchingEntries = entries.filter {
            $0.replacement.caseInsensitiveCompare(storedReplacementText) == .orderedSame
        }
        let existingTriggers = matchingEntries.flatMap(\.triggers)
        let combinedTriggers = self.normalizedTriggers(
            from: existingTriggers + incomingTriggers,
            intendedReplacement: storedReplacementText
        )
        let triggerKeys = Set(combinedTriggers)

        let mergedEntry = replacementID.map {
            SettingsStore.CustomDictionaryEntry(
                id: $0,
                triggers: combinedTriggers,
                replacement: storedReplacementText
            )
        } ?? SettingsStore.CustomDictionaryEntry(
            triggers: combinedTriggers,
            replacement: storedReplacementText
        )

        var didInsertMergedEntry = false
        var updatedEntries: [SettingsStore.CustomDictionaryEntry] = []
        updatedEntries.reserveCapacity(entries.count + (matchingIndex == nil ? 1 : 0))

        for entry in entries {
            if entry.replacement.caseInsensitiveCompare(storedReplacementText) == .orderedSame {
                if !didInsertMergedEntry {
                    updatedEntries.append(mergedEntry)
                    didInsertMergedEntry = true
                }
                continue
            }

            let remainingTriggers = entry.triggers.filter { trigger in
                guard let key = self.normalizedTrigger(trigger) else { return false }
                return !triggerKeys.contains(key)
            }
            guard !remainingTriggers.isEmpty else { continue }
            updatedEntries.append(
                SettingsStore.CustomDictionaryEntry(
                    id: entry.id,
                    triggers: remainingTriggers,
                    replacement: entry.replacement
                )
            )
        }

        if !didInsertMergedEntry {
            updatedEntries.insert(mergedEntry, at: 0)
        }

        return updatedEntries
    }
}

private struct ReplacementConfirmation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct ReplacementConfirmationToast: View {
    let confirmation: ReplacementConfirmation

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Rectangle()
                    .fill(self.palette.invBackground)
                    .frame(width: 30, height: 30)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.invForeground)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(self.confirmation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                Text(self.confirmation.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(self.palette.text2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(minWidth: 260, alignment: .leading)
        .padding(14)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct DictionaryTrainingReadinessRing: View {
    let progress: Int
    let total: Int
    let isReady: Bool

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            DatasheetMeter(value: self.progress, count: self.total, segmentWidth: 30, segmentHeight: 12)
            HStack(spacing: 7) {
                Text("\(min(self.progress, self.total))/\(self.total)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.isReady ? self.palette.text : self.palette.text2)
                    .monospacedDigit()
                Text(self.isReady ? "READY" : "CORRECT")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training progress")
        .accessibilityValue("\(self.progress) of \(self.total) correct")
    }
}

private struct TrainingVariantChip: View {
    let number: Int
    let variant: String
    let onDelete: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            Text("\(self.number)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(self.palette.text2)
                .frame(minWidth: 11)

            Text(self.variant)
                .font(.system(size: 11))
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .truncationMode(.tail)

            Button(action: self.onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Remove \(self.variant)")
        }
        .frame(maxWidth: 165)
        .padding(.leading, 6)
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }
}

private struct DictionaryPreviewChip: View {
    let text: String

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        Text(self.text)
            .font(.system(size: 11))
            .foregroundStyle(self.palette.text)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }
}

private enum BoostStrengthPreset: String, CaseIterable, Identifiable {
    case mild = "Mild"
    case balanced = "Balanced"
    case strong = "Strong"

    var id: String { self.rawValue }

    var weight: Float {
        switch self {
        case .mild: return 5.0
        case .balanced: return 10.0
        case .strong: return 13.0
        }
    }

    var hint: String {
        switch self {
        case .mild: return "Very light nudge with minimal impact."
        case .balanced: return "Best default for most names and product terms."
        case .strong: return "Use when this word should win more often in noisy audio."
        }
    }

    static func nearest(for weight: Float) -> Self {
        if weight < 8.5 { return .mild }
        if weight > 11.5 { return .strong }
        return .balanced
    }
}

// MARK: - Boost Term Row

struct BoostTermRow: View {
    let term: ParakeetVocabularyStore.VocabularyConfig.Term
    var isEnabled = true
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Text(self.term.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let weight = self.term.weight {
                let strength = BoostStrengthPreset.nearest(for: weight)
                Text(strength.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 94, alignment: .trailing)
            } else {
                Text("Default")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 94, alignment: .trailing)
            }

            HStack(spacing: 2) {
                Button {
                    self.onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 32, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(!self.isEnabled)
                .help("Configure \(self.term.text)")

                Button(role: .destructive) {
                    self.onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 32, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(!self.isEnabled)
                .help("Delete \(self.term.text)")
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }
}

// MARK: - Dictionary Entry Row

struct DictionaryEntryRow: View {
    let entry: SettingsStore.CustomDictionaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(self.entry.triggers.joined(separator: ", "))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(self.palette.text2)
                .frame(width: 20)

            Text(CustomDictionaryManualEntry.replacementDisplayText(self.entry.replacement))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                Button {
                    self.onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 32, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Configure replacement")

                Button(role: .destructive) {
                    self.onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 32, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Delete replacement")
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }
}

private struct PunctuationDictionaryRuleRow: View {
    let rule: SettingsStore.PunctuationDictionaryRule
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(self.rule.aliases.joined(separator: ", "))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(self.palette.text2)
                .frame(width: 20)

            Text(self.rule.symbol)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)

            HStack(spacing: 2) {
                Button {
                    self.onEdit()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 32, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Edit punctuation rule")

                Button(role: .destructive) {
                    self.onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 32, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Delete punctuation rule")
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }
}

// MARK: - Edit Entry Sheet

struct EditDictionaryEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(\.datasheetPalette) private var palette

    let entry: SettingsStore.CustomDictionaryEntry
    let existingTriggers: Set<String>
    let onSave: (SettingsStore.CustomDictionaryEntry) -> Void

    @State private var triggersText = ""
    @State private var replacement = ""

    private var duplicateTriggers: [String] {
        self.parseTriggers().filter { self.existingTriggers.contains($0) }
    }

    private var canSave: Bool {
        !self.parseTriggers().isEmpty &&
            !CustomDictionaryManualEntry.sanitizedReplacement(self.replacement).isEmpty &&
            self.duplicateTriggers.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("03 / CUSTOM DICTIONARY")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(self.palette.text2)
                    Text("Edit Dictionary Entry")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(self.palette.text)
                }
                Spacer()
                Button("Cancel") { self.dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(self.palette.field)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            }

            Rectangle().fill(self.palette.rule).frame(height: 1)

            // Triggers input
            VStack(alignment: .leading, spacing: 6) {
                Text("Misheard Words (triggers)")
                    .font(.subheadline.weight(.medium))
                Text("Add one version per line. Commas can be saved too.")
                    .font(.caption)
                    .foregroundStyle(self.palette.text2)
                TextEditor(text: self.$triggersText)
                    .font(.body)
                    .frame(minHeight: 54, maxHeight: 76)
                    .scrollContentBackground(.hidden)
                    .dictionaryInputChrome(minHeight: 54)

                // Duplicate warning
                if !self.duplicateTriggers.isEmpty {
                    HStack(alignment: .top, spacing: 7) {
                        DatasheetStatusSquare(kind: .orange)
                            .padding(.top, 4)
                        Text("Duplicate triggers: \(self.duplicateTriggers.joined(separator: ", "))")
                            .foregroundStyle(self.palette.text2)
                    }
                    .font(.caption)
                }
            }

            // Replacement input
            VStack(alignment: .leading, spacing: 6) {
                Text("Correct Spelling (replacement)")
                    .font(.subheadline.weight(.medium))
                Text("This is what will appear in the final transcription.")
                    .font(.caption)
                    .foregroundStyle(self.palette.text2)
                TextField("MouthKeys", text: self.$replacement)
                    .dictionaryInputChrome()
                    .onSubmit { self.saveIfValid() }
            }

            Spacer()

            // Preview
            if !self.triggersText.isEmpty && !self.replacement.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PREVIEW")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(self.palette.text2)

                    FlowLayout(spacing: 6) {
                        ForEach(self.parseTriggers(), id: \.self) { trigger in
                            Text(trigger)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .foregroundStyle(self.palette.text)
                                .background(self.duplicateTriggers.contains(trigger) ? self.palette.accent.opacity(0.16) : self.palette.field)
                                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(CustomDictionaryManualEntry.replacementDisplayText(
                            CustomDictionaryManualEntry.sanitizedReplacement(self.replacement)
                        ))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(self.palette.text)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(self.palette.surface)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            }

            // Save button
            HStack {
                Spacer()
                Button("Save Changes") { self.saveIfValid() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.palette.invForeground)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(self.palette.accent)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    .disabled(!self.canSave)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500)
        .frame(minHeight: 320, idealHeight: 380, maxHeight: 420)
        .dismissTextFocusOnBackgroundTap()
        .onAppear {
            self.triggersText = self.entry.triggers.joined(separator: "\n")
            self.replacement = self.entry.replacement
        }
    }

    private func parseTriggers() -> [String] {
        CustomDictionaryManualEntry.normalizedTriggers(
            self.triggersText.components(separatedBy: .newlines)
        )
    }

    private func saveIfValid() {
        guard self.canSave else { return }

        let updatedEntry = SettingsStore.CustomDictionaryEntry(
            id: self.entry.id,
            triggers: self.parseTriggers(),
            replacement: CustomDictionaryManualEntry.sanitizedReplacement(self.replacement)
        )
        self.onSave(updatedEntry)
        self.dismiss()
    }
}
