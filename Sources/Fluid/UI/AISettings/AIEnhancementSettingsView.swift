import SwiftUI

struct DatasheetAIFieldChrome: ViewModifier {
    @Environment(\.datasheetPalette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(minHeight: 32)
            .background(self.palette.field)
            .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
    }
}

extension View {
    func datasheetAIFieldChrome() -> some View {
        self.modifier(DatasheetAIFieldChrome())
    }
}

enum AIEnhancementConfigurationSection: String, CaseIterable, Identifiable {
    case providers
    case advancedPrompts

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .providers:
            return "AI Providers"
        case .advancedPrompts:
            return "Advanced Prompts"
        }
    }

    var systemImage: String {
        switch self {
        case .providers:
            return "cpu"
        case .advancedPrompts:
            return "slider.horizontal.3"
        }
    }
}

struct AIEnhancementSettingsView: View {
    @ObservedObject var viewModel: AIEnhancementSettingsViewModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var promptTest: DictationPromptTestCoordinator
    @Environment(\.datasheetPalette) var palette
    let theme: AppTheme
    @Binding var activeShortcutRecordingTarget: ShortcutRecordingTarget?
    @Binding var shortcutRecordingMessage: String?
    @State var expandedProviderID: String? = nil
    @State var providerSearchText: String = ""
    @State var selectedConfigurationSection: AIEnhancementConfigurationSection = .providers
    @State var hoveredConfigurationSection: AIEnhancementConfigurationSection?
    @State var hoveredPromptCardKey: String? = nil
    @State var selectedPromptMode: SettingsStore.PromptMode = .dictate
    @State var hoveredPromptModeKey: String? = nil
    @State var hoveredPromptScopeKey: String? = nil
    @State var isPromptProfilesHelpPresented: Bool = false
    @State var promptEditorPrimarySelectionDraft: SettingsStore.DictationPromptSelection? = nil
    @State var promptEditorShortcutDraft: HotkeyShortcut? = nil
    @State var promptEditorProviderIDDraft: String = ""
    @State var promptEditorModelDraft: String = ""
    @State var promptEditorOriginalConfiguration: SettingsStore.DictationPromptConfiguration? = nil
    // Installed render fixtures must not load credentials or normalize persisted settings.
    // Normal callers retain the original lifecycle and all action/alert modifiers.
    private let skipsLifecycleForRender: Bool

    init(
        viewModel: AIEnhancementSettingsViewModel,
        settings: SettingsStore,
        promptTest: DictationPromptTestCoordinator,
        theme: AppTheme,
        activeShortcutRecordingTarget: Binding<ShortcutRecordingTarget?> = .constant(nil),
        shortcutRecordingMessage: Binding<String?> = .constant(nil),
        initialConfigurationSection: AIEnhancementConfigurationSection = .providers,
        initialExpandedProviderID: String? = nil,
        skipsLifecycleForRender: Bool = false
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.promptTest = promptTest
        self.theme = theme
        self._activeShortcutRecordingTarget = activeShortcutRecordingTarget
        self._shortcutRecordingMessage = shortcutRecordingMessage
        self._selectedConfigurationSection = State(initialValue: initialConfigurationSection)
        self._expandedProviderID = State(initialValue: initialExpandedProviderID)
        self.skipsLifecycleForRender = skipsLifecycleForRender
    }

    var body: some View {
        self.aiConfigurationCard
            .onAppear {
                if !self.skipsLifecycleForRender {
                    self.viewModel.onAppear()
                }
            }
            .onChange(of: self.viewModel.connectionStatus) { oldValue, newValue in
                if oldValue == .success && newValue != .success {
                    self.expandedProviderID = self.viewModel.selectedProviderID
                }
            }
            .onChange(of: self.viewModel.showKeychainPermissionAlert) { _, isPresented in
                guard isPresented else { return }
                self.viewModel.presentKeychainAccessAlert(message: self.viewModel.keychainPermissionMessage)
                self.viewModel.showKeychainPermissionAlert = false
            }
            .alert("Delete Prompt?", isPresented: self.$viewModel.showingDeletePromptConfirm) {
                Button("Delete", role: .destructive) {
                    self.viewModel.deletePendingPrompt()
                }
                Button("Cancel", role: .cancel) {
                    self.viewModel.clearPendingDeletePrompt()
                }
            } message: {
                if self.viewModel.pendingDeletePromptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("This cannot be undone.")
                } else {
                    Text("Delete “\(self.viewModel.pendingDeletePromptName)”? This cannot be undone.")
                }
            }
            .alert(
                "Couldn't Add App Override",
                isPresented: Binding(
                    get: { !self.viewModel.appPromptBindingErrorMessage.isEmpty },
                    set: { isPresented in
                        if !isPresented {
                            self.viewModel.appPromptBindingErrorMessage = ""
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    self.viewModel.appPromptBindingErrorMessage = ""
                }
            } message: {
                Text(self.viewModel.appPromptBindingErrorMessage)
            }
    }

    var customPromptOnlyToggleRow: some View {
        DatasheetRow(
            label: "Send Custom Prompt Only",
            help: "For custom Dictate prompts, send your prompt without prepending the built-in dictation prompt.",
            showsBottomRule: false
        ) {
            Toggle("", isOn: Binding(
                get: { self.viewModel.sendCustomPromptOnly },
                set: { self.viewModel.setSendCustomPromptOnly($0) }
            ))
            .labelsHidden()
            .toggleStyle(DatasheetToggleStyle())
            .help("Send custom Dictate prompts without prepending the built-in dictation prompt.")
        }
    }
}
