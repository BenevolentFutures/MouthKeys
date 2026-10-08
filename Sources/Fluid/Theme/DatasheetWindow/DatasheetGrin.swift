import SwiftUI

enum DatasheetGrinDetailTier: Equatable {
    case full
    case heavy
    case compact

    static func forPixelsPerUnit(_ pixelsPerUnit: CGFloat) -> Self {
        if pixelsPerUnit >= 4.6 { return .full }
        if pixelsPerUnit >= 2.3 { return .heavy }
        return .compact
    }
}

enum DatasheetGrinStyle: Equatable {
    case solid
    case outline
}

struct DatasheetGrinLayout: Equatable {
    let viewport: CGRect
    let scale: CGFloat
    let pixelsPerUnit: CGFloat
    let usesLargeMaster: Bool

    var detailTier: DatasheetGrinDetailTier {
        DatasheetGrinDetailTier.forPixelsPerUnit(self.pixelsPerUnit)
    }
}

private struct DatasheetGrinMaster {
    let teeth: Int
    let toothWidth: CGFloat
    let pitch: CGFloat
    let gap: CGFloat
    let gold: Int
    let upper: [CGFloat]
    let lower: [CGFloat]
    let smile: [CGFloat]

    static let large = Self(
        teeth: 7,
        toothWidth: 5,
        pitch: 6.4,
        gap: 3,
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
        gold: 3,
        upper: [7, 11, 11, 11, 7],
        lower: [6, 10, 10, 10, 6],
        smile: [-2, 0, 0, 0, -2]
    )

    var closedBounds: CGRect {
        let x0 = 32 - (CGFloat(self.teeth - 1) * self.pitch + self.toothWidth) / 2
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for index in 0..<self.teeth {
            let upperY = 32 - self.gap / 2 - self.upper[index] + self.smile[index]
            let lowerY = 32 + self.gap / 2 + self.smile[index]
            minY = min(minY, upperY)
            maxY = max(maxY, max(upperY + self.upper[index], lowerY + self.lower[index]))
        }

        return CGRect(
            x: x0,
            y: minY,
            width: CGFloat(self.teeth - 1) * self.pitch + self.toothWidth,
            height: maxY - minY
        )
    }

    var jawViewport: CGRect {
        let bounds = self.closedBounds
        return CGRect(
            x: bounds.minX - DatasheetGrinGeometry.padding,
            y: bounds.minY - DatasheetGrinGeometry.padding,
            width: bounds.width + 2 * DatasheetGrinGeometry.padding,
            height: bounds.height + 2 * DatasheetGrinGeometry.padding + DatasheetGrinGeometry.maxJaw
        )
    }
}

enum DatasheetGrinGeometry {
    static let padding: CGFloat = 1
    static let maxJaw: CGFloat = 3

    static func layout(in size: CGSize, displayScale: CGFloat) -> DatasheetGrinLayout {
        let large = DatasheetGrinMaster.large
        let largeScale = self.fittingScale(size, to: large.jawViewport)
        let physicalScale = max(displayScale, 1)
        let useLarge = largeScale * physicalScale >= 2.3
        let master = useLarge ? large : DatasheetGrinMaster.small
        let scale = self.fittingScale(size, to: master.jawViewport)

        return DatasheetGrinLayout(
            viewport: master.jawViewport,
            scale: scale,
            pixelsPerUnit: scale * physicalScale,
            usesLargeMaster: useLarge
        )
    }

    private static func fittingScale(_ size: CGSize, to viewport: CGRect) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 0 }
        return min(size.width / viewport.width, size.height / viewport.height)
    }
}

struct DatasheetGrin: View {
    /// The lower jaw's displacement in the 64-unit drawing grid, from 0 (closed) to 3 (open).
    var jaw: CGFloat = 0
    var style: DatasheetGrinStyle = .solid

    @Environment(\.datasheetPalette) private var palette
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Canvas { initialContext, size in
            var context = initialContext
            let layout = DatasheetGrinGeometry.layout(in: size, displayScale: self.displayScale)
            let master = layout.usesLargeMaster ? DatasheetGrinMaster.large : DatasheetGrinMaster.small
            self.draw(master, layout: layout, in: &context, size: size)
        }
        .accessibilityLabel("MouthKeys grin")
        .accessibilityHidden(true)
    }

    private func draw(
        _ master: DatasheetGrinMaster,
        layout: DatasheetGrinLayout,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard layout.scale > 0 else { return }

        let tier = layout.detailTier
        let jaw = min(max(self.jaw, 0), DatasheetGrinGeometry.maxJaw)
        let drawnSize = CGSize(width: layout.viewport.width * layout.scale, height: layout.viewport.height * layout.scale)
        let origin = CGPoint(x: (size.width - drawnSize.width) / 2, y: (size.height - drawnSize.height) / 2)
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
            let upperRect = Self.map(upper, viewport: layout.viewport, origin: origin, scale: layout.scale)
            let lowerRect = Self.map(lower, viewport: layout.viewport, origin: origin, scale: layout.scale)

            if self.style == .solid {
                context.fill(Path(upperRect), with: .color(self.palette.ink))
                context.fill(Path(lowerRect), with: .color(index == master.gold ? self.palette.accent : self.palette.ink))
            } else {
                let upperColor = self.palette.text2
                let lowerColor = index == master.gold ? self.palette.accent : self.palette.text2
                context.stroke(Path(upperRect), with: .color(upperColor), lineWidth: 1)
                context.stroke(Path(lowerRect), with: .color(lowerColor), lineWidth: 1)
                if tier != .compact {
                    self.drawOutlineKeycap(upperRect, color: upperColor, upper: true, in: &context)
                    self.drawOutlineKeycap(lowerRect, color: lowerColor, upper: false, in: &context)
                }
            }

            if self.style == .solid, tier != .compact {
                self.drawKeycap(upperRect, upper: true, tier: tier, scale: layout.scale, in: &context)
                self.drawKeycap(lowerRect, upper: false, tier: tier, scale: layout.scale, in: &context)
            }
        }
    }

    private func drawOutlineKeycap(
        _ rect: CGRect,
        color: Color,
        upper: Bool,
        in context: inout GraphicsContext
    ) {
        let inset = rect.width * 0.22
        let face = CGRect(
            x: rect.minX + inset,
            y: rect.minY + inset * (upper ? 0.6 : 1.4),
            width: rect.width - 2 * inset,
            height: rect.height - inset * 2
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
        context.stroke(
            chamfers,
            with: .color(color.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter)
        )
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

    private static func map(_ rect: CGRect, viewport: CGRect, origin: CGPoint, scale: CGFloat) -> CGRect {
        CGRect(
            x: origin.x + (rect.minX - viewport.minX) * scale,
            y: origin.y + (rect.minY - viewport.minY) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }
}
