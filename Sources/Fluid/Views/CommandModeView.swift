import SwiftUI

struct CommandModeView: View {
    @ObservedObject var service: CommandModeService
    @EnvironmentObject var appServices: AppServices
    private var asr: ASRService { self.appServices.asr }
    @ObservedObject var settings = SettingsStore.shared
    @EnvironmentObject var menuBarManager: MenuBarManager
    var onClose: (() -> Void)?
    @State private var inputText: String = ""

    // Local state for available models (derived from shared AI Settings pool)
    @State private var availableModels: [String] = []

    // UI State
    @State private var showingClearConfirmation = false
    @State private var showHowTo = false

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                self.pageHeader

                self.readinessBanner
                self.howToSection
                self.chatArea
                    .frame(height: 240)

                if let pending = self.service.pendingCommand {
                    self.pendingCommandView(pending)
                }

                self.inputArea
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(self.palette.surface)
        .onAppear {
            self.updateAvailableModels()
            // Disable notch output when using in-app UI (conversation is shared but notch shouldn't show)
            self.service.enableNotchOutput = false
        }
        .onDisappear {
            // Re-enable notch output when leaving in-app UI
            self.service.enableNotchOutput = true
        }
        .onChange(of: self.asr.finalText) { _, newText in
            if !newText.isEmpty {
                self.inputText = newText
            }
        }
        .onChange(of: self.settings.commandModeSelectedProviderID) { _, _ in
            self.updateAvailableModels()
        }
        .onChange(of: self.settings.commandModeLinkedToGlobal) { _, _ in
            self.updateAvailableModels()
        }
        .onChange(of: self.settings.selectedProviderID) { _, _ in
            self.updateAvailableModels()
        }
        .onChange(of: self.settings.selectedModelByProvider) { _, _ in
            self.updateAvailableModels()
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        ViewThatFits(in: .horizontal) {
            DatasheetSheetHeader(
                placard: "EXEC / 04",
                title: "Command Mode",
                lede: "Control your Mac with voice commands. Execute terminal commands, open apps, and more."
            ) {
                self.headerView.fixedSize()
            }
            .frame(minWidth: 650)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 0) {
                DatasheetSheetHeader(
                    placard: "EXEC / 04",
                    title: "Command Mode",
                    lede: "Control your Mac with voice commands. Execute terminal commands, open apps, and more."
                )
                self.headerView.fixedSize()
                    .padding(.bottom, 20)
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                DatasheetMonoLabel(text: "CONFIRM", color: self.palette.text2)
                Toggle("Confirm before running commands", isOn: self.$settings.commandModeConfirmBeforeExecute)
                    .labelsHidden()
                    .toggleStyle(DatasheetToggleStyle())
                    .help("Ask for confirmation before running commands")
            }
            .fixedSize()

            Rectangle().fill(self.palette.rule).frame(width: 1, height: 22).padding(.horizontal, 4)

            DatasheetBracketed(rest: false) {
                Menu {
                    let recentChats = self.service.getRecentChats()
                    if recentChats.isEmpty {
                        Text("No recent chats")
                    } else {
                        ForEach(recentChats) { chat in
                            Button {
                                if chat.id != self.service.currentChatID {
                                    self.service.switchToChat(id: chat.id)
                                }
                            } label: {
                                HStack {
                                    if chat.id == self.service.currentChatID {
                                        Image(systemName: "checkmark")
                                    }
                                    Text(chat.title).lineLimit(1)
                                    Spacer()
                                    Text(chat.relativeTimeString).foregroundStyle(self.palette.text2)
                                }
                            }
                            .disabled(self.service.isProcessing)
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .frame(width: 30, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                }
                .menuStyle(.borderlessButton)
                .help("Recent chats")
            }

            DatasheetBracketed(rest: false) {
                Button(action: { self.service.createNewChat() }) {
                    Label("New chat", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .padding(.horizontal, 9)
                        .frame(height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("New chat")
                .disabled(self.service.isProcessing)
            }

            DatasheetBracketed(rest: false) {
                Button { self.showingClearConfirmation = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .frame(width: 30, height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .help("Delete chat")
                .disabled(self.service.isProcessing)
            }
        }
        .confirmationDialog(
            "Delete this chat?",
            isPresented: self.$showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                self.service.deleteCurrentChat()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var readinessBanner: some View {
        let issue = self.settings.commandModeReadinessIssue

        return HStack(alignment: .top, spacing: 10) {
            DatasheetStatusSquare(kind: issue == nil ? .ink : .orange, size: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                DatasheetMonoLabel(
                    text: issue == nil ? "COMMAND MODE READY" : "COMMAND MODE NOT READY",
                    color: self.palette.text
                )
                Text(issue ?? "Ready for a question or command.")
                    .font(.system(size: 12))
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Group {
                if issue != nil {
                    DatasheetBracketed(rest: false) {
                        Button("AI Settings") {
                            AppNavigationRouter.shared.request(.aiEnhancements)
                        }
                        .buttonStyle(DatasheetTextButtonStyle())
                    }
                } else {
                    Text("AI Settings")
                        .frame(width: 86, height: 30)
                        .hidden()
                }
            }
            .frame(width: 86, height: 30)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.palette.field)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }
    }

    // MARK: - How To Section

    private var shortcutDisplay: String {
        self.settings.commandModeHotkeyShortcut?.displayString ?? "Not set"
    }

    private var howToSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { self.showHowTo.toggle() }
            } label: {
                HStack(spacing: 8) {
                    DatasheetMonoLabel(text: "HOW TO USE", color: self.palette.text2)
                    Spacer()
                    Image(systemName: self.showHowTo ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(self.palette.text2)
                }
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .datasheetHoverBracket()
            .padding(.horizontal, 8)
            .overlay(alignment: .top) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }

            if self.showHowTo {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        DatasheetMonoLabel(text: "SHORTCUT", color: self.palette.text2)
                        Text(self.shortcutDisplay.uppercased())
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(self.palette.text)
                            .padding(.horizontal, 7)
                            .frame(height: 24)
                            .background(self.palette.field)
                            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                        Text("Opens Command Mode. Speak, then press again to send.")
                            .font(.system(size: 12))
                            .foregroundStyle(self.palette.text2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        DatasheetMonoLabel(text: "EXAMPLES", color: self.palette.text2)
                        VStack(alignment: .leading, spacing: 4) {
                            self.howToItem("\"List files in my Downloads folder\"")
                            self.howToItem("\"Create a folder called Projects on Desktop\"")
                            self.howToItem("\"What's my IP address?\"")
                            self.howToItem("\"Open Safari\"")
                        }
                    }

                    HStack(alignment: .top, spacing: 8) {
                        DatasheetStatusSquare(kind: .orange)
                            .padding(.top, 4)
                        Text("AI can make mistakes. Avoid dangerous commands. Destructive actions ask for confirmation when that setting is enabled.")
                            .font(.system(size: 12))
                            .foregroundStyle(self.palette.text2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay { Rectangle().strokeBorder(self.palette.ruleSoft, lineWidth: 1) }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, 8)
    }

    private func howToItem(_ text: String) -> some View {
        HStack(spacing: 6) {
            DatasheetStatusSquare(kind: .outline, size: 4)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(self.palette.text)
        }
    }

    // MARK: - Chat Area

    @State private var isThinkingExpanded = false

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(self.service.conversationHistory) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if self.service.isProcessing {
                        self.processingIndicator
                            .id("processing")
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(14)
            }
            .background(self.palette.surface)
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
            .onChange(of: self.service.conversationHistory.count) { _, _ in
                self.scrollToBottom(proxy)
            }
            .onChange(of: self.service.isProcessing) { _, isProcessing in
                // Scroll when processing starts, not on every streaming update
                if isProcessing {
                    self.scrollToBottom(proxy)
                    self.isThinkingExpanded = false // Collapse thinking for new request
                }
            }
            .onChange(of: self.service.currentStep) { _, _ in
                self.scrollToBottom(proxy)
            }
            // Removed: .onChange(of: service.streamingText) - causes scroll on every token, too expensive
        }
    }

    // MARK: - Processing Indicator (Minimal with Shimmer)

    private var processingIndicator: some View {
        VStack(alignment: .leading, spacing: 10) {
            CommandShimmerText(text: self.currentStepLabel)

            if self.settings.showThinkingTokens && !self.service.streamingThinkingText.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(self.service.streamingThinkingText)
                        .font(.system(size: 10))
                        .foregroundStyle(self.palette.text2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
            }
        }
        .frame(maxWidth: 520, minHeight: 72, alignment: .leading)
        .padding(10)
        .overlay { Rectangle().strokeBorder(self.palette.ruleSoft, lineWidth: 1) }
    }

    private var currentStepLabel: String {
        guard let step = service.currentStep else { return "Working..." }
        switch step {
        case .thinking: return "Thinking..."
        case let .checking(cmd): return "Checking \(self.truncateCommand(cmd, to: 30))"
        case let .executing(cmd): return "Running \(self.truncateCommand(cmd, to: 30))"
        case .verifying: return "Verifying..."
        case let .completed(success): return success ? "Done" : "Stopped"
        }
    }

    private func truncateCommand(_ cmd: String, to limit: Int) -> String {
        if cmd.count > limit {
            return String(cmd.prefix(limit - 3)) + "..."
        }
        return cmd
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Pending Command

    private func pendingCommandView(_ pending: CommandModeService.PendingCommand) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DatasheetStatusSquare(kind: .orange, size: 8)
                DatasheetMonoLabel(text: "CONFIRM EXECUTION", color: self.palette.text)
                Spacer(minLength: 8)
                if let purpose = pending.purpose {
                    Text(purpose)
                        .font(.system(size: 11))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                    DatasheetMonoLabel(text: "COMMAND", color: self.palette.text2)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

                Text(pending.command)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(self.palette.text)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay { Rectangle().strokeBorder(self.palette.accent, lineWidth: 1) }

            HStack(spacing: 10) {
                DatasheetBracketed(rest: false) {
                    Button {
                        self.service.cancelPendingCommand()
                    } label: {
                        Text("Cancel")
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(DatasheetTextButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }

                DatasheetBracketed(rest: true) {
                    Button {
                        Task { await self.service.confirmAndExecute() }
                    } label: {
                        Label("Run Command", systemImage: "play.fill")
                    }
                    .buttonStyle(DatasheetPrimaryButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(12)
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    // MARK: - Input Area

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Type a command or ask a question...", text: self.$inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .foregroundStyle(self.palette.text)
                    .lineLimit(1...4)
                    .onSubmit {
                        self.submitCommand()
                    }

                VStack(spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            self.syncControl
                            self.providerControl
                            self.modelControl
                        }
                        .fixedSize(horizontal: true, vertical: false)

                        VStack(alignment: .leading, spacing: 8) {
                            self.syncControl
                            HStack(spacing: 8) {
                                self.providerControl
                                self.modelControl
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Spacer(minLength: 0)

                        DatasheetBracketed(rest: false) {
                            Button(action: self.toggleRecording) {
                                Image(systemName: self.asr.isRunning ? "stop.fill" : "mic")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(self.asr.isRunning ? self.palette.onAccent : self.palette.text)
                                    .frame(width: 34, height: 34)
                                    .background(self.asr.isRunning ? self.palette.accent : self.palette.surface)
                                    .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                            .disabled(self.service.isProcessing)
                            .help(self.asr.isRunning ? "Stop voice command" : "Start voice command")
                        }

                        DatasheetBracketed(rest: true) {
                            Button(action: self.submitCommand) {
                                Label("Run", systemImage: "arrow.up")
                            }
                            .buttonStyle(DatasheetPrimaryButtonStyle())
                            .disabled(!self.canSubmitCommand)
                            .opacity(self.canSubmitCommand ? 1 : 0.42)
                            .help("Run command")
                        }
                    }
                }
            }
            .padding(12)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
    }

    private var syncControl: some View {
        HStack(spacing: 7) {
            DatasheetMonoLabel(text: "SYNC", color: self.palette.text2)
            Toggle("Sync", isOn: self.$settings.commandModeLinkedToGlobal)
                .labelsHidden()
                .toggleStyle(DatasheetToggleStyle())
                .fixedSize()
                .help("Use the same provider and model selected in AI Enhancement.")
        }
        .fixedSize()
    }

    private var providerControl: some View {
        SearchableProviderPicker(
            builtInProviders: self.verifiedBuiltInProvidersList,
            savedProviders: self.verifiedSavedProviders,
            selectedProviderID: Binding(
                get: { self.settings.effectiveCommandModeProviderID },
                set: { newValue in
                    guard !self.settings.commandModeLinkedToGlobal else { return }
                    self.settings.commandModeSelectedProviderID = newValue
                    self.updateAvailableModels()
                }
            ),
            controlWidth: 140,
            controlHeight: 30
        )
        .disabled(self.settings.commandModeLinkedToGlobal)
        .opacity(self.settings.commandModeLinkedToGlobal ? 0.55 : 1)
    }

    private var modelControl: some View {
        SearchableModelPicker(
            models: self.availableModels,
            selectedModel: Binding(
                get: { self.settings.effectiveCommandModeSelectedModel },
                set: { newValue in
                    guard !self.settings.commandModeLinkedToGlobal else { return }
                    self.settings.commandModeSelectedModel = newValue
                }
            ),
            onRefresh: nil,
            isRefreshing: false,
            selectionEnabled: !self.settings.commandModeLinkedToGlobal && !self.availableModels.isEmpty,
            controlWidth: 180,
            controlHeight: 30
        )
        .disabled(self.settings.commandModeLinkedToGlobal)
    }

    // MARK: - Actions

    private var canSubmitCommand: Bool {
        !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.service.isProcessing &&
            self.settings.commandModeReadinessIssue == nil
    }

    private func toggleRecording() {
        if self.asr.isRunning {
            Task {
                let command = await self.asr.stop().trimmingCharacters(in: .whitespacesAndNewlines)
                _ = self.asr.consumeLastCompletedAudioSnapshot()
                guard !command.isEmpty else { return }
                await MainActor.run {
                    self.inputText = command
                }
                guard self.settings.commandModeReadinessIssue == nil else { return }
                await self.service.processUserCommand(command)
                await MainActor.run {
                    self.inputText = ""
                }
            }
        } else {
            Task { await self.asr.start() }
        }
    }

    private func submitCommand() {
        let text = self.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard self.settings.commandModeReadinessIssue == nil else { return }
        self.inputText = ""
        Task {
            await self.service.processUserCommand(text)
        }
    }

    private func updateAvailableModels() {
        let currentProviderID = self.settings.effectiveCommandModeProviderID
        let currentModel = self.settings.commandModeSelectedModel ?? ""
        guard !currentProviderID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.availableModels = []
            return
        }
        self.availableModels = self.settings.commandModeModels(for: currentProviderID)

        // If current model not in list, select first available
        if !self.settings.commandModeLinkedToGlobal, !self.availableModels.contains(currentModel) {
            self.settings.commandModeSelectedModel = self.availableModels.first
        }
    }

    private var builtInProvidersList: [(id: String, name: String)] {
        ModelRepository.shared.builtInProvidersList()
    }

    private var verifiedBuiltInProvidersList: [(id: String, name: String)] {
        self.builtInProvidersList.filter { self.settings.isCommandModeProviderVerified($0.id) }
    }

    private var verifiedSavedProviders: [SettingsStore.SavedProvider] {
        self.settings.savedProviders.filter { self.settings.isCommandModeProviderVerified($0.id) }
    }
}

// MARK: - Shimmer Effect (Cursor-style)

struct CommandShimmerText: View {
    let text: String
    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        Text(self.text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(self.palette.text2)
        .accessibilityLabel(Text(self.text))
    }
}

// MARK: - Message Bubble (Minimal Design)

struct MessageBubble: View {
    let message: CommandModeService.Message
    @Environment(\.datasheetPalette) private var palette
    @State private var isThinkingExpanded: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            if self.message.role == .user {
                Spacer()
                self.userMessageView
            } else {
                self.agentMessageView
                Spacer()
            }
        }
    }

    // MARK: - User Message

    private var userMessageView: some View {
        Text(self.message.content)
            .font(.system(size: 13))
            .foregroundStyle(self.palette.text)
            .padding(10)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
            .frame(maxWidth: 380, alignment: .trailing)
    }

    // MARK: - Agent Message

    private var agentMessageView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thinking section (collapsible) - only if setting is enabled
            if let thinking = message.thinking, !thinking.isEmpty, SettingsStore.shared.showThinkingTokens {
                self.thinkingSection(thinking)
            }

            // Purpose label (minimal, gray)
            if let tc = message.toolCall, let purpose = tc.purpose {
                Text(purpose)
                    .font(.system(size: 11))
                    .foregroundStyle(self.palette.text2)
            }

            // Main content
            if self.message.role == .tool {
                self.toolOutputView
            } else if let tc = message.toolCall {
                self.commandCallView(tc)
            } else if !self.message.content.isEmpty {
                self.textContentView
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    // MARK: - Thinking Section (Persisted, Collapsible)

    private func thinkingSection(_ thinking: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { self.isThinkingExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Text("Thinking")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.text2)

                    if self.isThinkingExpanded {
                        Text("\(thinking.count) chars")
                            .font(.system(size: 9))
                            .foregroundStyle(self.palette.text2.opacity(0.72))
                    }

                    Image(systemName: self.isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(self.palette.text2)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // Expanded content
            if self.isThinkingExpanded {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(thinking)
                        .font(.system(size: 10))
                        .foregroundStyle(self.palette.text2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
                .frame(maxHeight: 150)
            }
        }
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.ruleSoft, lineWidth: 1) }
    }

    // MARK: - Command Call View (Minimal)

    private func commandCallView(_ tc: CommandModeService.Message.ToolCall) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Reasoning text (if meaningful)
            if !self.message.content.isEmpty &&
                !self.message.content.lowercased().starts(with: "checking") &&
                !self.message.content.lowercased().starts(with: "executing") &&
                !self.message.content.lowercased().starts(with: "i'll")
            {
                Text(self.message.content)
                    .font(.system(size: 12))
                    .foregroundStyle(self.palette.text2)
            }

            // Command block - clean and simple
            Text(tc.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .textSelection(.enabled)
                .padding(10)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        }
    }

    // MARK: - Tool Output View (Minimal)

    private var toolOutputView: some View {
        let parsed = self.parseToolOutput(self.message.content)

        return VStack(alignment: .leading, spacing: 0) {
            // Minimal header - just status and time
            HStack(spacing: 6) {
                DatasheetStatusSquare(kind: parsed.success ? .ink : .outline)
                DatasheetMonoLabel(
                    text: parsed.success ? "SUCCESS" : "ERROR",
                    color: self.palette.text2
                )

                Spacer()

                if parsed.executionTime > 0 {
                    Text("\(parsed.executionTime)ms")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.palette.text2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // Output content (if any)
            if !parsed.output.isEmpty || parsed.error != nil {
                Rectangle().fill(self.palette.rule).frame(height: 1)
                    .padding(.horizontal, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !parsed.output.isEmpty {
                            Text(self.markdownAttributedString(from: parsed.output))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(self.palette.text)
                                .textSelection(.enabled)
                        }

                        if let error = parsed.error, !error.isEmpty {
                            Text(error)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(self.palette.text2)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            }
        }
        .background(self.palette.field)
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    // MARK: - Text Content View (Minimal)

    private var textContentView: some View {
        Text(self.markdownAttributedString(from: self.message.content))
            .font(.system(size: 13))
            .foregroundStyle(self.palette.text)
            .textSelection(.enabled)
    }

    // MARK: - Markdown Rendering

    private func markdownAttributedString(from text: String) -> AttributedString {
        do {
            let attributed = try AttributedString(
                markdown: text,
                options: AttributedString
                    .MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
            return attributed
        } catch {
            return AttributedString(text)
        }
    }

    // MARK: - Helpers

    private struct ParsedOutput {
        let success: Bool
        let output: String
        let error: String?
        let exitCode: Int
        let executionTime: Int
    }

    private func parseToolOutput(_ json: String) -> ParsedOutput {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ParsedOutput(success: false, output: json, error: nil, exitCode: -1, executionTime: 0)
        }

        return ParsedOutput(
            success: parsed["success"] as? Bool ?? false,
            output: parsed["output"] as? String ?? "",
            error: parsed["error"] as? String,
            exitCode: parsed["exitCode"] as? Int ?? 0,
            executionTime: parsed["executionTimeMs"] as? Int ?? 0
        )
    }
}
