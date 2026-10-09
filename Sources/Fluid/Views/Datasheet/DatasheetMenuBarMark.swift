import AppKit

/// The menu bar mark (DESIGN.md §10): a 15 x 16 square-cornered template image, the mouth alone.
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

    static let size = NSSize(width: 15, height: 16)
    /// The furthest the lower jaw opens, in points.
    static let maxJaw: CGFloat = 2
    /// The lower tooth drawn hollow: the app icon's gold tooth at 16 px.
    static let goldTooth = 2

    private static var cache: [String: NSImage] = [:]

    static func image(jaw: CGFloat = 0, bracket: Bool) -> NSImage {
        let jaw = min(max(jaw.rounded(), 0), self.maxJaw)
        let key = "\(Int(jaw))|\(bracket)"
        if let cached = self.cache[key] { return cached }
        let image = NSImage(size: self.size, flipped: true) { _ in
            NSColor.black.set()
            // Teeth: 2 pt wide on a 3 pt pitch from x 2. Upper teeth hang from y 2 to the bite at 7
            // (the outer two to 6); the lower teeth start a point below the bite (the outer two a
            // point higher), dropped by the jaw.
            for (index, x) in [2, 5, 8, 11].map({ CGFloat($0) }).enumerated() {
                let outer = index == 0 || index == 3
                NSBezierPath(rect: NSRect(x: x, y: 2, width: 2, height: outer ? 4 : 5)).fill()
                let lower = NSRect(x: x, y: (outer ? 7 : 8) + jaw, width: 2, height: outer ? 3 : 4)
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
                let corners: [[NSPoint]] = [
                    [NSPoint(x: 0.75, y: 4.75), NSPoint(x: 0.75, y: 0.75), NSPoint(x: 4.75, y: 0.75)],
                    [NSPoint(x: 10.25, y: 0.75), NSPoint(x: 14.25, y: 0.75), NSPoint(x: 14.25, y: 4.75)],
                    [NSPoint(x: 14.25, y: 11.25), NSPoint(x: 14.25, y: 15.25), NSPoint(x: 10.25, y: 15.25)],
                    [NSPoint(x: 4.75, y: 15.25), NSPoint(x: 0.75, y: 15.25), NSPoint(x: 0.75, y: 11.25)],
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

    /// How far the lower jaw opens while listening, from the newest trace sample: ajar (1 pt)
    /// while the voice is on, wide (2 pt) on the louder half of the range, closed once the voice
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
