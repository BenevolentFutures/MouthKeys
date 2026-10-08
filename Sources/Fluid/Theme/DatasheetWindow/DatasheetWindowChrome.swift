import AppKit
import Combine
import SwiftUI

struct DatasheetSidebarColumnWidthReader: NSViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeNSView(context _: Context) -> NSView {
        let view = DatasheetSidebarColumnWidthView()
        view.onChange = self.onChange
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        guard let view = nsView as? DatasheetSidebarColumnWidthView else { return }
        view.onChange = self.onChange
        view.reportColumnWidth()
    }
}

private final class DatasheetSidebarColumnWidthView: NSView {
    var onChange: ((CGFloat) -> Void)?

    private var lastReportedWidth: CGFloat?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.reportColumnWidth()
    }

    override func layout() {
        super.layout()
        self.reportColumnWidth()
    }

    func reportColumnWidth() {
        guard let splitView = self.enclosingSidebarSplitView,
              let sidebarColumn = splitView.subviews.first
        else { return }

        let width = sidebarColumn.frame.width
        guard width >= 220, width <= 300,
              self.lastReportedWidth.map({ abs($0 - width) > 0.5 }) ?? true
        else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil,
                  self.lastReportedWidth.map({ abs($0 - width) > 0.5 }) ?? true
            else { return }

            self.lastReportedWidth = width
            self.onChange?(width)
        }
    }

    private var enclosingSidebarSplitView: NSSplitView? {
        var ancestor = self.superview
        while let view = ancestor {
            if let splitView = view as? NSSplitView,
               splitView.isVertical,
               splitView.subviews.count >= 2,
               let sidebarColumn = splitView.subviews.first,
               self.isDescendant(of: sidebarColumn)
            {
                return splitView
            }
            ancestor = view.superview
        }
        return nil
    }
}

enum DatasheetInputReadout {
    static func selectedInputUIDChanges(
        settings: SettingsStore,
        notificationCenter: NotificationCenter = .default
    ) -> AnyPublisher<String, Never> {
        notificationCenter.publisher(for: .microphonePickDidChange)
            .map { _ in settings.preferredInputDeviceUID ?? "" }
            .eraseToAnyPublisher()
    }

    static func name(
        selectedInputUID: String,
        connectedInputs: [AudioDevice.Device],
        savedPriority: [SettingsStore.MicrophonePriorityEntry]
    ) -> String {
        if let selectedInput = connectedInputs.first(where: { $0.uid == selectedInputUID }) {
            return selectedInput.name
        }
        if let savedInput = savedPriority.first(where: { $0.uid == selectedInputUID }) {
            return savedInput.name
        }
        return selectedInputUID.isEmpty ? "System Default" : selectedInputUID
    }
}

struct DatasheetNavRow: View {
    let index: String
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    private var isInverted: Bool {
        self.isSelected || self.isHovered
    }

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 8) {
                Text(self.index)
                    .font(DatasheetTheme.Typography.tableLabel.font)
                    .tracking(0.4)
                    .foregroundStyle(self.isInverted ? self.palette.invForeground2 : self.palette.text2)
                    .frame(width: 19, alignment: .leading)

                Image(systemName: self.systemImage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(self.isInverted ? self.palette.invForeground2 : self.palette.text2)
                    .frame(width: 16)
                    .accessibilityHidden(true)

                Text(self.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(self.isInverted ? self.palette.invForeground : self.palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(self.isInverted ? self.palette.invBackground : self.palette.sidebar)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .accessibilityLabel("\(self.index) \(self.title)")
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

struct DatasheetSidebarSectionHeader: View {
    let title: String
    var topSpacing: CGFloat = 0

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        Text(self.title.uppercased())
            .font(DatasheetTheme.Typography.tableLabel.font)
            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
            .foregroundStyle(self.palette.text2)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30, alignment: .bottom)
            .padding(.top, self.topSpacing)
    }
}

struct DatasheetWindowTitleStrip: View {
    let sidebarWidth: CGFloat
    let sidebarIsVisible: Bool
    let section: String
    let index: String
    let title: String
    let typingWPM: Int
    let theme: String
    let themeAccessibilityLabel: String
    let sidebarToggleAction: () -> Void
    let todayAction: () -> Void
    let themeAction: () -> Void
    let reportAction: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        GeometryReader { geometry in
            let leadingChromeWidth = max(self.sidebarWidth, 112)
            let availableDetailWidth = geometry.size.width - leadingChromeWidth

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: leadingChromeWidth, height: 40)
                    .overlay(alignment: .leading) {
                        DatasheetSidebarToggleButton(
                            isVisible: self.sidebarIsVisible,
                            action: self.sidebarToggleAction
                        )
                        .padding(.leading, 72)
                    }
                    .overlay(alignment: .trailing) {
                        if self.sidebarIsVisible {
                            Rectangle().fill(self.palette.rule).frame(width: 1)
                        }
                    }

                if availableDetailWidth >= 700 {
                    self.fullBreadcrumb
                } else {
                    self.compactBreadcrumb
                }

                DatasheetTodayTitleButton(typingWPM: self.typingWPM, action: self.todayAction)

                DatasheetTitleStripButton(
                    label: "THEME",
                    value: self.theme,
                    width: 100,
                    accessibilityLabel: self.themeAccessibilityLabel,
                    action: self.themeAction
                )

                DatasheetTitleStripButton(
                    label: "REPORT",
                    width: 72,
                    accessibilityLabel: "Report an issue",
                    action: self.reportAction
                )
            }
        }
        .frame(height: 40)
        .background(self.palette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
    }

    private var fullBreadcrumb: some View {
        HStack(spacing: 8) {
            Text("MOUTHKEYS")
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)

            self.separator

            Text(self.section.uppercased())
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)

            self.separator

            Text("\(self.index)  \(self.title.uppercased())")
                .fontWeight(.semibold)
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(DatasheetTheme.Typography.tableLabel.font)
        .tracking(DatasheetTheme.Typography.tableLabel.tracking)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .overlay(alignment: .leading) {
            Rectangle().fill(self.palette.rule).frame(width: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("MouthKeys / \(self.section) / \(self.index) \(self.title)")
    }

    private var compactBreadcrumb: some View {
        Text("\(self.index)  \(self.title.uppercased())")
            .font(DatasheetTheme.Typography.tableLabel.font.weight(.semibold))
            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
            .foregroundStyle(self.palette.text)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .frame(height: 40)
            .overlay(alignment: .leading) {
                Rectangle().fill(self.palette.rule).frame(width: 1)
            }
            .accessibilityLabel("MouthKeys / \(self.section) / \(self.index) \(self.title)")
    }

    private var separator: some View {
        Text("/").foregroundStyle(self.palette.graticule)
    }
}

private struct DatasheetSidebarToggleButton: View {
    let isVisible: Bool
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            Image(systemName: self.isVisible ? "sidebar.left" : "sidebar.right")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(self.isHovered ? self.palette.invForeground : self.palette.text2)
                .frame(width: 28, height: 28)
                .background(self.isHovered ? self.palette.invBackground : self.palette.surface)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .help(self.isVisible ? "Hide Sidebar" : "Show Sidebar")
        .accessibilityLabel(self.isVisible ? "Hide Sidebar" : "Show Sidebar")
    }
}

private struct DatasheetTodayTitleButton: View {
    @ObservedObject private var historyStore = TranscriptionHistoryStore.shared

    let typingWPM: Int
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    var body: some View {
        let summary = self.historyStore.todaySummary
        let hasActivity = summary.words > 0
        let saved = summary.formattedTimeSaved(typingWPM: self.typingWPM).uppercased()

        Button(action: self.action) {
            HStack(spacing: 3) {
                Text("TODAY")
                    .frame(width: 34, alignment: .leading)

                Text(hasActivity ? "\(summary.words.formatted()) WORDS" : "— WORDS")
            .frame(width: 76, alignment: .leading)

                Text("·")
                    .frame(width: 8, alignment: .center)

                Text(hasActivity ? "\(saved) SAVED" : "— SAVED")
                    .frame(width: 66, alignment: .trailing)
            }
            .font(DatasheetTheme.Typography.tableLabel.font)
            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
            .monospacedDigit()
            .foregroundStyle(self.isHovered ? self.palette.invForeground : self.palette.text2)
            .padding(.horizontal, 8)
            .frame(width: 208, height: 40)
            .background(self.isHovered ? self.palette.invBackground : self.palette.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .overlay(alignment: .leading) {
            Rectangle().fill(self.palette.rule).frame(width: 1)
        }
        .help(hasActivity ? "Today: \(summary.words) words · \(saved) saved - view stats" : "View your stats")
        .accessibilityLabel("Today stats")
    }
}

private struct DatasheetTitleStripButton: View {
    let label: String
    var value: String? = nil
    var valueWidth: CGFloat = 38
    let width: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 6) {
                Text(self.label)
                    .lineLimit(1)
                    .layoutPriority(1)

                if let value = self.value {
                    Spacer(minLength: 0)
                    Text(value.uppercased())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: self.valueWidth, alignment: .trailing)
                }
            }
            .font(DatasheetTheme.Typography.tableLabel.font)
            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
            .foregroundStyle(self.isHovered ? self.palette.invForeground : self.palette.text2)
            .padding(.horizontal, 6)
            .frame(width: self.width, height: 40, alignment: .leading)
            .background(self.isHovered ? self.palette.invBackground : self.palette.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .overlay(alignment: .leading) {
            Rectangle().fill(self.palette.rule).frame(width: 1)
        }
        .accessibilityLabel(self.accessibilityLabel)
    }
}

struct DatasheetSidebarStamp: View {
    let version: String
    let engine: String
    let input: String
    let hotkey: String
    let jaw: CGFloat
    let repositoryURL: URL

    @Environment(\.datasheetPalette) private var palette
    @State private var isGitHubHovered = false

    var body: some View {
        GeometryReader { _ in
            let markColumnWidth: CGFloat = 132

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    DatasheetGrin(jaw: self.jaw)
                        .frame(width: 108, height: 62)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .frame(width: markColumnWidth, height: 86)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(self.palette.rule).frame(width: 1)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MOUTHKEYS")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(1.04)
                            .foregroundStyle(self.palette.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text("VOICE→TEXT")
                            .font(DatasheetTheme.Typography.tableLabel.font)
                            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
                            .foregroundStyle(self.palette.text2)
                            .lineLimit(1)

                        Text("V\(self.version)")
                            .font(DatasheetTheme.Typography.tableLabel.font)
                            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
                            .foregroundStyle(self.palette.text2)
                            .lineLimit(1)

                        Button {
                            NSWorkspace.shared.open(self.repositoryURL)
                        } label: {
                            Text("GITHUB ↗")
                                .font(DatasheetTheme.Typography.tableLabel.font)
                                .tracking(DatasheetTheme.Typography.tableLabel.tracking)
                                .foregroundStyle(self.isGitHubHovered ? self.palette.invForeground : self.palette.text)
                                .padding(.horizontal, 5)
                                .frame(height: 18)
                                .background(self.isGitHubHovered ? self.palette.invBackground : self.palette.sidebar)
                                .overlay {
                                    Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .onHover { self.isGitHubHovered = $0 }
                        .accessibilityLabel("MouthKeys on GitHub")
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 86)
                }
                .frame(height: 86)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(self.palette.rule).frame(height: 1)
                }

                DatasheetStampReadoutRow(label: "ENGINE", value: self.engine)
                DatasheetStampReadoutRow(label: "INPUT", value: self.input)
                DatasheetStampReadoutRow(label: "HOTKEY", value: self.hotkey)
            }
            .background(self.palette.sidebar)
        }
        .frame(height: 164)
        .background(self.palette.sidebar)
        .overlay(alignment: .top) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct DatasheetStampReadoutRow: View {
    let label: String
    let value: String

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Text(self.label)
                .frame(width: 52, alignment: .leading)
                .foregroundStyle(self.palette.text2)

            Spacer(minLength: 0)

            Text(self.value.isEmpty ? "—" : self.value.uppercased())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(self.palette.text)
        }
        .font(DatasheetTheme.Typography.tableLabel.font)
        .tracking(DatasheetTheme.Typography.tableLabel.tracking)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
