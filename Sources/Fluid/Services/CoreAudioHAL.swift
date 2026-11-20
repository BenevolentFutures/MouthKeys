import Foundation

/// Where MouthKeys' Core Audio calls run, so the main thread never waits on the HAL.
///
/// The hotkey tap hops to main for every key (`DispatchQueue.main.sync`), and macOS disables a
/// tap that takes about a second, so a main thread waiting on Core Audio means dead hotkeys. On
/// 2026-11-19 at 17:58:20 it waited forever: after a `coreaudiod` restart the HAL's notification
/// thread, tearing a dead device down, was delivering that device's listener to the main queue
/// (`dispatch_sync`), while the main thread was removing the same listener, which waits for any
/// delivery in flight. Each waited for the other.
///
/// - Listener add and remove run on `listenerLane` (`CoreAudioPropertyListener`).
/// - A read made on the main thread runs on `readLane`, and main waits for it at most
///   `mainThreadDeadline`; past that, or while the lane is still busy with an earlier call, main
///   gets the caller's fallback (`read(_:fallback:_:)`).
/// - The watchdog logs `CORE_AUDIO_HAL state=stuck` for any call that has not returned after
///   `stuckAfter`, and `state=recovered` when it does.
nonisolated enum CoreAudioHAL {
    /// The longest the main thread waits on Core Audio. A healthy property read takes
    /// microseconds and a full device listing a few milliseconds.
    static let mainThreadDeadline: TimeInterval = 0.2

    static let watchdog = Watchdog(stuckAfter: 2.0)
    static let listenerLane = Lane(label: "com.stage11.mouthkeys.core-audio.listeners", watchdog: watchdog)
    static let readLane = Lane(label: "com.stage11.mouthkeys.core-audio.reads", watchdog: watchdog)

    /// A Core Audio call has not returned for `watchdog.stuckAfter` or longer.
    static var isStuck: Bool {
        self.watchdog.isStuck
    }

    /// A synchronous read from the HAL. Off the main thread it runs inline, so the caller waits
    /// as long as Core Audio takes, watched by the watchdog. On the main thread it runs on
    /// `readLane` and main waits at most `deadline`, then returns `fallback`; while the lane is
    /// still busy with an earlier call past that deadline, main returns `fallback` at once and
    /// nothing more is queued behind the stuck call.
    static func read<T: Sendable>(
        _ operation: String,
        deadline: TimeInterval = CoreAudioHAL.mainThreadDeadline,
        lane: Lane = CoreAudioHAL.readLane,
        fallback: @autoclosure () -> T,
        _ work: @escaping @Sendable () -> T
    ) -> T {
        if Thread.isMainThread {
            return lane.run(operation, waitingAtMost: deadline, queueWhenBusy: false, work) ?? fallback()
        }
        if Lane.isOnAnyLane {
            return work()
        }
        let token = lane.watchdog.begin(operation)
        defer { lane.watchdog.end(token) }
        return work()
    }

    /// Runs `work` on `readLane` and waits at most `deadline` without blocking a thread. Returns
    /// nil on timeout, or at once when the lane is still busy with an earlier call past
    /// `deadline` (Core Audio is stuck; another call would only queue behind it).
    static func readAsync<T: Sendable>(
        _ operation: String,
        deadline: TimeInterval,
        _ work: @escaping @Sendable () -> T
    ) async -> T? {
        await self.readLane.runAsync(operation, deadline: deadline, work)
    }

    // MARK: - Lane

    /// A serial queue for Core Audio calls. Every call is watched; a caller may wait for one with
    /// a deadline.
    final class Lane: @unchecked Sendable {
        private static let laneKey = DispatchSpecificKey<Bool>()

        /// True on any lane's queue, where a nested `read` runs inline without a second watch.
        static var isOnAnyLane: Bool {
            DispatchQueue.getSpecific(key: Self.laneKey) == true
        }

        let label: String
        let watchdog: Watchdog
        private let queue: DispatchQueue
        private let lock = NSLock()
        private var runningSince: TimeInterval?

        init(label: String, watchdog: Watchdog) {
            self.label = label
            self.watchdog = watchdog
            // Main waits on this queue (with a deadline), so it runs at main's QoS.
            self.queue = DispatchQueue(label: label, qos: .userInteractive)
            self.queue.setSpecific(key: Self.laneKey, value: true)
        }

        /// How long the call now running has run, or nil when the lane is idle.
        var currentCallAge: TimeInterval? {
            self.lock.withLock {
                self.runningSince.map { ProcessInfo.processInfo.systemUptime - $0 }
            }
        }

        func isBusy(longerThan interval: TimeInterval) -> Bool {
            (self.currentCallAge ?? 0) > interval
        }

        /// Queues `work`; never waits.
        func async(_ operation: String, _ work: @escaping @Sendable () -> Void) {
            self.queue.async { [self] in
                let token = self.watchdog.begin(operation)
                self.lock.withLock { self.runningSince = ProcessInfo.processInfo.systemUptime }
                work()
                self.lock.withLock { self.runningSince = nil }
                self.watchdog.end(token)
            }
        }

        /// Queues `work` and waits for its result at most `deadline`. Returns nil on timeout. While
        /// the lane is busy with an earlier call for longer than `deadline`, returns nil at once,
        /// and queues `work` (to run later) only when `queueWhenBusy`.
        func run<T: Sendable>(
            _ operation: String,
            waitingAtMost deadline: TimeInterval,
            queueWhenBusy: Bool,
            _ work: @escaping @Sendable () -> T
        ) -> T? {
            let busy = self.isBusy(longerThan: deadline)
            if busy, queueWhenBusy == false {
                return nil
            }
            let box = ResultBox<T>()
            let done = DispatchSemaphore(value: 0)
            self.async(operation) {
                box.set(work())
                done.signal()
            }
            if busy {
                return nil
            }
            guard done.wait(timeout: .now() + deadline) == .success else {
                DebugLogger.shared.warning(
                    "CORE_AUDIO_HAL wait=gave_up op=\(operation) lane=\(self.label) " +
                        "deadlineMs=\(Int((deadline * 1000).rounded())) thread=\(Thread.isMainThread ? "main" : "other")",
                    source: "CoreAudioHAL"
                )
                return nil
            }
            return box.value
        }

        func runAsync<T: Sendable>(
            _ operation: String,
            deadline: TimeInterval,
            _ work: @escaping @Sendable () -> T
        ) async -> T? {
            guard self.isBusy(longerThan: deadline) == false else {
                DebugLogger.shared.warning(
                    "CORE_AUDIO_HAL wait=skipped op=\(operation) lane=\(self.label) " +
                        "busyMs=\(Int(((self.currentCallAge ?? 0) * 1000).rounded()))",
                    source: "CoreAudioHAL"
                )
                return nil
            }
            return await withCheckedContinuation { continuation in
                let once = ResumeOnce(continuation)
                self.async(operation) {
                    once.resume(returning: work())
                }
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + deadline) { [self] in
                    guard once.resume(returning: nil) else { return }
                    DebugLogger.shared.warning(
                        "CORE_AUDIO_HAL wait=gave_up op=\(operation) lane=\(self.label) " +
                            "deadlineMs=\(Int((deadline * 1000).rounded())) thread=async",
                        source: "CoreAudioHAL"
                    )
                }
            }
        }

        /// Waits until every call queued so far has returned. Tests only.
        func drainForTesting() {
            self.queue.sync {}
        }
    }

    // MARK: - Watchdog

    /// Notices Core Audio calls that have not returned. One stuck call makes `isStuck` true until
    /// every stuck call has returned; both changes are logged and posted on main as
    /// `.coreAudioHALStuckStateDidChange`.
    final class Watchdog: @unchecked Sendable {
        struct Token: Sendable {
            fileprivate let id: UInt64
        }

        private struct Call {
            let operation: String
            let startedAt: TimeInterval
            var isFlagged = false
        }

        private let stuckAfterSeconds: TimeInterval
        private let queue = DispatchQueue(label: "com.stage11.mouthkeys.core-audio.watchdog", qos: .utility)
        private let lock = NSLock()
        private var nextID: UInt64 = 0
        private var calls: [UInt64: Call] = [:]
        private var stuck = false

        init(stuckAfter: TimeInterval) {
            self.stuckAfterSeconds = stuckAfter
        }

        var stuckAfter: TimeInterval {
            self.stuckAfterSeconds
        }

        var isStuck: Bool {
            self.lock.withLock { self.stuck }
        }

        func begin(_ operation: String) -> Token {
            let id: UInt64 = self.lock.withLock {
                self.nextID &+= 1
                self.calls[self.nextID] = Call(operation: operation, startedAt: ProcessInfo.processInfo.systemUptime)
                return self.nextID
            }
            self.queue.asyncAfter(deadline: .now() + self.stuckAfterSeconds) { [weak self] in
                self?.flagIfStillRunning(id)
            }
            return Token(id: id)
        }

        func end(_ token: Token) {
            let now = ProcessInfo.processInfo.systemUptime
            let (call, recovered, stillStuck): (Call?, Bool, Int) = self.lock.withLock {
                let call = self.calls.removeValue(forKey: token.id)
                let stillStuck = self.calls.values.filter(\.isFlagged).count
                let recovered = self.stuck && stillStuck == 0
                if recovered { self.stuck = false }
                return (call, recovered, stillStuck)
            }
            guard let call, call.isFlagged else { return }
            DebugLogger.shared.warning(
                "CORE_AUDIO_HAL state=\(recovered ? "recovered" : "call_returned") op=\(call.operation) " +
                    "waitedMs=\(Int(((now - call.startedAt) * 1000).rounded())) stillStuck=\(stillStuck)",
                source: "CoreAudioHAL"
            )
            if recovered { self.post(isStuck: false) }
        }

        private func flagIfStillRunning(_ id: UInt64) {
            let now = ProcessInfo.processInfo.systemUptime
            let (call, becameStuck): (Call?, Bool) = self.lock.withLock {
                guard var call = self.calls[id] else { return (nil, false) }
                call.isFlagged = true
                self.calls[id] = call
                let becameStuck = self.stuck == false
                self.stuck = true
                return (call, becameStuck)
            }
            guard let call else { return }
            DebugLogger.shared.error(
                "CORE_AUDIO_HAL state=stuck op=\(call.operation) " +
                    "waitedMs=\(Int(((now - call.startedAt) * 1000).rounded()))",
                source: "CoreAudioHAL"
            )
            if becameStuck { self.post(isStuck: true) }
        }

        private func post(isStuck: Bool) {
            DispatchQueue.main.async { [self] in
                NotificationCenter.default.post(
                    name: .coreAudioHALStuckStateDidChange,
                    object: self,
                    userInfo: ["isStuck": isStuck]
                )
            }
        }
    }

    // MARK: - Helpers

    private final class ResultBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: T?

        func set(_ value: T) {
            self.lock.withLock { self.stored = value }
        }

        var value: T? {
            self.lock.withLock { self.stored }
        }
    }

    private final class ResumeOnce<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Never>?

        init(_ continuation: CheckedContinuation<T, Never>) {
            self.continuation = continuation
        }

        /// Resumes the first time; returns true for the call that did.
        @discardableResult
        func resume(returning value: T) -> Bool {
            let continuation = self.lock.withLock {
                let continuation = self.continuation
                self.continuation = nil
                return continuation
            }
            continuation?.resume(returning: value)
            return continuation != nil
        }
    }
}

extension Notification.Name {
    /// A watchdog's `isStuck` changed (object: the `CoreAudioHAL.Watchdog`; userInfo
    /// `isStuck: Bool`). Posted on main.
    static let coreAudioHALStuckStateDidChange = Notification.Name("CoreAudioHALStuckStateDidChange")
    /// `coreaudiod` restarted: every device ID and listener from before is gone. Posted on main,
    /// once per restart, by `AudioHardwareObserver`.
    static let coreAudioServiceDidRestart = Notification.Name("CoreAudioServiceDidRestart")
}
