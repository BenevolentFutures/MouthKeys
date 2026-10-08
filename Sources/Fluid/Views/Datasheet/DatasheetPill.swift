import SwiftUI

/// The pill (DESIGN.md §4, round 6): a square surface with a 1 px edge and the flat 2 pt drop rule.
/// Rows top to bottom: padding 10, the top area (preview, delivered statement, notice, or a
/// card's grown body), gap 6, the 38 pt trace row, gap 4, the 16 pt foot row, padding 8.
struct DatasheetPill<Top: View>: View {
    let geometry: DatasheetOverlayGeometry
    /// The top area's height: the preview area, or a card's body for a grown pill.
    let topHeight: CGFloat
    let traceRow: DatasheetTraceRow
    let foot: DatasheetFootRow
    var marksFailure = false
    var isBracketVisible = false
    @ViewBuilder let top: Top

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        let metrics = DatasheetTheme.Metrics.self
        VStack(spacing: 0) {
            if self.topHeight > 0 {
                self.top
                    .frame(width: self.geometry.innerWidth, height: self.topHeight, alignment: .topLeading)
                Color.clear.frame(height: metrics.previewGap)
            }
            self.traceRow
            Color.clear.frame(height: metrics.micGap)
            self.foot
                .frame(width: self.geometry.innerWidth)
        }
        .padding(.top, metrics.pillPaddingTop)
        .padding(.bottom, metrics.pillPaddingBottom)
        .padding(.horizontal, metrics.pillPaddingHorizontal)
        .frame(width: self.geometry.pillWidth, height: self.height, alignment: .top)
        .datasheetSurface()
        .overlay(alignment: .top) {
            if self.marksFailure {
                Rectangle()
                    .fill(self.palette.accent)
                    .frame(height: metrics.failedTopRule)
                    .allowsHitTesting(false)
            }
        }
        .datasheetBracket(.pill, visible: self.isBracketVisible)
    }

    var height: CGFloat {
        let metrics = DatasheetTheme.Metrics.self
        let top = self.topHeight > 0 ? self.topHeight + metrics.previewGap : 0
        return metrics.pillPaddingTop + top + metrics.traceRowHeight + metrics.micGap + metrics.micRowHeight
            + metrics.pillPaddingBottom
    }
}
