//
//  AISettingsView+AdvancedSettings.swift
//  fluid
//
//  Extracted from AISettingsView.swift to keep view body under lint limit.
//

import AppKit
import SwiftUI

private struct PromptCardAssignments {
    let isDefault: Bool
    let shortcutDisplay: String?
    let modelPicker: PromptCardModelPicker?
    let onMakeDefault: () -> Void
}

private struct PromptCardModelPicker {
    let summary: String
    let selectedModel: String
    let models: [String]
    let providerName: String
    let onSelectModel: (String) -> Void
    let onOpenProviders: () -> Void
}

extension AIEnhancementSettingsView {
    // MARK: - Advanced Settings Card

    var advancedSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            self.promptModeViewport(mode: .dictate)
        }
        .sheet(item: self.$viewModel.promptEditorMode) { mode in
            self.promptEditorSheet(mode: mode)
        }
    }

    var promptProfilesHelpPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                    .frame(width: 26, height: 26)
                    .background(self.palette.field)
                    .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Prompt Profiles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(self.palette.text)
                    Text("Choose the prompt behavior for dictation.")
                        .font(.system(size: 13))
                        .foregroundStyle(self.palette.text2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                self.promptProfilesHelpRow("Built-in is the normal prompt. Assign any prompt as Primary to use it with your main hotkey.")
                self.promptProfilesHelpRow("Custom prompts can be assigned globally, by app, or by shortcut.")
            }
        }
        .padding(14)
        .frame(width: 310, alignment: .leading)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private func promptProfilesHelpRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            DatasheetStatusSquare(kind: .ink, size: 4)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promptModeViewport(mode: SettingsStore.PromptMode) -> some View {
        self.promptModeSection(mode: mode)
            .frame(
                maxWidth: .infinity,
                minHeight: AISettingsLayout.promptModeMinHeight,
                alignment: .topLeading
            )
            .transaction { transaction in
                transaction.animation = nil
            }
    }

    private func promptProfileCard(
        cardKey: String,
        title: String,
        subtitle: String,
        mode: SettingsStore.PromptMode,
        isSelected: Bool,
        assignments: PromptCardAssignments? = nil,
        notice: String? = nil,
        onManage: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        isEnabled: Bool = true
    ) -> some View {
        let tone = self.palette.text
        let isHovering = self.hoveredPromptCardKey == cardKey
        let isDefaultRow = assignments?.isDefault == true
        let isSelectedRow = isDefaultRow || (assignments == nil && isSelected)
        let shape = Rectangle()

        return VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                self.promptCardIcon(
                    title: title,
                    mode: mode,
                    isSelected: isSelectedRow,
                    tone: tone
                )

                self.promptCardTitleBlock(
                    title: title,
                    subtitle: subtitle,
                    mode: mode,
                    isSelected: isSelectedRow,
                    assignments: assignments,
                    notice: notice,
                    tone: tone
                )

                Spacer(minLength: 10)

                HStack(spacing: 8) {
                    if let onManage {
                        Button {
                            onManage()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: AISettingsLayout.providerRowControlHeight, height: AISettingsLayout.providerRowControlHeight)
                        }
                        .buttonStyle(DatasheetAIButtonStyle(kind: .outline))
                        .disabled(!isEnabled)
                        .help("Configure")
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: AISettingsLayout.providerRowControlHeight, height: AISettingsLayout.providerRowControlHeight)
                        }
                        .buttonStyle(DatasheetAIButtonStyle(kind: .outline))
                        .disabled(!isEnabled)
                        .help("Delete")
                    } else {
                        Color.clear
                            .frame(width: AISettingsLayout.providerRowControlHeight, height: AISettingsLayout.providerRowControlHeight)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Line 2: config metadata chips
            if let assignments {
                self.promptCardMetadataChips(
                    assignments: assignments,
                    tone: tone,
                    isEnabled: isEnabled
                )
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .frame(minHeight: 86)
        .opacity(isEnabled ? 1 : 0.68)
        .background(
            shape
                .fill(isSelectedRow ? self.palette.invBackground : self.palette.surface)
                .overlay(
                    shape
                        .stroke(
                            isSelectedRow ? self.palette.invBackground : (isHovering ? self.palette.text2 : self.palette.edge),
                            lineWidth: 1
                        )
                )
        )
        .onHover { hovering in
            if hovering {
                self.hoveredPromptCardKey = cardKey
            } else if self.hoveredPromptCardKey == cardKey {
                self.hoveredPromptCardKey = nil
            }
        }
        .animation(nil, value: isHovering)
    }

    private func promptCardIcon(
        title: String,
        mode: SettingsStore.PromptMode,
        isSelected: Bool,
        tone: Color
    ) -> some View {
        let symbol: String
        if title.localizedCaseInsensitiveContains("default") {
            symbol = "text.bubble.fill"
        } else {
            symbol = mode.normalized == .dictate ? "quote.bubble.fill" : "text.cursor"
        }

        return ZStack {
            Rectangle()
                .fill(isSelected ? self.palette.invBackground : self.palette.field)
                .overlay { Rectangle().strokeBorder(isSelected ? self.palette.invBackground : self.palette.edge, lineWidth: 1) }

            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? self.palette.invForeground : self.palette.text2)
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    private func promptCardTitleBlock(
        title: String,
        subtitle: String,
        mode: SettingsStore.PromptMode,
        isSelected: Bool,
        assignments: PromptCardAssignments?,
        notice: String?,
        tone: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? self.palette.invForeground : self.palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                self.promptStatusTags(
                    assignments: assignments,
                    isSelected: isSelected,
                    mode: mode,
                    tone: tone
                )
            }

            if let notice {
                self.promptNoticeRow(notice)
            } else if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? self.palette.invForeground.opacity(0.75) : self.palette.text2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func promptCardMetadataChips(
        assignments: PromptCardAssignments,
        tone: Color,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 6) {
            // Provider chip
            if let modelPicker = assignments.modelPicker, !modelPicker.providerName.isEmpty {
                self.promptConfigChip(
                    systemImage: "server.rack",
                    text: modelPicker.providerName,
                    tone: tone
                )
            }

            // Model chip
            if let modelPicker = assignments.modelPicker, !modelPicker.summary.isEmpty {
                self.promptConfigChip(
                    systemImage: "cpu",
                    text: modelPicker.selectedModel.isEmpty
                        ? (modelPicker.providerName.isEmpty ? "No model" : modelPicker.summary)
                        : modelPicker.selectedModel,
                    tone: tone
                )
            }

            // Shortcut chip
            if let shortcutDisplay = assignments.shortcutDisplay {
                self.promptConfigChip(
                    systemImage: "keyboard",
                    text: shortcutDisplay,
                    tone: tone
                )
            } else {
                self.promptConfigChip(
                    systemImage: "keyboard",
                    text: "No shortcut",
                    tone: self.palette.textDim,
                    isGhost: true
                )
            }

            Spacer(minLength: 0)
        }
        .opacity(isEnabled ? 1 : 0.68)
    }

    private func promptConfigChip(
        systemImage: String,
        text: String,
        tone: Color,
        isGhost: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isGhost ? self.palette.textDim : tone)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func promptNoticeRow(_ text: String) -> some View {
        HStack(spacing: 5) {
            DatasheetStatusSquare(kind: .outline, size: 5)
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(self.palette.text2)
    }

    @ViewBuilder
    private func promptStatusTags(
        assignments: PromptCardAssignments?,
        isSelected: Bool,
        mode: SettingsStore.PromptMode,
        tone: Color
    ) -> some View {
        if assignments == nil, isSelected {
            HStack(spacing: 5) {
                DatasheetStatusSquare(kind: .ink, size: 5)
                Text("SELECTED")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(isSelected ? self.palette.invForeground : self.palette.text)
        }

        if mode.normalized == .edit {
            HStack(spacing: 5) {
                DatasheetStatusSquare(kind: .outline, size: 5)
                Text("CONTEXT: AUTO")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(self.palette.text2)
        }
    }

    private func promptStatusBadge(
        _ title: String,
        systemImage: String,
        tone: Color,
        isProminent: Bool
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            .foregroundStyle(tone)
    }

    private func promptAssignments(
        selection: SettingsStore.DictationPromptSelection
    ) -> PromptCardAssignments {
        let configuration = self.settings.dictationPromptConfiguration(for: selection)
        return PromptCardAssignments(
            isDefault: self.viewModel.isDictationPromptSelection(selection, for: .primary),
            shortcutDisplay: configuration.shortcut?.displayString,
            modelPicker: self.promptModelPicker(selection: selection),
            onMakeDefault: {
                self.viewModel.setDictationPromptSelection(selection, for: .primary)
            }
        )
    }

    private func promptEditorSelection(for mode: PromptEditorMode) -> SettingsStore.DictationPromptSelection? {
        switch mode {
        case let .defaultPrompt(promptMode):
            guard promptMode.normalized == .dictate else { return nil }
            return .default
        case let .edit(promptID):
            guard self.viewModel.draftPromptMode.normalized == .dictate else { return nil }
            return .profile(promptID)
        case .newPrompt:
            return nil
        }
    }

    private func preparePromptEditorConfigurationDraft(mode: PromptEditorMode) {
        self.promptEditorPrimarySelectionDraft = self.viewModel.dictationPromptSelection(for: .primary)

        if case .newPrompt = mode {
            let pending = self.viewModel.pendingNewPromptConfiguration
            self.promptEditorOriginalConfiguration = nil
            self.promptEditorShortcutDraft = pending?.shortcut
            let providerID = pending?.providerID.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.promptEditorProviderIDDraft = providerID.isEmpty
                ? self.viewModel.defaultVerifiedPromptProviderID()
                : providerID
            self.promptEditorModelDraft = pending?.modelName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if self.promptEditorModelDraft.isEmpty, !self.promptEditorProviderIDDraft.isEmpty {
                self.promptEditorModelDraft = self.viewModel.selectedModel(for: self.promptEditorProviderIDDraft)
            }
            return
        }

        let selection = self.promptEditorSelection(for: mode)
        let configuration = selection.map { self.settings.dictationPromptConfiguration(for: $0) }
        self.promptEditorOriginalConfiguration = configuration
        self.promptEditorShortcutDraft = configuration?.shortcut

        let providerID = configuration?.providerID.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.promptEditorProviderIDDraft = providerID.isEmpty ? self.viewModel.defaultVerifiedPromptProviderID() : providerID
        self.promptEditorModelDraft = configuration?.modelName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if self.promptEditorModelDraft.isEmpty, !self.promptEditorProviderIDDraft.isEmpty {
            self.promptEditorModelDraft = self.viewModel.selectedModel(for: self.promptEditorProviderIDDraft)
        }

        if mode.isDefault, let promptMode = mode.mode {
            self.viewModel.draftPromptMode = promptMode.normalized
        }
    }

    private func applyPromptEditorConfigurationDraft(mode: PromptEditorMode) {
        if case .newPrompt = mode {
            let providerID = self.promptEditorProviderIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelName = self.promptEditorModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            self.viewModel.pendingNewPromptConfiguration = SettingsStore.DictationPromptConfiguration(
                shortcut: self.promptEditorShortcutDraft,
                providerID: providerID,
                modelName: modelName
            )
            return
        }

        if let selection = self.promptEditorSelection(for: mode) {
            if self.promptEditorPrimarySelectionDraft == selection {
                self.viewModel.setDictationPromptSelection(selection, for: .primary)
            }
            let providerID = self.promptEditorProviderIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let modelName = self.promptEditorModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let configuration = SettingsStore.DictationPromptConfiguration(
                shortcut: self.promptEditorShortcutDraft,
                providerID: providerID,
                modelName: modelName
            )
            self.settings.setDictationPromptConfiguration(configuration, for: selection)
            NotificationCenter.default.post(name: .dictationPromptShortcutsChanged, object: nil)
        }
    }

    private func restorePromptEditorConfigurationDraft(mode: PromptEditorMode) {
        guard let selection = self.promptEditorSelection(for: mode) else { return }
        if let original = self.promptEditorOriginalConfiguration {
            self.settings.setDictationPromptConfiguration(original, for: selection)
        } else {
            self.settings.removeDictationPromptConfiguration(for: selection)
        }
        NotificationCenter.default.post(name: .dictationPromptShortcutsChanged, object: nil)
    }

    private func promptEditorAssignments(mode: PromptEditorMode) -> PromptCardAssignments? {
        if case .newPrompt = mode {
            return PromptCardAssignments(
                isDefault: false,
                shortcutDisplay: self.promptEditorShortcutDraft?.displayString,
                modelPicker: self.promptEditorModelPicker(),
                onMakeDefault: {
                    // New prompts can't be the default key until saved
                }
            )
        }

        guard let selection = self.promptEditorSelection(for: mode) else { return nil }

        return PromptCardAssignments(
            isDefault: self.promptEditorPrimarySelectionDraft == selection,
            shortcutDisplay: self.promptEditorShortcutDraft?.displayString,
            modelPicker: self.promptEditorModelPicker(),
            onMakeDefault: {
                self.promptEditorPrimarySelectionDraft = selection
            }
        )
    }

    private func promptEditorModelPicker() -> PromptCardModelPicker? {
        let providerID = self.promptEditorProviderIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !providerID.isEmpty else {
            return PromptCardModelPicker(
                summary: "Choose provider first",
                selectedModel: "",
                models: [],
                providerName: "",
                onSelectModel: { _ in },
                onOpenProviders: {
                    self.selectedConfigurationSection = .providers
                    self.expandedProviderID = nil
                }
            )
        }

        let providerName = self.viewModel.providerDisplayName(for: providerID)
        let selectedModel = self.promptEditorModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = selectedModel.isEmpty ? providerName : "\(providerName) - \(selectedModel)"

        return PromptCardModelPicker(
            summary: summary,
            selectedModel: selectedModel,
            models: self.viewModel.models(for: providerID),
            providerName: providerName,
            onSelectModel: { modelName in
                self.promptEditorModelDraft = modelName
                self.syncDraftToPendingConfig()
            },
            onOpenProviders: {
                self.selectedConfigurationSection = .providers
                self.expandedProviderID = providerID
            }
        )
    }

    private func syncDraftToPendingConfig() {
        guard self.viewModel.promptEditorMode?.isNewPrompt == true else { return }
        self.viewModel.pendingNewPromptConfiguration = SettingsStore.DictationPromptConfiguration(
            shortcut: self.promptEditorShortcutDraft,
            providerID: self.promptEditorProviderIDDraft.trimmingCharacters(in: .whitespacesAndNewlines),
            modelName: self.promptEditorModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func shouldShowPromptEditorConfigurationPanel(for mode: PromptEditorMode) -> Bool {
        if case .newPrompt = mode {
            return self.viewModel.draftPromptMode.normalized == .dictate
        }
        return self.promptEditorSelection(for: mode) != nil
    }

    private func promptEditorConfigurationPanel(mode: PromptEditorMode) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
            self.promptEditorShortcutRow(mode: mode)
            self.promptEditorProviderRow
            self.promptEditorModelRow
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private func promptEditorShortcutRow(mode: PromptEditorMode) -> some View {
        let isNewPrompt: Bool = {
            if case .newPrompt = mode { return true }
            return false
        }()
        let selection = self.promptEditorSelection(for: mode)
        let configurationKey = selection.flatMap { self.settings.dictationPromptConfigurationKey(for: $0) }
        let isRecording: Bool = {
            if isNewPrompt {
                return self.activeShortcutRecordingTarget == .newPrompt
            }
            return configurationKey.map { self.activeShortcutRecordingTarget == .dictationPrompt($0) } ?? false
        }()
        let hasShortcut = self.promptEditorShortcutDraft != nil

        return self.promptEditorConfigRow(title: "Custom shortcut", description: "Optional shortcut just for this prompt.") {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "keyboard")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.palette.accent)
                        Text("Press shortcut...")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.palette.accent)
                            .lineLimit(1)
                    } else if let shortcut = self.promptEditorShortcutDraft {
                        Image(systemName: "keyboard")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.palette.text2)
                        Text(shortcut.displayString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(self.palette.text)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "keyboard")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.palette.textDim)
                        Text("None")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.palette.textDim)
                    }
                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 9)
                .frame(width: 114, height: AISettingsLayout.controlHeight, alignment: .leading)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }

                Button {
                    self.shortcutRecordingMessage = nil
                    if isNewPrompt {
                        self.activeShortcutRecordingTarget = .newPrompt
                    } else if let configurationKey {
                        self.activeShortcutRecordingTarget = .dictationPrompt(configurationKey)
                    }
                } label: {
                    Text(isRecording ? "Recording..." : "Change")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: 70, height: AISettingsLayout.controlHeight)
                }
                .buttonStyle(DatasheetAIButtonStyle(kind: isRecording ? .orange : .outline))
                .disabled(isRecording)

                if hasShortcut {
                    Button {
                        self.promptEditorShortcutDraft = nil
                        if isNewPrompt {
                            if self.activeShortcutRecordingTarget == .newPrompt {
                                self.activeShortcutRecordingTarget = nil
                            }
                        } else if let configurationKey, self.activeShortcutRecordingTarget == .dictationPrompt(configurationKey) {
                            self.activeShortcutRecordingTarget = nil
                        }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .frame(width: 70, height: AISettingsLayout.controlHeight)
                    }
                    .buttonStyle(DatasheetAIButtonStyle(kind: .outline))
                } else {
                    Color.clear
                        .frame(width: 70, height: AISettingsLayout.controlHeight)
                }
            }
            .frame(width: AISettingsLayout.promptEditorControlColumnWidth, alignment: .leading)
        }
    }

    private var promptEditorProviderRow: some View {
        self.promptEditorConfigRow(title: "AI provider", description: "Verified providers only.") {
            Menu {
                let providers = self.viewModel.verifiedPromptProviders()
                if providers.isEmpty {
                    Text("No verified providers")
                } else {
                    ForEach(providers) { provider in
                        Button {
                            self.promptEditorProviderIDDraft = provider.id
                            let models = self.viewModel.models(for: provider.id)
                            if !models.contains(self.promptEditorModelDraft) {
                                self.promptEditorModelDraft = self.viewModel.selectedModel(for: provider.id)
                            }
                            self.syncDraftToPendingConfig()
                        } label: {
                            Label(provider.name, systemImage: provider.id == self.promptEditorProviderIDDraft ? "checkmark" : "")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(self.viewModel.providerDisplayName(for: self.promptEditorProviderIDDraft))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                }
                .padding(.horizontal, 10)
                .frame(width: AISettingsLayout.promptEditorControlColumnWidth, height: AISettingsLayout.controlHeight)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private var promptEditorModelRow: some View {
        self.promptEditorConfigRow(title: "Model", description: "Used for this prompt.") {
            HStack(spacing: 8) {
                SearchableModelPicker(
                    models: self.viewModel.models(for: self.promptEditorProviderIDDraft),
                    selectedModel: self.promptEditorModelBinding,
                    onRefresh: nil,
                    selectionEnabled: !self.viewModel.models(for: self.promptEditorProviderIDDraft).isEmpty,
                    controlWidth: AISettingsLayout.promptEditorControlColumnWidth - AISettingsLayout.providerRowControlHeight - 8,
                    controlHeight: AISettingsLayout.controlHeight
                )

                self.companionIconButton(
                    isRefreshing: self.viewModel.refreshingProviderID == self.promptEditorProviderIDDraft,
                    disabled: !self.canFetchModels(for: self.promptEditorProviderIDDraft),
                    opacity: self.canFetchModels(for: self.promptEditorProviderIDDraft) ? 1 : 0.45,
                    help: "Refresh model list"
                ) {
                    Task { await self.viewModel.fetchModels(for: self.promptEditorProviderIDDraft) }
                }
            }
        }
    }

    private var promptEditorModelBinding: Binding<String> {
        Binding(
            get: { self.promptEditorModelDraft },
            set: { newValue in
                self.promptEditorModelDraft = newValue
                self.syncDraftToPendingConfig()
            }
        )
    }

    private func promptEditorConfigRow<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .gridColumnAlignment(.leading)
            .frame(width: AISettingsLayout.promptEditorLabelColumnWidth, alignment: .leading)

            content()
                .gridColumnAlignment(.leading)
                .frame(width: AISettingsLayout.promptEditorControlColumnWidth, alignment: .leading)
        }
    }

    private func promptModelPicker(
        selection: SettingsStore.DictationPromptSelection
    ) -> PromptCardModelPicker? {
        let configuration = self.settings.dictationPromptConfiguration(for: selection)
        let configuredProviderID = configuration.providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        if SettingsStore.isRetiredProviderID(configuredProviderID) {
            // Pinned to a removed provider: dictation with this prompt stays raw until one is chosen.
            return PromptCardModelPicker(
                summary: "Provider removed, choose another",
                selectedModel: "",
                models: [],
                providerName: "",
                onSelectModel: { _ in },
                onOpenProviders: {
                    self.selectedConfigurationSection = .providers
                    self.expandedProviderID = nil
                }
            )
        }
        let providerID = configuredProviderID.isEmpty
            ? self.viewModel.selectedProviderID.trimmingCharacters(in: .whitespacesAndNewlines)
            : configuredProviderID
        guard !providerID.isEmpty else {
            return PromptCardModelPicker(
                summary: "Choose provider first",
                selectedModel: "",
                models: [],
                providerName: "",
                onSelectModel: { _ in },
                onOpenProviders: {
                    self.selectedConfigurationSection = .providers
                    self.expandedProviderID = nil
                }
            )
        }

        let providerName = self.viewModel.providerDisplayName(for: providerID)
        let configuredModel = configuration.modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedModel = configuredModel.isEmpty ? self.viewModel.selectedModel(for: providerID) : configuredModel
        let summary = selectedModel.isEmpty ? providerName : "\(providerName) - \(selectedModel)"

        return PromptCardModelPicker(
            summary: summary,
            selectedModel: selectedModel,
            models: self.viewModel.models(for: providerID),
            providerName: providerName,
            onSelectModel: { modelName in
                var updated = self.settings.dictationPromptConfiguration(for: selection)
                updated.providerID = providerID
                updated.modelName = modelName
                self.settings.setDictationPromptConfiguration(updated, for: selection)
            },
            onOpenProviders: {
                self.selectedConfigurationSection = .providers
                self.expandedProviderID = providerID
            }
        )
    }

    @ViewBuilder
    private func promptModeSection(mode: SettingsStore.PromptMode) -> some View {
        let customProfiles = self.viewModel.dictationPromptProfiles
            .filter { $0.mode.normalized == mode }
        let isSelectedAppsOnly = self.viewModel.promptRoutingScope(for: mode) == .selectedAppsOnly

        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                self.promptRoutingScopeRow(mode: mode)

                if mode.normalized == .dictate {
                    self.customPromptOnlyToggleRow
                }

                Text(
                    isSelectedAppsOnly
                        ? "Custom prompts only run in apps listed in App Overrides."
                        : "Custom prompts run based on your shortcut or the app you're in."
                )
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

                Group {
                    let defaultSelection = SettingsStore.DictationPromptSelection.default
                    self.promptProfileCard(
                        cardKey: "\(mode.normalized.rawValue)-default",
                        title: mode.normalized == .dictate ? "Built-in Default" : "Default \(self.friendlyModeName(mode))",
                        subtitle: "",
                        mode: mode,
                        isSelected: mode.normalized == .dictate
                            ? (self.viewModel.selectedPromptID(for: mode) == nil)
                            : (self.viewModel.selectedPromptID(for: mode) == nil),
                        assignments: mode.normalized == .dictate
                            ? self.promptAssignments(selection: defaultSelection)
                            : nil,
                        onManage: { self.viewModel.openDefaultPromptViewer(for: mode) },
                        isEnabled: !isSelectedAppsOnly
                    )

                    if !customProfiles.isEmpty {
                        ForEach(customProfiles) { profile in
                            let profileSelection = SettingsStore.DictationPromptSelection.profile(profile.id)
                            self.promptProfileCard(
                                cardKey: "\(profile.mode.normalized.rawValue)-\(profile.id)",
                                title: profile.name.isEmpty ? "Untitled Prompt" : profile.name,
                                subtitle: "",
                                mode: profile.mode,
                                isSelected: self.viewModel.selectedPromptID(for: profile.mode) == profile.id,
                                assignments: profile.mode.normalized == .dictate
                                    ? self.promptAssignments(selection: profileSelection)
                                    : nil,
                                onManage: { self.viewModel.openEditor(for: profile) },
                                onDelete: { self.viewModel.requestDeletePrompt(profile) },
                                isEnabled: !isSelectedAppsOnly
                            )
                        }
                    }
                }
                .opacity(isSelectedAppsOnly ? 0.5 : 1)

                self.appPromptBindingsSection(mode: mode, isEmphasized: isSelectedAppsOnly, isEnabled: true)
            }
        }
        .padding(.top, 2)
    }

    private func promptModeHintRow(mode: SettingsStore.PromptMode) -> some View {
        HStack {
            if mode.normalized == .dictate {
                Text("Default uses the main dictation shortcut. Add a custom shortcut only when a prompt needs one.")
                    .font(.system(size: 13))
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(height: AISettingsLayout.promptModeHintHeight, alignment: .topLeading)
        .padding(.horizontal, 4)
    }

    private func promptRoutingScopeRow(mode: SettingsStore.PromptMode) -> some View {
        HStack(alignment: .center, spacing: 12) {
            DatasheetSegmented(
                selection: Binding(
                    get: { self.viewModel.promptRoutingScope(for: mode) },
                    set: { self.viewModel.setPromptRoutingScope($0, for: mode) }
                ),
                choices: [
                    .init(value: .allApps, title: "All Apps"),
                    .init(value: .selectedAppsOnly, title: "Selected Apps"),
                ],
                cellWidth: 112
            )

            Spacer(minLength: 8)

            if mode.normalized == .edit {
                self.editModeInlineModelControls
            } else {
                Button {
                    self.viewModel.openNewPromptEditor(prefillMode: .dictate)
                } label: {
                    Text("+ ADD PROMPT")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(self.palette.invForeground)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(self.palette.invBackground)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 34)
        .padding(.vertical, 4)
    }

    private func selectedAppsOnlySummary(mode: SettingsStore.PromptMode) -> some View {
        HStack(spacing: 8) {
            DatasheetStatusSquare(kind: .outline)

            Text(
                mode.normalized == .dictate
                    ? "No default enhancement. Add app overrides to use prompts in selected apps."
                    : "Default edit stays built-in. App overrides can use custom prompts."
            )
            .font(.system(size: 13))
            .foregroundStyle(self.palette.text2)
            .lineLimit(1)

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private var editModeInlineModelControls: some View {
        let verified = self.editModeVerifiedProviders

        return HStack(alignment: .center, spacing: 10) {
            Text("Edit model")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(self.palette.text2)

            if verified.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("No verified chat provider")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                let providerID = self.activeEditModeProviderID
                let models = self.viewModel.models(for: providerID)
                Group {
                    Toggle("Sync", isOn: self.editModeLinkedToGlobalBinding)
                        .toggleStyle(.checkbox)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                        .onChange(of: self.settings.rewriteModeLinkedToGlobal) { _, linked in
                            if linked {
                                self.syncEditModeToGlobalSelection()
                            } else {
                                self.normalizeEditModeProviderSelection()
                            }
                        }

                    Text("Provider")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    Picker("", selection: self.editModeProviderBinding) {
                        ForEach(verified) { provider in
                            Text(provider.name).tag(provider.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: AISettingsLayout.promptInlinePickerWidth)
                    .disabled(self.settings.rewriteModeLinkedToGlobal)

                    Text("Model")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)

                    SearchableModelPicker(
                        models: models,
                        selectedModel: self.editModeModelBinding(for: providerID),
                        onRefresh: { await self.viewModel.fetchModels(for: providerID) },
                        isRefreshing: self.viewModel.refreshingProviderID == providerID,
                        refreshEnabled: !self.settings.rewriteModeLinkedToGlobal && self.canFetchModels(for: providerID),
                        selectionEnabled: !self.settings.rewriteModeLinkedToGlobal && !models.isEmpty,
                        controlWidth: AISettingsLayout.promptInlineModelWidth,
                        controlHeight: 26
                    )
                    .disabled(self.settings.rewriteModeLinkedToGlobal)
                }
                .opacity(self.settings.rewriteModeLinkedToGlobal ? 0.65 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onAppear {
            self.ensureDefaultEditModeSyncState()
            if self.settings.rewriteModeLinkedToGlobal {
                self.syncEditModeToGlobalSelection()
            } else if !verified.isEmpty {
                self.normalizeEditModeProviderSelection()
            }
        }
    }

    @ViewBuilder
    private func appPromptBindingsSection(mode: SettingsStore.PromptMode, isEmphasized: Bool = false, isEnabled: Bool = true) -> some View {
        let bindings = self.viewModel.appBindings(for: mode)
        let appTargets = self.viewModel.appBindingTargets(for: mode)
        let modeProfiles = self.viewModel.dictationPromptProfiles
            .filter { $0.mode.normalized == mode.normalized }

        DatasheetSection(letter: "", title: "App Overrides", trailing: "\(bindings.count) APPS") {
            if bindings.isEmpty {
                Text("No app overrides yet. Add one to use a different prompt for a specific app.")
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .foregroundStyle(self.palette.text2)
                    .padding(.vertical, 10)
            } else {
                ForEach(bindings) { binding in
                    self.appPromptBindingRow(
                        binding: binding,
                        mode: mode,
                        modeProfiles: modeProfiles,
                        isEnabled: isEnabled
                    )
                }
            }

            DatasheetRow(label: "Add App Override", help: "Choose a running app or select one from Applications.", showsBottomRule: false) {
                Menu {
                    if appTargets.isEmpty {
                        Text("No unassigned running apps")
                    } else {
                        ForEach(appTargets) { target in
                            Button(self.appBindingTargetMenuTitle(target)) {
                                self.viewModel.addAppPromptBinding(
                                    for: mode,
                                    appBundleID: target.bundleID,
                                    appName: target.name
                                )
                            }
                        }
                    }

                    Divider()

                    Button("Choose App…") {
                        self.viewModel.addAppPromptBindingFromFilePicker(for: mode)
                    }
                } label: {
                    Text("+ ADD APP")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(self.palette.invForeground)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(self.palette.invBackground)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.48)
            }
        }
    }

    @ViewBuilder
    private func appPromptBindingRow(
        binding: SettingsStore.AppPromptBinding,
        mode: SettingsStore.PromptMode,
        modeProfiles: [SettingsStore.DictationPromptProfile],
        isEnabled: Bool = true
    ) -> some View {
        return HStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                self.appIconView(bundleID: binding.appBundleID)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 5) {
                    Text(binding.appName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                    Text(binding.appBundleID)
                        .font(.system(size: 13))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 10)

                HStack(spacing: 8) {
                    Menu {
                        Button("Default") {
                            self.viewModel.setPromptID(nil, for: binding)
                        }

                        Divider()

                        Button("Create New Prompt…") {
                            self.viewModel.openNewPromptEditor(prefillMode: mode)
                        }

                        if !modeProfiles.isEmpty {
                            Divider()
                            ForEach(modeProfiles) { profile in
                                Button(profile.name.isEmpty ? "Untitled Prompt" : profile.name) {
                                    self.viewModel.setPromptID(profile.id, for: binding)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(self.viewModel.promptName(for: mode, promptID: binding.promptID))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(self.palette.text)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(self.palette.text2)
                        }
                        .padding(.horizontal, 10)
                        .frame(width: 200, height: AISettingsLayout.controlHeight)
                        .background(self.palette.field)
                        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)

                    Button {
                        guard isEnabled else { return }
                        self.viewModel.removeAppPromptBinding(binding)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(self.palette.text2)
                            .frame(width: AISettingsLayout.providerRowControlHeight, height: AISettingsLayout.providerRowControlHeight)
                            .background(self.palette.field)
                            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isEnabled)
                    .help("Remove app-specific override")
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: 72)
        .opacity(isEnabled ? 1 : 0.68)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    @ViewBuilder
    private func appIconView(bundleID: String) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(self.palette.text2)
                .frame(width: 24, height: 24)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        }
    }

    private var editModeVerifiedProviders: [AIEnhancementSettingsViewModel.ProviderItemData] {
        self.viewModel.cachedVerifiedProviderItems
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var editModeSelectedProviderID: String {
        let current = self.settings.rewriteModeSelectedProviderID
        if self.editModeVerifiedProviders.contains(where: { $0.id == current }) {
            return current
        }
        return self.editModeVerifiedProviders.first?.id ?? current
    }

    private var activeEditModeProviderID: String {
        if self.settings.rewriteModeLinkedToGlobal {
            return self.viewModel.selectedProviderID
        }
        return self.editModeSelectedProviderID
    }

    private var editModeLinkedToGlobalBinding: Binding<Bool> {
        Binding(
            get: { self.settings.rewriteModeLinkedToGlobal },
            set: { self.settings.rewriteModeLinkedToGlobal = $0 }
        )
    }

    private var editModeProviderBinding: Binding<String> {
        Binding(
            get: { self.activeEditModeProviderID },
            set: { newProviderID in
                guard !self.settings.rewriteModeLinkedToGlobal else { return }
                self.settings.rewriteModeSelectedProviderID = newProviderID
                let models = self.viewModel.models(for: newProviderID)
                let current = self.settings.rewriteModeSelectedModel ?? ""
                if !models.contains(current) {
                    self.settings.rewriteModeSelectedModel = models.first
                }
            }
        )
    }

    private func editModeModelBinding(for providerID: String) -> Binding<String> {
        Binding(
            get: {
                if self.settings.rewriteModeLinkedToGlobal {
                    let key = self.viewModel.providerKey(for: providerID)
                    return self.settings.selectedModelByProvider[key]
                        ?? self.settings.selectedModel
                        ?? self.viewModel.models(for: providerID).first
                        ?? ""
                }
                return self.settings.rewriteModeSelectedModel ?? self.viewModel.models(for: providerID).first ?? ""
            },
            set: { newModel in
                guard !self.settings.rewriteModeLinkedToGlobal else { return }
                self.settings.rewriteModeSelectedModel = newModel
            }
        )
    }

    private func normalizeEditModeProviderSelection() {
        guard let first = self.editModeVerifiedProviders.first else { return }
        let current = self.settings.rewriteModeSelectedProviderID
        if !self.editModeVerifiedProviders.contains(where: { $0.id == current }) {
            self.settings.rewriteModeSelectedProviderID = first.id
        }

        let providerID = self.settings.rewriteModeSelectedProviderID
        let models = self.viewModel.models(for: providerID)
        let currentModel = self.settings.rewriteModeSelectedModel ?? ""
        if !models.contains(currentModel) {
            self.settings.rewriteModeSelectedModel = models.first
        }
    }

    private func syncEditModeToGlobalSelection() {
        let global = self.viewModel.selectedProviderID
        guard !global.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.settings.rewriteModeSelectedProviderID = ""
            self.settings.rewriteModeSelectedModel = nil
            return
        }

        self.settings.rewriteModeSelectedProviderID = global

        let key = self.viewModel.providerKey(for: global)
        let model = self.settings.selectedModelByProvider[key]
            ?? self.settings.selectedModel
            ?? self.viewModel.models(for: global).first
        self.settings.rewriteModeSelectedModel = model
    }

    private func ensureDefaultEditModeSyncState() {
        // If no persisted value exists yet, default Sync to ON.
        if UserDefaults.standard.object(forKey: "RewriteModeLinkedToGlobal") == nil {
            self.settings.rewriteModeLinkedToGlobal = true
            self.syncEditModeToGlobalSelection()
        }
    }

    private func canFetchModels(for providerID: String) -> Bool {
        let apiKey = self.viewModel.providerAPIKey(for: providerID)
        let hasAPIKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let baseURL: String
        if let saved = self.viewModel.savedProviders.first(where: { $0.id == providerID }) {
            baseURL = saved.baseURL
        } else {
            baseURL = ModelRepository.shared.defaultBaseURL(for: providerID)
        }
        let trimmedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLocal = self.viewModel.isLocalEndpoint(trimmedBaseURL)

        return isLocal ? !trimmedBaseURL.isEmpty : (hasAPIKey && !trimmedBaseURL.isEmpty)
    }

    private func promptSectionDescription(for mode: SettingsStore.PromptMode) -> String {
        switch mode {
        case .dictate:
            return "Each prompt can have its own provider, model, and optional shortcut."
        case .edit, .write, .rewrite:
            return "Uses selected text as context (when text is selected) - Edit or rewrite selected text - answer questions, summarize, convert to bullets etc."
        }
    }

    private func modeAccentColor(_ mode: SettingsStore.PromptMode) -> Color {
        _ = mode
        return self.palette.accent
    }

    private func appBindingTargetMenuTitle(_ target: AIEnhancementSettingsViewModel.AppBindingTarget) -> String {
        if target.name.caseInsensitiveCompare(target.bundleID) == .orderedSame {
            return target.bundleID
        }
        return "\(target.name) (\(target.bundleID))"
    }

    private func modeSymbol(_ mode: SettingsStore.PromptMode) -> String {
        switch mode.normalized {
        case .dictate:
            return "mic.fill"
        case .edit, .write, .rewrite:
            return "square.and.pencil"
        }
    }

    private func friendlyModeName(_ mode: SettingsStore.PromptMode) -> String {
        switch mode.normalized {
        case .dictate:
            return "Dictate"
        case .edit, .write, .rewrite:
            return "Edit Text"
        }
    }

    func promptEditorSheet(mode: PromptEditorMode) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                self.promptEditorFields(mode: mode)
            }

            Rectangle().fill(self.palette.rule).frame(height: 1)
            self.promptEditorFooter(mode: mode)
        }
        .frame(minWidth: 780, idealWidth: 820, minHeight: 420, idealHeight: 700, maxHeight: 720)
        .onAppear {
            self.preparePromptEditorConfigurationDraft(mode: mode)
        }
        .onDisappear {
            self.promptTest.deactivate()
        }
        .onChange(of: self.viewModel.promptEditorSessionID) { _, _ in
            self.preparePromptEditorConfigurationDraft(mode: mode)
        }
        .onChange(of: self.activeShortcutRecordingTarget) { oldValue, newValue in
            if case .newPrompt = mode {
                if newValue == nil, oldValue != nil {
                    if let pending = self.viewModel.pendingNewPromptConfiguration {
                        self.promptEditorShortcutDraft = pending.shortcut
                    } else {
                        self.promptEditorShortcutDraft = nil
                    }
                }
                return
            }
            guard newValue == nil, oldValue != nil,
                  let selection = self.promptEditorSelection(for: mode)
            else {
                return
            }
            self.promptEditorShortcutDraft = self.settings.dictationPromptConfiguration(for: selection).shortcut
        }
        .onChange(of: self.viewModel.selectedProviderID) { _, _ in
            self.autoDisablePromptTestIfNeeded()
        }
        .onChange(of: self.viewModel.providerAPIKeys) { _, _ in
            self.autoDisablePromptTestIfNeeded()
        }
        .onChange(of: self.viewModel.savedProviders) { _, _ in
            self.autoDisablePromptTestIfNeeded()
        }
    }

    private func promptEditorFields(mode: PromptEditorMode) -> some View {
        VStack(spacing: 14) {
            self.promptEditorHeading(mode: mode)

            if self.shouldShowPromptEditorConfigurationPanel(for: mode) {
                self.promptEditorConfigurationPanel(mode: mode)
            }

            self.promptEditorNameField(isLocked: mode.isDefault)
            self.promptEditorTextField

            if self.viewModel.draftPromptMode == .dictate {
                self.baseDictationPromptReference
                self.promptTestPanel
            } else {
                self.promptEditorContextReference
                if self.promptTest.isActive {
                    Text("Prompt test mode is available only for Dictate prompts.")
                        .font(.system(size: 13))
                        .foregroundStyle(self.palette.text2)
                        .onAppear { self.promptTest.deactivate() }
                }
            }
        }
        .padding()
    }

    private func promptEditorHeading(mode: PromptEditorMode) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(self.promptEditorTitle(for: mode))
                    .font(.headline)
                if mode.isDefault {
                    Text("This is the built-in prompt. Create a custom prompt to override it.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func promptEditorTitle(for mode: PromptEditorMode) -> String {
        switch mode {
        case let .defaultPrompt(promptMode):
            return "Default \(self.friendlyModeName(promptMode)) Prompt"
        case let .newPrompt(prefillMode):
            return "New \(self.friendlyModeName(prefillMode)) Prompt"
        case .edit:
            return "Edit Prompt"
        }
    }

    private func promptEditorNameField(isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("Prompt name", text: self.$viewModel.draftPromptName)
                .textFieldStyle(.plain)
                .datasheetAIFieldChrome()
                .disabled(isLocked)
        }
    }

    private var promptEditorTextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prompt")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            PromptTextView(
                text: self.$viewModel.draftPromptText,
                isEditable: true,
                font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            )
            .id(self.viewModel.promptEditorSessionID)
            .frame(minHeight: 180)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
            .onChange(of: self.viewModel.draftPromptText) { _, newValue in
                guard self.viewModel.draftPromptMode == .dictate else { return }
                let combined = self.viewModel.combinedDraftPrompt(newValue, mode: self.viewModel.draftPromptMode)
                self.promptTest.updateDraftPromptText(combined)
            }
        }
    }

    private var promptEditorContextReference: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected text is added automatically when text is selected.")
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)

            Text("Context block added automatically:")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Text(SettingsStore.contextTemplateText())
                .font(.system(.caption2, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        }
    }

    private var promptTestPanel: some View {
        let canTest = self.viewModel.isAIPostProcessingConfiguredForDictation()
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundStyle(self.palette.accent)
                Text("Test")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            self.promptTestModeRow(canTest: canTest)
            self.promptTestStatus(canTest: canTest)
            if self.promptTest.isActive {
                if self.promptTest.isProcessing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).fixedSize()
                        Text("Processing…")
                            .font(.system(size: 13))
                            .foregroundStyle(self.palette.text2)
                    }
                }
                if !self.promptTest.lastError.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        DatasheetStatusSquare(kind: .orange)
                            .padding(.top, 4)
                        Text(self.promptTest.lastError)
                            .font(.system(size: 13))
                            .foregroundStyle(self.palette.text2)
                            .textSelection(.enabled)
                    }
                }
                self.promptTestTextPane(title: "Raw transcription", text: Binding(
                    get: { self.promptTest.lastTranscriptionText },
                    set: { _ in }
                ), minHeight: 70)
                self.promptTestTextPane(title: "Post-processed output", text: Binding(
                    get: { self.promptTest.lastOutputText },
                    set: { _ in }
                ), minHeight: 110)
            }
        }
        .padding(12)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }

    private func promptTestModeRow(canTest: Bool) -> some View {
        let hotkeyDisplay = self.settings.primaryDictationShortcutDisplayString
        return DatasheetRow(
            label: "Prompt Test Mode",
            help: "Enable with \(hotkeyDisplay). Test output appears here and is never typed into another app.",
            showsBottomRule: false
        ) {
            Toggle("Enable Test Mode", isOn: Binding(
                get: { self.promptTest.isActive },
                set: { enabled in
                    if enabled {
                        let combined = self.viewModel.combinedDraftPrompt(self.viewModel.draftPromptText, mode: self.viewModel.draftPromptMode)
                        self.promptTest.activate(draftPromptText: combined)
                    } else {
                        self.promptTest.deactivate()
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(DatasheetToggleStyle())
            .disabled(!canTest)
        }
    }

    @ViewBuilder
    private func promptTestStatus(canTest: Bool) -> some View {
        if !canTest {
            Text("Testing is disabled because AI post-processing is not configured.")
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
        } else if self.promptTest.isActive {
            Text("Press the hotkey to start/stop recording. The transcription will be post-processed using your draft prompt and shown below (nothing will be typed into other apps).")
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
        }
    }

    private func promptTestTextPane(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: minHeight)
                .scrollContentBackground(.hidden)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        }
    }

    private func promptEditorFooter(mode: PromptEditorMode) -> some View {
        HStack(spacing: 10) {
            if mode.isDefault,
               let promptMode = mode.mode,
               self.viewModel.hasDefaultPromptOverride(for: promptMode)
            {
                Button("Reset to Built-in") {
                    self.viewModel.resetDefaultPromptOverride(for: promptMode)
                    self.viewModel.openDefaultPromptViewer(for: promptMode)
                    self.preparePromptEditorConfigurationDraft(mode: .defaultPrompt(mode: promptMode))
                }
                .buttonStyle(DatasheetAIButtonStyle(kind: .outline))
                .frame(minWidth: AISettingsLayout.primaryActionMinWidth, minHeight: AISettingsLayout.controlHeight)
            }

            Spacer(minLength: 0)

            Button("Cancel") {
                self.restorePromptEditorConfigurationDraft(mode: mode)
                self.viewModel.closePromptEditor()
            }
            .buttonStyle(DatasheetAIButtonStyle(kind: .outline))
            .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)

            Button("Save") {
                self.applyPromptEditorConfigurationDraft(mode: mode)
                self.viewModel.savePromptEditor(mode: mode)
            }
            .buttonStyle(DatasheetAIButtonStyle(kind: .ink))
            .frame(minWidth: AISettingsLayout.actionMinWidth, minHeight: AISettingsLayout.controlHeight)
            .disabled(!mode.isDefault && self.viewModel.draftPromptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private var baseDictationPromptReference: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Built-in Base Prompt")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text("Reference only. Copy any parts you want into a custom prompt.")
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)

            PromptTextView(
                text: .constant(SettingsStore.baseDictationPromptText()),
                isEditable: false,
                font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            )
            .frame(height: 110)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        }
    }

    private func autoDisablePromptTestIfNeeded() {
        guard self.promptTest.isActive else { return }
        if !self.viewModel.isAIPostProcessingConfiguredForDictation() {
            self.promptTest.deactivate()
        }
    }

    func openDefaultPromptViewer(for mode: SettingsStore.PromptMode) {
        self.viewModel.openDefaultPromptViewer(for: mode)
    }

    func openNewPromptEditor(prefillMode: SettingsStore.PromptMode = .edit) {
        self.viewModel.openNewPromptEditor(prefillMode: prefillMode)
    }

    func openEditor(for profile: SettingsStore.DictationPromptProfile) {
        self.viewModel.openEditor(for: profile)
    }

    func closePromptEditor() {
        self.viewModel.closePromptEditor()
    }

    // MARK: - Prompt Test Gating

    func isAIPostProcessingConfiguredForDictation() -> Bool {
        self.viewModel.isAIPostProcessingConfiguredForDictation()
    }

    func savePromptEditor(mode: PromptEditorMode) {
        self.viewModel.savePromptEditor(mode: mode)
    }
}
