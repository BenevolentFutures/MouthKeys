import SwiftUI

enum DatasheetGrinDetailTier: Equatable {
    case full
    case heavy
    case compact

    static func forPixelWidth(_ pixelWidth: CGFloat) -> Self {
        if pixelWidth >= 256 { return .full }
        if pixelWidth >= 128 { return .heavy }
        return .compact
    }
}

private struct DatasheetGrinMaster {
    let teeth: Int
    let toothWidth: CGFloat
    let pitch: CGFloat
    let gap: CGFloat
    let scale: CGFloat
    let gold: Int
    let upper: [CGFloat]
    let lower: [CGFloat]
    let smile: [CGFloat]

    static let large = Self(
        teeth: 7,
        toothWidth: 5,
        pitch: 6.4,
        gap: 3,
        scale: 1.15,
        gold: 4,
        upper: [5, 8, 9, 9, 9, 8, 5],
        lower: [4, 7, 9, 9, 9, 7, 4],
        smile: [-2.5, -1, -0.3, 0, -0.3, -1, -2.5]
    )

    static let small = Self(
        teeth: 5,
        toothWidth: 6,
        pitch: 8,
        gap: 4,
        scale: 1.1,
        gold: 3,
        upper: [7, 11, 11, 11, 7],
        lower: [6, 10, 10, 10, 6],
        smile: [-2, 0, 0, 0, -2]
    )
}

struct DatasheetGrin: View {
    /// The lower jaw's displacement in the 64-unit drawing grid, from 0 (closed) to 3 (open).
    var jaw: CGFloat = 0

    @Environment(\.datasheetPalette) private var palette
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { initialContext, size in
            var context = initialContext
            let pixelSize = size.width * self.displayScale
            let tier = DatasheetGrinDetailTier.forPixelWidth(pixelSize)
            let master = tier == .compact ? DatasheetGrinMaster.small : DatasheetGrinMaster.large
            self.draw(master, tier: tier, in: &context, size: size)
        }
        .accessibilityLabel("MouthKeys grin")
        .accessibilityHidden(true)
    }

    private func draw(
        _ master: DatasheetGrinMaster,
        tier: DatasheetGrinDetailTier,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let unit = min(size.width, size.height) / 64
        let scale = unit * master.scale
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let jaw = min(max(self.jaw, 0), 3)
        let x0 = 32 - (CGFloat(master.teeth - 1) * master.pitch + master.toothWidth) / 2

        for index in 0..<master.teeth {
            let x = x0 + CGFloat(index) * master.pitch
            let upper = CGRect(
                x: x,
                y: 32 - master.gap / 2 - master.upper[index] + master.smile[index],
                width: master.toothWidth,
                height: master.upper[index]
            )
            let lower = CGRect(
                x: x,
                y: 32 + master.gap / 2 + master.smile[index] + jaw,
                width: master.toothWidth,
                height: master.lower[index]
            )
            let upperRect = Self.map(upper, center: center, scale: scale)
            let lowerRect = Self.map(lower, center: center, scale: scale)

            context.fill(Path(upperRect), with: .color(self.palette.ink))
            context.fill(Path(lowerRect), with: .color(index == master.gold ? self.palette.accent : self.palette.ink))

            if tier != .compact {
                self.drawKeycap(upperRect, upper: true, tier: tier, scale: scale, in: &context)
                self.drawKeycap(lowerRect, upper: false, tier: tier, scale: scale, in: &context)
            }
        }
    }

    private func drawKeycap(
        _ rect: CGRect,
        upper: Bool,
        tier: DatasheetGrinDetailTier,
        scale: CGFloat,
        in context: inout GraphicsContext
    ) {
        let isFull = tier == .full
        let inset = rect.width * (isFull ? 0.22 : 0.24)
        let near: CGFloat = isFull ? 0.6 : 0.5
        let far: CGFloat = isFull ? 1.4 : 1.5
        let face = CGRect(
            x: rect.minX + inset,
            y: rect.minY + inset * (upper ? near : far),
            width: rect.width - 2 * inset,
            height: rect.height - inset * (near + far)
        )

        var chamfers = Path()
        chamfers.addRect(face)
        chamfers.move(to: CGPoint(x: rect.minX, y: rect.minY))
        chamfers.addLine(to: CGPoint(x: face.minX, y: face.minY))
        chamfers.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        chamfers.addLine(to: CGPoint(x: face.maxX, y: face.minY))
        chamfers.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        chamfers.addLine(to: CGPoint(x: face.minX, y: face.maxY))
        chamfers.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        chamfers.addLine(to: CGPoint(x: face.maxX, y: face.maxY))

        let line: CGFloat = isFull ? 0.3 : 0.6
        let alpha: Double = isFull ? 0.55 : 0.8
        context.stroke(
            chamfers,
            with: .color(self.palette.surface.opacity(alpha)),
            style: StrokeStyle(lineWidth: line * scale, lineCap: .butt, lineJoin: .miter)
        )
    }

    private static func map(_ rect: CGRect, center: CGPoint, scale: CGFloat) -> CGRect {
        CGRect(
            x: center.x + (rect.minX - 32) * scale,
            y: center.y + (rect.minY - 32) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
