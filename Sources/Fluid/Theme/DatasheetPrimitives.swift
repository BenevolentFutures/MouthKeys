import SwiftUI

// Datasheet primitives (DESIGN.md §5–§7, §11): the selection bracket, the surface (fill, 1 px edge,
// flat 2 pt drop rule), and the card buttons. Every one is square: no corner radius anywhere.

/// Four L marks, one at each corner of the rect it is given. The path runs on the stroke's
/// centreline, `inset` inside that rect: the rect itself is laid out on whole points, and the
/// fractional offset lives here, so the strokes land exactly where they are meant to.
struct DatasheetBracketShape: Shape {
    /// Arm length measured from the centreline vertex.
    let arm: CGFloat
    /// The centreline's distance inside the rect.
    var inset: CGFloat = 0

    func path(in bounds: CGRect) -> Path {
        let rect = bounds.insetBy(dx: self.inset, dy: self.inset)
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
        ]
        for (vertex, dx, dy) in corners {
            path.move(to: CGPoint(x: vertex.x, y: vertex.y + dy * self.arm))
            path.addLine(to: vertex)
            path.addLine(to: CGPoint(x: vertex.x + dx * self.arm, y: vertex.y))
        }
        return path
    }
}

/// The selection bracket drawn outside a box: a 1 pt knockout halo in the surface colour, then
/// the 1.5 pt ink stroke. It never changes layout or hit-testing; it fades in and out over 60 ms
/// linear (a cut under reduced motion). Its window must leave `DatasheetTheme.Metrics.windowInset`
/// of room around the box.
private struct DatasheetBracketOverlay: ViewModifier {
    let spec: DatasheetTheme.BracketSpec
    let isVisible: Bool
    let opacity: Double
    @Environment(\.datasheetPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let stroke = DatasheetTheme.BracketSpec.stroke
        let halo = DatasheetTheme.BracketSpec.halo
        // The overlay reaches a whole number of points outside the box (past the halo), and the
        // bottom also clears the drop rule. The ink's inner edge sits `gap` clear of the box, so
        // its centreline is `gap + stroke / 2` out, which is `inset` inside the overlay's rect.
        let outset = (self.spec.gap + stroke + halo).rounded(.up)
        let inset = outset - self.spec.gap - stroke / 2
        // Arms are measured from the outer vertex; the path runs on the centreline.
        let inkArm = self.spec.length - stroke / 2
        content.overlay {
            ZStack {
                DatasheetBracketShape(arm: inkArm + halo, inset: inset)
                    .stroke(self.palette.surface, style: StrokeStyle(lineWidth: stroke + 2 * halo, lineCap: .butt, lineJoin: .miter))
                DatasheetBracketShape(arm: inkArm, inset: inset)
                    .stroke(self.palette.bracket, style: StrokeStyle(lineWidth: stroke, lineCap: .butt, lineJoin: .miter))
            }
            .padding(EdgeInsets(
                top: -outset,
                leading: -outset,
                bottom: -(outset + self.spec.drop),
                trailing: -outset
            ))
            .opacity(self.isVisible ? self.opacity : 0)
            .animation(self.reduceMotion ? nil : .linear(duration: DatasheetTheme.Motion.bracketFade), value: self.isVisible)
            .animation(self.reduceMotion ? nil : .linear(duration: DatasheetTheme.Motion.bracketFade), value: self.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct DatasheetHoverBracket: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .datasheetBracket(.chip, visible: self.isHovered)
            .onHover { hovering in
                if hovering != self.isHovered { self.isHovered = hovering }
            }
    }
}

/// A Datasheet surface: an opaque fill, a 1 px edge drawn inside the frame, and the flat,
/// unblurred 2 pt drop rule under it.
private struct DatasheetSurface: ViewModifier {
    let hasEdge: Bool
    let hasDrop: Bool
    @Environment(\.datasheetPalette) private var palette

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                if self.hasDrop {
                    Rectangle()
                        .fill(self.palette.drop)
                        .offset(y: DatasheetTheme.Metrics.dropRule)
                }
                Rectangle().fill(self.palette.surface)
                if self.hasEdge {
                    Rectangle().strokeBorder(self.palette.edge, lineWidth: DatasheetTheme.Metrics.edgeWidth)
                }
            }
        }
    }
}

extension View {
    /// A selection bracket outside this view's frame, shown only while `visible`.
    func datasheetBracket(_ spec: DatasheetTheme.BracketSpec, visible: Bool, opacity: Double = 1) -> some View {
        self.modifier(DatasheetBracketOverlay(spec: spec, isVisible: visible, opacity: opacity))
    }

    /// A chip's outside bracket while the pointer is over this control: for a button that has no
    /// hover bracket of its own (DESIGN.md §7: brackets mark only what you can click).
    func datasheetHoverBracket() -> some View {
        self.modifier(DatasheetHoverBracket())
    }

    /// Fill, 1 px edge and drop rule (DESIGN.md §6: no materials).
    func datasheetSurface(edge: Bool = true, drop: Bool = true) -> some View {
        self.modifier(DatasheetSurface(hasEdge: edge, hasDrop: drop))
    }
}

// MARK: - Click targets

/// Where a surface's own buttons are (chips, card and notice actions), in its hosting view's
/// coordinates (top-left origin). The overlay's double-click-to-reset lives in AppKit, not in a
/// SwiftUI double-tap gesture: a parent `onTapGesture(count: 2)` makes every child Button wait
/// out the double-click interval before it acts (measured at ~350 ms on the History chip). So a
/// double-click resets the position only where it does not land on one of these.
struct DatasheetClickTargetsKey: PreferenceKey {
    static let defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

/// The overlay's click targets as last laid out. A reference, not view state: it is written
/// from a preference change and read by the hosting view on a mouse-down.
final class DatasheetClickTargets {
    var rects: [CGRect] = []

    /// A double-click resets the overlay's position (DESIGN.md §4) unless it lands on a button.
    static func isPositionResetClick(clickCount: Int, at point: CGPoint, targets: [CGRect]) -> Bool {
        clickCount == 2 && !targets.contains { $0.contains(point) }
    }
}

extension View {
    /// Reports this button's frame as a click target (`DatasheetClickTargetsKey`). A dimmed or inert
    /// button (`isActive` false) acts on nothing, so a double-click there still resets the position.
    func datasheetClickTarget(isActive: Bool = true) -> some View {
        self.background {
            GeometryReader { proxy in
                Color.clear.preference(key: DatasheetClickTargetsKey.self, value: isActive ? [proxy.frame(in: .global)] : [])
            }
        }
    }
}

// MARK: - Card buttons

/// A recovery card's primary action (DESIGN.md §15): a solid orange square button, at least
/// 88 x 28, 12 pt side padding. A copy confirmation swaps in at the same width. Pressed, it inverts.
struct DatasheetPrimaryButtonStyle: ButtonStyle {
    @Environment(\.datasheetPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DatasheetTheme.Typography.button.font)
            .foregroundStyle(configuration.isPressed ? self.palette.invForeground : self.palette.onAccent)
            .padding(.horizontal, 12)
            .frame(minWidth: DatasheetTheme.Metrics.copyButtonWidth)
            .frame(height: DatasheetTheme.Metrics.buttonHeight)
            .background(configuration.isPressed ? self.palette.invBackground : self.palette.accent)
            .contentShape(Rectangle())
            .datasheetClickTarget()
            .animation(.linear(duration: DatasheetTheme.Motion.chipPress), value: configuration.isPressed)
    }
}

/// A text-only action ("Dismiss"): ink, orange while pressed; its hover mark is a chip bracket
/// (`datasheetHoverBracket`, DESIGN.md §7).
struct DatasheetTextButtonStyle: ButtonStyle {
    @Environment(\.datasheetPalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DatasheetTheme.Typography.textButton.font)
            .foregroundStyle(configuration.isPressed ? self.palette.accent : self.palette.text)
            .frame(height: DatasheetTheme.Metrics.buttonHeight)
            .contentShape(Rectangle())
            .datasheetClickTarget()
    }
}

/// A mono uppercase label: every number and placard in Datasheet Mono.
struct DatasheetMonoLabel: View {
    let text: String
    var role: DatasheetTheme.TypeRole = DatasheetTheme.Typography.meta
    var color: Color

    var body: some View {
        Text(self.text)
            .font(self.role.font)
            .tracking(self.role.tracking)
            .textCase(.uppercase)
            .foregroundStyle(self.color)
            .lineLimit(1)
    }
}
