//
//  AISettingsView+SpeechRecognition.swift
//  fluid
//
//  Speech recognition settings in the Datasheet Mono window.
//

import SwiftUI

extension VoiceEngineSettingsView {
    var speechRecognitionCard: some View {
        let selectedModel = self.settings.selectedSpeechModel
        let activeModel = selectedModel.isInstalled ? selectedModel : nil
        let otherModels = self.viewModel.filteredSpeechModels.filter { model in
            guard let activeModel else { return true }
            return model != activeModel
        }

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DatasheetSheetHeader(
                    placard: "02 / Configure",
                    title: "Voice Engine",
                    lede: "Click a row to preview. Press Activate to load the model."
                ) {
                    HStack(spacing: 12) {
                        DatasheetPicker(
                            title: "Filter",
                            value: self.viewModel.providerFilter.rawValue,
                            minimumWidth: 142
                        ) {
                            ForEach(SpeechProviderFilter.allCases) { option in
                                Button(option.rawValue) {
                                    self.viewModel.providerFilter = option
                                }
                            }
                        }

                        DatasheetPicker(
                            title: "Sort",
                            value: self.viewModel.modelSortOption.rawValue,
                            minimumWidth: 142
                        ) {
                            ForEach(ModelSortOption.allCases) { option in
                                Button(option.rawValue) {
                                    self.viewModel.modelSortOption = option
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }

                self.modelStatsPanel

                self.sectionHeading(
                    "Active Model",
                    trailing: self.viewModel.asr.isAsrReady
                        ? "Loaded · will stay warm"
                        : (self.viewModel.asr.isDownloadingModel || self.viewModel.asr.isLoadingModel
                            ? self.viewModel.asr.modelPreparationStatusText : "No model loaded")
                )
                self.modelTableHeader
                if let activeModel {
                    self.speechModelCard(for: activeModel)
                } else {
                    HStack(spacing: 10) {
                        DatasheetStatusSquare(kind: .outline)
                        Text("No active model yet. Download and activate one below.")
                            .font(.system(size: 13))
                            .foregroundStyle(self.palette.text2)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 56)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
                    }
                }

                self.sectionHeading(
                    activeModel == nil ? "Available Models" : "Other Models",
                    trailing: "\(otherModels.count) models"
                )
                self.modelTableHeader
                ForEach(otherModels) { model in
                    self.speechModelCard(for: model)
                }

                self.fillerWordsSection
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .opacity(self.viewModel.asr.isRunning ? 0.65 : 1)
        .allowsHitTesting(!self.viewModel.asr.isRunning)
    }

    var modelStatsPanel: some View {
        let model = self.viewModel.previewSpeechModel
        let speed = Int(model.speedPercent * 100)
        let accuracy = Int(model.accuracyPercent * 100)

        return VStack(spacing: 0) {
            HStack {
                self.monoLabel("Preview · \(model.brandName)")
                Spacer()
                if let badge = model.badgeText {
                    Text(badge.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(self.palette.invForeground)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(self.palette.invBackground)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .overlay(alignment: .bottom) {
                Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
            }

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.humanReadableName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(self.palette.text)

                    self.monoLabel(model.displayName.uppercased())

                    Text(model.cardDescription)
                        .font(.system(size: 14))
                        .lineSpacing(2)
                        .foregroundStyle(self.palette.text2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let warning = model.memoryWarning {
                        Text(warning)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(self.palette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                self.previewAction(for: model)
                    .frame(width: 140, alignment: .trailing)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)

            HStack(spacing: 0) {
                self.specCell("Download Size", value: model.downloadSize)
                self.specDivider
                self.specCell("Languages", value: model.languageSupport)
                self.specDivider
                self.meterCell("Speed", value: speed)
                self.specDivider
                self.meterCell("Accuracy", value: accuracy)
                self.specDivider
                self.specCell("Runs On", value: model.requiresAppleSilicon ? "Apple Silicon" : "macOS")
            }
            .overlay(alignment: .top) {
                Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
            }

            if model.supportsCustomVocabulary {
                HStack(alignment: .center, spacing: 14) {
                    self.monoLabel("Custom Words")
                    Text("Custom Words supported on Parakeet. Teach names, product terms, and uncommon words for better accuracy.")
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundStyle(self.palette.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        NotificationCenter.default.post(name: .openCustomDictionaryFromVoiceEngine, object: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Open Custom Dictionary")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(self.palette.text)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .overlay(alignment: .top) {
                    Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
                }
            }
        }
        .background(self.palette.surface)
        .overlay {
            Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
        }
    }

    private var modelTableHeader: some View {
        HStack(spacing: 10) {
            self.monoLabel("Model").frame(maxWidth: .infinity, alignment: .leading)
            self.monoLabel("Size").frame(width: 72, alignment: .leading)
            self.monoLabel("Languages").frame(width: 112, alignment: .leading)
            self.monoLabel("Speed").frame(width: 42, alignment: .trailing)
            self.monoLabel("Acc").frame(width: 42, alignment: .trailing)
            self.monoLabel("State").frame(width: 136, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 34)
        .overlay(alignment: .top) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
        }
    }

    private func speechModelCard(for model: SettingsStore.SpeechModel) -> some View {
        let isSelected = self.viewModel.previewSpeechModel == model
        let isConfiguredActive = self.viewModel.isActiveSpeechModel(model)
        let isActive = isConfiguredActive && model.isInstalled && self.viewModel.asr.isAsrReady
        let rowText = isSelected ? self.palette.invForeground : self.palette.text
        let metaText = isSelected ? self.palette.invForeground2 : self.palette.text2

        return HStack(spacing: 10) {
            DatasheetStatusSquare(kind: self.statusKind(isActive: isActive, model: model))

            VStack(alignment: .leading, spacing: 3) {
                Text(model.humanReadableName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(rowText)
                    .lineLimit(1)

                self.monoLabel(self.speechModelSubtitle(for: model), color: metaText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            self.monoLabel(model.downloadSize, color: metaText)
                .frame(width: 72, alignment: .leading)
                .lineLimit(1)
            self.monoLabel(model.languageSupport, color: metaText)
                .frame(width: 112, alignment: .leading)
                .lineLimit(1)
            self.monoLabel("\(Int(model.speedPercent * 100))", color: metaText)
                .frame(width: 42, alignment: .trailing)
            self.monoLabel("\(Int(model.accuracyPercent * 100))", color: metaText)
                .frame(width: 42, alignment: .trailing)
            self.modelAction(for: model, isActive: isActive, isConfiguredActive: isConfiguredActive)
                .frame(width: 136, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .background(isSelected ? self.palette.invBackground : self.palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
        }
        .onTapGesture {
            self.viewModel.previewSpeechModel = model
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(model.humanReadableName), \(self.speechModelSubtitle(for: model))")
    }

    @ViewBuilder
    private func modelAction(
        for model: SettingsStore.SpeechModel,
        isActive: Bool,
        isConfiguredActive: Bool
    ) -> some View {
        if self.viewModel.downloadingModel == model {
            self.progressAction(for: model, preparation: false)
        } else if (self.viewModel.asr.isDownloadingModel || self.viewModel.asr.isLoadingModel || self.viewModel.asr.isCancellingModelPreparation),
                  isConfiguredActive,
                  !self.viewModel.asr.isAsrReady
        {
            self.progressAction(for: model, preparation: true)
        } else if model.isInstalled {
            HStack(spacing: 8) {
                if isActive {
                    self.speechModelLanguagePicker(for: model)
                        .disabled(self.viewModel.areSpeechModelActionsBlocked)
                    HStack(spacing: 5) {
                        DatasheetStatusSquare(kind: .ink)
                        self.monoLabel("Active")
                    }
                } else {
                    self.actionButton("Activate") {
                        self.viewModel.activateSpeechModel(model)
                    }
                    .disabled(self.viewModel.areSpeechModelActionsBlocked)
                }

                if !model.usesAppleLogo, self.viewModel.previewSpeechModel == model {
                    Button {
                        self.viewModel.deleteSpeechModel(model)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(self.palette.text2)
                    }
                    .buttonStyle(.plain)
                    .help("Delete this downloaded model")
                    .disabled(self.viewModel.areSpeechModelActionsBlocked)
                }
            }
        } else {
            HStack(spacing: 8) {
                if model.requiresExternalArtifacts,
                   model.externalCoreMLSpec?.sourceURL != nil
                {
                    Button {
                        self.viewModel.openExternalModelSource(for: model)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(self.palette.text2)
                    }
                    .buttonStyle(.plain)
                    .help("Open model source")
                    .disabled(self.viewModel.areSpeechModelActionsBlocked)
                } else if !self.viewModel.previewSpeechModel.isInstalled {
                    self.monoLabel("Not downloaded")
                        .lineLimit(1)
                }

                self.actionButton("Download") {
                    self.viewModel.previewSpeechModel = model
                    self.viewModel.downloadSpeechModel(model)
                }
                .disabled(self.viewModel.areSpeechModelActionsBlocked)
            }
        }
    }

    @ViewBuilder
    private func previewAction(for model: SettingsStore.SpeechModel) -> some View {
        let isConfiguredActive = self.viewModel.isActiveSpeechModel(model)
        let isActive = isConfiguredActive && model.isInstalled && self.viewModel.asr.isAsrReady

        if self.viewModel.downloadingModel == model {
            self.progressAction(for: model, preparation: false)
                .frame(minWidth: 140, alignment: .trailing)
        } else if isConfiguredActive, !self.viewModel.asr.isAsrReady,
                  self.viewModel.asr.isDownloadingModel || self.viewModel.asr.isLoadingModel || self.viewModel.asr.isCancellingModelPreparation
        {
            self.progressAction(for: model, preparation: true)
                .frame(minWidth: 140, alignment: .trailing)
        } else if model.isInstalled {
            if isActive {
                HStack(spacing: 6) {
                    DatasheetStatusSquare(kind: .orange)
                    self.monoLabel("Active Now")
                }
            } else {
                DatasheetBracketed(rest: true) {
                    self.actionButton("Activate") {
                        self.viewModel.activateSpeechModel(model)
                    }
                    .disabled(self.viewModel.areSpeechModelActionsBlocked)
                }
            }
        } else {
            DatasheetBracketed(rest: true) {
                self.actionButton("Download") {
                    self.viewModel.downloadSpeechModel(model)
                }
                .disabled(self.viewModel.areSpeechModelActionsBlocked)
            }
        }
    }

    @ViewBuilder
    private func progressAction(for model: SettingsStore.SpeechModel, preparation: Bool) -> some View {
        let cancelling = preparation
            ? self.viewModel.asr.isCancellingModelPreparation
            : self.viewModel.isCancellingModelDownload
        let progress = self.viewModel.asr.downloadProgress
        VStack(alignment: .trailing, spacing: 5) {
            if cancelling {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(self.palette.accent)
                    self.monoLabel("Cancelling…")
                }
            } else if self.viewModel.asr.modelPreparationPhase == .downloading, let progress {
                HStack(spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(self.palette.ruleSoft)
                            Rectangle().fill(self.palette.accent)
                                .frame(width: proxy.size.width * max(0, min(1, progress)))
                        }
                    }
                    .frame(width: 64, height: 4)
                    self.monoLabel("\(Int(progress * 100))%")
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(self.palette.accent)
                    self.monoLabel(self.viewModel.asr.modelPreparationStatusText)
                        .lineLimit(1)
                }
            }

            Button(cancelling ? "Cancelling…" : "Cancel") {
                if preparation {
                    self.viewModel.cancelActiveModelPreparation()
                } else {
                    self.viewModel.cancelSpeechModelDownload()
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(self.palette.text)
            .buttonStyle(.plain)
            .disabled(cancelling)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Model download progress for \(model.humanReadableName)")
    }

    private var fillerWordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.sectionHeading("Remove Filler Words")

            DatasheetRow(
                label: "Remove Filler Words",
                help: "Automatically remove filler sounds like 'um', 'uh', 'er' from transcriptions",
                showsBottomRule: false
            ) {
                Toggle("Remove Filler Words", isOn: self.$viewModel.removeFillerWordsEnabled)
                    .labelsHidden()
                    .toggleStyle(DatasheetToggleStyle())
                    .onChange(of: self.viewModel.removeFillerWordsEnabled) { _, newValue in
                        self.settings.removeFillerWordsEnabled = newValue
                    }
            }

            if self.viewModel.removeFillerWordsEnabled {
                FillerWordsEditor()
                    .padding(.top, 6)
            }
        }
        .padding(.top, 14)
    }

    private func sectionHeading(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(self.palette.text)

            Rectangle().fill(self.palette.rule).frame(height: 1)

            if let trailing {
                Text(trailing.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(self.palette.text2)
                    .fixedSize()
            }
        }
        .padding(.top, 30)
        .padding(.bottom, 8)
    }

    private func specCell(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            self.monoLabel(label)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func meterCell(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            self.monoLabel(label)
            HStack(spacing: 8) {
                DatasheetMeter(value: value / 10, count: 10, segmentWidth: 6, segmentHeight: 8)
                Text("\(value)%")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var specDivider: some View {
        Rectangle().fill(self.palette.ruleSoft).frame(width: 1)
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(self.palette.text)
                .padding(.horizontal, 10)
                .frame(minWidth: 66, minHeight: 28)
                .overlay {
                    Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func monoLabel(_ text: String, color: Color? = nil) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.45)
            .foregroundStyle(color ?? self.palette.text2)
            .lineLimit(1)
    }

    private func statusKind(isActive: Bool, model: SettingsStore.SpeechModel) -> DatasheetStatusSquareKind {
        if self.viewModel.downloadingModel == model || self.viewModel.isActiveSpeechModel(model) && !self.viewModel.asr.isAsrReady {
            return .orange
        }
        return isActive ? .ink : .outline
    }

    @ViewBuilder
    private func speechModelLanguagePicker(for model: SettingsStore.SpeechModel) -> some View {
        if model == .cohereTranscribeSixBit {
            Menu {
                ForEach(SettingsStore.CohereLanguage.allCases) { language in
                    Button {
                        guard language != self.settings.selectedCohereLanguage else { return }
                        self.settings.selectedCohereLanguage = language
                    } label: {
                        HStack {
                            Text(language.displayName)
                            if language == self.settings.selectedCohereLanguage {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                self.languageChipLabel(self.settings.selectedCohereLanguage.displayName)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
        } else if model == .nemotronOffline || model == .nemotronStreaming || model == .nemotronStreaming320 {
            Menu {
                ForEach(SettingsStore.NemotronLanguage.allCases) { language in
                    Button {
                        self.settings.selectedNemotronLanguage = language
                    } label: {
                        HStack {
                            Text(language.displayName)
                            if language == self.settings.selectedNemotronLanguage {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                self.languageChipLabel(self.settings.selectedNemotronLanguage.compactDisplayName)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.visible)
        }
    }

    private func languageChipLabel(_ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "globe")
            Text(title).lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .medium))
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(0.3)
        .foregroundStyle(self.palette.text2)
        .padding(.horizontal, 6)
        .frame(height: 24)
        .overlay {
            Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
        }
    }

    private func speechModelSubtitle(for model: SettingsStore.SpeechModel) -> String {
        switch model {
        case .nemotronStreaming, .nemotronStreaming320:
            return "Nemotron Speech 3.5 · Streaming capable"
        default:
            return "\(model.brandName) · \(model.displayName)"
        }
    }
}

extension Notification.Name {
    static let openCustomDictionaryFromVoiceEngine = Notification.Name("OpenCustomDictionaryFromVoiceEngine")
}
