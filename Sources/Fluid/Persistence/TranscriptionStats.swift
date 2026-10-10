//
//  TranscriptionStats.swift
//  Fluid
//
//  Every number the Stats page and the title strip show, computed off the main thread.
//

import Combine
import Foundation

// MARK: - Tally

/// Words and dictations over some span of the history.
nonisolated struct TranscriptionTally: Equatable, Sendable {
    var words = 0
    var transcriptions = 0

    init(words: Int = 0, transcriptions: Int = 0) {
        self.words = words
        self.transcriptions = transcriptions
    }

    mutating func add(words: Int) {
        self.words += words
        self.transcriptions += 1
    }

    var averageWords: Int {
        self.transcriptions > 0 ? self.words / self.transcriptions : 0
    }

    func timeSavedMinutes(typingWPM: Int = 40, speakingWPM: Int = 150) -> Double {
        guard typingWPM > 0 && speakingWPM > 0 else { return 0 }

        let words = Double(self.words)
        let typingTime = words / Double(typingWPM)
        let speakingTime = words / Double(speakingWPM)

        return max(0, typingTime - speakingTime)
    }

    /// "< 1m", "45m", "2h", "2h 45m".
    func formattedTimeSaved(typingWPM: Int = 40) -> String {
        let minutes = self.timeSavedMinutes(typingWPM: typingWPM)

        if minutes < 1 {
            return "< 1m"
        } else if minutes < 60 {
            return "\(Int(minutes))m"
        } else {
            let hours = Int(minutes) / 60
            let mins = Int(minutes) % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Snapshot

/// The Stats page's numbers at one moment. Built in one pass over the history from each entry's
/// stored word count, so nothing re-tokenizes the transcripts; views only read it.
nonisolated struct TranscriptionStatsSnapshot: Equatable, Sendable {
    struct DayWords: Equatable, Sendable {
        let date: Date
        let words: Int
    }

    struct Milestone: Equatable, Sendable {
        let target: Int
        let achieved: Bool
        let label: String
    }

    /// Rolling windows ending now, not calendar days.
    enum Window: CaseIterable, Sendable {
        case sixHours, twentyFourHours, sevenDays, thirtyDays

        var seconds: TimeInterval {
            switch self {
            case .sixHours: 6 * 3600
            case .twentyFourHours: 24 * 3600
            case .sevenDays: 7 * 86_400
            case .thirtyDays: 30 * 86_400
            }
        }
    }

    /// Days of daily words kept for the activity chart (its widest choice).
    static let chartDays = 30

    var total = TranscriptionTally()
    var today = TranscriptionTally()
    var lastSixHours = TranscriptionTally()
    var lastTwentyFourHours = TranscriptionTally()
    var lastSevenDays = TranscriptionTally()
    var lastThirtyDays = TranscriptionTally()
    var currentStreak = 0
    var bestStreak = 0
    /// Words per calendar day for the last `chartDays` days, oldest first; today is last.
    var dailyWords: [DayWords] = []
    /// The three apps dictated into most, most first.
    var topApps: [String] = []
    var aiProcessedCount = 0
    /// The hour of day (0-23) with the most dictations.
    var peakHour: Int?
    var longestTranscriptionWords = 0
    var mostWordsInDay = 0
    var mostTranscriptionsInDay = 0

    func tally(for window: Window) -> TranscriptionTally {
        switch window {
        case .sixHours: self.lastSixHours
        case .twentyFourHours: self.lastTwentyFourHours
        case .sevenDays: self.lastSevenDays
        case .thirtyDays: self.lastThirtyDays
        }
    }

    /// Daily words for the last `days` days, oldest first.
    func dailyWords(days: Int) -> [DayWords] {
        Array(self.dailyWords.suffix(days))
    }

    /// Percentage of transcriptions that were AI-enhanced (0-100).
    var aiEnhancementRate: Int {
        self.total.transcriptions > 0 ? self.aiProcessedCount * 100 / self.total.transcriptions : 0
    }

    // MARK: Milestones

    var wordMilestones: [Milestone] {
        Self.milestones([(1000, "1K"), (10_000, "10K"), (50_000, "50K"), (100_000, "100K"), (500_000, "500K"), (1_000_000, "1M")], reached: self.total.words)
    }

    var transcriptionMilestones: [Milestone] {
        Self.milestones([(50, "50"), (100, "100"), (500, "500"), (1000, "1K"), (5000, "5K"), (10_000, "10K")], reached: self.total.transcriptions)
    }

    var streakMilestones: [Milestone] {
        Self.milestones([(7, "7 days"), (14, "14 days"), (30, "30 days"), (60, "60 days"), (100, "100 days"), (365, "1 year")], reached: self.bestStreak)
    }

    var milestonesAchieved: Int {
        (self.wordMilestones + self.transcriptionMilestones + self.streakMilestones).filter(\.achieved).count
    }

    var milestonesPossible: Int {
        self.wordMilestones.count + self.transcriptionMilestones.count + self.streakMilestones.count
    }

    private static func milestones(_ targets: [(Int, String)], reached: Int) -> [Milestone] {
        targets.map { Milestone(target: $0.0, achieved: reached >= $0.0, label: $0.1) }
    }

    // MARK: Building

    /// One pass over `entries` (any order). Calendar lookups are cached per day and per hour, so
    /// a history of 17k entries costs a few milliseconds.
    static func make(
        entries: [TranscriptionHistoryEntry],
        now: Date,
        calendar: Calendar = .current,
        weekendsDontBreakStreak: Bool
    ) -> TranscriptionStatsSnapshot {
        var snapshot = TranscriptionStatsSnapshot()
        let today = calendar.dateInterval(of: .day, for: now)
        let windowStarts = Window.allCases.map { now.addingTimeInterval(-$0.seconds) }

        var dayTotals: [Date: TranscriptionTally] = [:]
        var hourCounts = [Int](repeating: 0, count: 24)
        var appCounts: [String: Int] = [:]
        var cachedDay: DateInterval?
        var cachedHour: (interval: DateInterval, hour: Int)?

        for entry in entries {
            let words = entry.wordCount
            let timestamp = entry.timestamp

            snapshot.total.add(words: words)
            if let today, timestamp >= today.start, timestamp < today.end {
                snapshot.today.add(words: words)
            }
            if timestamp > windowStarts[0] { snapshot.lastSixHours.add(words: words) }
            if timestamp > windowStarts[1] { snapshot.lastTwentyFourHours.add(words: words) }
            if timestamp > windowStarts[2] { snapshot.lastSevenDays.add(words: words) }
            if timestamp > windowStarts[3] { snapshot.lastThirtyDays.add(words: words) }

            if cachedDay.map({ timestamp < $0.start || timestamp >= $0.end }) ?? true {
                cachedDay = calendar.dateInterval(of: .day, for: timestamp)
            }
            if let day = cachedDay {
                dayTotals[day.start, default: TranscriptionTally()].add(words: words)
            }

            if cachedHour.map({ timestamp < $0.interval.start || timestamp >= $0.interval.end }) ?? true {
                cachedHour = calendar.dateInterval(of: .hour, for: timestamp).map {
                    (interval: $0, hour: calendar.component(.hour, from: timestamp))
                }
            }
            if let hour = cachedHour?.hour, hourCounts.indices.contains(hour) {
                hourCounts[hour] += 1
            }

            appCounts[entry.appName.isEmpty ? "Unknown" : entry.appName, default: 0] += 1
            if entry.wasAIProcessed {
                snapshot.aiProcessedCount += 1
            }
            snapshot.longestTranscriptionWords = max(snapshot.longestTranscriptionWords, words)
        }

        snapshot.mostWordsInDay = dayTotals.values.map(\.words).max() ?? 0
        snapshot.mostTranscriptionsInDay = dayTotals.values.map(\.transcriptions).max() ?? 0
        snapshot.topApps = appCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(3)
            .map(\.key)
        if !entries.isEmpty, let peak = hourCounts.indices.max(by: { hourCounts[$0] < hourCounts[$1] }) {
            snapshot.peakHour = peak
        }

        let startOfToday = today?.start ?? calendar.startOfDay(for: now)
        snapshot.dailyWords = (0..<Self.chartDays).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { return nil }
            let day = calendar.startOfDay(for: date)
            return DayWords(date: day, words: dayTotals[day]?.words ?? 0)
        }

        let activeDays = dayTotals.keys.sorted(by: >)
        snapshot.currentStreak = Self.currentStreak(
            activeDays: activeDays, today: startOfToday, calendar: calendar, skipWeekends: weekendsDontBreakStreak
        )
        snapshot.bestStreak = Self.bestStreak(
            activeDays: activeDays, calendar: calendar, skipWeekends: weekendsDontBreakStreak
        )
        return snapshot
    }

    // MARK: Streaks

    /// Consecutive active days ending today or yesterday (the last weekday or the one before it
    /// when weekends don't count). `activeDays` are day starts, newest first.
    static func currentStreak(activeDays: [Date], today: Date, calendar: Calendar, skipWeekends: Bool) -> Int {
        // Weekend usage neither extends nor breaks a streak when weekends don't count.
        let days = skipWeekends ? activeDays.filter { !calendar.isDateInWeekend($0) } : activeDays
        guard let firstActiveDay = days.first else { return 0 }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Must have activity on a recent valid day to have an active streak.
        let isRecent: Bool
        if skipWeekends {
            var lastValidDay = today
            while calendar.isDateInWeekend(lastValidDay) {
                guard let previous = calendar.date(byAdding: .day, value: -1, to: lastValidDay) else { break }
                lastValidDay = previous
            }
            // Allow one weekday gap (the weekday before lastValidDay).
            guard let previousWeekday = self.previousWeekday(before: lastValidDay, calendar: calendar) else {
                return firstActiveDay == lastValidDay ? 1 : 0
            }
            isRecent = firstActiveDay == lastValidDay || firstActiveDay == previousWeekday
        } else {
            isRecent = firstActiveDay == today || firstActiveDay == yesterday
        }
        guard isRecent else { return 0 }

        var streak = 1
        var previousDay = firstActiveDay
        for day in days.dropFirst() {
            let expectedPrevious = skipWeekends
                ? self.previousWeekday(before: previousDay, calendar: calendar)
                : calendar.date(byAdding: .day, value: -1, to: previousDay)
            guard let expected = expectedPrevious, day == expected else { break }
            streak += 1
            previousDay = day
        }
        return streak
    }

    /// The longest run of consecutive active days ever. `activeDays` are day starts, newest first.
    static func bestStreak(activeDays: [Date], calendar: Calendar, skipWeekends: Bool) -> Int {
        let days = (skipWeekends ? activeDays.filter { !calendar.isDateInWeekend($0) } : activeDays).reversed()
        guard var previousDay = days.first else { return 0 }

        var maxStreak = 1
        var currentStreak = 1
        for day in days.dropFirst() {
            let expectedNext = skipWeekends
                ? self.nextWeekday(after: previousDay, calendar: calendar)
                : calendar.date(byAdding: .day, value: 1, to: previousDay)
            if let expected = expectedNext, day == expected {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 1
            }
            previousDay = day
        }
        return maxStreak
    }

    private static func previousWeekday(before date: Date, calendar: Calendar) -> Date? {
        var candidate = calendar.date(byAdding: .day, value: -1, to: date)
        while let day = candidate, calendar.isDateInWeekend(day) {
            candidate = calendar.date(byAdding: .day, value: -1, to: day)
        }
        return candidate
    }

    private static func nextWeekday(after date: Date, calendar: Calendar) -> Date? {
        var candidate = calendar.date(byAdding: .day, value: 1, to: date)
        while let day = candidate, calendar.isDateInWeekend(day) {
            candidate = calendar.date(byAdding: .day, value: 1, to: day)
        }
        return candidate
    }
}

// MARK: - Model

/// Publishes the stats snapshot, kept apart from the history store so a history change never
/// re-renders the Stats page by itself: the page renders once, when the new snapshot lands.
///
/// A history change waits `settleDelay` (a dictation adds its entry just before it pastes, and
/// attaches its audio just after) and is then computed off the main thread. While a Stats page is
/// on screen a timer refreshes the snapshot every `liveRefreshInterval`, so the rolling windows
/// decay with no new dictation; a new day, a clock change or a time zone change refreshes it too.
@MainActor
final class TranscriptionStatsModel: ObservableObject {
    /// Nil until the first pass over the history lands; views show "—" until then.
    @Published private(set) var snapshot: TranscriptionStatsSnapshot?

    static let liveRefreshInterval: TimeInterval = 60

    /// Reads the history when a pass starts. Holding the array between passes would make every
    /// insert copy all of it (copy on write), on the dictation path.
    var historySource: () -> [TranscriptionHistoryEntry] = { [] }

    private let settleNanoseconds: UInt64
    private var refreshTask: Task<Void, Never>?
    private var refreshRevision: UInt64 = 0
    private var pendingSettle = false
    private var liveViewers = 0
    private var liveTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(settleDelay: TimeInterval = 1) {
        self.settleNanoseconds = UInt64(max(0, settleDelay) * 1_000_000_000)
        let names: [Notification.Name] = [.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange]
        self.observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    deinit {
        self.observers.forEach(NotificationCenter.default.removeObserver)
        self.liveTimer?.invalidate()
    }

    /// The store calls this on every history change. The first history is computed at once; later
    /// changes settle first.
    func historyDidChange() {
        self.scheduleRefresh(settle: self.snapshot != nil)
    }

    /// Recomputes from the current history now (for a clock tick, a setting, a new day).
    func refresh() {
        self.scheduleRefresh(settle: false)
    }

    /// A Stats page appeared: refresh now and every `liveRefreshInterval` until the last one goes.
    func beginLiveUpdates() {
        self.liveViewers += 1
        self.refresh()
        guard self.liveTimer == nil else { return }
        let timer = Timer(timeInterval: Self.liveRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.liveTimer = timer
    }

    func endLiveUpdates() {
        self.liveViewers = max(0, self.liveViewers - 1)
        guard self.liveViewers == 0 else { return }
        self.liveTimer?.invalidate()
        self.liveTimer = nil
    }

    var isRefreshingLive: Bool {
        self.liveTimer != nil
    }

    /// Waits until the snapshot has caught up with the history. For tests.
    func waitForSnapshot() async {
        while let task = self.refreshTask {
            await task.value
        }
    }

    /// Computes the snapshot on the calling thread at once. For renders and tests only.
    func computeNow(now: Date = Date()) {
        self.snapshot = TranscriptionStatsSnapshot.make(
            entries: self.historySource(),
            now: now,
            weekendsDontBreakStreak: SettingsStore.shared.weekendsDontBreakStreak
        )
    }

    private func scheduleRefresh(settle: Bool) {
        self.refreshRevision &+= 1
        self.pendingSettle = self.pendingSettle || settle
        guard self.refreshTask == nil else { return }
        self.refreshTask = Task { @MainActor [weak self] in
            // Coalesce a burst of changes (restore, delete-many, add then attach audio) into one pass.
            if let self, self.pendingSettle, self.settleNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: self.settleNanoseconds)
            } else {
                await Task.yield()
            }
            while let self {
                self.pendingSettle = false
                let revision = self.refreshRevision
                let entries = self.historySource()
                let now = Date()
                let calendar = Calendar.current
                let skipWeekends = SettingsStore.shared.weekendsDontBreakStreak
                let snapshot = await Task.detached(priority: .utility) {
                    TranscriptionStatsSnapshot.make(
                        entries: entries, now: now, calendar: calendar, weekendsDontBreakStreak: skipWeekends
                    )
                }.value
                guard revision == self.refreshRevision else {
                    if self.pendingSettle, self.settleNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: self.settleNanoseconds)
                    }
                    continue
                }
                if self.snapshot != snapshot {
                    self.snapshot = snapshot
                }
                self.refreshTask = nil
                return
            }
        }
    }
}
