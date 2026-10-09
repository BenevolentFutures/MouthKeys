import AppKit
import SwiftUI

/// The menu bar mark (DESIGN.md §10): a 21 x 22 square-cornered template image, the mouth alone,
/// as tall as the status bar (22 pt) allows with the jaw wide open.
/// Four square-ended teeth a jaw, the bite smiling, the app icon's gold tooth (third lower) drawn
/// hollow, since a template image cannot be orange. While listening the lower jaw opens with the
/// level at 8 Hz (still during Spoken Send's countdown); otherwise it is closed. The width never
/// changes. On hover, and while the menu is open, a bracket draws inside the box (the menu bar has
/// no room outside it).
enum DatasheetMenuBarMark {
    enum Kind: Equatable {
        case idle
        case listening
        case transcribing
    }

    static let size = NSSize(width: 21, height: 22)
    /// The furthest the lower jaw opens, in steps of `unit`.
    static let maxJaw: CGFloat = 2
    /// The lower tooth drawn hollow: the app icon's gold tooth at 16 px.
    static let goldTooth = 2
    /// The 16 px icon's grid, scaled to fill the status bar: every edge on a 2x device pixel.
    private static let unit: CGFloat = 1.5

    private static var cache: [String: NSImage] = [:]

    static func image(jaw: CGFloat = 0, bracket: Bool) -> NSImage {
        let jaw = min(max(jaw.rounded(), 0), self.maxJaw)
        let key = "\(Int(jaw))|\(bracket)"
        if let cached = self.cache[key] { return cached }
        let image = NSImage(size: self.size, flipped: true) { _ in
            NSColor.black.set()
            // On the 16 px grid (times `unit`, from a 2 pt margin): teeth 2 wide on a 3 pitch. Upper
            // teeth hang from 0 to the bite at 5 (the outer two to 4); the lower teeth start one
            // below the bite (the outer two one higher), dropped by the jaw. Closed, the mouth is
            // 16.5 x 15 pt; wide open, 18 pt tall.
            let u = self.unit
            for index in 0..<4 {
                let outer = index == 0 || index == 3
                let x = 2 + CGFloat(index * 3) * u
                NSBezierPath(rect: NSRect(x: x, y: 2, width: 2 * u, height: (outer ? 4 : 5) * u)).fill()
                let lower = NSRect(x: x, y: 2 + ((outer ? 5 : 6) + jaw) * u, width: 2 * u, height: (outer ? 3 : 4) * u)
                if index == self.goldTooth {
                    // A half-point edge inside the tooth's own rect: one device pixel at 2x.
                    let outline = NSBezierPath(rect: lower.insetBy(dx: 0.25, dy: 0.25))
                    outline.lineWidth = 0.5
                    outline.stroke()
                } else {
                    NSBezierPath(rect: lower).fill()
                }
            }
            if bracket {
                let path = NSBezierPath()
                path.lineWidth = 1.5
                path.lineCapStyle = .butt
                path.lineJoinStyle = .miter
                // Centred on the box's edge pixels; arms end on whole points.
                let (left, top, right, bottom, arm): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) =
                    (0.75, 0.75, self.size.width - 0.75, self.size.height - 0.75, 5.25)
                let corners: [[NSPoint]] = [
                    [NSPoint(x: left, y: top + arm), NSPoint(x: left, y: top), NSPoint(x: left + arm, y: top)],
                    [NSPoint(x: right - arm, y: top), NSPoint(x: right, y: top), NSPoint(x: right, y: top + arm)],
                    [NSPoint(x: right, y: bottom - arm), NSPoint(x: right, y: bottom), NSPoint(x: right - arm, y: bottom)],
                    [NSPoint(x: left + arm, y: bottom), NSPoint(x: left, y: bottom), NSPoint(x: left, y: bottom - arm)],
                ]
                for corner in corners {
                    path.move(to: corner[0])
                    path.line(to: corner[1])
                    path.line(to: corner[2])
                }
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "MouthKeys"
        if self.cache.count > 64 { self.cache.removeAll() }
        self.cache[key] = image
        return image
    }

    /// How far the lower jaw opens while listening, from the newest trace sample: ajar (1 step)
    /// while the voice is on, wide (2 steps) on the louder half of the range, closed once the voice
    /// has been off past the 250 ms hangover, so the mark never talks while Atin is quiet.
    static func listeningJaw(
        from trace: DatasheetTraceModel,
        at now: TimeInterval = Date().timeIntervalSinceReferenceDate
    ) -> CGFloat {
        guard trace.isVoiceActive(at: now), let sample = trace.current.dropLast().last ?? trace.current.last else { return 0 }
        let level = (sample - DatasheetTraceModel.floor) / (DatasheetTraceModel.ceiling - DatasheetTraceModel.floor)
        return level >= 0.5 ? self.maxJaw : 1
    }
}

/// The menu's header row: "MOUTHKEYS" on the left and the state on the right, mono 10 pt
/// uppercase, with the orange square while listening (DESIGN.md §10).
final class DatasheetMenuHeaderView: NSView {
    var stateText = "Ready" {
        didSet { if self.stateText != oldValue { self.needsDisplay = true } }
    }

    var isLive = false {
        didSet { if self.isLive != oldValue { self.needsDisplay = true } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 262, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 14
        let label = self.attributed("MouthKeys", weight: .medium, color: .secondaryLabelColor)
        let labelSize = label.size()
        label.draw(at: NSPoint(x: inset, y: (self.bounds.height - labelSize.height) / 2))

        let state = self.attributed(self.stateText, weight: .semibold, color: .labelColor)
        let stateSize = state.size()
        let stateX = self.bounds.width - inset - stateSize.width
        state.draw(at: NSPoint(x: stateX, y: (self.bounds.height - stateSize.height) / 2))
        if self.isLive {
            DatasheetTheme.AppKitColors.accent.setFill()
            NSRect(x: stateX - 12, y: self.bounds.midY - 3, width: 6, height: 6).fill()
        }
    }

    private func attributed(_ text: String, weight: NSFont.Weight, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: weight),
            .kern: 0.6,
            .foregroundColor: color,
        ])
    }
}

/// The status menu's colors (DESIGN.md §10), from the Datasheet palette for the menu's own
/// appearance: rows draw the sheet's surface and invert while highlighted.
struct DatasheetMenuColors {
    let surface: NSColor
    let text: NSColor
    let text2: NSColor
    let rule: NSColor
    let edge: NSColor
    let invBackground: NSColor
    let invForeground: NSColor
    let invForeground2: NSColor

    init(appearance: NSAppearance) {
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let palette = isDark ? DatasheetTheme.Palette.dark : DatasheetTheme.Palette.light
        self.surface = NSColor(palette.surface)
        self.text = NSColor(palette.text)
        self.text2 = isDark ? NSColor(palette.text2) : NSColor(palette.text2).withAlphaComponent(0.62)
        self.rule = isDark ? NSColor(palette.rule) : NSColor(palette.rule).withAlphaComponent(0.18)
        self.edge = NSColor(palette.edge)
        self.invBackground = NSColor(palette.invBackground)
        self.invForeground = NSColor(palette.invForeground)
        self.invForeground2 = NSColor(palette.invForeground2)
    }

    /// Mono uppercase, tracked +0.06 em (DESIGN.md §3).
    static func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: weight),
            .kern: size * 0.06,
            .foregroundColor: color,
        ])
    }
}

/// One status menu row in Datasheet Mono: an optional record square under the header's grin, a
/// mono uppercase label in line with MOUTHKEYS, and a mono detail or keycap at the right. The row
/// inverts while highlighted, by the pointer or the arrow keys. The view draws everything; the
/// item's title stays for accessibility.
final class DatasheetMenuRowView: NSView {
    enum Detail: Equatable {
        case none
        case text(String)
        case keycap(String)
    }

    static let height: CGFloat = 26
    static let width: CGFloat = 262
    /// Labels start in line with the header's MOUTHKEYS; marks centre under its grin.
    static let labelX: CGFloat = 40
    static let markCentreX: CGFloat = 21

    var label: String {
        didSet { if self.label != oldValue { self.needsDisplay = true } }
    }

    var detail: Detail {
        didSet { if self.detail != oldValue { self.needsDisplay = true } }
    }

    /// nil: no mark. false: an outlined record square. true: solid orange, while recording.
    var recordMark: Bool? {
        didSet { if self.recordMark != oldValue { self.needsDisplay = true } }
    }

    init(label: String, detail: Detail = .none, recordMark: Bool? = nil) {
        self.label = label
        self.detail = detail
        self.recordMark = recordMark
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
        self.autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override var allowsVibrancy: Bool {
        false
    }

    /// Renders and tests set this; in the menu the item's highlight decides.
    var isHighlightForced: Bool?

    var isHighlighted: Bool {
        if let forced = self.isHighlightForced { return forced }
        guard let item = self.enclosingMenuItem else { return false }
        return item.isHighlighted && item.isEnabled
    }

    override func draw(_ dirtyRect: NSRect) {
        let colors = DatasheetMenuColors(appearance: self.effectiveAppearance)
        let highlighted = self.isHighlighted
        let enabled = self.enclosingMenuItem?.isEnabled ?? true
        (highlighted ? colors.invBackground : colors.surface).setFill()
        self.bounds.fill()
        let foreground = highlighted ? colors.invForeground : (enabled ? colors.text : colors.text2)
        let foreground2 = highlighted ? colors.invForeground2 : colors.text2

        if let live = self.recordMark {
            let square = NSRect(x: Self.markCentreX - 4, y: self.bounds.midY - 4, width: 8, height: 8)
            if live {
                DatasheetTheme.AppKitColors.accent.setFill()
                square.fill()
            } else {
                foreground.setStroke()
                let outline = NSBezierPath(rect: square.insetBy(dx: 0.5, dy: 0.5))
                outline.lineWidth = 1
                outline.stroke()
            }
        }

        let right = self.bounds.width - 14
        var labelLimit = right - Self.labelX
        switch self.detail {
        case .none:
            break
        case let .text(text):
            let detail = DatasheetMenuColors.label(text, size: 10, weight: .regular, color: foreground2)
            let size = detail.size()
            detail.draw(at: NSPoint(x: right - size.width, y: (self.bounds.height - size.height) / 2))
            labelLimit -= size.width + 12
        case let .keycap(text):
            let cap = DatasheetMenuColors.label(text, size: 10, weight: .medium, color: foreground)
            let size = cap.size()
            let box = NSRect(x: right - size.width - 12, y: self.bounds.midY - 8, width: size.width + 12, height: 16)
            (highlighted ? colors.invForeground2 : colors.edge).setStroke()
            let edge = NSBezierPath(rect: box.insetBy(dx: 0.5, dy: 0.5))
            edge.lineWidth = 1
            edge.stroke()
            cap.draw(at: NSPoint(x: box.minX + 6, y: (self.bounds.height - size.height) / 2))
            labelLimit -= box.width + 12
        }

        let label = NSMutableAttributedString(
            attributedString: DatasheetMenuColors.label(self.label, size: 11, weight: .medium, color: foreground)
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        label.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: label.length))
        let size = label.size()
        label.draw(in: NSRect(x: Self.labelX, y: (self.bounds.height - size.height) / 2, width: max(0, labelLimit), height: size.height))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in self.trackingAreas {
            self.removeTrackingArea(area)
        }
        self.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    // The menu moves the highlight; redraw on both edges so the invert follows the pointer.
    override func mouseEntered(with event: NSEvent) {
        self.needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        self.needsDisplay = true
    }

    /// A view-backed item does not fire on its own: close the menu, then send the item's action
    /// on the next turn, once the menu is gone (Settings… raises a window).
    override func mouseUp(with event: NSEvent) {
        guard let item = self.enclosingMenuItem, item.isEnabled, let menu = item.menu else { return }
        menu.cancelTracking()
        DispatchQueue.main.async {
            let index = menu.index(of: item)
            if index >= 0 { menu.performActionForItem(at: index) }
        }
    }
}

/// A 1 px rule across the status menu, on the sheet's surface.
final class DatasheetMenuRuleView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.autoresizingMask = [.width]
    }

    convenience init() {
        self.init(frame: NSRect(x: 0, y: 0, width: DatasheetMenuRowView.width, height: 9))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool {
        true
    }

    override var allowsVibrancy: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        let colors = DatasheetMenuColors(appearance: self.effectiveAppearance)
        colors.surface.setFill()
        self.bounds.fill()
        colors.rule.setFill()
        NSRect(x: 0, y: 4, width: self.bounds.width, height: 1).fill()
    }
}
