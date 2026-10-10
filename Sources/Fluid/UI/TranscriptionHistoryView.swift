import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct TranscriptionHistoryView: View {
    var onOpenPlayground: (() -> Void)?

    @ObservedObject private var historyStore = TranscriptionHistoryStore.shared
    @Environment(\.datasheetPalette) private var palette

    @State private var searchQuery = ""
    @State private var showClearConfirmation = false
    @State private var selectedEntryID: UUID?
    /// The last search's matches, computed off the main thread for each query and history change.
    @State private var searchResults: SearchResults?
    /// Rows the index has built so far. It grows a page at a time as the list scrolls, so a
    /// history change (one per dictation) costs a few hundred rows, not every entry.
    @State private var shownRowLimit = Self.rowPageSize

    static let rowPageSize = 200

    init(onOpenPlayground: (() -> Void)? = nil) {
        self.onOpenPlayground = onOpenPlayground
    }

    private static let rowTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private struct SearchKey: Equatable {
        let query: String
        let revision: UInt64
    }

    private struct SearchResults {
        let query: String
        let entries: [TranscriptionHistoryEntry]
    }

    private var isSearching: Bool {
        !self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The history, or the matches for the search. Never searched here: rows and helpers read it
    /// many times per render. While a new search runs, the previous matches stay up (the whole
    /// history before the first ones land).
    private var filteredEntries: [TranscriptionHistoryEntry] {
        guard self.isSearching, let results = self.searchResults else { return self.historyStore.entries }
        return results.entries
    }

    /// Searches off the main thread, so a dictation landing while a search is up costs it nothing.
    /// A new query waits briefly for the next keystroke.
    private func runSearch() async {
        guard self.isSearching else {
            self.searchResults = nil
            return
        }
        let query = self.searchQuery
        if self.searchResults?.query != query {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
        }
        let entries = self.historyStore.entries
        let matches = await Task.detached(priority: .userInitiated) {
            TranscriptionHistoryStore.search(query: query, in: entries)
        }.value
        guard !Task.isCancelled else { return }
        self.searchResults = SearchResults(query: query, entries: matches)
    }

    private var selectedEntry: TranscriptionHistoryEntry? {
        guard let id = self.selectedEntryID else { return self.filteredEntries.first }
        return self.filteredEntries.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if self.historyStore.entries.isEmpty, self.searchQuery.isEmpty {
                DatasheetEmptyState(
                    placard: "00 ENTRIES",
                    title: "No History Yet",
                    message: "Your transcriptions will appear here. Start dictating to begin.",
                    actionTitle: "Open Playground",
                    action: { self.onOpenPlayground?() }
                ) {
                    DatasheetGrin(style: .outline)
                        .frame(width: 96, height: 48)
                }
            } else {
                HSplitView {
                    self.indexPanel
                        .frame(minWidth: 200, idealWidth: 300, maxWidth: 360)

                    if let entry = self.selectedEntry {
                        self.entryDetailView(entry)
                            .frame(minWidth: 320)
                    } else {
                        self.noSelectionView
                            .frame(minWidth: 320)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(self.palette.surface)
        .onChange(of: self.searchQuery) { _, _ in
            self.shownRowLimit = Self.rowPageSize
        }
        .task(id: SearchKey(query: self.searchQuery, revision: self.historyStore.revision)) {
            await self.runSearch()
        }
        .onAppear {
            if self.selectedEntryID == nil {
                self.selectedEntryID = self.filteredEntries.first?.id
            }
        }
        .alert("Clear All History", isPresented: self.$showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.historyStore.clearAllHistory()
                    self.selectedEntryID = nil
                }
            }
        } message: {
            Text("This will permanently delete all \(self.historyStore.entries.count) transcription entries. This action cannot be undone.")
        }
    }

    // MARK: - Index panel

    private var indexPanel: some View {
        VStack(spacing: 0) {
            self.searchBar
                .padding(12)

            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)

            if self.filteredEntries.isEmpty {
                self.noSearchResults
            } else {
                self.entryListView
            }

            self.footerView
        }
        .background(self.palette.surface)
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.palette.text2)
                .accessibilityHidden(true)

            TextField("Search transcriptions...", text: self.$searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text)
                .accessibilityLabel("Search transcriptions")

            DatasheetBracketed(rest: false) {
                Button {
                    self.searchQuery = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(self.palette.text2)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
            .opacity(self.searchQuery.isEmpty ? 0 : 1)
            .disabled(self.searchQuery.isEmpty)
            .accessibilityHidden(self.searchQuery.isEmpty)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(self.palette.field)
        .overlay {
            Rectangle().strokeBorder(self.palette.edge, lineWidth: 1)
        }
    }

    private var entryListView: some View {
        let entries = self.filteredEntries
        let shownCount = min(entries.count, self.shownRowLimit)
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(entries.prefix(shownCount).enumerated()), id: \.element.id) { offset, entry in
                    if self.startsNewDay(at: offset) {
                        self.dayHeading(for: entry.timestamp)
                    }

                    self.entryRow(entry, index: offset + 1)
                }

                if shownCount < entries.count {
                    // Scrolled to the end of the built rows: build the next page.
                    Color.clear
                        .frame(height: 1)
                        .onAppear { self.shownRowLimit = shownCount + Self.rowPageSize }
                }
            }
        }
        .accessibilityLabel("Transcription history")
    }

    private func startsNewDay(at index: Int) -> Bool {
        guard index > 0, index < self.filteredEntries.count else { return true }
        return !Calendar.current.isDate(
            self.filteredEntries[index - 1].timestamp,
            inSameDayAs: self.filteredEntries[index].timestamp
        )
    }

    private func dayHeading(for date: Date) -> some View {
        HStack(spacing: 10) {
            DatasheetMonoLabel(
                text: self.dayTitle(for: date),
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
            .fixedSize()
            Rectangle()
                .fill(self.palette.ruleSoft)
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 30, alignment: .bottom)
        .background(self.palette.surface)
    }

    private func dayTitle(for date: Date) -> String {
        let day = Self.dayFormatter.string(from: date).uppercased()
        if Calendar.current.isDateInToday(date) { return "TODAY · \(day)" }
        if Calendar.current.isDateInYesterday(date) { return "YESTERDAY · \(day)" }
        return day
    }

    private func entryRow(_ entry: TranscriptionHistoryEntry, index: Int) -> some View {
        let isSelected = self.selectedEntryID == entry.id

        return HistoryIndexRow(isSelected: isSelected, action: {
            self.selectedEntryID = entry.id
        }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: "%02d", index))
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .monospacedDigit()

                    Text(Self.rowTimeFormatter.string(from: entry.timestamp).uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.3)
                        .opacity(0.72)
                }
                .frame(width: 48, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.previewText)
                        .font(.system(size: 13, weight: .regular))
                        .lineSpacing(2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(self.durationText(for: entry)) · \(self.wordCount(entry.processedText)) WORDS · \(entry.appName.isEmpty ? "UNKNOWN APP" : entry.appName.uppercased())")
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 4) {
                            Rectangle()
                                .strokeBorder(isSelected ? self.palette.invForeground : self.palette.text2, lineWidth: 1)
                                .frame(width: 6, height: 6)
                            Text("UNKNOWN")
                        }
                        .help("Delivery outcome was not recorded for this entry.")
                        .accessibilityLabel("Delivery outcome not recorded")
                        .fixedSize()
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.35)
                    .opacity(0.74)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
        }
        .contextMenu {
            Button {
                self.copyToClipboard(entry.processedText)
            } label: {
                Label(entry.wasAIProcessed ? "Copy AI Text" : "Copy Text", systemImage: "doc.on.doc")
            }

            if entry.wasAIProcessed {
                Button {
                    self.copyToClipboard(entry.rawText)
                } label: {
                    Label("Copy Raw Text", systemImage: "doc.on.doc.fill")
                }

                Button {
                    self.copyToClipboard(self.combinedText(for: entry))
                } label: {
                    Label("Copy Both", systemImage: "doc.on.doc")
                }
            }

            if self.hasAudio(entry) {
                Divider()

                Button {
                    self.exportPair(entry)
                } label: {
                    Label("Export Pair...", systemImage: "square.and.arrow.up")
                }

                Button {
                    self.revealAudio(entry)
                } label: {
                    Label("Reveal Audio", systemImage: "waveform")
                }
            }

            Divider()

            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.historyStore.deleteEntry(id: entry.id)
                    if self.selectedEntryID == entry.id {
                        self.selectedEntryID = self.filteredEntries.first(where: { $0.id != entry.id })?.id
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var noSearchResults: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 16)
            DatasheetMonoLabel(text: "NO MATCHES", color: self.palette.text2)
            Text("Try a different search term.")
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
                .multilineTextAlignment(.center)
            DatasheetBracketed(rest: false) {
                Button("Clear Search") {
                    self.searchQuery = ""
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.palette.text)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    private var footerView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)

            HStack(spacing: 8) {
                Text("\(self.filteredEntries.count) ENTRIES · NEWEST FIRST")
                    .font(DatasheetTheme.Typography.tableLabel.font)
                    .tracking(DatasheetTheme.Typography.tableLabel.tracking)
                    .foregroundStyle(self.palette.text2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                if !self.historyStore.entries.isEmpty {
                    DatasheetBracketed(rest: false) {
                        Button("Clear All") {
                            self.showClearConfirmation = true
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
        }
        .background(self.palette.surface)
    }

    // MARK: - Detail

    private func entryDetailView(_ entry: TranscriptionHistoryEntry) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    self.titleBlock(entry)

                    if let aiError = entry.aiProcessingError {
                        self.aiErrorBanner(aiError)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            self.entryMetadataLabel("ENTRY \(self.entryNumber(for: entry)) · FINAL TEXT")
                            self.entryMetadataLabel("CONTEXT · \(self.windowLabel(entry))")
                            self.entryMetadataLabel("TIMESTAMP · \(entry.fullDateString.uppercased())")
                        }
                        .fixedSize(horizontal: false, vertical: true)

                        Text(entry.processedText)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(self.palette.text)
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .contextMenu {
                                Button {
                                    self.copyToClipboard(entry.processedText)
                                } label: {
                                    Label(entry.wasAIProcessed ? "Copy AI Text" : "Copy Text", systemImage: "doc.on.doc")
                                }

                                if entry.wasAIProcessed {
                                    Button {
                                        self.copyToClipboard(entry.rawText)
                                    } label: {
                                        Label("Copy Raw Text", systemImage: "doc.on.doc.fill")
                                    }

                                    Button {
                                        self.copyToClipboard(self.combinedText(for: entry))
                                    } label: {
                                        Label("Copy Both", systemImage: "doc.on.doc")
                                    }
                                }
                            }

                        if entry.wasAIProcessed {
                            Rectangle()
                                .fill(self.palette.ruleSoft)
                                .frame(height: 1)
                                .padding(.top, 8)

                            DatasheetMonoLabel(
                                text: "ORIGINAL TRANSCRIPTION",
                                role: DatasheetTheme.Typography.tableLabel,
                                color: self.palette.text2
                            )
                            .padding(.top, 8)

                            Text(entry.rawText)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(self.palette.text2)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        self.secondaryDetails(entry)
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            self.detailActions(entry)
        }
        .background(self.palette.surface)
    }

    private func entryMetadataLabel(_ text: String) -> some View {
        Text(text)
            .font(DatasheetTheme.Typography.tableLabel.font)
            .tracking(DatasheetTheme.Typography.tableLabel.tracking)
            .textCase(.uppercase)
            .foregroundStyle(self.palette.text2)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func titleBlock(_ entry: TranscriptionHistoryEntry) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                self.factCell(label: "APPLICATION", value: entry.appName.isEmpty ? "Unknown" : entry.appName)
                self.factCell(label: "LENGTH", value: self.durationText(for: entry))
                self.factCell(label: "WORDS", value: "\(self.wordCount(entry.processedText))")
                self.factCell(label: "CHARACTERS", value: "\(entry.characterCount)")
                self.deliveryFact
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    self.factCell(label: "APPLICATION", value: entry.appName.isEmpty ? "Unknown" : entry.appName)
                    self.factCell(label: "LENGTH", value: self.durationText(for: entry))
                }
                HStack(spacing: 0) {
                    self.factCell(label: "WORDS", value: "\(self.wordCount(entry.processedText))")
                    self.factCell(label: "CHARACTERS", value: "\(entry.characterCount)")
                    self.deliveryFact
                }
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(self.palette.rule)
                .frame(height: 1)
        }
    }

    private var deliveryFact: some View {
        VStack(alignment: .leading, spacing: 7) {
            DatasheetMonoLabel(
                text: "DELIVERY",
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
            HStack(spacing: 5) {
                Rectangle()
                    .strokeBorder(self.palette.text2, lineWidth: 1)
                    .frame(width: 6, height: 6)
                Text("UNKNOWN")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(self.palette.text)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Delivery outcome not recorded for this entry")
            .help("Delivery outcome was not recorded for this entry.")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }

    private func factCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            DatasheetMonoLabel(
                text: label,
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(self.palette.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(self.palette.ruleSoft)
                .frame(width: 1)
        }
    }

    private func aiErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(self.palette.accent)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 4) {
                DatasheetMonoLabel(text: "AI ENHANCEMENT FAILED", color: self.palette.accent)
                Text("The original transcription is shown below.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(self.palette.text)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(self.palette.text2)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .overlay {
            Rectangle().strokeBorder(self.palette.rule, lineWidth: 1)
        }
    }

    private func secondaryDetails(_ entry: TranscriptionHistoryEntry) -> some View {
        VStack(spacing: 0) {
            self.detailFact(label: "WINDOW", value: entry.windowTitle.isEmpty ? "Unknown" : entry.windowTitle)
            self.detailFact(
                label: "AI PROCESSED",
                value: entry.wasAIProcessed ? (entry.processingModel ?? "Yes") : "No"
            )
            self.detailFact(label: "AUDIO", value: self.audioMetadataText(for: entry))
        }
        .overlay {
            Rectangle().strokeBorder(self.palette.rule, lineWidth: 1)
        }
    }

    private func detailFact(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            DatasheetMonoLabel(
                text: label,
                role: DatasheetTheme.Typography.tableLabel,
                color: self.palette.text2
            )
            .frame(width: 124, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(self.palette.text2)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .overlay(alignment: .bottom) {
            Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
        }
    }

    private func detailActions(_ entry: TranscriptionHistoryEntry) -> some View {
        HistoryEntryActionBar(
            hasAudio: self.hasAudio(entry),
            copyHelp: entry.wasAIProcessed ? "Copy AI text" : "Copy transcription",
            copy: { self.copyToClipboard(entry.processedText) },
            audio: { self.revealAudio(entry) },
            export: { self.exportPair(entry) },
            delete: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let nextEntry = self.filteredEntries.first(where: { $0.id != entry.id })
                    self.historyStore.deleteEntry(id: entry.id)
                    self.selectedEntryID = nextEntry?.id
                }
            }
        )
    }

    private var noSelectionView: some View {
        VStack(spacing: 8) {
            DatasheetMonoLabel(text: "NO ENTRY SELECTED", color: self.palette.text2)
            Text("Choose a transcription from the index.")
                .font(.system(size: 13))
                .foregroundStyle(self.palette.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(self.palette.surface)
    }

    // MARK: - Existing history actions

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func combinedText(for entry: TranscriptionHistoryEntry) -> String {
        "\(entry.rawText)\n\n\(entry.processedText)"
    }

    private func hasAudio(_ entry: TranscriptionHistoryEntry) -> Bool {
        DictationAudioHistoryStore.shared.audioFileExists(for: entry)
    }

    private func audioMetadataText(for entry: TranscriptionHistoryEntry) -> String {
        guard let audio = entry.audio, self.hasAudio(entry) else { return "No" }
        let seconds = Double(audio.durationMilliseconds) / 1000.0
        let size = ByteCountFormatter.string(fromByteCount: Int64(audio.byteCount), countStyle: .file)
        return "Saved · \(String(format: "%.1f", seconds))s · \(size)"
    }

    private func durationText(for entry: TranscriptionHistoryEntry) -> String {
        guard let audio = entry.audio, self.hasAudio(entry) else { return "—" }
        let seconds = max(0, Int((Double(audio.durationMilliseconds) / 1000).rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func windowLabel(_ entry: TranscriptionHistoryEntry) -> String {
        let app = entry.appName.isEmpty ? "UNKNOWN APP" : entry.appName.uppercased()
        let window = entry.windowTitle.isEmpty ? "" : " — \(entry.windowTitle.uppercased())"
        return "\(app)\(window)"
    }

    private func entryNumber(for entry: TranscriptionHistoryEntry) -> String {
        let number = (self.filteredEntries.firstIndex(where: { $0.id == entry.id }) ?? 0) + 1
        return String(format: "%03d", number)
    }

    private func revealAudio(_ entry: TranscriptionHistoryEntry) {
        guard let url = DictationAudioHistoryStore.shared.audioFileURL(for: entry),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func exportPair(_ entry: TranscriptionHistoryEntry) {
        do {
            guard self.hasAudio(entry) else { throw DictationAudioHistoryError.audioMissing }
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = DictationAudioHistoryStore.shared.suggestedPairExportFilename(for: entry)

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try DictationAudioHistoryStore.shared.exportPair(entry: entry, to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Pair Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

private struct HistoryIndexRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    private var isInverted: Bool { self.isSelected || self.isHovered }

    var body: some View {
        Button(action: self.action) {
            self.content
                .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                .padding(.horizontal, 16)
                .foregroundStyle(self.isInverted ? self.palette.invForeground : self.palette.text)
                .background(self.isInverted ? self.palette.invBackground : self.palette.surface)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(self.palette.ruleSoft).frame(height: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

#Preview {
    TranscriptionHistoryView()
        .frame(width: 800, height: 600)
        .datasheetPalette()
}

/// The same actions stay fully labelled when the split detail becomes narrow.
struct HistoryEntryActionBar: View {
    let hasAudio: Bool
    let copyHelp: String
    let copy: () -> Void
    let audio: () -> Void
    let export: () -> Void
    let delete: () -> Void

    @Environment(\.datasheetPalette) private var palette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                self.copyButton
                self.audioButton
                self.exportButton
                Spacer(minLength: 0)
                self.deleteButton
            }
            .frame(minWidth: 366)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    self.copyButton
                    self.audioButton
                    Spacer(minLength: 0)
                    self.deleteButton
                }
                self.exportButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(self.palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(self.palette.rule).frame(height: 1) }
    }

    private var copyButton: some View {
        DatasheetBracketed(rest: true) {
            Button(action: self.copy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(self.palette.invForeground)
                    .fixedSize()
                    .frame(width: 100, height: 28)
                    .background(self.palette.invBackground)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(self.copyHelp)
            .accessibilityIdentifier("history-copy")
        }
    }

    private var audioButton: some View {
        self.secondaryButton("Audio", symbol: "waveform", width: 88, action: self.audio)
            .disabled(!self.hasAudio)
            .opacity(self.hasAudio ? 1 : 0.42)
    }

    private var exportButton: some View {
        self.secondaryButton("Export Pair", symbol: "square.and.arrow.up", width: 120, action: self.export)
            .disabled(!self.hasAudio)
            .opacity(self.hasAudio ? 1 : 0.42)
    }

    private var deleteButton: some View {
        DatasheetBracketed(rest: false) {
            Button(role: .destructive, action: self.delete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.palette.text)
                    .frame(width: 34, height: 28)
                    .contentShape(Rectangle())
                    .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .help("Delete entry")
            .accessibilityLabel("Delete entry")
        }
    }

    private func secondaryButton(_ title: String, symbol: String, width: CGFloat, action: @escaping () -> Void) -> some View {
        DatasheetBracketed(rest: false) {
            Button(action: action) {
                Label(title, systemImage: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(self.palette.text)
                    .fixedSize()
                    .frame(width: width, height: 28)
                    .contentShape(Rectangle())
                    .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }
}
