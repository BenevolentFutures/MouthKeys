import SwiftUI
import UniformTypeIdentifiers

struct MeetingTranscriptionView: View {
    let asrService: ASRService
    @StateObject private var transcriptionService: MeetingTranscriptionService
    @ObservedObject private var fileHistoryStore = FileTranscriptionHistoryStore.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var selectedFileURL: URL?
    @Environment(\.datasheetPalette) private var palette

    init(asrService: ASRService) {
        self.asrService = asrService
        _transcriptionService = StateObject(wrappedValue: MeetingTranscriptionService(asrService: asrService))
    }

    @State private var showingFilePicker = false
    @State private var showingExportDialog = false
    @State private var exportResult: TranscriptionResult?
    @State private var exportFormat: ExportFormat = .text
    @State private var showingCopyConfirmation = false
    @State private var isDropTargeted = false
    @State private var dropErrorMessage: String?

    enum ExportFormat: String, CaseIterable {
        case text = "Text (.txt)"
        case json = "JSON (.json)"

        var fileExtension: String {
            switch self {
            case .text: return "txt"
            case .json: return "json"
            }
        }
    }

    private var selectedFileIsVideo: Bool {
        guard let fileExtension = selectedFileURL?.pathExtension.lowercased() else { return false }
        return UTType(filenameExtension: fileExtension)?.conforms(to: .movie) ?? false
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DatasheetSheetHeader(
                    placard: "USE / 05",
                    title: "File Transcription",
                    lede: "Choose an audio or video file to transcribe."
                )

                self.fileSelectionCard

                if self.transcriptionService.isTranscribing {
                    self.progressSection.padding(.top, 24)
                }

                if let result = self.transcriptionService.result {
                    self.resultsCard(result: result).padding(.top, 24)
                }

                if let error = self.transcriptionService.error {
                    self.errorCard(error: error).padding(.top, 24)
                }

                if let message = self.dropErrorMessage {
                    self.dropErrorCard(message: message).padding(.top, 24)
                }

                if !self.fileHistoryStore.entries.isEmpty {
                    self.recentTranscriptionsSection.padding(.top, 24)
                }
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(self.palette.surface)
        .overlay(alignment: .topTrailing) {
            if self.showingCopyConfirmation {
                Text("Copied!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(self.palette.onAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(self.palette.accent)
                    .padding(16)
                    .transition(.opacity)
            }
        }
        .fileExporter(
            isPresented: self.$showingExportDialog,
            document: TranscriptionDocument(
                result: self.exportResult ?? TranscriptionResult(text: "", confidence: 0, duration: 0, processingTime: 0, fileName: "transcript"),
                format: self.exportFormat,
                service: self.transcriptionService
            ),
            contentType: self.exportFormat == .text ? .plainText : .json,
            defaultFilename: "\((self.exportResult?.fileName).map { "\($0)_transcript" } ?? "transcript").\(self.exportFormat.fileExtension)"
        ) { exportCompletion in
            switch exportCompletion {
            case .success:
                DebugLogger.shared.info("File exported successfully", source: "MeetingTranscriptionView")
            case let .failure(error):
                DebugLogger.shared.error("Export failed: \(error)", source: "MeetingTranscriptionView")
            }
            self.exportResult = nil
        }
    }

    // MARK: - Source file and options

    private var fileSelectionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let fileURL = self.selectedFileURL {
                HStack(spacing: 12) {
                    Image(systemName: self.selectedFileIsVideo ? "film" : "waveform")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(fileURL.lastPathComponent)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(self.palette.text)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text(self.formatFileSize(fileURL: fileURL))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(self.palette.text2)
                    }

                    Spacer(minLength: 8)

                    DatasheetBracketed(rest: false) {
                        Button {
                            self.selectedFileURL = nil
                            self.transcriptionService.reset()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(self.palette.text)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .help("Remove selected file")
                        .accessibilityLabel("Remove selected file")
                    }
                }
                .padding(14)
                .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

                if SpeakerDiarizationService.isSupported {
                    DatasheetRow(
                        label: "LABEL SPEAKERS",
                        help: self.selectedFileIsVideo
                            ? "Available for audio files only."
                            : "Identify who said what. Speaker models download on first use.",
                        showsBottomRule: true
                    ) {
                        Toggle("Label speakers", isOn: self.$settings.fileTranscriptionSpeakerLabelsEnabled)
                            .labelsHidden()
                            .toggleStyle(DatasheetToggleStyle())
                            .disabled(self.selectedFileIsVideo)
                    }

                    DatasheetRow(
                        label: "NUMBER OF SPEAKERS",
                        help: self.selectedFileIsVideo
                            ? "Available for audio files only."
                            : (self.settings.fileTranscriptionSpeakerLabelsEnabled
                                ? "Choose a count or let MouthKeys detect it."
                                : "Enable speaker labels to choose a count."),
                        indent: true,
                        showsBottomRule: true
                    ) {
                        DatasheetPicker(
                            title: "Number of speakers",
                            value: self.speakerCountLabel,
                            minimumWidth: 148
                        ) {
                            Button("Auto") { self.settings.fileTranscriptionExpectedSpeakerCount = 0 }
                                .disabled(!self.settings.fileTranscriptionSpeakerLabelsEnabled || self.selectedFileIsVideo)
                            ForEach(2...8, id: \.self) { count in
                                Button("\(count)") { self.settings.fileTranscriptionExpectedSpeakerCount = count }
                                    .disabled(!self.settings.fileTranscriptionSpeakerLabelsEnabled || self.selectedFileIsVideo)
                            }
                        }
                        .disabled(!self.settings.fileTranscriptionSpeakerLabelsEnabled || self.selectedFileIsVideo)
                    }
                }

                DatasheetRow(
                    label: "ENGINE",
                    help: "File transcription uses the currently selected Voice Engine model.",
                    showsBottomRule: false
                ) {
                    Text(self.asrService.activeProviderName)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                        .frame(maxWidth: 240, alignment: .trailing)
                }
                .padding(.horizontal, 14)

                DatasheetBracketed(rest: true) {
                    Button {
                        Task { await self.transcribeFile() }
                    } label: {
                        Label("Transcribe", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DatasheetPrimaryButtonStyle())
                    .disabled(self.transcriptionService.isTranscribing)
                }
                .padding(14)
                .overlay(alignment: .top) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
            } else {
                DatasheetBracketed(rest: true) {
                    Button {
                        self.showingFilePicker = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(self.isDropTargeted ? self.palette.accent : self.palette.text)

                            Text("Drag and drop a file here, or click to open")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(self.palette.text)
                                .multilineTextAlignment(.center)

                            Text(MeetingTranscriptionService.supportedFormatsDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(self.palette.text2)
                                .multilineTextAlignment(.center)

                            Text("CHOOSE FILE…")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(0.4)
                                .foregroundStyle(self.palette.text)
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 176)
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onDrop(of: [.fileURL], isTargeted: self.$isDropTargeted) { providers in
                        self.handleDrop(providers: providers)
                    }
                }
                .background(self.palette.surface)
                .overlay {
                    Rectangle()
                        .stroke(
                            self.isDropTargeted ? self.palette.accent : self.palette.ruleSoft,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .allowsHitTesting(false)
                }
                .fileImporter(
                    isPresented: self.$showingFilePicker,
                    allowedContentTypes: MeetingTranscriptionService.allowedContentTypes,
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case let .success(urls):
                        if let url = urls.first {
                            self.selectedFileURL = url
                            self.transcriptionService.reset()
                        }
                    case let .failure(error):
                        DebugLogger.shared.error("File picker error: \(error)", source: "MeetingTranscriptionView")
                    }
                }
            }
        }
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    private var speakerCountLabel: String {
        let count = self.settings.fileTranscriptionExpectedSpeakerCount
        return count == 0 ? "Auto" : "\(count)"
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.sectionHeading("TRANSCRIPTION PROGRESS")

            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: self.transcriptionService.progress)
                    .progressViewStyle(.linear)
                    .tint(self.palette.accent)

                HStack(spacing: 8) {
                    DatasheetStatusSquare(kind: .orange)
                    Text(self.transcriptionService.currentStatus.uppercased())
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(self.palette.text2)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
        }
    }

    // MARK: - Results

    private func resultsCard(result: TranscriptionResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    DatasheetMonoLabel(text: "TRANSCRIPTION COMPLETE", color: self.palette.text2)
                    HStack(spacing: 14) {
                        self.resultFact("\(String(format: "%.1f", result.duration))s", label: "LENGTH")
                        self.resultFact("\(String(format: "%.0f%%", result.confidence * 100))", label: "CONFIDENCE")
                        self.resultFact("\(String(format: "%.1f", result.duration / result.processingTime))×", label: "SPEED")
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    self.iconActionButton("Copy", systemImage: "doc.on.doc") {
                        self.copyToClipboard(result.text)
                    }
                    self.iconActionButton("Export", systemImage: "square.and.arrow.up") {
                        self.exportResult = result
                        self.showingExportDialog = true
                    }
                }
            }
            .padding(14)
            .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

            if let notice = self.transcriptionService.fallbackNotice {
                HStack(alignment: .top, spacing: 8) {
                    DatasheetStatusSquare(kind: .orange)
                    Text(notice)
                        .font(.system(size: 12))
                        .foregroundStyle(self.palette.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
            }

            if !result.speakerSegments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(result.speakerSegments) { segment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                DatasheetMonoLabel(text: segment.speaker, color: self.palette.text2)
                                Text(segment.timestampText)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(self.palette.text2)
                            }
                            Text(segment.text)
                                .font(.system(size: 14))
                                .foregroundStyle(self.palette.text)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            } else {
                Text(result.text)
                    .font(.system(size: 15))
                    .foregroundStyle(self.palette.text)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    private func resultFact(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(self.palette.text)
            DatasheetMonoLabel(text: label, role: DatasheetTheme.Typography.tableLabel, color: self.palette.text2)
        }
    }

    // MARK: - Recent file transcriptions

    private var recentTranscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.sectionHeading("RECENT TRANSCRIPTIONS", trailing: "\(self.fileHistoryStore.entries.count) ENTRIES") {
                Button("Clear all") {
                    self.fileHistoryStore.clearAll()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.palette.text)
                .buttonStyle(.plain)
                .datasheetHoverBracket()
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    self.tableHeader("FILE", alignment: .leading)
                    self.tableHeader("WHEN", width: 92, alignment: .leading)
                    self.tableHeader("LENGTH", width: 70, alignment: .trailing)
                    self.tableHeader("CONF", width: 62, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .frame(height: 30)
                .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

                ForEach(self.fileHistoryStore.entries) { entry in
                    FileTranscriptionIndexRow(
                        entry: entry,
                        isSelected: self.fileHistoryStore.selectedEntryID == entry.id,
                        length: self.durationText(entry.duration),
                        confidence: String(format: "%.0f%%", entry.confidence * 100)
                    ) {
                        self.fileHistoryStore.selectedEntryID = entry.id
                    }
                }
            }
            .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }

            if let entry = self.fileHistoryStore.selectedEntry {
                self.historyDetailCard(entry: entry)
            }
        }
    }

    private func historyDetailCard(entry: FileTranscriptionEntry) -> some View {
        let result = entry.toTranscriptionResult()

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    DatasheetMonoLabel(text: "FROM HISTORY", color: self.palette.text2)
                    Text(entry.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(self.palette.text)
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        self.resultFact("\(String(format: "%.1f", entry.duration))s", label: "LENGTH")
                        self.resultFact("\(String(format: "%.0f%%", entry.confidence * 100))", label: "CONFIDENCE")
                        self.resultFact(entry.fullDateString.uppercased(), label: "WHEN")
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    self.iconActionButton("Copy", systemImage: "doc.on.doc") {
                        self.copyToClipboard(entry.text)
                    }
                    self.iconActionButton("Export", systemImage: "square.and.arrow.up") {
                        self.exportResult = result
                        self.showingExportDialog = true
                    }
                    DatasheetBracketed(rest: false) {
                        Button(role: .destructive) {
                            self.fileHistoryStore.deleteEntry(id: entry.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(self.palette.text)
                                .frame(width: 30, height: 28)
                                .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .help("Remove from history")
                        .accessibilityLabel("Delete recent transcription")
                    }
                }
            }
            .padding(12)
            .overlay(alignment: .bottom) { Rectangle().fill(self.palette.rule).frame(height: 1) }

            ScrollView {
                Text(entry.text)
                    .font(.system(size: 14))
                    .foregroundStyle(self.palette.text)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 260)
        }
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    // MARK: - Error and file helpers

    private func errorCard(error: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(self.palette.accent).frame(width: 2)
            DatasheetMonoLabel(text: "TRANSCRIPTION ERROR", color: self.palette.accent)
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(self.palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            self.textActionButton("Dismiss") {
                self.transcriptionService.reset()
            }
        }
        .padding(12)
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    private func dropErrorCard(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle().fill(self.palette.accent).frame(width: 2)
            DatasheetMonoLabel(text: "FILE NOT SUPPORTED", color: self.palette.accent)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(self.palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            self.textActionButton("Dismiss") {
                self.dropErrorMessage = nil
            }
        }
        .padding(12)
        .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
    }

    private static let supportedFileExtensions = MeetingTranscriptionService.supportedFileExtensions
    private static let dropErrorCopy = MeetingTranscriptionService.dropErrorCopy

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL? = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            guard let url = url else { return }
            let ext = url.pathExtension.lowercased()
            guard Self.supportedFileExtensions.contains(ext) else {
                DispatchQueue.main.async {
                    self.dropErrorMessage = Self.dropErrorCopy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.dropErrorMessage = nil
                    }
                }
                return
            }
            DispatchQueue.main.async {
                self.selectedFileURL = url
                self.transcriptionService.reset()
                self.dropErrorMessage = nil
            }
        }
        return true
    }

    private func transcribeFile() async {
        guard let fileURL = self.selectedFileURL else { return }

        do {
            _ = try await self.transcriptionService.transcribeFile(fileURL)
        } catch {
            DebugLogger.shared.error("Transcription error: \(error)", source: "MeetingTranscriptionView")
        }
    }

    private func formatFileSize(fileURL: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int64
        else {
            return "Unknown size"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        withAnimation {
            self.showingCopyConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.showingCopyConfirmation = false
            }
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    private func sectionHeading<Actions: View>(
        _ title: String,
        trailing: String? = nil,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) -> some View {
        HStack(spacing: 10) {
            DatasheetMonoLabel(text: title, role: DatasheetTheme.Typography.tableLabel, color: self.palette.text)
            if let trailing {
                DatasheetMonoLabel(text: trailing, role: DatasheetTheme.Typography.tableLabel, color: self.palette.text2)
            }
            Rectangle().fill(self.palette.rule).frame(height: 1)
            actions()
        }
        .frame(height: 20)
    }

    private func tableHeader(_ title: String, width: CGFloat? = nil, alignment: Alignment = .leading) -> some View {
        DatasheetMonoLabel(text: title, role: DatasheetTheme.Typography.tableLabel, color: self.palette.text2)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private func iconActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        DatasheetBracketed(rest: false) {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(self.palette.text)
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .overlay { Rectangle().strokeBorder(self.palette.rule, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private func textActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        DatasheetBracketed(rest: false) {
            Button(title, action: action)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(self.palette.text)
                .buttonStyle(DatasheetTextButtonStyle())
        }
    }
}

private struct FileTranscriptionIndexRow: View {
    let entry: FileTranscriptionEntry
    let isSelected: Bool
    let length: String
    let confidence: String
    let action: () -> Void

    @Environment(\.datasheetPalette) private var palette
    @State private var isHovered = false

    private var isInverted: Bool { self.isSelected || self.isHovered }

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: 10) {
                Text(self.entry.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(self.entry.relativeTimeString.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.3)
                    .lineLimit(1)
                    .frame(width: 92, alignment: .leading)

                Text(self.length)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 70, alignment: .trailing)

                Text(self.confidence)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .frame(width: 62, alignment: .trailing)
            }
            .foregroundStyle(self.isInverted ? self.palette.invForeground : self.palette.text)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(self.isInverted ? self.palette.invBackground : self.palette.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(self.palette.ruleSoft).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { self.isHovered = $0 }
        .accessibilityAddTraits(self.isSelected ? .isSelected : [])
    }
}

// MARK: - Document for Export

struct TranscriptionDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText, .json]
    }

    let result: TranscriptionResult
    let format: MeetingTranscriptionView.ExportFormat
    let service: MeetingTranscriptionService

    init(
        result: TranscriptionResult,
        format: MeetingTranscriptionView.ExportFormat,
        service: MeetingTranscriptionService
    ) {
        self.result = result
        self.format = format
        self.service = service
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnknown)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp.\(self.format.fileExtension)")

        switch self.format {
        case .text:
            try self.service.exportToText(self.result, to: tempURL)
        case .json:
            try self.service.exportToJSON(self.result, to: tempURL)
        }

        let data = try Data(contentsOf: tempURL)
        try? FileManager.default.removeItem(at: tempURL)

        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    MeetingTranscriptionView(asrService: ASRService())
        .frame(width: 700, height: 800)
        .datasheetPalette()
}
