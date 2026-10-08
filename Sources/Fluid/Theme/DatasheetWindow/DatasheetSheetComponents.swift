import SwiftUI

struct DatasheetSheetHeader<Actions: View>: View {
    let placard: String
    let title: String
    let lede: String?
    let actions: Actions

    @Environment(\.datasheetPalette) private var palette

    init(
        placard: String,
        title: String,
        lede: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.placard = placard
        self.title = title
        self.lede = lede
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(self.placard.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(self.palette.text2)
                        .padding(.bottom, 8)

                    Text(self.title)
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.28)
                        .foregroundStyle(self.palette.text)

                    if let lede = self.lede {
                        Text(lede)
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(2)
                            .foregroundStyle(self.palette.text2)
                            .padding(.top, 8)
                    }
                }

                Spacer(minLength: 0)
                self.actions
            }

            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)
        }
        .padding(.bottom, 26)
    }
}

extension DatasheetSheetHeader where Actions == EmptyView {
    init(placard: String, title: String, lede: String? = nil) {
        self.init(placard: placard, title: title, lede: lede) { EmptyView() }
    }
}

struct DatasheetSection<Content: View>: View {
    let letter: String
    let title: String
    let trailing: String?
    let note: String?
    let topSpacing: CGFloat
    let content: Content

    @Environment(\.datasheetPalette) private var palette

    init(
        letter: String,
        title: String,
        trailing: String? = nil,
        note: String? = nil,
        topSpacing: CGFloat = 34,
        @ViewBuilder content: () -> Content
    ) {
        self.letter = letter
        self.title = title
        self.trailing = trailing
        self.note = note
        self.topSpacing = topSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                if !self.letter.isEmpty {
                    Text(self.letter.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(self.palette.invForeground)
                        .background(self.palette.invBackground)
                }

                Text(self.title.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(self.palette.text)

                if let trailing = self.trailing {
                    Spacer(minLength: 8)
                    Text(trailing.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(self.palette.text2)
                }

                Rectangle()
                    .fill(self.palette.rule)
                    .frame(height: 1)
            }

            if let note = self.note {
                Text(note)
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(2)
                    .foregroundStyle(self.palette.text2)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
            }

            self.content
        }
        .padding(.top, self.topSpacing)
    }
}

struct DatasheetRow<Control: View>: View {
    let label: String
    let help: String?
    let indent: Bool
    let dimmed: Bool
    let showsBottomRule: Bool
    let control: Control

    @Environment(\.datasheetPalette) private var palette

    init(
        label: String,
        help: String? = nil,
        indent: Bool = false,
        dimmed: Bool = false,
        showsBottomRule: Bool = true,
        @ViewBuilder control: () -> Control
    ) {
        self.label = label
        self.help = help
        self.indent = indent
        self.dimmed = dimmed
        self.showsBottomRule = showsBottomRule
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(self.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(self.dimmed ? self.palette.textDim : self.palette.text)

                if let help = self.help {
                    Text(help)
                        .font(.system(size: 13, weight: .regular))
                        .lineSpacing(2)
                        .foregroundStyle(self.dimmed ? self.palette.textDim : self.palette.text2)
                        .frame(maxWidth: 470, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            self.control
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.leading, self.indent ? 22 : 0)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) {
            if self.showsBottomRule {
                Rectangle()
                    .fill(self.palette.ruleSoft)
                    .frame(height: 1)
            }
        }
        .overlay(alignment: .leading) {
            if self.indent {
                GeometryReader { proxy in
                    Path { path in
                        path.move(to: CGPoint(x: 6, y: 0))
                        path.addLine(to: CGPoint(x: 6, y: proxy.size.height / 2))
                        path.addLine(to: CGPoint(x: 15, y: proxy.size.height / 2))
                    }
                    .stroke(self.palette.graticule, lineWidth: 1)
                }
                .frame(width: 22)
                .allowsHitTesting(false)
            }
        }
    }
}

struct DatasheetEmptyState: View {
    let placard: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    private let illustration: AnyView?

    @Environment(\.datasheetPalette) private var palette

    init(
        placard: String = "00 ENTRIES",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.placard = placard
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.illustration = nil
    }

    init<Illustration: View>(
        placard: String = "00 ENTRIES",
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder illustration: () -> Illustration
    ) {
        self.placard = placard
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.illustration = AnyView(illustration())
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                for x in stride(from: CGFloat.zero, through: size.width, by: 24) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(self.palette.ruleSoft), lineWidth: 1)
                }
                for y in stride(from: CGFloat.zero, through: size.height, by: 24) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(self.palette.ruleSoft), lineWidth: 1)
                }
            }

            VStack(spacing: 0) {
                if let illustration = self.illustration {
                    illustration
                        .padding(.bottom, 16)
                }

                Text(self.placard.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(self.palette.text2)
                    .padding(.bottom, 10)

                Text(self.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(self.palette.text)
                    .padding(.bottom, 8)

                Text(self.message)
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(self.palette.text2)
                    .frame(maxWidth: 360)

                if let actionTitle = self.actionTitle, let action = self.action {
                    DatasheetBracketed(rest: true) {
                        Button(action: action) {
                            Text(actionTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(minWidth: 112, minHeight: 36)
                                .foregroundStyle(self.palette.invForeground)
                                .background(self.palette.invBackground)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 18)
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(self.palette.surface)
            .overlay {
                Rectangle().strokeBorder(self.palette.rule, lineWidth: 1)
            }
        }
        .background(self.palette.surface)
        .frame(maxWidth: .infinity, minHeight: 440)
        .overlay {
            Rectangle().strokeBorder(self.palette.rule, lineWidth: 1)
        }
    }
}
