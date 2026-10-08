import SwiftUI

struct StatsView: View {
    @ObservedObject private var historyStore = TranscriptionHistoryStore.shared
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.datasheetPalette) private var palette

    @State private var showResetConfirmation = false
    @State private var showWPMEditor = false
    @State private var editingWPM = ""
    @State private var chartDays = 7
    @State private var hoveredActivityIndex: Int?

    private static let activityTooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                self.pageHeader
                self.kpiGrid
                self.activitySection.padding(.top, 34)
                self.milestonesSection.padding(.top, 34)

                HStack(alignment: .top, spacing: 20) {
                    self.insightsSection
                    self.recordsSection
                }
                .padding(.top, 34)

                self.resetAction.padding(.top, 34)
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(self.palette.surface)
        .alert("Reset All Stats", isPresented: self.$showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                self.historyStore.clearAllHistory()
            }
        } message: {
            Text("This will permanently delete all \(self.historyStore.entries.count) transcriptions and reset all statistics. This action cannot be undone.")
        }
    }

    // MARK: - Header and KPIs

    private var pageHeader: some View {
        DatasheetSheetHeader(placard: "ACTIVITY / 07", title: "Stats", lede: self.motivationalMessage(
            wordsToday: self.historyStore.todaySummary.words,
            streak: self.historyStore.currentStreak
        )) {
            HStack(spacing: 6) {
                DatasheetStatusSquare(kind: self.historyStore.currentStreak > 0 ? .orange : .outline)
                DatasheetMonoLabel(
                    text: self.historyStore.currentStreak > 0
                        ? "\(self.historyStore.currentStreak) DAY STREAK"
                        : "NO STREAK",
                    role: DatasheetTheme.Typography.tableLabel,
                    color: self.historyStore.currentStreak > 0 ? self.palette.text : self.palette.text2
                )
            }
            .fixedSize()
        }
    }

    private var kpiGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                self.timeSavedKPI
                self.totalWordsKPI
                self.streakKPI
                self.transcriptionsKPI
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) { self.timeSavedKPI; self.totalWordsKPI }
                HStack(spacing: 0) { self.streakKPI; self.transcriptionsKPI }
            }
        }
        .overlay {
            Rectangle().strokeBorder(self.palette.rule, lineWidth: 1)
        }
    }

    private var timeSavedKPI: some View {
        self.kpiCell(title: "TIME SAVED", value: self.historyStore.formattedTimeSaved(typingWPM: self.settings.userTypingWPM)) {
            Button {
                self.editingWPM = "\(self.settings.userTypingWPM)"
                self.showWPMEditor = true
            } label: {
                HStack(spacing: 5) {
                    Text("BASED ON \(self.settings.userTypingWPM) WPM TYPING")
                    Image(systemName: "pencil")
                        .font(.system(size: 8, weight: .medium))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(self.palette.text2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .datasheetHoverBracket()
            .popover(isPresented: self.$showWPMEditor) {
                self.wpmEditorPopover
            }
        }
    }

    private var totalWordsKPI: some View {
        self.kpiCell(title: "TOTAL WORDS", value: self.formatNumber(self.historyStore.totalWords)) {
            DatasheetMonoLabel(
                text: "+\(self.formatNumber(self.historyStore.wordsToday)) TODAY",
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
        }
    }

    private var streakKPI: some View {
        self.kpiCell(title: "CURRENT STREAK", value: "\(self.historyStore.currentStreak)") {
            DatasheetMonoLabel(
                text: "BEST: \(self.historyStore.bestStreak) DAYS",
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
        }
    }

    private var transcriptionsKPI: some View {
        self.kpiCell(title: "TRANSCRIPTIONS", value: self.formatNumber(self.historyStore.entries.count)) {
            VStack(alignment: .leading, spacing: 3) {
                DatasheetMonoLabel(
                    text: "\(self.historyStore.todaySummary.transcriptions) TODAY",
                    role: DatasheetTheme.Typography.tableLabel,
                    color: self.palette.text2
                )
                .accessibilityLabel("\(self.historyStore.todaySummary.transcriptions) sessions today")
                DatasheetMonoLabel(
                    text: "AVG: \(self.historyStore.averageWordsPerTranscription) WORDS EACH",
                    role: DatasheetTheme.Typography.tableLabel,
                    color: self.palette.text2
                )
            }
        }
    }

    private func kpiCell<Foot: View>(title: String, value: String, @ViewBuilder foot: () -> Foot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DatasheetMonoLabel(
                text: title,
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)

            foot()
                .frame(maxWidth: .infinity, minHeight: 31, alignment: .topLeading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 170, maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .overlay(alignment: .trailing) {
            Rectangle().fill(self.palette.ruleSoft).frame(width: 1)
        }
    }

    private var wpmEditorPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatasheetMonoLabel(text: "TYPING SPEED", color: self.palette.text2)

            TextField("WPM", text: self.$editingWPM)
                .textFieldStyle(.plain)
                .font(.system(size: 14, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 74, height: 32)
                .background(self.palette.field)
                .overlay { Rectangle().strokeBorder(self.palette.edge, lineWidth: 1) }
                .accessibilityLabel("Words per minute")

            Text("Average typing: 40 WPM · Professional: 65–75 WPM")
                .font(.system(size: 11))
                .foregroundStyle(self.palette.text2)

            HStack(spacing: 8) {
                self.squareActionButton("Cancel") {
                    self.showWPMEditor = false
                }

                DatasheetBracketed(rest: true) {
                    Button("Save") {
                        if let wpm = Int(self.editingWPM), wpm > 0 {
                            self.settings.userTypingWPM = wpm
                        }
                        self.showWPMEditor = false
                    }
                    .buttonStyle(DatasheetPrimaryButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .background(self.palette.surface)
        .environment(\.datasheetPalette, self.palette)
    }

    // MARK: - Activity chart

    private var activitySection: some View {
        VStack(spacing: 8) {
            self.sectionHeading("ACTIVITY")

            VStack(spacing: 0) {
                HStack {
                    DatasheetMonoLabel(text: "WORDS PER DAY", color: self.palette.text2)
                    Spacer(minLength: 8)
                    DatasheetSegmented(
                        selection: self.$chartDays,
                        choices: [
                            .init(value: 7, title: "7 DAYS"),
                            .init(value: 30, title: "30 DAYS"),
                        ],
                        cellWidth: 76
                    )
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

                self.activityPlot

                HStack(spacing: 8) {
                    DatasheetMonoLabel(
                        text: "\(self.formatNumber(self.activityTotals.words)) WORDS ACROSS \(self.activityTotals.activeDays) ACTIVE DAYS",
                        role: DatasheetTheme.Typography.tableLabel,
                        color: self.palette.text
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 12)
                .frame(height: 34)
                .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
            }
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        }
    }

    private var activityData: [(date: Date, words: Int)] {
        self.historyStore.dailyWordCounts(days: self.chartDays)
    }

    private var activityTotals: (words: Int, activeDays: Int) {
        let data = self.activityData
        return (
            data.reduce(0) { $0 + $1.words },
            data.filter { $0.words > 0 }.count
        )
    }

    private var activityPlot: some View {
        let data = self.activityData
        let maxWords = data.map(\.words).max() ?? 0
        let plotHeight: CGFloat = 128
        let barWidth: CGFloat = self.chartDays == 7 ? 30 : 8
        let spacing: CGFloat = self.chartDays == 7 ? 8 : 2

        return HStack(alignment: .bottom, spacing: 8) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle().fill(self.palette.rule).frame(height: 1)
                }

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                        self.activityBar(
                            item,
                            index: index,
                            maxWords: maxWords,
                            barWidth: barWidth,
                            plotHeight: plotHeight
                        )
                    }
                }
            }
            .frame(height: plotHeight)
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 0) {
                Text(self.axisLabel(maxWords))
                Spacer(minLength: 0)
                Text(self.axisLabel(maxWords / 2))
                Spacer(minLength: 0)
                Text("0")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(self.palette.text2)
            .frame(width: 36, height: plotHeight, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            if maxWords == 0 {
                Text("NO ACTIVITY YET")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(self.palette.text2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    }

    private func activityBar(
        _ item: (date: Date, words: Int),
        index: Int,
        maxWords: Int,
        barWidth: CGFloat,
        plotHeight: CGFloat
    ) -> some View {
        let isToday = Calendar.current.isDateInToday(item.date)
        let scaledHeight = maxWords > 0 && item.words > 0
            ? CGFloat(item.words) / CGFloat(maxWords) * (plotHeight - 20)
            : 2

        return VStack(spacing: 4) {
            Rectangle()
                .fill(isToday ? self.palette.accent : (item.words > 0 ? self.palette.ink : self.palette.ruleSoft))
                .frame(width: barWidth, height: max(2, scaledHeight))
                .overlay(alignment: .top) {
                    if self.hoveredActivityIndex == index {
                        self.activityTooltip(for: item)
                            .offset(y: -46)
                            .zIndex(1)
                    }
                }
                .contentShape(Rectangle())
                .onHover { self.hoveredActivityIndex = $0 ? index : nil }

            if self.chartDays == 7 {
                Text(Calendar.current.isDateInToday(item.date) ? "TODAY" : self.dayLabel(item.date))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.25)
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(minWidth: barWidth, maxWidth: .infinity, alignment: .center)
    }

    private func activityTooltip(for item: (date: Date, words: Int)) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            DatasheetMonoLabel(
                text: Self.activityTooltipDateFormatter.string(from: item.date),
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
            Text("\(self.formatNumber(item.words)) \(item.words == 1 ? "word" : "words")")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(self.palette.text)
        }
        .padding(8)
        .background(self.palette.surface)
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        .fixedSize()
        .allowsHitTesting(false)
    }

    private func axisLabel(_ value: Int) -> String {
        guard value >= 1000 else { return "\(value)" }
        let thousands = Double(value) / 1000
        return thousands.rounded(.down) == thousands ? "\(Int(thousands))K" : String(format: "%.1fK", thousands)
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(spacing: 8) {
            self.sectionHeading(
                "MILESTONES",
                trailing: "\(self.historyStore.totalMilestonesAchieved) OF \(self.historyStore.totalMilestonesPossible)"
            )

            VStack(spacing: 0) {
                self.milestoneRow(title: "WORDS", milestones: self.historyStore.wordMilestones)
                self.milestoneRow(title: "TRANSCRIPTIONS", milestones: self.historyStore.transcriptionMilestones)
                self.milestoneRow(title: "STREAK", milestones: self.historyStore.streakMilestones)
            }
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        }
    }

    private func milestoneRow(
        title: String,
        milestones: [(target: Int, achieved: Bool, label: String)]
    ) -> some View {
        HStack(spacing: 0) {
            DatasheetMonoLabel(text: title, role: DatasheetTheme.Typography.tableLabel, color: self.palette.text2)
                .frame(width: 112, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(minHeight: 38)
                .overlay(alignment: .trailing) { Rectangle().fill(self.palette.ruleSoft).frame(width: 1) }

            ForEach(Array(milestones.enumerated()), id: \.offset) { _, milestone in
                Text(milestone.label.uppercased())
                    .font(.system(size: 10, weight: milestone.achieved ? .semibold : .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(milestone.achieved ? self.palette.invForeground : self.palette.text2)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(milestone.achieved ? self.palette.invBackground : self.palette.surface)
                    .overlay(alignment: .trailing) { Rectangle().fill(self.palette.ruleSoft).frame(width: 1) }
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    // MARK: - Insights and records

    private var insightsSection: some View {
        VStack(spacing: 8) {
            self.sectionHeading("INSIGHTS")
            VStack(spacing: 0) {
                self.insightRow(title: "TOP APPS", value: self.historyStore.topAppsFormatted(limit: 3).joined(separator: " · "), fallback: "No data yet")
                self.insightRow(title: "AI ENHANCED", value: "\(self.historyStore.aiEnhancementRate)%", fallback: "0%")
                self.insightRow(title: "PEAK TIME", value: self.historyStore.peakHourFormatted, fallback: "N/A")
                self.insightRow(title: "AVG LENGTH", value: "\(self.historyStore.averageWordsPerTranscription) words", fallback: "0 words")
            }
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var recordsSection: some View {
        VStack(spacing: 8) {
            self.sectionHeading("PERSONAL RECORDS")
            VStack(spacing: 0) {
                self.insightRow(title: "LONGEST TRANSCRIPTION", value: "\(self.historyStore.longestTranscriptionWords) words", fallback: "0 words")
                self.insightRow(title: "MOST WORDS IN A DAY", value: "\(self.formatNumber(self.historyStore.mostWordsInDay)) words", fallback: "0 words")
                self.insightRow(title: "MOST IN A DAY", value: "\(self.historyStore.mostTranscriptionsInDay) transcriptions", fallback: "0 transcriptions")
            }
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func insightRow(title: String, value: String, fallback: String) -> some View {
        HStack(spacing: 12) {
            DatasheetMonoLabel(
                text: title,
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            Text(value.isEmpty ? fallback : value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
    }

    private var resetAction: some View {
        HStack {
            Spacer()
            DatasheetBracketed(rest: false) {
                Button {
                    self.showResetConfirmation = true
                } label: {
                    Label("Reset All Stats", systemImage: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(self.historyStore.entries.isEmpty)
                .opacity(self.historyStore.entries.isEmpty ? 0.4 : 1)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private func sectionHeading(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 10) {
            DatasheetMonoLabel(
                text: title,
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text
            )

            if let trailing {
                DatasheetMonoLabel(
                    text: trailing,
                    role: DatasheetTheme.Typography.tableLabel,
                    color: self.palette.text2
                )
            }

            Rectangle().fill(self.palette.rule).frame(height: 1)
        }
        .frame(height: 18)
    }

    private func squareActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        DatasheetBracketed(rest: false) {
            Button(title, action: action)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.palette.text)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                .buttonStyle(.plain)
        }
    }

    private func motivationalMessage(wordsToday: Int, streak: Int) -> String {
        if wordsToday == 0 {
            return streak > 0 ? "Keep the streak alive — say a few words." : "Ready when you are. Start dictating to save time."
        }

        if wordsToday < 100 {
            return "Warming up. Every word counts."
        }

        if wordsToday < 500 {
            return "Solid pace — you're saving real time today."
        }

        if wordsToday < 1500 {
            return streak > 2 ? "On fire. The streak is paying off." : "Strong day. Your hands thank you."
        }

        return "Outstanding. You've reclaimed serious time today."
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

#Preview {
    StatsView()
        .frame(width: 800, height: 600)
        .datasheetPalette()
}
