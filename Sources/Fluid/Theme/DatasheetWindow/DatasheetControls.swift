import SwiftUI

enum DatasheetControlBracketPolicy {
    static let hoverSpec = DatasheetTheme.BracketSpec.chip
    static let toggleSwitchSize = CGSize(width: 40, height: 20)

    static func hoverIsVisible(isEnabled: Bool, isHovered: Bool) -> Bool {
        isEnabled && isHovered
    }

    static func isVisible(rest: Bool, isEnabled: Bool, isHovered: Bool) -> Bool {
        rest || self.hoverIsVisible(isEnabled: isEnabled, isHovered: isHovered)
    }

    static func opacity(rest: Bool, isEnabled: Bool, isHovered: Bool) -> Double {
        if self.hoverIsVisible(isEnabled: isEnabled, isHovered: isHovered) { return 1 }
        return rest ? 0.62 : 0
    }
}

enum DatasheetStatusSquareKind {
    case ink
    case orange
    case outline
}

struct DatasheetStatusSquare: View {
    let kind: DatasheetStatusSquareKind
    var size: CGFloat = 6

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        Group {
            switch self.kind {
            case .ink:
                Rectangle().fill(self.palette.text)
            case .orange:
                Rectangle().fill(self.palette.accent)
            case .outline:
                Rectangle().strokeBorder(self.palette.text2, lineWidth: 1)
            }
        }
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }
}

struct DatasheetMeter: View {
    let value: Int
    let count: Int
    var segmentWidth: CGFloat = 6
    var segmentHeight: CGFloat = 10
    var accentLastFilled: Bool = false

    @Environment(\.datasheetPalette) private var palette

    init(value: Int, count: Int = 10, segmentWidth: CGFloat = 6, segmentHeight: CGFloat = 10, accentLastFilled: Bool = false) {
        self.value = value
        self.count = count
        self.segmentWidth = segmentWidth
        self.segmentHeight = segmentHeight
        self.accentLastFilled = accentLastFilled
    }

    private var safeCount: Int {
        max(self.count, 0)
    }

    private var filledCount: Int {
        min(max(self.value, 0), self.safeCount)
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<self.safeCount, id: \.self) { index in
                Rectangle()
                    .fill(index < self.filledCount ? (self.accentLastFilled && index == self.filledCount - 1 ? self.palette.accent : self.palette.ink) : self.palette.surface)
                    .overlay {
                        if index >= self.filledCount {
                            Rectangle().strokeBorder(self.palette.graticule, lineWidth: 1)
                        }
                    }
                    .frame(width: self.segmentWidth, height: self.segmentHeight)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Meter")
        .accessibilityValue("\(self.filledCount) of \(self.safeCount)")
    }
}

struct DatasheetToggleStyle: ToggleStyle {
    @Environment(\.datasheetPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                DatasheetToggleSwitch(isOn: configuration.isOn)

                Text(configuration.isOn ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 24, alignment: .leading)

                configuration.label
                    .hidden()
                    .frame(width: 0, height: 0)
            }
            .frame(width: 74, height: 20, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) {
                configuration.label
            }
            .toggleStyle(.switch)
        }
    }
}

private struct DatasheetToggleSwitch: View {
    let isOn: Bool

    @Environment(\.datasheetPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: self.isOn ? .trailing : .leading) {
            Rectangle()
                .fill(self.isOn ? self.palette.invBackground : self.palette.field)
                .overlay {
                    Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                }
                .frame(width: DatasheetControlBracketPolicy.toggleSwitchSize.width, height: DatasheetControlBracketPolicy.toggleSwitchSize.height)

            Rectangle()
                .fill(self.isOn ? self.palette.surface : self.palette.text2)
                .frame(width: 12, height: 12)
                .padding(4)
        }
        .datasheetBracket(
            DatasheetControlBracketPolicy.hoverSpec,
            visible: DatasheetControlBracketPolicy.hoverIsVisible(isEnabled: self.isEnabled, isHovered: self.isHovered)
        )
        .onHover { self.isHovered = DatasheetControlBracketPolicy.hoverIsVisible(isEnabled: self.isEnabled, isHovered: $0) }
        .onChange(of: self.isEnabled) { _, enabled in
            if !enabled { self.isHovered = false }
        }
        .accessibilityHidden(true)
    }
}

struct DatasheetSegmented<Value: Hashable>: View {
    struct Choice: Identifiable {
        let value: Value
        let title: String

        var id: Value { self.value }
    }

    @Binding var selection: Value
    let choices: [Choice]
    let cellWidth: CGFloat

    @Environment(\.datasheetPalette) private var palette

    init(selection: Binding<Value>, choices: [Choice], cellWidth: CGFloat = 76) {
        self._selection = selection
        self.choices = choices
        self.cellWidth = cellWidth
    }

    var body: some View {
        DatasheetBracketed(rest: false) {
            HStack(spacing: 0) {
                ForEach(Array(self.choices.enumerated()), id: \.offset) { entry in
                    let choice = entry.element
                    if entry.offset > 0 {
                        Rectangle()
                            .fill(self.palette.edge)
                            .frame(width: 1)
                    }

                    let isSelected = self.selection == choice.value
                    Button {
                        self.selection = choice.value
                    } label: {
                        Text(choice.title.uppercased())
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(isSelected ? self.palette.invForeground : self.palette.text2)
                            .frame(width: self.cellWidth, height: 30)
                            .background(isSelected ? self.palette.invBackground : self.palette.surface)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .overlay {
                Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
            }
        }
    }
}

struct DatasheetPicker<Content: View>: View {
    let title: String
    let value: String
    let detail: String?
    let minimumWidth: CGFloat
    let content: Content

    @Environment(\.datasheetPalette) private var palette

    init(
        title: String,
        value: String,
        detail: String? = nil,
        minimumWidth: CGFloat = 240,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.minimumWidth = minimumWidth
        self.content = content()
    }

    var body: some View {
        DatasheetBracketed(rest: false) {
            ZStack {
                Menu {
                    self.content
                } label: {
                    // AppKit sizes a borderless Menu from its label's intrinsic size,
                    // ignoring SwiftUI frames on Text. A transparent, field-sized image
                    // gives the native popup the same action surface as the label below.
                    Image(nsImage: NSImage(size: NSSize(width: self.minimumWidth, height: 32)))
                        .renderingMode(.original)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .frame(width: self.minimumWidth, height: 32)
                .accessibilityLabel(self.title)
                .accessibilityValue(self.accessibilityValue)

                HStack(spacing: 0) {
                    Text(self.value)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(self.palette.text)
                        .layoutPriority(0)

                    if let detail = self.detail {
                        Text(detail.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(self.palette.text2)
                            .fixedSize()
                            .padding(.leading, 8)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(width: self.minimumWidth, height: 32, alignment: .leading)
                .background(self.palette.field)
                .overlay {
                    Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .frame(width: self.minimumWidth, height: 32)
        }
    }

    private var accessibilityValue: String {
        guard let detail = self.detail, !detail.isEmpty else { return self.value }
        return "\(self.value), \(detail.uppercased())"
    }
}

struct DatasheetSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String
    let width: CGFloat
    let readout: (Double) -> String

    @Environment(\.datasheetPalette) private var palette

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 0,
        label: String,
        width: CGFloat = 220,
        readout: @escaping (Double) -> String = { String(format: "%.1f", $0) }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.width = width
        self.readout = readout
    }

    private var fraction: CGFloat {
        guard self.range.upperBound > self.range.lowerBound else { return 0 }
        return CGFloat(min(max((self.value - self.range.lowerBound) / (self.range.upperBound - self.range.lowerBound), 0), 1))
    }

    private var displayValue: String {
        self.readout(self.value)
    }

    var body: some View {
        DatasheetBracketed(rest: false) {
            HStack(spacing: 14) {
                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        Canvas { context, size in
                            var track = Path()
                            track.move(to: CGPoint(x: 0, y: 10))
                            track.addLine(to: CGPoint(x: size.width, y: 10))
                            context.stroke(track, with: .color(self.palette.edge), lineWidth: 1)

                            let thumbCenter = self.fraction * size.width
                            let fill = Path(CGRect(x: 0, y: 9, width: thumbCenter, height: 3))
                            context.fill(fill, with: .color(self.palette.ink))

                            for index in 0...10 {
                                let x = size.width * CGFloat(index) / 10
                                let major = index.isMultiple(of: 5)
                                var tick = Path()
                                tick.move(to: CGPoint(x: x, y: 17))
                                tick.addLine(to: CGPoint(x: x, y: major ? 23 : 20))
                                context.stroke(tick, with: .color(self.palette.graticule), lineWidth: 1)
                            }
                        }

                        Rectangle()
                            .fill(self.palette.surface)
                            .frame(width: 10, height: 16)
                            .overlay {
                                Rectangle().strokeBorder(self.palette.ink, lineWidth: 1.5)
                            }
                            .offset(x: min(max(self.fraction * proxy.size.width - 5, 0), proxy.size.width - 10), y: 3)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { gesture in
                            self.setValue(at: gesture.location.x, width: proxy.size.width)
                        }
                    )
                }
                .frame(width: self.width, height: 28)

                Text(self.displayValue)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(self.palette.text)
                    .frame(width: 46, alignment: .trailing)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(self.label)
            .accessibilityValue(self.displayValue)
            .accessibilityAdjustableAction { direction in
                let amount = self.step > 0 ? self.step : (self.range.upperBound - self.range.lowerBound) / 100
                switch direction {
                case .increment: self.assign(self.value + amount)
                case .decrement: self.assign(self.value - amount)
                @unknown default: break
                }
            }
        }
    }

    private func setValue(at x: CGFloat, width: CGFloat) {
        guard width > 0, self.range.upperBound > self.range.lowerBound else { return }
        let fraction = min(max(Double(x / width), 0), 1)
        self.assign(self.range.lowerBound + fraction * (self.range.upperBound - self.range.lowerBound))
    }

    private func assign(_ rawValue: Double) {
        let rounded = self.step > 0
            ? self.range.lowerBound + ((rawValue - self.range.lowerBound) / self.step).rounded() * self.step
            : rawValue
        self.value = min(max(rounded, self.range.lowerBound), self.range.upperBound)
    }
}

struct DatasheetHotkeyWell<Content: View>: View {
    let content: Content

    @Environment(\.datasheetPalette) private var palette

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        DatasheetBracketed(rest: false) {
            self.content
                .padding(.horizontal, 6)
                .frame(minWidth: 168, minHeight: 34, alignment: .leading)
                .background(self.palette.field)
                .overlay {
                    Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
    }
}

struct DatasheetTableRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    init(isSelected: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    private var isInverted: Bool {
        self.isSelected || self.isHovered
    }

    var body: some View {
        Button(action: self.action) {
            self.content
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 16)
                .foregroundStyle(self.isInverted ? self.palette.invForeground : self.palette.text)
                .background(self.isInverted ? self.palette.invBackground : self.palette.surface)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(self.palette.ruleSoft)
                        .frame(height: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

struct DatasheetBracketed<Content: View>: View {
    let rest: Bool
    let content: Content

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    init(rest: Bool, @ViewBuilder content: () -> Content) {
        self.rest = rest
        self.content = content()
    }

    var body: some View {
        self.content
            .datasheetBracket(
                DatasheetControlBracketPolicy.hoverSpec,
                visible: DatasheetControlBracketPolicy.isVisible(
                    rest: self.rest,
                    isEnabled: self.isEnabled,
                    isHovered: self.isHovered
                ),
                opacity: DatasheetControlBracketPolicy.opacity(
                    rest: self.rest,
                    isEnabled: self.isEnabled,
                    isHovered: self.isHovered
                )
            )
            .onHover { self.isHovered = DatasheetControlBracketPolicy.hoverIsVisible(isEnabled: self.isEnabled, isHovered: $0) }
            .onChange(of: self.isEnabled) { _, enabled in
                if !enabled { self.isHovered = false }
            }
    }
}
