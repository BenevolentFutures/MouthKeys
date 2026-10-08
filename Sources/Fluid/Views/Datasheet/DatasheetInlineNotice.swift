import SwiftUI

/// A notice row (DESIGN.md §15): news that needs no rescue, in the pill's reserved preview slot,
/// the way Pasted swaps in. Three 16 pt rows (round 6): the headline (Pro 12.5 semibold), the reason
/// (Pro 12, `text-2`), then inline text actions, **Reprocess** (Pro 12 semibold in `accent` with a
/// 12 pt glyph, no fill) · **Dismiss** (Pro 12 medium, `text-2`). Each action draws its own outside
/// bracket on hover, like a chip, and the pill's bracket yields; a press inverts it.
struct DatasheetInlineNotice: View {
    let notice: DatasheetNotice
    /// Holds an action's hover for renders ("notice-reprocess", "notice-dismiss").
    var isHoverForced: String?
    var onHoverChanged: (String, Bool) -> Void = { _, _ in }
    let onReprocess: () -> Void
    let onDismiss: () -> Void

    @Environment(\.datasheetPalette) private var palette

    static let rowHeight: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(self.notice.headline)
                .font(DatasheetTheme.Typography.failedHeadline.font)
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .frame(height: Self.rowHeight, alignment: .leading)
            Text(self.notice.reason)
                .font(DatasheetTheme.Typography.reason.font)
                .foregroundStyle(self.palette.text2)
                .lineLimit(1)
                .frame(height: Self.rowHeight, alignment: .leading)
            HStack(spacing: 6) {
                DatasheetTextAction(
                    id: "notice-reprocess",
                    title: "Reprocess",
                    systemName: "arrow.clockwise",
                    isAccent: true,
                    help: "Transcribe the kept audio",
                    isHoverForced: self.isHoverForced == "notice-reprocess",
                    onHoverChanged: self.onHoverChanged,
                    action: self.onReprocess
                )
                Text("·")
                    .font(DatasheetTheme.Typography.reason.font)
                    .foregroundStyle(self.palette.text2)
                    .accessibilityHidden(true)
                DatasheetTextAction(
                    id: "notice-dismiss",
                    title: "Dismiss",
                    help: "Dismiss",
                    isHoverForced: self.isHoverForced == "notice-dismiss",
                    onHoverChanged: self.onHoverChanged,
                    action: self.onDismiss
                )
            }
            .frame(height: Self.rowHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(self.notice.headline)
    }
}

/// An inline text action: no fill at rest, a chip's outside bracket on hover, inverted while
/// pressed. Its 4 pt side padding is taken back from the layout, so the text sits where the
/// prototype puts it and the press fill still has room.
private struct DatasheetTextAction: View {
    let id: String
    let title: String
    var systemName: String?
    var isAccent = false
    let help: String
    var isHoverForced = false
    let onHoverChanged: (String, Bool) -> Void
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 5) {
                if let systemName = self.systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(self.title)
            }
        }
        .buttonStyle(DatasheetTextActionStyle(isAccent: self.isAccent, palette: self.palette))
        .datasheetBracket(.chip, visible: self.isHovered || self.isHoverForced)
        .padding(.horizontal, -4)
        .onHover { hovering in
            guard hovering != self.isHovered else { return }
            self.isHovered = hovering
            self.onHoverChanged(self.id, hovering)
        }
        .onDisappear {
            if self.isHovered { self.onHoverChanged(self.id, false) }
        }
        .help(self.help)
        .accessibilityLabel(self.title)
    }
}

private struct DatasheetTextActionStyle: ButtonStyle {
    let isAccent: Bool
    let palette: DatasheetTheme.Palette

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: DatasheetTheme.Typography.inlineAction.size, weight: self.isAccent ? .semibold : .medium))
            .foregroundStyle(pressed ? self.palette.invForeground : (self.isAccent ? self.palette.accent : self.palette.text2))
            .frame(height: DatasheetInlineNotice.rowHeight)
            .padding(.horizontal, 4)
            .background(pressed ? self.palette.invBackground : Color.clear)
            .contentShape(Rectangle())
            .datasheetClickTarget()
            .animation(.linear(duration: DatasheetTheme.Motion.chipPress), value: pressed)
    }
}
