//
//  FeedbackView.swift
//  fluid
//
//  Extracted from ContentView.swift to reduce monolithic architecture.
//  Created: 2025-12-14
//

import AppKit
import SwiftUI

struct FeedbackView: View {
    @Environment(\.datasheetPalette) private var palette

    @State private var feedbackText = ""
    @State private var includeSystemInfo = true

    private var trimmedFeedback: String {
        self.feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var repositoryURL: URL {
        MouthKeysLinks.newIssue.deletingLastPathComponent().deletingLastPathComponent()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DatasheetSheetHeader(
                    placard: "09 / Help",
                    title: "Send Feedback",
                    lede: "Report a bug or suggest a change on the MouthKeys GitHub."
                ) {
                    self.repositoryLink(title: "MouthKeys on GitHub", compact: true)
                }

                self.sectionHeading("Feedback")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: self.$feedbackText)
                        .font(.system(size: 13))
                        .foregroundStyle(self.palette.text)
                        .scrollContentBackground(.hidden)
                        .padding(8)

                    if self.feedbackText.isEmpty {
                        Text("Share your thoughts, report bugs, or suggest features...")
                            .font(.system(size: 13))
                            .foregroundStyle(self.palette.textDim)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 15)
                            .allowsHitTesting(false)
                    }
                }
                .frame(height: 200)
                .background(self.palette.field)
                .overlay {
                    Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                }

                DatasheetRow(
                    label: "Include app and macOS version",
                    help: Self.systemInfo(),
                    showsBottomRule: false
                ) {
                    Toggle("Include app and macOS version", isOn: self.$includeSystemInfo)
                        .labelsHidden()
                        .toggleStyle(DatasheetToggleStyle())
                }
                .padding(.top, 4)

                HStack(alignment: .center, spacing: 18) {
                    DatasheetBracketed(rest: !self.trimmedFeedback.isEmpty) {
                        Button(action: self.openFeedbackIssue) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.square")
                                Text("Open GitHub Issue")
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(self.palette.invForeground)
                            .frame(minWidth: 172, minHeight: 40)
                            .background(self.palette.invBackground)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(self.trimmedFeedback.isEmpty)
                        .opacity(self.trimmedFeedback.isEmpty ? 0.5 : 1)
                    }

                    Text("Opens a prefilled issue in your browser. Nothing is sent until you submit it on GitHub.")
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundStyle(self.palette.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 8)

                self.sectionHeading("Credit")
                HStack(alignment: .top, spacing: 16) {
                    Rectangle()
                        .fill(self.palette.text)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("BUILT ON FLUIDVOICE  ·  ALTIC-DEV")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(self.palette.text2)

                        Text("MouthKeys is built on FluidVoice by altic-dev.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(self.palette.text)

                        Text("FluidVoice is the open-source dictation app this fork comes from. If MouthKeys is useful to you, consider supporting its original author.")
                            .font(.system(size: 13))
                            .lineSpacing(3)
                            .foregroundStyle(self.palette.text2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            self.repositoryLink(title: "FluidVoice", destination: MouthKeysLinks.upstreamRepository)
                            self.repositoryLink(title: "Sponsor FluidVoice", destination: MouthKeysLinks.upstreamSponsor)
                        }
                        .padding(.top, 2)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay {
                        Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                self.sectionHeading("About")
                FeedbackFigure(repositoryURL: self.repositoryURL)
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(.horizontal, 40)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(self.palette.text)

            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)
        }
        .padding(.top, 26)
        .padding(.bottom, 12)
    }

    private func repositoryLink(title: String, destination: URL? = nil, compact: Bool = false) -> some View {
        let url = destination ?? self.repositoryURL
        return Link(destination: url) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.right.square")
                Text(title)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(self.palette.text)
            .padding(.horizontal, compact ? 12 : 14)
            .frame(height: 34)
            .overlay {
                Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func openFeedbackIssue() {
        let feedback = self.trimmedFeedback
        guard !feedback.isEmpty else { return }

        let url = MouthKeysLinks.prefilledIssueURL(
            title: MouthKeysLinks.issueTitle(forFeedback: feedback),
            body: feedback,
            footer: self.includeSystemInfo ? "---\n" + Self.systemInfo() : ""
        )
        DebugLogger.shared.info("Opening prefilled feedback issue on GitHub", source: "FeedbackView")
        NSWorkspace.shared.open(url)
    }

    private static func systemInfo() -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        return """
        MouthKeys \(version) (\(build))
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
    }
}

private struct FeedbackFigure: View {
    let repositoryURL: URL

    @Environment(\.datasheetPalette) private var palette

    private var revision: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                self.placard("Fig. 1  ·  MouthKeys · the keycap grin")
                Spacer()
                self.placard("Plan view · scale 6.4 : 1")
            }
            .padding(.horizontal, 16)
            .frame(height: 34)
            .overlay(alignment: .bottom) {
                Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
            }

            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Canvas { context, canvasSize in
                        for x in stride(from: CGFloat.zero, through: canvasSize.width, by: 24) {
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                            context.stroke(path, with: .color(self.palette.ruleSoft), lineWidth: 1)
                        }
                        for y in stride(from: CGFloat.zero, through: canvasSize.height, by: 24) {
                            var path = Path()
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                            context.stroke(path, with: .color(self.palette.ruleSoft), lineWidth: 1)
                        }

                        var dimensions = Path()
                        dimensions.move(to: CGPoint(x: size.width * 0.17, y: size.height * 0.22))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.17, y: size.height * 0.76))
                        dimensions.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.86))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.57, y: size.height * 0.86))
                        dimensions.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.49))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.57, y: size.height * 0.49))
                        dimensions.move(to: CGPoint(x: size.width * 0.54, y: size.height * 0.35))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.26))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.26))
                        dimensions.move(to: CGPoint(x: size.width * 0.54, y: size.height * 0.52))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.52))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.52))
                        dimensions.move(to: CGPoint(x: size.width * 0.48, y: size.height * 0.67))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.65, y: size.height * 0.70))
                        dimensions.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.70))
                        context.stroke(dimensions, with: .color(self.palette.text2), lineWidth: 1)
                    }

                    DatasheetGrin()
                        .frame(width: size.width * 0.46, height: size.height * 0.60)
                        .position(x: size.width * 0.38, y: size.height * 0.50)

                    Text("21.3")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(self.palette.text2)
                        .rotationEffect(.degrees(-90))
                        .position(x: size.width * 0.13, y: size.height * 0.49)

                    self.teethLabel("01     02     03     04     05     06     07")
                        .position(x: size.width * 0.38, y: size.height * 0.18)
                    self.teethLabel("08     09     10     11     12     13     14")
                        .position(x: size.width * 0.38, y: size.height * 0.78)

                    VStack(alignment: .leading, spacing: 10) {
                        self.callout("KEYCAP · PLAN VIEW", detail: "FACE INSET 0.22  ·  4 CHAMFERS")
                        self.callout("BITE 3.0  ·  SMILE 2.5", detail: nil)
                        HStack(spacing: 6) {
                            Rectangle().fill(self.palette.accent).frame(width: 6, height: 6)
                            self.callout("TOOTH 12 · GOLD", detail: "THE ONE COLOUR · #FF4F1F")
                        }
                    }
                    .frame(width: size.width * 0.28, alignment: .leading)
                    .position(x: size.width * 0.80, y: size.height * 0.48)

                    self.placard("43.4  ·  7 KEYS × 6.4 PITCH")
                        .position(x: size.width * 0.38, y: size.height * 0.89)
                }
            }
            .frame(height: 250)

            HStack(spacing: 0) {
                self.placard("DWG MK-001")
                    .frame(width: 92, alignment: .leading)
                self.ruleDivider
                self.placard("REV \(self.revision)")
                    .frame(width: 100, alignment: .leading)
                self.ruleDivider
                Link("MIT · github.com/BenevolentFutures/MouthKeys ↗", destination: self.repositoryURL)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                self.ruleDivider
                self.placard("SHEET 09 / 09")
                    .frame(width: 102, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .frame(height: 30)
            .overlay(alignment: .top) {
                Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
            }
        }
        .overlay {
            Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
        }
    }

    private var ruleDivider: some View {
        Rectangle().fill(self.palette.ruleSoft).frame(width: 1)
    }

    private func placard(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.45)
            .foregroundStyle(self.palette.text2)
            .lineLimit(1)
    }

    private func teethLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(self.palette.text2)
            .lineLimit(1)
    }

    private func callout(_ title: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            self.placard(title)
            if let detail {
                self.placard(detail)
            }
        }
    }
}

#Preview {
    FeedbackView()
        .datasheetPalette()
}
