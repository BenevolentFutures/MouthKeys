//
//  TranscriptionHistoryStore.swift
//  Fluid
//
//  Persistence manager for Transcription Mode history
//

import Combine
import Foundation

// MARK: - Transcription History Entry Model

nonisolated struct TranscriptionHistoryEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let rawText: String
    let processedText: String
    let appName: String
    let windowTitle: String
    let characterCount: Int
    /// Words in `processedText`, counted once when the entry is made (or decoded from history
    /// written before it was stored), so stats never re-tokenize the transcripts.
    let wordCount: Int
    let wasAIProcessed: Bool
    let processingModel: String?
    /// Non-nil when AI post-processing was configured but failed and we fell
    /// back to typing the raw transcription. The string carries the error
    /// message for display / debugging.
    let aiProcessingError: String?
    let audio: DictationAudioMetadata?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawText: String,
        processedText: String,
        appName: String,
        windowTitle: String,
        wasAIProcessed: Bool,
        processingModel: String? = nil,
        aiProcessingError: String? = nil,
        audio: DictationAudioMetadata? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.processedText = processedText
        self.appName = appName
        self.windowTitle = windowTitle
        self.characterCount = processedText.count
        self.wordCount = TranscriptionHistoryStore.countWords(in: processedText)
        self.wasAIProcessed = wasAIProcessed
        self.processingModel = processingModel
        self.aiProcessingError = aiProcessingError
        self.audio = audio
    }

    private init(
        id: UUID,
        timestamp: Date,
        rawText: String,
        processedText: String,
        appName: String,
        windowTitle: String,
        characterCount: Int,
        wordCount: Int,
        wasAIProcessed: Bool,
        processingModel: String?,
        aiProcessingError: String?,
        audio: DictationAudioMetadata?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawText = rawText
        self.processedText = processedText
        self.appName = appName
        self.windowTitle = windowTitle
        self.characterCount = characterCount
        self.wordCount = wordCount
        self.wasAIProcessed = wasAIProcessed
        self.processingModel = processingModel
        self.aiProcessingError = aiProcessingError
        self.audio = audio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.rawText = try container.decode(String.self, forKey: .rawText)
        self.processedText = try container.decode(String.self, forKey: .processedText)
        self.appName = try container.decode(String.self, forKey: .appName)
        self.windowTitle = try container.decode(String.self, forKey: .windowTitle)
        self.characterCount = try container.decode(Int.self, forKey: .characterCount)
        self.wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount)
            ?? TranscriptionHistoryStore.countWords(in: self.processedText)
        self.wasAIProcessed = try container.decode(Bool.self, forKey: .wasAIProcessed)
        self.processingModel = try container.decodeIfPresent(String.self, forKey: .processingModel)
        self.aiProcessingError = try container.decodeIfPresent(String.self, forKey: .aiProcessingError)
        self.audio = try container.decodeIfPresent(DictationAudioMetadata.self, forKey: .audio)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, rawText, processedText, appName, windowTitle
        case characterCount, wordCount, wasAIProcessed, processingModel, aiProcessingError, audio
    }

    /// Preview text for list display (first 80 chars)
    var previewText: String {
        let text = self.processedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 80 {
            return String(text.prefix(77)) + "..."
        }
        return text
    }

    var clipboardText: String? {
        let processed = self.processedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = self.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = processed.isEmpty ? raw : processed
        return text.isEmpty ? nil : text
    }

    /// Relative time string for display
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self.timestamp, relativeTo: Date())
    }

    /// Full formatted date string
    var fullDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self.timestamp)
    }

    var hasAudioMetadata: Bool {
        self.audio != nil
    }

    func replacingAudio(_ audio: DictationAudioMetadata?) -> TranscriptionHistoryEntry {
        TranscriptionHistoryEntry(
            id: self.id,
            timestamp: self.timestamp,
            rawText: self.rawText,
            processedText: self.processedText,
            appName: self.appName,
            windowTitle: self.windowTitle,
            characterCount: self.characterCount,
            wordCount: self.wordCount,
            wasAIProcessed: self.wasAIProcessed,
            processingModel: self.processingModel,
            aiProcessingError: self.aiProcessingError,
            audio: audio
        )
    }
}

// MARK: - Transcription History Store

/// Writes the history to UserDefaults off the main thread. The store hands over immutable
/// snapshots; only the newest pending one is encoded, so a burst of changes costs one write.
///
/// Durability: a write starts at once, but encoding a large history takes ~60-100 ms, so a crash
/// in that window loses the newest entry (the text was already typed; the previous history is
/// intact on disk). Quitting flushes (`flush()` from applicationWillTerminate). A crash handler
/// cannot flush: encoding and UserDefaults are not async-signal-safe, and an uncaught exception
/// may be raised on this very queue.
nonisolated final class TranscriptionHistoryWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TranscriptionHistory.writer", qos: .utility)
    private let lock = NSLock()
    private var pending: [TranscriptionHistoryEntry]?
    private var isDraining = false
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults, key: String) {
        self.defaults = defaults
        self.key = key
    }

    func write(_ snapshot: [TranscriptionHistoryEntry]) {
        let shouldSchedule: Bool = self.lock.withLock {
            self.pending = snapshot
            guard !self.isDraining else { return false }
            self.isDraining = true
            return true
        }
        guard shouldSchedule else { return }
        self.queue.async { self.drain() }
    }

    /// Blocks until every snapshot handed over so far is on disk. For termination and tests.
    func flush() {
        self.queue.sync {}
    }

    private func drain() {
        while let snapshot = self.takePending() {
            let startedAt = ProcessInfo.processInfo.systemUptime
            guard let encoded = try? JSONEncoder().encode(snapshot) else {
                DebugLogger.shared.error("Could not encode transcription history (\(snapshot.count) entries)", source: "TranscriptionHistoryStore")
                continue
            }
            self.defaults.set(encoded, forKey: self.key)
            DebugLogger.shared.debug(
                "History saved off main entries=\(snapshot.count) bytes=\(encoded.count) " +
                    "elapsedMs=\(Int(((ProcessInfo.processInfo.systemUptime - startedAt) * 1000).rounded()))",
                source: "TranscriptionHistoryStore"
            )
        }
    }

    private func takePending() -> [TranscriptionHistoryEntry]? {
        self.lock.withLock {
            guard let snapshot = self.pending else {
                self.isDraining = false
                return nil
            }
            self.pending = nil
            return snapshot
        }
    }
}

@MainActor
final class TranscriptionHistoryStore: ObservableObject {
    static let shared = TranscriptionHistoryStore()

    private let defaults: UserDefaults
    private let writer: TranscriptionHistoryWriter

    private enum Keys {
        static let transcriptionHistory = "TranscriptionHistoryEntries"
    }

    @Published private(set) var entries: [TranscriptionHistoryEntry] = [] {
        didSet {
            self.revision &+= 1
            self.presence.update(hasEntries: !self.entries.isEmpty)
            self.stats.historyDidChange()
        }
    }

    /// Changes whenever `entries` does, so views can cache what they derive from the history.
    private(set) var revision: UInt64 = 0

    @Published var selectedEntryID: UUID?

    /// The Stats page's numbers, computed off the main thread whenever the history changes. A
    /// separate object, so a history change never re-renders the views that only show stats.
    let stats: TranscriptionStatsModel

    /// Whether there is any history, for views that need nothing else (the overlay's History
    /// chip). Observing the store itself re-rendered the overlay on every dictation, mid-stop.
    let presence = TranscriptionHistoryPresence()

    /// `defaults` is injectable so tests and benchmarks never touch the app's own history.
    init(defaults: UserDefaults = .standard, statsSettleDelay: TimeInterval = 1) {
        self.defaults = defaults
        self.writer = TranscriptionHistoryWriter(defaults: defaults, key: Keys.transcriptionHistory)
        self.stats = TranscriptionStatsModel(settleDelay: statsSettleDelay)
        self.stats.historySource = { [weak self] in self?.entries ?? [] }
        self.loadEntries()
    }

    /// Blocks until every change so far is written. Called at termination.
    func flushPendingWrites() {
        self.writer.flush()
    }

    // MARK: - Public Methods

    /// Get selected entry
    var selectedEntry: TranscriptionHistoryEntry? {
        guard let id = selectedEntryID else { return nil }
        return self.entries.first(where: { $0.id == id })
    }

    var latestClipboardText: String? {
        self.entries.first?.clipboardText
    }

    /// Add a new transcription entry
    func addEntry(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawText: String,
        processedText: String,
        appName: String,
        windowTitle: String,
        wasAIProcessed: Bool? = nil,
        processingModel: String? = nil,
        aiProcessingError: String? = nil,
        audio: DictationAudioMetadata? = nil
    ) {
        // Skip empty transcriptions
        guard !processedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let entry = TranscriptionHistoryEntry(
            id: id,
            timestamp: timestamp,
            rawText: rawText,
            processedText: processedText,
            appName: appName,
            windowTitle: windowTitle,
            wasAIProcessed: wasAIProcessed ?? (processingModel != nil && aiProcessingError == nil),
            processingModel: processingModel,
            aiProcessingError: aiProcessingError,
            audio: audio
        )

        // Insert at beginning (newest first)
        self.entries.insert(entry, at: 0)

        self.saveEntries()
        if audio != nil {
            self.pruneAudioToBudget()
        }

        DebugLogger.shared.debug("Added transcription to history (total: \(self.entries.count))", source: "TranscriptionHistoryStore")
    }

    /// Delete a specific entry
    func deleteEntry(id: UUID) {
        if let audio = self.entries.first(where: { $0.id == id })?.audio {
            DictationAudioHistoryStore.shared.deleteAudio(fileName: audio.fileName)
        }
        self.entries.removeAll { $0.id == id }

        // Clear selection if deleted
        if self.selectedEntryID == id {
            self.selectedEntryID = self.entries.first?.id
        }

        self.saveEntries()
    }

    /// Delete multiple entries
    func deleteEntries(ids: Set<UUID>) {
        for entry in self.entries where ids.contains(entry.id) {
            if let audio = entry.audio {
                DictationAudioHistoryStore.shared.deleteAudio(fileName: audio.fileName)
            }
        }
        self.entries.removeAll { ids.contains($0.id) }

        if let selected = selectedEntryID, ids.contains(selected) {
            self.selectedEntryID = self.entries.first?.id
        }

        self.saveEntries()
    }

    /// Clear all history
    func clearAllHistory() {
        DictationAudioHistoryStore.shared.deleteAllAudioFiles()
        // Clearing history means no dictation audio is left, a timed-out recording included.
        DictationAudioHistoryStore.shared.discardKeptDictation()
        self.entries.removeAll()
        self.selectedEntryID = nil
        self.saveEntries()

        DebugLogger.shared.info("Cleared all transcription history", source: "TranscriptionHistoryStore")
    }

    /// Search entries by text content
    func search(query: String) -> [TranscriptionHistoryEntry] {
        Self.search(query: query, in: self.entries)
    }

    /// Entries whose text, app or window title contains `query`, ignoring case. Safe off the main
    /// thread. Bridged to NSString: Swift's `range(of:options:)` was 20 times slower, and
    /// lowercasing four copies of every entry allocated tens of megabytes on a long history.
    nonisolated static func search(query: String, in entries: [TranscriptionHistoryEntry]) -> [TranscriptionHistoryEntry] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return entries
        }

        func matches(_ text: String) -> Bool {
            (text as NSString).range(of: query, options: .caseInsensitive).location != NSNotFound
        }
        return entries.filter { entry in
            matches(entry.processedText) || matches(entry.rawText) || matches(entry.appName) || matches(entry.windowTitle)
        }
    }

    /// Get entries filtered by date range
    func entriesInRange(from startDate: Date, to endDate: Date) -> [TranscriptionHistoryEntry] {
        self.entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get total character count across all entries
    var totalCharacterCount: Int {
        self.entries.reduce(0) { $0 + $1.characterCount }
    }

    /// Get count of AI-processed entries
    var aiProcessedCount: Int {
        self.entries.filter { $0.wasAIProcessed }.count
    }

    func makeBackupPayload() -> [TranscriptionHistoryEntry] {
        self.entries
    }

    func restore(from payload: [TranscriptionHistoryEntry]) {
        self.entries = payload.sorted { $0.timestamp > $1.timestamp }
        self.selectedEntryID = self.entries.first?.id
        self.saveEntries()
    }

    func attachAudio(_ audio: DictationAudioMetadata, to entryID: UUID) {
        guard let index = self.entries.firstIndex(where: { $0.id == entryID }) else {
            DictationAudioHistoryStore.shared.deleteAudio(fileName: audio.fileName)
            return
        }
        self.entries[index] = self.entries[index].replacingAudio(audio)
        self.saveEntries()
        self.pruneAudioToBudget()
    }

    /// - Parameter includingKeptRecording: the user's "Delete all saved audio" also discards a kept
    ///   timed-out recording; an automatic prune to a zero budget does not.
    @discardableResult
    func deleteAllSavedAudio(includingKeptRecording: Bool = true) -> Int {
        let removedCount = self.entries.filter { $0.audio != nil }.count
        DictationAudioHistoryStore.shared.deleteAllAudioFiles()
        if includingKeptRecording {
            DictationAudioHistoryStore.shared.discardKeptDictation()
        }
        self.entries = self.entries.map { $0.replacingAudio(nil) }
        self.saveEntries()
        DebugLogger.shared.info("Deleted saved dictation audio (\(removedCount) entries)", source: "TranscriptionHistoryStore")
        return removedCount
    }

    @discardableResult
    func pruneAudioToBudget() -> Int {
        let budgetBytes = SettingsStore.shared.audioHistoryBudgetBytes
        guard budgetBytes > 0 else {
            return self.deleteAllSavedAudio(includingKeptRecording: false)
        }

        var currentBytes = DictationAudioHistoryStore.shared.audioUsageBytes()
        guard currentBytes > budgetBytes else { return 0 }

        var updatedEntries = self.entries
        let referencedFileNames = Set(updatedEntries.compactMap { $0.audio?.fileName })
        let orphanedAudio = DictationAudioHistoryStore.shared.deleteUnreferencedAudioFiles(referencedFileNames: referencedFileNames)
        if orphanedAudio.fileCount > 0 {
            currentBytes = max(0, currentBytes - orphanedAudio.byteCount)
            DebugLogger.shared.info("Pruned orphaned dictation audio (\(orphanedAudio.fileCount) files)", source: "TranscriptionHistoryStore")
        }
        guard currentBytes > budgetBytes else { return 0 }

        var prunedCount = 0
        for index in updatedEntries.indices.reversed() {
            guard let audio = updatedEntries[index].audio else { continue }
            let removedBytes = DictationAudioHistoryStore.shared.deleteAudio(fileName: audio.fileName)
            currentBytes = max(0, currentBytes - removedBytes)
            updatedEntries[index] = updatedEntries[index].replacingAudio(nil)
            prunedCount += 1
            if currentBytes <= budgetBytes {
                break
            }
        }

        if prunedCount > 0 {
            self.entries = updatedEntries
            self.saveEntries()
            DebugLogger.shared.info("Pruned saved dictation audio (\(prunedCount) entries)", source: "TranscriptionHistoryStore")
        }
        return prunedCount
    }

    // MARK: - Private Methods

    private func loadEntries() {
        guard let data = defaults.data(forKey: Keys.transcriptionHistory),
              let decoded = try? JSONDecoder().decode([TranscriptionHistoryEntry].self, from: data)
        else {
            self.entries = []
            return
        }
        self.entries = decoded
    }

    /// Hands the current history to the background writer. Encoding thousands of entries on
    /// the main thread cost ~60 ms of every dictation's stop path; `entries` being @Published
    /// already tells observers about the change.
    private func saveEntries() {
        self.writer.write(self.entries)
    }
}

// MARK: - Presence

@MainActor
final class TranscriptionHistoryPresence: ObservableObject {
    @Published private(set) var hasEntries = false

    func update(hasEntries: Bool) {
        if self.hasEntries != hasEntries {
            self.hasEntries = hasEntries
        }
    }
}

// MARK: - Word Counting

extension TranscriptionHistoryStore {
    private nonisolated static let wordSeparators = CharacterSet.whitespacesAndNewlines

    /// Words in `text`: runs of characters between whitespace and newlines. One walk over the
    /// Unicode scalars with no allocation; splitting into substrings made a pass over a 17k-entry
    /// history cost about a second on the main thread.
    nonisolated static func countWords(in text: String) -> Int {
        var count = 0
        var isInWord = false
        for scalar in text.unicodeScalars {
            let isSeparator: Bool
            switch scalar.value {
            case 0x09...0x0D, 0x20: isSeparator = true
            case 0..<0x80: isSeparator = false
            default: isSeparator = Self.wordSeparators.contains(scalar)
            }
            if isSeparator {
                isInWord = false
            } else if !isInWord {
                isInWord = true
                count += 1
            }
        }
        return count
    }
}
