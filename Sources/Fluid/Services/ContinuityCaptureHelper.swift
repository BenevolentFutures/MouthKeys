import Darwin
import Foundation

/// ContinuityCaptureAgent, the macOS helper behind an iPhone microphone (Continuity). It runs as
/// the user, and launchd starts it again whenever it exits.
///
/// On 2026-11-19 (and before, 2026-09-11 and 09-14) it blocked audio input for every app on the
/// Mac: every microphone's start stalled inside Core Audio (coreaudiod `StartIOThread ... Error:
/// 0x3C` every ~14 s). Restarting coreaudiod did not help; stopping this agent cleared it at once.
/// No sudo is needed: it is the user's own process. It is found by PID and signalled by PID,
/// never by a name match handed to a shell.
nonisolated enum ContinuityCaptureHelper {
    static let executablePath = "/usr/libexec/ContinuityCaptureAgent"
    static let processName = "ContinuityCaptureAgent"

    struct RestartReport: Equatable {
        /// The agent's PIDs before the restart.
        var found: [pid_t] = []
        /// PIDs gone after SIGTERM.
        var exited: [pid_t] = []
        /// PIDs that needed SIGKILL.
        var forced: [pid_t] = []
        /// PIDs still running, or that could not be signalled, with errno.
        var failed: [pid_t: Int32] = [:]
        /// The agent's PIDs afterwards (launchd's respawn), if it is back yet.
        var after: [pid_t] = []
        var elapsedMilliseconds = 0

        var logDescription: String {
            "found=\(self.found) exited=\(self.exited) forced=\(self.forced) " +
                "failed=\(self.failed) after=\(self.after) elapsedMs=\(self.elapsedMilliseconds)"
        }
    }

    /// The current user's ContinuityCaptureAgent processes.
    static func runningPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let filled = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard filled > 0 else { return [] }
        let uid = getuid()
        return pids.prefix(Int(filled)).filter { pid in
            pid > 0 && Self.isAgent(pid: pid, ownedBy: uid)
        }
    }

    private static func isAgent(pid: pid_t, ownedBy uid: uid_t) -> Bool {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size, info.pbi_uid == uid else {
            return false
        }
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        if proc_pidpath(pid, &path, UInt32(path.count)) > 0 {
            return String(cString: path) == Self.executablePath
        }
        let name = withUnsafeBytes(of: info.pbi_name) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return name == Self.processName
    }

    private static func isRunning(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno != ESRCH
    }

    /// Stops every agent of this user with SIGTERM, then SIGKILL for any still running after
    /// `gracePeriod`, and waits briefly for launchd to start it again. Blocks; call it off the
    /// main thread.
    static func restart(gracePeriod: TimeInterval = 2) -> RestartReport {
        let startedAt = ProcessInfo.processInfo.systemUptime
        var report = RestartReport()
        report.found = Self.runningPIDs()
        var pending: [pid_t] = []
        for pid in report.found {
            if kill(pid, SIGTERM) == 0 {
                pending.append(pid)
            } else if errno == ESRCH {
                report.exited.append(pid)
            } else {
                report.failed[pid] = errno
            }
        }
        let signalled = pending
        pending = Self.wait(for: pending, upTo: gracePeriod)
        let stillRunning = pending
        report.exited += signalled.filter { !stillRunning.contains($0) }
        let uid = getuid()
        for pid in pending {
            // Still the agent? A PID freed and reused within the grace period is not ours to kill.
            guard Self.isAgent(pid: pid, ownedBy: uid) else {
                report.exited.append(pid)
                continue
            }
            if kill(pid, SIGKILL) == 0 || errno == ESRCH {
                report.forced.append(pid)
            } else {
                report.failed[pid] = errno
            }
        }
        for pid in Self.wait(for: report.forced, upTo: 0.5) {
            report.failed[pid] = ETIMEDOUT
        }
        // launchd brings the agent back on its own; note whether it already has.
        let respawnDeadline = ProcessInfo.processInfo.systemUptime + 1
        repeat {
            report.after = Self.runningPIDs().filter { !report.found.contains($0) }
            if !report.after.isEmpty || report.found.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.05)
        } while ProcessInfo.processInfo.systemUptime < respawnDeadline
        report.elapsedMilliseconds = Int(((ProcessInfo.processInfo.systemUptime - startedAt) * 1000).rounded())
        return report
    }

    /// The PIDs still running after `timeout`.
    private static func wait(for pids: [pid_t], upTo timeout: TimeInterval) -> [pid_t] {
        var remaining = pids
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while !remaining.isEmpty, ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.02)
            remaining = remaining.filter(Self.isRunning)
        }
        return remaining
    }
}
