import CoreAudio
#if SWIFT_PACKAGE
import CoreAudioCaptureSupport
#endif
import Foundation

/// A Core Audio property listener that can be taken off again.
///
/// Swift imports `AudioObjectPropertyListenerBlock` as a Swift closure and bridges it to a new
/// block on every call, so `AudioObjectRemovePropertyListenerBlock` called from Swift never
/// matches the block that was added: it returns noErr, and the listener stays and keeps firing.
/// Found 2026-11-19, when one `io_stopped_abnormally` ran the listeners of 87 earlier recordings
/// at once: every direct capture had left its 11 behind. The C side keeps the one block Core
/// Audio was given and removes exactly that.
///
/// Dropping a listener without `remove()` leaves it registered, as before; only the handle is
/// freed.
final nonisolated class CoreAudioPropertyListener: @unchecked Sendable {
    let objectID: AudioObjectID
    let address: AudioObjectPropertyAddress

    private let lock = NSLock()
    private var handle: FVCoreAudioListenerRef?

    private init(objectID: AudioObjectID, address: AudioObjectPropertyAddress, handle: FVCoreAudioListenerRef) {
        self.objectID = objectID
        self.address = address
        self.handle = handle
    }

    deinit {
        if let handle = self.takeHandle() {
            fv_core_audio_listener_discard(handle)
        }
    }

    /// Registers `block` for the property at `address`, delivered on `queue`. Returns the
    /// listener, or nil with Core Audio's status when it refused.
    static func add(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        queue: DispatchQueue,
        block: @escaping AudioObjectPropertyListenerBlock
    ) -> (listener: CoreAudioPropertyListener?, status: OSStatus) {
        var address = address
        var handle: FVCoreAudioListenerRef?
        let status = fv_core_audio_listener_add(objectID, &address, queue, block, &handle)
        guard status == noErr, let handle else { return (nil, status) }
        return (CoreAudioPropertyListener(objectID: objectID, address: address, handle: handle), status)
    }

    /// Takes the listener off. Safe to call more than once; later calls do nothing.
    @discardableResult
    func remove() -> OSStatus {
        guard let handle = self.takeHandle() else { return noErr }
        return fv_core_audio_listener_remove(handle)
    }

    var isRegistered: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.handle != nil
    }

    private func takeHandle() -> FVCoreAudioListenerRef? {
        self.lock.lock()
        defer { self.lock.unlock() }
        let handle = self.handle
        self.handle = nil
        return handle
    }
}
