import CoreAudio
#if SWIFT_PACKAGE
import CoreAudioCaptureSupport
#endif
import Foundation

/// A Core Audio property listener that can be taken off again, without the caller ever waiting
/// on Core Audio.
///
/// Swift imports `AudioObjectPropertyListenerBlock` as a Swift closure and bridges it to a new
/// block on every call, so `AudioObjectRemovePropertyListenerBlock` called from Swift never
/// matches the block that was added: it returns noErr, and the listener stays and keeps firing.
/// Found 2026-11-19, when one `io_stopped_abnormally` ran the listeners of 87 earlier recordings
/// at once: every direct capture had left its 11 behind. The C side keeps the one block Core
/// Audio was given and removes exactly that.
///
/// Removal waits inside Core Audio for any delivery of that listener in flight, and during a
/// device teardown the HAL delivers with `dispatch_sync` onto the listener's queue. When that
/// queue was main and main was removing, each waited for the other forever (2026-11-19 17:58:20,
/// after a `coreaudiod` restart: MouthKeys alive, hotkeys dead). So:
/// - Core Audio delivers only to `deliveryQueue`, which never blocks: it hands each
///   notification on to the caller's queue with `async`.
/// - `remove()` returns at once. From then on the caller's block is never started again, and the
///   real removal runs on `CoreAudioHAL.listenerLane`.
/// - `add` from the main thread runs on the same lane and waits at most
///   `CoreAudioHAL.mainThreadDeadline`; off main it runs inline and returns Core Audio's status.
///
/// Dropping a listener without `remove()` leaves its block registered with Core Audio, but the
/// caller's block no longer runs.
final nonisolated class CoreAudioPropertyListener: @unchecked Sendable {
    /// What registers a block with Core Audio. Tests put a fake HAL here.
    struct Backend: @unchecked Sendable {
        var add: (AudioObjectID, AudioObjectPropertyAddress, DispatchQueue, @escaping AudioObjectPropertyListenerBlock)
            -> (handle: FVCoreAudioListenerRef?, status: OSStatus)
        var remove: (FVCoreAudioListenerRef) -> OSStatus
        var discard: (FVCoreAudioListenerRef) -> Void

        static let coreAudio = Backend(
            add: { objectID, address, queue, block in
                var address = address
                var handle: FVCoreAudioListenerRef?
                let status = fv_core_audio_listener_add(objectID, &address, queue, block, &handle)
                return (handle, status)
            },
            remove: { fv_core_audio_listener_remove($0) },
            discard: { fv_core_audio_listener_discard($0) }
        )
    }

    /// The status `add` reports for a registration still queued behind a stuck Core Audio call
    /// ('mkpd'). The listener is real and registers when the lane frees up.
    static let registrationPendingStatus = OSStatus(0x6D6B_7064)

    /// The only queue Core Audio delivers to. Its blocks never wait on anything.
    static let deliveryQueue = DispatchQueue(label: "com.stage11.mouthkeys.core-audio.delivery", qos: .userInitiated)

    let objectID: AudioObjectID
    let address: AudioObjectPropertyAddress

    private let backend: Backend
    private let lane: CoreAudioHAL.Lane
    private let lock = NSLock()
    private var handle: FVCoreAudioListenerRef?
    private var active = true
    private var removalRequested = false
    private var halDeliveries = 0

    private init(objectID: AudioObjectID, address: AudioObjectPropertyAddress, backend: Backend, lane: CoreAudioHAL.Lane) {
        self.objectID = objectID
        self.address = address
        self.backend = backend
        self.lane = lane
    }

    deinit {
        // Only reached once nothing holds the listener, so no lane call is still queued for it.
        if let handle = self.takeHandle() {
            self.backend.discard(handle)
        }
    }

    /// Registers `block` for the property at `address`, delivered on `queue`. Returns the
    /// listener, or nil with Core Audio's status when it refused. From the main thread a
    /// registration still queued at the deadline returns the listener with
    /// `registrationPendingStatus`; a later failure is logged.
    static func add(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        backend: Backend = .coreAudio,
        lane: CoreAudioHAL.Lane = CoreAudioHAL.listenerLane,
        block: @escaping AudioObjectPropertyListenerBlock
    ) -> (listener: CoreAudioPropertyListener?, status: OSStatus) {
        let listener = CoreAudioPropertyListener(objectID: objectID, address: address, backend: backend, lane: lane)
        let forward = listener.forwardingBlock(to: queue, block: block)
        let operation = "add_listener selector=\(Self.fourCC(address.mSelector)) object=\(objectID)"
        let status: OSStatus
        if Thread.isMainThread {
            status = lane.run(operation, waitingAtMost: CoreAudioHAL.mainThreadDeadline, queueWhenBusy: true) {
                listener.register(forward, logFailure: true)
            } ?? Self.registrationPendingStatus
        } else {
            let token = CoreAudioHAL.Lane.isOnAnyLane ? nil : lane.watchdog.begin(operation)
            status = listener.register(forward, logFailure: false)
            if let token { lane.watchdog.end(token) }
        }
        if status == noErr || status == Self.registrationPendingStatus {
            return (listener, status)
        }
        listener.deactivate()
        return (nil, status)
    }

    /// Takes the listener off. Returns at once: the caller's block is never started after this
    /// returns (one already running finishes), and Core Audio drops the registration on
    /// `CoreAudioHAL.listenerLane`. Safe to call more than once.
    func remove() {
        let firstRequest: Bool = self.lock.withLock {
            self.active = false
            guard self.removalRequested == false else { return false }
            self.removalRequested = true
            return true
        }
        guard firstRequest else { return }
        let operation = "remove_listener selector=\(Self.fourCC(self.address.mSelector)) object=\(self.objectID)"
        self.lane.async(operation) { [self] in
            guard let handle = self.takeHandle() else { return }
            let status = self.backend.remove(handle)
            if status != noErr, status != kAudioHardwareBadObjectError {
                DebugLogger.shared.warning(
                    "CORE_AUDIO_HAL op=remove_listener status=\(status) object=\(self.objectID) " +
                        "selector=\(Self.fourCC(self.address.mSelector))",
                    source: "CoreAudioHAL"
                )
            }
        }
    }

    /// False once `remove()` was called or the registration failed.
    var isActive: Bool {
        self.lock.withLock { self.active }
    }

    /// Core Audio still holds the block (registered and not yet taken off on the lane).
    var isRegistered: Bool {
        self.lock.withLock { self.handle != nil }
    }

    /// How many notifications Core Audio delivered to this listener, whether or not they reached
    /// the caller. Tests use it to prove Core Audio dropped the block.
    var coreAudioDeliveryCount: Int {
        self.lock.withLock { self.halDeliveries }
    }

    // MARK: - Private

    /// Runs where the registration runs (the lane, or the caller's thread off main).
    private func register(_ forward: @escaping AudioObjectPropertyListenerBlock, logFailure: Bool) -> OSStatus {
        let result = self.backend.add(self.objectID, self.address, Self.deliveryQueue, forward)
        guard result.status == noErr, let handle = result.handle else {
            self.deactivate()
            if logFailure {
                DebugLogger.shared.warning(
                    "CORE_AUDIO_HAL op=add_listener status=\(result.status) object=\(self.objectID) " +
                        "selector=\(Self.fourCC(self.address.mSelector))",
                    source: "CoreAudioHAL"
                )
            }
            return result.status == noErr ? kAudioHardwareUnspecifiedError : result.status
        }
        self.lock.withLock { self.handle = handle }
        return noErr
    }

    /// The block Core Audio holds. It copies the addresses (valid only during the call) and
    /// hands them on; the caller's block runs only while the listener is still active.
    private func forwardingBlock(
        to queue: DispatchQueue,
        block: @escaping AudioObjectPropertyListenerBlock
    ) -> AudioObjectPropertyListenerBlock {
        { [weak self] count, addresses in
            guard let self else { return }
            let stillActive: Bool = self.lock.withLock {
                self.halDeliveries += 1
                return self.active
            }
            guard stillActive else { return }
            let copied = Array(UnsafeBufferPointer(start: addresses, count: Int(count)))
            queue.async { [weak self] in
                guard let self, self.isActive else { return }
                copied.withUnsafeBufferPointer { buffer in
                    guard let base = buffer.baseAddress else { return }
                    block(UInt32(buffer.count), base)
                }
            }
        }
    }

    private func deactivate() {
        self.lock.withLock { self.active = false }
    }

    private func takeHandle() -> FVCoreAudioListenerRef? {
        self.lock.withLock {
            let handle = self.handle
            self.handle = nil
            return handle
        }
    }

    static func fourCC(_ value: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xFF) }
        guard bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) else { return String(value) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
