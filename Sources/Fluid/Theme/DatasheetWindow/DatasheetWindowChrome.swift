import AppKit
import Combine
import SwiftUI

/// Own the main window's split items: a system sidebar item adds a floating glass card on
/// macOS 26. Default items keep native divider/collapse mechanics without that decoration.
struct DatasheetWindowSplitView<Sidebar: View, Detail: View>: NSViewControllerRepresentable {
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let onSidebarWidthChange: (CGFloat) -> Void
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    func makeNSViewController(context: Context) -> DatasheetMainWindowSplitController {
        let controller = DatasheetMainWindowSplitController()
        self.updateNSViewController(controller, context: context)
        return controller
    }

    func updateNSViewController(_ controller: DatasheetMainWindowSplitController, context: Context) {
        // A native hosting controller is a new SwiftUI root. Forward the full environment,
        // including the palette, services and mouse tracker, on every update.
        controller.sidebarHost.rootView = AnyView(self.sidebar().environment(\.self, context.environment))
        controller.detailHost.rootView = AnyView(self.detail().environment(\.self, context.environment))
        controller.ruleColor = NSColor(context.environment.datasheetPalette.rule)
        controller.onSidebarWidthChange = self.onSidebarWidthChange
        let visibility = self.$columnVisibility
        controller.onCollapsedChange = { collapsed in
            let next: NavigationSplitViewVisibility = collapsed ? .detailOnly : .all
            if visibility.wrappedValue != next { visibility.wrappedValue = next }
        }
        controller.setSidebarCollapsed(self.columnVisibility == .detailOnly)
    }

    static func dismantleNSViewController(_ controller: DatasheetMainWindowSplitController, coordinator _: ()) {
        controller.onSidebarWidthChange = nil
        controller.onCollapsedChange = nil
    }
}

final class DatasheetMainWindowSplitController: NSSplitViewController {
    let sidebarHost = NSHostingController(rootView: AnyView(EmptyView()))
    let detailHost = NSHostingController(rootView: AnyView(EmptyView()))
    var onSidebarWidthChange: ((CGFloat) -> Void)?
    var onCollapsedChange: ((Bool) -> Void)?
    var ruleColor: NSColor = .clear {
        didSet {
            (self.splitView as? DatasheetMainWindowSplit)?.ruleColor = self.ruleColor
            self.splitView.needsDisplay = true
        }
    }

    private var collapsedObservation: NSKeyValueObservation?
    private var resizeObserver: NSObjectProtocol?
    private var didSetInitialWidth = false
    private var lastReportedWidth: CGFloat?
    private var isUpdatingVisibility = false
    private var layoutUpdateScheduled = false
    private var desiredCollapsed = false

    init() {
        super.init(nibName: nil, bundle: nil)
        let split = DatasheetMainWindowSplit()
        split.isVertical = true
        split.dividerStyle = .thin
        self.splitView = split
        self.sidebarHost.sizingOptions = []
        self.detailHost.sizingOptions = []

        let sidebar = NSSplitViewItem(viewController: self.sidebarHost)
        sidebar.minimumThickness = 220
        sidebar.maximumThickness = 300
        sidebar.holdingPriority = .init(260)
        sidebar.canCollapse = true
        sidebar.collapseBehavior = .preferResizingSiblingsWithFixedSplitView
        self.addSplitViewItem(sidebar)

        let detail = NSSplitViewItem(viewController: self.detailHost)
        detail.holdingPriority = .init(250)
        self.addSplitViewItem(detail)

        self.resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification, object: split, queue: .main
        ) { [weak self] _ in
            self?.scheduleLayoutUpdate()
        }
        self.collapsedObservation = sidebar.observe(\.isCollapsed, options: [.new]) { [weak self] _, _ in
            guard let self, !self.isUpdatingVisibility else { return }
            self.desiredCollapsed = self.splitViewItems[0].isCollapsed
            // Avoid changing a SwiftUI binding during an AppKit/representable layout pass.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onCollapsedChange?(self.splitViewItems[0].isCollapsed)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { nil }

    deinit {
        if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
    }

    func setSidebarCollapsed(_ collapsed: Bool) {
        self.desiredCollapsed = collapsed
        self.scheduleLayoutUpdate()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        self.scheduleLayoutUpdate()
    }

    private func scheduleLayoutUpdate() {
        guard !self.layoutUpdateScheduled else { return }
        self.layoutUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.layoutUpdateScheduled = false
            guard self.view.window != nil, self.splitView.bounds.width >= 800 else { return }
            let sidebar = self.splitViewItems[0]
            if sidebar.isCollapsed != self.desiredCollapsed {
                self.isUpdatingVisibility = true
                sidebar.isCollapsed = self.desiredCollapsed
                self.isUpdatingVisibility = false
            }
            guard !sidebar.isCollapsed else { return }
            // Initial representable layout can precede the host window's final constraints.
            // Apply the ideal width after that pass, never reentrantly inside SwiftUI rendering.
            if !self.didSetInitialWidth {
                self.didSetInitialWidth = true
                self.splitView.setPosition(250, ofDividerAt: 0)
            }
            // Observe native divider changes too; parent viewDidLayout need not run for them.
            let width = self.sidebarHost.view.frame.width
            guard width > 0, self.lastReportedWidth.map({ abs($0 - width) > 0.5 }) ?? true else { return }
            self.lastReportedWidth = width
            self.onSidebarWidthChange?(width)
        }
    }
}

private final class DatasheetMainWindowSplit: NSSplitView {
    var ruleColor: NSColor = .clear
    override var dividerColor: NSColor { self.ruleColor }
}

enum DatasheetInputReadout {
    /// The microphone in use after each pick: an overlay pick held for now, else the first ranked.
    static func selectedInputUIDChanges(
        settings: SettingsStore,
        sessionPickUID: @escaping () -> String? = { nil },
        notificationCenter: NotificationCenter = .default
    ) -> AnyPublisher<String, Never> {
        notificationCenter.publisher(for: .microphonePickDidChange)
            .map { _ in sessionPickUID() ?? settings.preferredInputDeviceUID ?? "" }
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
    /// The stats alone, not the history: a dictation re-renders this once, when its words land.
    @ObservedObject private var stats = TranscriptionHistoryStore.shared.stats

    let typingWPM: Int
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    var body: some View {
        let summary = self.stats.snapshot?.today ?? TranscriptionTally()
        let hasActivity = summary.words > 0
        let formattedSaved = summary.formattedTimeSaved(typingWPM: self.typingWPM)
        let saved = formattedSaved
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        let words = self.compactWordCount(summary.words)

        Button(action: self.action) {
            HStack(spacing: 2) {
                Text("TODAY")
                    .lineLimit(1)
                    .frame(width: 34, alignment: .leading)

                Text(hasActivity ? "\(words) WORDS" : "— WORDS")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 82, alignment: .leading)

                Text("·")
                    .lineLimit(1)
                    .frame(width: 6, alignment: .center)

                Text(hasActivity ? "\(saved) SAVED" : "— SAVED")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 60, alignment: .trailing)
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
        .help(hasActivity ? "Today: \(summary.words) words · \(formattedSaved) saved - view stats" : "View your stats")
        .accessibilityLabel(hasActivity ? "Today stats: \(summary.words) words, \(formattedSaved) saved" : "Today stats")
    }

    private func compactWordCount(_ words: Int) -> String {
        guard words >= 10_000 else { return words.formatted() }

        let units: [(value: Double, suffix: String)] = [
            (1_000, "K"),
            (1_000_000, "M"),
            (1_000_000_000, "B"),
            (1_000_000_000_000, "T"),
            (1_000_000_000_000_000, "P"),
            (1_000_000_000_000_000_000, "E"),
        ]
        var unitIndex = units.lastIndex(where: { Double(words) >= $0.value }) ?? 0
        var amount = Double(words) / units[unitIndex].value
        if amount >= 999.95, unitIndex + 1 < units.count {
            unitIndex += 1
            amount = Double(words) / units[unitIndex].value
        }
        return amount.formatted(.number.precision(.fractionLength(0...1))) + units[unitIndex].suffix
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

/// The sidebar stamp with its grin following the voice: an 8 Hz clock while listening, and no
/// clock at all otherwise (it used to tick 8 times a second whenever the window was open).
struct DatasheetLiveSidebarStamp: View {
    let version: String
    let engine: String
    let input: String
    let hotkey: String
    let repositoryURL: URL

    @ObservedObject private var overlay = DatasheetOverlayModel.shared

    var body: some View {
        let isListening = self.overlay.phase == .listening
        TimelineView(.animation(minimumInterval: 0.125, paused: !isListening)) { context in
            let jaw = isListening
                ? DatasheetMenuBarMark.listeningJaw(from: self.overlay.trace, at: context.date.timeIntervalSinceReferenceDate)
                : 0
            DatasheetSidebarStamp(
                version: self.version,
                engine: self.engine,
                input: self.input,
                hotkey: self.hotkey,
                jaw: jaw * 1.5,
                repositoryURL: self.repositoryURL
            )
        }
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
    @State private var isWordmarkHovered = false

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
                        Button {
                            NSWorkspace.shared.open(self.repositoryURL)
                        } label: {
                            Text("MOUTHKEYS")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .tracking(1.04)
                                .underline(self.isWordmarkHovered)
                                .foregroundStyle(self.palette.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .buttonStyle(.plain)
                        .onHover { self.isWordmarkHovered = $0 }
                        .help("Open MouthKeys on GitHub")
                        .accessibilityLabel("MouthKeys project on GitHub")

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
