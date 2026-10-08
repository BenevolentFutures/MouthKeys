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

/// Content-lane headers keep their controls labelled when the native detail is narrow.
/// The shared header remains unchanged; compact actions get their own row below its rule.
struct DatasheetContentHeader<Actions: View>: View {
    let placard: String
    let title: String
    let lede: String?
    let minimumInlineWidth: CGFloat
    let actions: Actions

    init(placard: String, title: String, lede: String? = nil, minimumInlineWidth: CGFloat = 620, @ViewBuilder actions: () -> Actions) {
        self.placard = placard
        self.title = title
        self.lede = lede
        self.minimumInlineWidth = minimumInlineWidth
        self.actions = actions()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            DatasheetSheetHeader(placard: self.placard, title: self.title, lede: self.lede) { self.actions }
                .frame(minWidth: self.minimumInlineWidth, idealWidth: self.minimumInlineWidth, maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                DatasheetSheetHeader(placard: self.placard, title: self.title, lede: self.lede)
                self.actions.padding(.bottom, 26)
            }
        }
    }
}
