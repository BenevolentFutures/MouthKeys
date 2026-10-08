import SwiftUI

struct VoiceEngineSettingsView: View {
    @ObservedObject var viewModel: VoiceEngineSettingsViewModel
    @ObservedObject var settings: SettingsStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.datasheetPalette) var palette
    @State var isShowingNemotronLanguagePicker = false
    let theme: AppTheme

    var voiceEngineTitleText: Color {
        Color(nsColor: .labelColor)
    }

    var voiceEngineSecondaryText: Color {
        self.colorScheme == .light ? Color(nsColor: .labelColor).opacity(0.90) : self.theme.palette.primaryText.opacity(0.82)
    }

    var voiceEngineTertiaryText: Color {
        self.colorScheme == .light ? Color(nsColor: .labelColor).opacity(0.85) : self.theme.palette.secondaryText
    }

    // A render fixture installs this actual View, without initiating model checks.
    private let skipsLifecycleForRender: Bool

    init(
        viewModel: VoiceEngineSettingsViewModel,
        settings: SettingsStore,
        theme: AppTheme,
        skipsLifecycleForRender: Bool = false
    ) {
        self.viewModel = viewModel
        self.settings = settings
        self.theme = theme
        self.skipsLifecycleForRender = skipsLifecycleForRender
    }

    var body: some View {
        self.speechRecognitionCard
            .onAppear {
                if !self.skipsLifecycleForRender {
                    self.viewModel.onAppear()
                }
            }
            .onChange(of: self.settings.selectedSpeechModel) { _, newValue in
                if !self.skipsLifecycleForRender {
                    self.viewModel.handleSelectedSpeechModelChange(newValue)
                }
            }
    }
}
