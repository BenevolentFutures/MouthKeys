import AppKit
import Carbon
import Foundation
import IOKit

/// Watches macOS Secure Event Input. While any process holds it, keyboard events never reach
/// event taps, so every hotkey is silently dead while system shortcuts (⌘Space) still work
/// (2026-11-19: hours of a dead ⌥Space with a healthy app). It logs each flip as one
/// `SECURE_INPUT` line and the menu shows "Keys Blocked" while it is on.
///
/// The holder comes from `kCGSSessionSecureInputPID` in the console session, which names the
/// last process to change the flag, so it is a suspect, not proof.
@MainActor
final class SecureInputMonitor {
    static let shared = SecureInputMonitor()

    /// A cheap Carbon read; two seconds keeps the menu current without a busy wakeup.
    static let pollInterval: TimeInterval = 2

    struct Holder: Equatable {
        let pid: Int32
        let name: String?
    }

    private(set) var isEnabled = false
    private(set) var holder: Holder?

    private let enabledProvider: () -> Bool
    private let holderProvider: () -> Holder?
    private var timer: Timer?

    init(
        enabledProvider: @escaping () -> Bool = { IsSecureEventInputEnabled() },
        holderProvider: @escaping () -> Holder? = { SecureInputMonitor.currentHolder() }
    ) {
        self.enabledProvider = enabledProvider
        self.holderProvider = holderProvider
    }

    func start() {
        guard self.timer == nil, !TestHostQuietMode.isActive else { return }
        self.refresh()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Re-reads the flag; logs and records the holder only when it flips (and on demand, for an
    /// open menu, since one app can hand Secure Input to another without a flip).
    func refresh(rereadHolder: Bool = false) {
        let enabled = self.enabledProvider()
        if enabled, enabled == self.isEnabled, rereadHolder {
            self.holder = self.holderProvider()
        }
        guard enabled != self.isEnabled else { return }
        self.isEnabled = enabled
        self.holder = enabled ? self.holderProvider() : nil
        DebugLogger.shared.info(Self.logLine(enabled: enabled, holder: self.holder), source: "SecureInputMonitor")
    }

    /// Short holder label for the menu row.
    var holderLabel: String {
        guard let holder else { return "Secure Input" }
        return holder.name ?? "pid \(holder.pid)"
    }

    static func logLine(enabled: Bool, holder: Holder?) -> String {
        guard enabled else { return "SECURE_INPUT enabled=false" }
        let pid = holder.map { String($0.pid) } ?? "unknown"
        let name = holder?.name ?? "unknown"
        return "SECURE_INPUT enabled=true holderPID=\(pid) holder=\(name) effect=hotkeys_blocked"
    }

    /// The console session's last secure-input PID and its process name, read from IORegistry.
    nonisolated static func currentHolder() -> Holder? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        guard
            let value = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue(),
            let sessions = value as? [[String: Any]]
        else { return nil }
        for session in sessions {
            guard (session["kCGSSessionOnConsoleKey"] as? NSNumber)?.boolValue ?? true else { continue }
            guard let pid = (session["kCGSSessionSecureInputPID"] as? NSNumber)?.int32Value, pid > 0 else { continue }
            return Holder(pid: pid, name: Self.processName(pid))
        }
        return nil
    }

    nonisolated static func processName(_ pid: Int32) -> String? {
        if let name = NSRunningApplication(processIdentifier: pid)?.localizedName { return name }
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
