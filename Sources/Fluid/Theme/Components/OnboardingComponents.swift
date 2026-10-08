import AppKit
import SwiftUI

struct FluidOnboardingLandingHero<Actions: View>: View {
    @Environment(\.theme) private var theme

    let eyebrow: String
    let title: String
    let accentTitle: String
    let firstDetail: String
    let secondDetail: String
    let actions: Actions

    init(
        eyebrow: String,
        title: String,
        accentTitle: String,
        firstDetail: String,
        secondDetail: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.accentTitle = accentTitle
        self.firstDetail = firstDetail
        self.secondDetail = secondDetail
        self.actions = actions()
    }

    var body: some View {
        VStack(spacing: 0) {
            FluidOnboardingAppIconMark()
                .padding(.bottom, self.eyebrow.isEmpty ? 40 : 26)

            if !self.eyebrow.isEmpty {
                Text(self.eyebrow)
                    .font(.system(size: 14, weight: .bold))
                    .tracking(4.2)
                    .foregroundStyle(FluidOnboardingLandingColors.blue.opacity(0.72))
                    .textCase(.uppercase)
                    .padding(.bottom, 16)
            }

            VStack(spacing: 4) {
                Text(self.title)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.82)

                Text(self.accentTitle)
                    .font(.system(size: 50, weight: .semibold))
                    .italic()
                    .foregroundStyle(FluidOnboardingLandingColors.blue)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
            }
            .lineLimit(1)
            .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 5)
            .padding(.bottom, 28)

            VStack(spacing: 8) {
                Text(self.firstDetail)
                Text(self.secondDetail)
            }
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.70))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.bottom, 42)

            self.actions
        }
        .padding(.horizontal, self.theme.metrics.onboardingSurface.landing.heroPadding)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct FluidOnboardingLandingBackdrop: View {
    let glowCenter: UnitPoint

    init(glowCenter: UnitPoint = UnitPoint(x: 0.5, y: 0.18)) {
        self.glowCenter = glowCenter
    }

    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.019, blue: 0.031)

            RadialGradient(
                colors: [
                    FluidOnboardingLandingColors.blue.opacity(0.18),
                    Color(red: 0.014, green: 0.032, blue: 0.068).opacity(0.30),
                    .clear,
                ],
                center: self.glowCenter,
                startRadius: 0,
                endRadius: 620
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.026),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}

struct FluidOnboardingCompactProgress: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedValue = min(max(self.value, 0), 1)
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(FluidOnboardingLandingColors.blue)
                    .frame(width: width * clampedValue)
                    .shadow(color: FluidOnboardingLandingColors.blue.opacity(0.38), radius: 8, x: 0, y: 0)
            }
        }
        .frame(width: 292, height: 4)
        .accessibilityHidden(true)
    }
}

struct FluidOnboardingCompactAppIconMark: View {
    private static let appIconImage: NSImage = NSApplication.shared.applicationIconImage
        ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    let size: CGFloat

    init(size: CGFloat = 66) {
        self.size = size
    }

    var body: some View {
        Image(nsImage: Self.appIconImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: self.size, height: self.size)
            .shadow(color: FluidOnboardingLandingColors.blue.opacity(0.45), radius: 24, x: 0, y: 0)
            .shadow(color: Color.black.opacity(0.42), radius: 14, x: 0, y: 9)
            .accessibilityHidden(true)
    }
}

struct FluidOnboardingLandingHoverTracker: NSViewRepresentable {
    let onMove: (CGPoint, CGSize) -> Void
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMove: self.onMove, onExit: self.onExit)
    }

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        context.coordinator.onMove = self.onMove
        context.coordinator.onExit = self.onExit
        view.coordinator = context.coordinator
    }

    final class Coordinator {
        var onMove: (CGPoint, CGSize) -> Void
        var onExit: () -> Void

        init(onMove: @escaping (CGPoint, CGSize) -> Void, onExit: @escaping () -> Void) {
            self.onMove = onMove
            self.onExit = onExit
        }
    }

    final class TrackingView: NSView {
        weak var coordinator: Coordinator?
        private var trackingArea: NSTrackingArea?

        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()

            if let trackingArea {
                self.removeTrackingArea(trackingArea)
            }

            let options: NSTrackingArea.Options = [
                .activeInKeyWindow,
                .inVisibleRect,
                .mouseEnteredAndExited,
                .mouseMoved,
            ]
            let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self)
            self.addTrackingArea(trackingArea)
            self.trackingArea = trackingArea
        }

        override func mouseEntered(with event: NSEvent) {
            self.report(event)
        }

        override func mouseMoved(with event: NSEvent) {
            self.report(event)
        }

        override func mouseExited(with event: NSEvent) {
            self.coordinator?.onExit()
        }

        private func report(_ event: NSEvent) {
            let location = self.convert(event.locationInWindow, from: nil)
            self.coordinator?.onMove(location, self.bounds.size)
        }
    }
}

struct FluidOnboardingLandingPrimaryButton: NSViewRepresentable {
    static let size = CGSize(width: 236, height: 56)

    let title: String
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: self.action)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = LandingPrimaryNSButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.performAction)
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false
        button.wantsLayer = true
        button.focusRingType = .none
        button.keyEquivalent = "\r"
        button.keyEquivalentModifierMask = []
        button.setAccessibilityLabel(self.title)
        button.update(title: self.title, isHighlighted: false)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = self.action

        guard let button = button as? LandingPrimaryNSButton else {
            button.title = self.title
            button.setAccessibilityLabel(self.title)
            return
        }

        button.setAccessibilityLabel(self.title)
        button.update(title: self.title, isHighlighted: button.isHighlighted)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            self.action()
        }
    }
}

private final class LandingPrimaryNSButton: NSButton {
    private static let normalColor = NSColor(srgbRed: 0.16, green: 0.49, blue: 1.0, alpha: 1.0)
    private static let highlightedColor = NSColor(srgbRed: 0.10, green: 0.40, blue: 0.92, alpha: 1.0)
    private static let hoverColor = NSColor(srgbRed: 0.20, green: 0.54, blue: 1.0, alpha: 1.0)
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    override var isHighlighted: Bool {
        didSet {
            self.update(title: self.title, isHighlighted: self.isHighlighted)
        }
    }

    override var intrinsicContentSize: NSSize {
        FluidOnboardingLandingPrimaryButton.size
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard self.isEnabled, !self.isHidden, self.alphaValue > 0, self.bounds.contains(point) else {
            return nil
        }

        return self
    }

    override func layout() {
        super.layout()
        self.layer?.cornerRadius = self.bounds.height / 2
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            self.removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: .zero, options: options, owner: self)
        self.addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        self.isHovering = true
        self.update(title: self.title, isHighlighted: self.isHighlighted)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        self.isHovering = false
        self.update(title: self.title, isHighlighted: self.isHighlighted)
    }

    func update(title: String, isHighlighted: Bool) {
        self.title = title
        self.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
        )
        self.alignment = .center
        self.layer?.masksToBounds = false
        self.layer?.backgroundColor = self.backgroundColor(isHighlighted: isHighlighted).cgColor
        self.layer?.cornerRadius = self.bounds.height > 0 ? self.bounds.height / 2 : 28
        self.layer?.shadowColor = Self.normalColor.withAlphaComponent(0.34).cgColor
        self.layer?.shadowOpacity = isHighlighted ? 0.20 : 0.34
        self.layer?.shadowRadius = isHighlighted ? 8 : 14
        self.layer?.shadowOffset = NSSize(width: 0, height: isHighlighted ? 4 : 7)
    }

    private func backgroundColor(isHighlighted: Bool) -> NSColor {
        if isHighlighted {
            return Self.highlightedColor
        }

        return self.isHovering ? Self.hoverColor : Self.normalColor
    }
}

private struct FluidOnboardingAppIconMark: View {
    private static let appIconImage: NSImage = NSApplication.shared.applicationIconImage
        ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)

    var body: some View {
        ZStack {
            Circle()
                .fill(FluidOnboardingLandingColors.blue.opacity(0.28))
                .blur(radius: 42)
                .frame(width: 188, height: 188)
                .offset(y: -16)

            FluidOnboardingPortalGlow()
                .offset(y: 58)

            Image(nsImage: Self.appIconImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 116, height: 116)
                .shadow(color: Color.black.opacity(0.56), radius: 20, x: 0, y: 15)
                .shadow(color: FluidOnboardingLandingColors.blue.opacity(0.58), radius: 36, x: 0, y: 0)
        }
        .frame(width: 360, height: 176)
        .accessibilityHidden(true)
    }
}

private struct FluidOnboardingPortalGlow: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.74),
                            FluidOnboardingLandingColors.blue.opacity(0.64),
                            FluidOnboardingLandingColors.blue.opacity(0.05),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 112
                    )
                )
                .blur(radius: 7)
                .frame(width: 230, height: 25)

            Ellipse()
                .stroke(FluidOnboardingLandingColors.blue.opacity(0.42), lineWidth: 3)
                .blur(radius: 1.4)
                .frame(width: 326, height: 35)

            Ellipse()
                .stroke(FluidOnboardingLandingColors.blue.opacity(0.24), lineWidth: 1.4)
                .frame(width: 260, height: 22)
        }
    }
}

enum FluidOnboardingLandingColors {
    static let blue = Color(red: 0.10, green: 0.46, blue: 1.0)
}

private struct OnboardingSelectableSurfaceModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let isSelected: Bool
    let cornerRadius: CGFloat?
    let padding: CGFloat?
    let selectedBorderOpacity: Double?

    func body(content: Content) -> some View {
        let surface = self.theme.metrics.onboardingSurface
        let radius = self.cornerRadius ?? surface.optionCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .padding(self.padding ?? surface.optionPadding)
            .background(
                shape
                    .fill(self.theme.palette.cardBackground.opacity(
                        self.isSelected ? surface.selectedFillOpacity : surface.normalFillOpacity
                    ))
                    .overlay(
                        shape.stroke(
                            self.isSelected
                                ? self.theme.palette.accent.opacity(self.selectedBorderOpacity ?? surface.selectedBorderOpacity)
                                : self.theme.palette.cardBorder.opacity(surface.normalBorderOpacity),
                            lineWidth: 1
                        )
                    )
            )
            .contentShape(shape)
    }
}

private struct OnboardingEditorSurfaceModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        let surface = self.theme.metrics.onboardingSurface
        let radius = self.cornerRadius ?? surface.editorCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .padding(surface.editorPadding)
            .background(
                shape
                    .fill(self.theme.palette.cardBackground)
                    .overlay(
                        shape.stroke(self.theme.palette.cardBorder.opacity(surface.editorBorderOpacity), lineWidth: 1)
                    )
            )
    }
}

private struct OnboardingProminentButtonModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let controlSize: ControlSize?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let controlSize {
            content
                .buttonStyle(.borderedProminent)
                .controlSize(controlSize)
                .tint(self.theme.palette.accent)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(self.theme.palette.accent)
        }
    }
}

private struct OnboardingSecondaryButtonModifier: ViewModifier {
    let controlSize: ControlSize?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let controlSize {
            content
                .buttonStyle(.bordered)
                .controlSize(controlSize)
        } else {
            content
                .buttonStyle(.bordered)
        }
    }
}

extension View {
    func fluidOnboardingSelectableSurface(
        isSelected: Bool,
        cornerRadius: CGFloat? = nil,
        padding: CGFloat? = nil,
        selectedBorderOpacity: Double? = nil
    ) -> some View {
        self.modifier(OnboardingSelectableSurfaceModifier(
            isSelected: isSelected,
            cornerRadius: cornerRadius,
            padding: padding,
            selectedBorderOpacity: selectedBorderOpacity
        ))
    }

    func fluidOnboardingEditorSurface(cornerRadius: CGFloat? = nil) -> some View {
        self.modifier(OnboardingEditorSurfaceModifier(cornerRadius: cornerRadius))
    }

    func fluidOnboardingProminentButton(controlSize: ControlSize? = nil) -> some View {
        self.modifier(OnboardingProminentButtonModifier(controlSize: controlSize))
    }

    func fluidOnboardingSecondaryButton(controlSize: ControlSize? = nil) -> some View {
        self.modifier(OnboardingSecondaryButtonModifier(controlSize: controlSize))
    }
}

/// Welcome-step engineering drawing, using the app's shipping grin geometry.
struct OnboardingFigureOne: View {
    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            OnboardingFigureDrawing()
                .frame(height: 181)

            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)

            HStack(spacing: 12) {
                Text("DWG / MK-01")
                Spacer(minLength: 8)
                Text("REV 01")
                Spacer(minLength: 8)
                Text("SHEET 01 OF 01")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(self.palette.text2)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Figure 1. MouthKeys grin engineering drawing, fourteen teeth, tooth twelve highlighted.")
    }
}

private struct OnboardingFigureDrawing: View {
    @Environment(\.datasheetPalette) private var palette
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            let drawing = OnboardingFigureDrawingGeometry(
                canvasSize: proxy.size,
                displayScale: self.displayScale
            )
            let calloutWidth = max(0, proxy.size.width - drawing.calloutX - 8)

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    var centerline = Path()
                    centerline.move(to: CGPoint(x: drawing.bounds.minX - 16, y: drawing.centerlineY))
                    centerline.addLine(to: CGPoint(x: drawing.bounds.maxX + 16, y: drawing.centerlineY))
                    context.stroke(
                        centerline,
                        with: .color(self.palette.graticule),
                        style: StrokeStyle(lineWidth: 1, dash: [10, 3, 2, 3])
                    )
                }

                DatasheetGrin()
                    .frame(width: drawing.grinFrame.width, height: drawing.grinFrame.height)
                    .position(x: drawing.grinFrame.midX, y: drawing.grinFrame.midY)

                Canvas { context, _ in
                    self.drawDimensions(drawing, in: &context)
                    self.drawCalloutLeaders(drawing, in: &context)
                }

                ForEach(0..<7, id: \.self) { index in
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.palette.text2)
                        .position(x: drawing.upperToothCenters[index].x, y: drawing.upperLabelY - 5)

                    Text(String(format: "%02d", index + 8))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(index + 8 == 12 ? self.palette.accent : self.palette.text2)
                        .position(x: drawing.lowerToothCenters[index].x, y: drawing.lowerLabelY - 5)
                }

                Text("43.4 · 7 KEYS × 6.4 PITCH")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .frame(width: 174, height: 12)
                    .background(self.palette.surface)
                    .position(x: drawing.bounds.midX, y: drawing.widthDimensionY - 1)

                Text("21.3")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text2)
                    .background(self.palette.surface)
                    .rotationEffect(.degrees(-90))
                    .position(x: drawing.heightDimensionX - 8, y: drawing.bounds.midY)

                self.callout("KEYCAP · PLAN VIEW", detail: "FACE INSET 0.22 · 4 CHAMFERS")
                    .frame(width: calloutWidth, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(self.palette.surface)
                    .position(x: drawing.calloutX + calloutWidth / 2, y: drawing.keycapCalloutCenterY)

                self.callout("BITE 3.0 · SMILE 2.5", detail: "CENTRE LINE THROUGH THE BITE")
                    .frame(width: calloutWidth, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(self.palette.surface)
                    .position(x: drawing.calloutX + calloutWidth / 2, y: drawing.biteCalloutCenterY)

                self.callout("TOOTH 12 · GOLD", detail: "THE ONE COLOUR · #FF4F1F", isLive: true)
                    .frame(width: calloutWidth, alignment: .leading)
                    .padding(.horizontal, 4)
                    .background(self.palette.surface)
                    .position(x: drawing.calloutX + calloutWidth / 2, y: drawing.goldCalloutCenterY)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private func callout(_ title: String, detail: String, isLive: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isLive {
                    DatasheetStatusSquare(kind: .orange, size: 5)
                }
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.35)
                    .foregroundStyle(self.palette.text)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)

            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.25)
                .foregroundStyle(self.palette.text2)
                .lineLimit(2)
        }
    }

    private func drawDimensions(_ drawing: OnboardingFigureDrawingGeometry, in context: inout GraphicsContext) {
        var path = Path()
        path.move(to: CGPoint(x: drawing.bounds.minX, y: drawing.widthExtensionStartY))
        path.addLine(to: CGPoint(x: drawing.bounds.minX, y: drawing.widthDimensionY + 5))
        path.move(to: CGPoint(x: drawing.bounds.maxX, y: drawing.widthExtensionStartY))
        path.addLine(to: CGPoint(x: drawing.bounds.maxX, y: drawing.widthDimensionY + 5))
        path.move(to: CGPoint(x: drawing.bounds.minX, y: drawing.widthDimensionY))
        path.addLine(to: CGPoint(x: drawing.bounds.maxX, y: drawing.widthDimensionY))

        path.move(to: CGPoint(x: drawing.bounds.minX, y: drawing.widthDimensionY - 4))
        path.addLine(to: CGPoint(x: drawing.bounds.minX + 6, y: drawing.widthDimensionY))
        path.move(to: CGPoint(x: drawing.bounds.minX, y: drawing.widthDimensionY + 4))
        path.addLine(to: CGPoint(x: drawing.bounds.minX + 6, y: drawing.widthDimensionY))
        path.move(to: CGPoint(x: drawing.bounds.maxX, y: drawing.widthDimensionY - 4))
        path.addLine(to: CGPoint(x: drawing.bounds.maxX - 6, y: drawing.widthDimensionY))
        path.move(to: CGPoint(x: drawing.bounds.maxX, y: drawing.widthDimensionY + 4))
        path.addLine(to: CGPoint(x: drawing.bounds.maxX - 6, y: drawing.widthDimensionY))

        path.move(to: CGPoint(x: drawing.bounds.minX - 8, y: drawing.closedBounds.minY))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX - 5, y: drawing.closedBounds.minY))
        path.move(to: CGPoint(x: drawing.bounds.minX - 8, y: drawing.closedBounds.maxY))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX - 5, y: drawing.closedBounds.maxY))
        path.move(to: CGPoint(x: drawing.heightDimensionX, y: drawing.closedBounds.minY))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX, y: drawing.closedBounds.maxY))

        path.move(to: CGPoint(x: drawing.heightDimensionX - 4, y: drawing.closedBounds.minY + 6))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX, y: drawing.closedBounds.minY))
        path.move(to: CGPoint(x: drawing.heightDimensionX + 4, y: drawing.closedBounds.minY + 6))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX, y: drawing.closedBounds.minY))
        path.move(to: CGPoint(x: drawing.heightDimensionX - 4, y: drawing.closedBounds.maxY - 6))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX, y: drawing.closedBounds.maxY))
        path.move(to: CGPoint(x: drawing.heightDimensionX + 4, y: drawing.closedBounds.maxY - 6))
        path.addLine(to: CGPoint(x: drawing.heightDimensionX, y: drawing.closedBounds.maxY))

        context.stroke(path, with: .color(self.palette.text2), lineWidth: 1)
    }

    private func drawCalloutLeaders(_ drawing: OnboardingFigureDrawingGeometry, in context: inout GraphicsContext) {
        var path = Path()

        let keycap = drawing.upperTooth(index: 5)
        let keycapAnchor = CGPoint(x: keycap.midX, y: keycap.minY + keycap.height * 0.35)
        path.addEllipse(in: CGRect(x: keycapAnchor.x - 2, y: keycapAnchor.y - 2, width: 4, height: 4))
        path.move(to: keycapAnchor)
        path.addLine(to: CGPoint(x: drawing.calloutX - 8, y: drawing.keycapCalloutY))
        path.addLine(to: CGPoint(x: drawing.calloutX - 2, y: drawing.keycapCalloutY))

        let biteX = drawing.bounds.maxX + 12
        let biteTop = drawing.point(x: 0, y: 32 - 1.5 + SelfFigureMasterGeometry.smile[0]).y
        let biteBottom = drawing.point(x: 0, y: 32 + 1.5 + SelfFigureMasterGeometry.smile[0]).y
        path.move(to: CGPoint(x: drawing.bounds.maxX + 6, y: biteTop))
        path.addLine(to: CGPoint(x: biteX, y: biteTop))
        path.addLine(to: CGPoint(x: biteX, y: biteBottom))
        path.addLine(to: CGPoint(x: drawing.calloutX - 8, y: drawing.biteCalloutY))
        path.addLine(to: CGPoint(x: drawing.calloutX - 2, y: drawing.biteCalloutY))

        let gold = drawing.lowerTooth(index: 4)
        let goldAnchor = CGPoint(x: gold.midX, y: gold.midY)
        let goldLeaderY = drawing.point(x: 0, y: 41).y
        path.move(to: goldAnchor)
        path.addLine(to: CGPoint(x: goldAnchor.x, y: goldLeaderY))
        path.addLine(to: CGPoint(x: drawing.calloutX - 8, y: goldLeaderY))
        path.addLine(to: CGPoint(x: drawing.calloutX - 2, y: drawing.goldCalloutTargetY))

        context.stroke(path, with: .color(self.palette.text2), lineWidth: 1)

        let goldMarker = CGRect(x: goldAnchor.x - 3, y: goldLeaderY - 3, width: 6, height: 6)
        context.stroke(Path(goldMarker), with: .color(self.palette.text), lineWidth: 1.5)
    }
}

private enum SelfFigureMasterGeometry {
    static let teeth = 7
    static let toothWidth: CGFloat = 5
    static let pitch: CGFloat = 6.4
    static let gap: CGFloat = 3
    static let upper: [CGFloat] = [5, 8, 9, 9, 9, 8, 5]
    static let lower: [CGFloat] = [4, 7, 9, 9, 9, 7, 4]
    static let smile: [CGFloat] = [-2.5, -1, -0.3, 0, -0.3, -1, -2.5]

    static let x0 = 32 - (CGFloat(Self.teeth - 1) * Self.pitch + Self.toothWidth) / 2
    static let closedBounds: CGRect = {
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for index in 0..<Self.teeth {
            let upperY = 32 - Self.gap / 2 - Self.upper[index] + Self.smile[index]
            let lowerY = 32 + Self.gap / 2 + Self.smile[index]
            minY = min(minY, upperY)
            maxY = max(maxY, max(upperY + Self.upper[index], lowerY + Self.lower[index]))
        }
        return CGRect(
            x: Self.x0,
            y: minY,
            width: CGFloat(Self.teeth - 1) * Self.pitch + Self.toothWidth,
            height: maxY - minY
        )
    }()
}

private struct OnboardingFigureDrawingGeometry {
    let grinFrame: CGRect
    let origin: CGPoint
    let layout: DatasheetGrinLayout
    let canvasSize: CGSize

    private let sourceBounds = SelfFigureMasterGeometry.closedBounds

    init(canvasSize: CGSize, displayScale: CGFloat) {
        self.canvasSize = canvasSize
        let frameWidth = min(320, max(0, canvasSize.width * 0.52))
        let frameHeight = min(110, canvasSize.height)
        self.grinFrame = CGRect(x: 0, y: (canvasSize.height - frameHeight) / 2, width: frameWidth, height: frameHeight)
        self.layout = DatasheetGrinGeometry.layout(in: self.grinFrame.size, displayScale: displayScale)
        let drawnSize = CGSize(
            width: self.layout.viewport.width * self.layout.scale,
            height: self.layout.viewport.height * self.layout.scale
        )
        self.origin = CGPoint(
            x: self.grinFrame.minX + (self.grinFrame.width - drawnSize.width) / 2,
            y: self.grinFrame.minY + (self.grinFrame.height - drawnSize.height) / 2
        )
    }

    var closedBounds: CGRect {
        self.map(self.sourceBounds)
    }

    var bounds: CGRect {
        self.closedBounds
    }

    var calloutX: CGFloat {
        self.bounds.maxX + 46
    }

    var centerlineY: CGFloat {
        self.point(x: 0, y: 32).y
    }

    var upperLabelY: CGFloat {
        self.bounds.minY - 12
    }

    var lowerLabelY: CGFloat {
        self.point(x: 0, y: self.sourceBounds.maxY + 3).y + 12
    }

    var widthExtensionStartY: CGFloat {
        self.lowerLabelY + 8
    }

    var widthDimensionY: CGFloat {
        self.lowerLabelY + 18
    }

    var heightDimensionX: CGFloat {
        self.bounds.minX - 34
    }

    var upperToothCenters: [CGPoint] {
        (0..<SelfFigureMasterGeometry.teeth).map { self.upperTooth(index: $0).midPoint }
    }

    var lowerToothCenters: [CGPoint] {
        (0..<SelfFigureMasterGeometry.teeth).map { self.lowerTooth(index: $0).midPoint }
    }

    var keycapCalloutY: CGFloat {
        self.bounds.minY - 4
    }

    var keycapCalloutCenterY: CGFloat {
        self.keycapCalloutY + 14
    }

    var biteCalloutY: CGFloat {
        self.centerlineY + 6
    }

    var biteCalloutCenterY: CGFloat {
        self.biteCalloutY + 13
    }

    var goldCalloutY: CGFloat {
        self.point(x: 0, y: 41).y
    }

    var goldCalloutCenterY: CGFloat {
        min(self.canvasSize.height - 20, self.goldCalloutY + 30)
    }

    var goldCalloutTargetY: CGFloat {
        self.goldCalloutCenterY - 16
    }

    func point(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(
            x: self.origin.x + (x - self.layout.viewport.minX) * self.layout.scale,
            y: self.origin.y + (y - self.layout.viewport.minY) * self.layout.scale
        )
    }

    func upperTooth(index: Int) -> CGRect {
        let gridRect = CGRect(
            x: SelfFigureMasterGeometry.x0 + CGFloat(index) * SelfFigureMasterGeometry.pitch,
            y: 32 - SelfFigureMasterGeometry.gap / 2 - SelfFigureMasterGeometry.upper[index] + SelfFigureMasterGeometry.smile[index],
            width: SelfFigureMasterGeometry.toothWidth,
            height: SelfFigureMasterGeometry.upper[index]
        )
        return self.map(gridRect)
    }

    func lowerTooth(index: Int) -> CGRect {
        let gridRect = CGRect(
            x: SelfFigureMasterGeometry.x0 + CGFloat(index) * SelfFigureMasterGeometry.pitch,
            y: 32 + SelfFigureMasterGeometry.gap / 2 + SelfFigureMasterGeometry.smile[index],
            width: SelfFigureMasterGeometry.toothWidth,
            height: SelfFigureMasterGeometry.lower[index]
        )
        return self.map(gridRect)
    }

    private func map(_ rect: CGRect) -> CGRect {
        CGRect(
            x: self.origin.x + (rect.minX - self.layout.viewport.minX) * self.layout.scale,
            y: self.origin.y + (rect.minY - self.layout.viewport.minY) * self.layout.scale,
            width: rect.width * self.layout.scale,
            height: rect.height * self.layout.scale
        )
    }
}

private extension CGRect {
    var midPoint: CGPoint {
        CGPoint(x: self.midX, y: self.midY)
    }
}

/// Datasheet rendering of the Accessibility recovery states shared with the app's existing
/// trust monitor. The monitor and its actions remain the source of truth.
struct OnboardingDatasheetRecoveryHintView: View {
    @Environment(\.datasheetPalette) private var palette

    let hint: AccessibilityHint
    var conflictingCopies: [URL] = []
    let openAccessibilitySettings: () -> Void
    let relaunch: () -> Void

    var body: some View {
        switch self.hint {
        case .none:
            EmptyView()
        case .staleGrant:
            self.content(
                headline: AccessibilityHintPolicy.staleGrantHeadline,
                body: AccessibilityHintPolicy.staleGrantBody,
                buttonTitle: "Open Accessibility Settings",
                buttonIcon: "arrow.up.right",
                action: self.openAccessibilitySettings
            )
        case .conflictingCopies:
            self.content(
                headline: AccessibilityHintPolicy.conflictingCopiesHeadline,
                body: AccessibilityHintPolicy.conflictingCopiesBody,
                paths: self.conflictingCopies.prefix(3).map { ConflictingAppCopyDetector.displayPath($0) },
                buttonTitle: "Show in Finder",
                buttonIcon: "folder",
                action: {
                    NSWorkspace.shared.activateFileViewerSelecting(Array(self.conflictingCopies.prefix(3)))
                },
                secondaryTitle: "Open Accessibility Settings",
                secondaryAction: self.openAccessibilitySettings
            )
        case .relaunch:
            self.content(
                headline: AccessibilityHintPolicy.relaunchHeadline,
                body: AccessibilityHintPolicy.relaunchBody,
                buttonTitle: "Relaunch MouthKeys",
                buttonIcon: "arrow.clockwise",
                action: self.relaunch
            )
        }
    }

    private func content(
        headline: String,
        body: String,
        paths: [String] = [],
        buttonTitle: String,
        buttonIcon: String,
        action: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            DatasheetStatusSquare(kind: .orange)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 5) {
                Text(headline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.text)

                ForEach(paths, id: \.self) { path in
                    Text(path)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Text(body)
                    .font(.system(size: 12, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(self.palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Button(action: action) {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(self.palette.invForeground)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 116)
                        .frame(height: 30)
                        .background(self.palette.invBackground)
                }
                .buttonStyle(.plain)
                .datasheetHoverBracket()
                .fixedSize()

                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(self.palette.text2)
                        .buttonStyle(.plain)
                        .datasheetHoverBracket()
                        .fixedSize()
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(headline) \(body)")
    }
}
