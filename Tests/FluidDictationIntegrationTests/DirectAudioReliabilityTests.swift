import CoreAudio
@testable import MouthKeys_Debug
import Foundation
import XCTest

final class DirectAudioReliabilityTests: XCTestCase {
    /// 2026-11-19: `AudioObjectRemovePropertyListenerBlock` called from Swift never removed
    /// anything (Swift hands Core Audio a new block on every call), so every capture left its
    /// listeners behind. Toggles this process's own input mute: silent, and no other app sees it.
    func testCoreAudioPropertyListenerRemovalStopsDelivery() throws {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessInputMute,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(system, &address) else {
            throw XCTSkip("Process input mute is unavailable on this macOS")
        }
        let queue = DispatchQueue(label: "test.listener-removal")
        let lock = NSLock()
        var calls: [String] = []
        func listen(_ name: String) throws -> CoreAudioPropertyListener {
            try XCTUnwrap(CoreAudioPropertyListener.add(objectID: system, address: address, queue: queue) { _, _ in
                lock.withLock { calls.append(name) }
            }.listener)
        }
        let removed = try listen("removed")
        let kept = try listen("kept")
        removed.remove()
        removed.remove() // a second remove does nothing
        CoreAudioHAL.listenerLane.drainForTesting()
        XCTAssertFalse(removed.isRegistered)

        func setMute(_ value: UInt32) {
            var value = value
            _ = AudioObjectSetPropertyData(system, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        }
        setMute(1)
        setMute(0)
        let deadline = Date().addingTimeInterval(3)
        while lock.withLock({ calls.filter { $0 == "kept" }.count }) < 2, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        queue.sync {}
        kept.remove()
        let delivered = lock.withLock { calls }
        XCTAssertEqual(delivered.filter { $0 == "kept" }.count, 2, "the listener left on hears both changes")
        XCTAssertFalse(delivered.contains("removed"), "a removed listener never fires: \(delivered)")
        XCTAssertEqual(removed.coreAudioDeliveryCount, 0, "Core Audio itself dropped the removed block")
    }

    /// 2026-11-19 17:58:20, after a `coreaudiod` restart: the HAL's notification thread, tearing
    /// a dead device down, delivered its listener with `dispatch_sync` onto the listener's queue
    /// (main), while main was removing that listener, which waits for any delivery in flight.
    /// MouthKeys stayed alive with its main thread blocked forever. The fake HAL here does the
    /// same two things: delivery is a `sync` onto the registered queue, and remove waits for it.
    func testListenerRemovalDuringASynchronousDeliveryNeverBlocksMain() throws {
        let hal = FakeListenerHAL()
        let lane = CoreAudioHAL.Lane(label: "test.listener-lane", watchdog: CoreAudioHAL.Watchdog(stuckAfter: 5))
        let calls = LockedCounter()
        let listener = try XCTUnwrap(CoreAudioPropertyListener.add(
            objectID: 42,
            address: FakeListenerHAL.address,
            queue: .main,
            backend: hal.backend,
            lane: lane
        ) { _, _ in calls.increment() }.listener)
        XCTAssertFalse(hal.registeredQueues.contains { $0 === DispatchQueue.main }, "Core Audio never delivers to main")

        let deliveryStarted = DispatchSemaphore(value: 0)
        let removeCalled = DispatchSemaphore(value: 0)
        let deliveryDone = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            hal.deliverSynchronously(onceInFlight: {
                deliveryStarted.signal()
                _ = removeCalled.wait(timeout: .now() + 5)
            })
            deliveryDone.signal()
        }
        XCTAssertEqual(deliveryStarted.wait(timeout: .now() + 2), .success)

        let removeStartedAt = ProcessInfo.processInfo.systemUptime
        listener.remove()
        let removeMs = (ProcessInfo.processInfo.systemUptime - removeStartedAt) * 1000
        removeCalled.signal()
        XCTAssertLessThan(removeMs, 50, "remove() returns at once on main")

        // Main keeps serving its queue while the HAL's delivery and removal finish.
        let deadline = Date().addingTimeInterval(3)
        while deliveryDone.wait(timeout: .now()) != .success, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        lane.drainForTesting()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertFalse(hal.removeTimedOut, "the removal waited for a delivery that could never finish")
        XCTAssertFalse(listener.isRegistered)
        XCTAssertEqual(hal.liveRegistrations, 0)
        XCTAssertEqual(calls.value, 0, "a delivery that arrives after remove() never reaches the caller")
    }

    /// A removal stuck inside Core Audio leaves main free, and the watchdog says so.
    func testStuckListenerRemovalLeavesMainResponsiveAndIsReported() throws {
        let hal = FakeListenerHAL()
        hal.blockRemoval()
        let watchdog = CoreAudioHAL.Watchdog(stuckAfter: 0.2)
        let lane = CoreAudioHAL.Lane(label: "test.stuck-lane", watchdog: watchdog)
        let stuckPosts = LockedCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: .coreAudioHALStuckStateDidChange, object: watchdog, queue: nil
        ) { _ in stuckPosts.increment() }
        defer { NotificationCenter.default.removeObserver(observer) }
        let listener = try XCTUnwrap(CoreAudioPropertyListener.add(
            objectID: 42, address: FakeListenerHAL.address, queue: .main, backend: hal.backend, lane: lane
        ) { _, _ in }.listener)

        let removeStartedAt = ProcessInfo.processInfo.systemUptime
        listener.remove()
        XCTAssertLessThan((ProcessInfo.processInfo.systemUptime - removeStartedAt) * 1000, 50)

        var mainServed = false
        DispatchQueue.main.async { mainServed = true }
        let deadline = Date().addingTimeInterval(2)
        while mainServed == false || watchdog.isStuck == false ||
            lane.isBusy(longerThan: CoreAudioHAL.mainThreadDeadline) == false,
            Date() < deadline
        {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(mainServed)
        XCTAssertTrue(watchdog.isStuck, "a call past stuckAfter is reported")

        // Another add from main while the lane is stuck does not wait for it.
        let addStartedAt = ProcessInfo.processInfo.systemUptime
        let pending = CoreAudioPropertyListener.add(
            objectID: 43, address: FakeListenerHAL.address, queue: .main, backend: hal.backend, lane: lane
        ) { _, _ in }
        XCTAssertLessThan((ProcessInfo.processInfo.systemUptime - addStartedAt) * 1000, 50)
        XCTAssertEqual(pending.status, CoreAudioPropertyListener.registrationPendingStatus)
        XCTAssertNotNil(pending.listener)

        hal.unblockRemoval()
        lane.drainForTesting()
        XCTAssertFalse(watchdog.isStuck)
        XCTAssertTrue(pending.listener?.isRegistered == true, "the queued add ran once the lane was free")
        pending.listener?.remove()
        lane.drainForTesting()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(stuckPosts.value, 2, "stuck, then recovered")
    }

    /// A read on main gets the deadline, then the fallback; while the lane is still stuck the
    /// next one does not wait at all.
    func testMainThreadReadFallsBackAtItsDeadline() {
        let lane = CoreAudioHAL.Lane(label: "test.read-lane", watchdog: CoreAudioHAL.Watchdog(stuckAfter: 5))
        let release = DispatchSemaphore(value: 0)
        let firstStartedAt = ProcessInfo.processInfo.systemUptime
        let first = CoreAudioHAL.read("test_stuck_read", deadline: 0.1, lane: lane, fallback: -1) {
            _ = release.wait(timeout: .now() + 5)
            return 1
        }
        let firstMs = (ProcessInfo.processInfo.systemUptime - firstStartedAt) * 1000
        XCTAssertEqual(first, -1)
        XCTAssertLessThan(firstMs, 300)

        let secondStartedAt = ProcessInfo.processInfo.systemUptime
        let second = CoreAudioHAL.read("test_read_behind_stuck", deadline: 0.1, lane: lane, fallback: -2) { 2 }
        XCTAssertEqual(second, -2)
        XCTAssertLessThan((ProcessInfo.processInfo.systemUptime - secondStartedAt) * 1000, 20, "no wait behind a stuck call")

        release.signal()
        lane.drainForTesting()
        XCTAssertEqual(CoreAudioHAL.read("test_read", deadline: 0.1, lane: lane, fallback: -3) { 3 }, 3)
    }

    /// One `coreaudiod` restart reaches MouthKeys from more than one listener; the app
    /// re-registers once.
    @MainActor
    func testCoreAudioServiceRestartIsHandledOncePerRestart() {
        let observer = AudioHardwareObserver()
        let posts = LockedCounter()
        let token = NotificationCenter.default.addObserver(
            forName: .coreAudioServiceDidRestart, object: observer, queue: nil
        ) { _ in posts.increment() }
        defer { NotificationCenter.default.removeObserver(token) }
        observer.noteCoreAudioServiceRestarted(source: "hardware_observer")
        observer.noteCoreAudioServiceRestarted(source: "direct_capture")
        XCTAssertEqual(posts.value, 1)
    }

    /// One microphone stalling is that microphone; two different ones in a row are macOS's audio
    /// input, and audio arriving forgets them.
    func testTwoDifferentStalledMicrophonesMeanMacInputIsStuck() {
        var tracker = AudioCaptureIdlePolicy.StalledInputTracker()
        tracker.recordStall(uid: "atr")
        XCTAssertFalse(tracker.isMacInputStuck)
        tracker.recordStall(uid: "atr")
        XCTAssertFalse(tracker.isMacInputStuck, "the same microphone twice is still one microphone")
        tracker.recordStall(uid: "builtin")
        XCTAssertTrue(tracker.isMacInputStuck)
        XCTAssertEqual(tracker.stalledInputUIDs, ["atr", "builtin"])
        XCTAssertTrue(tracker.captureWorked())
        XCTAssertFalse(tracker.isMacInputStuck)
        XCTAssertFalse(tracker.captureWorked(), "nothing left to forget")
    }

    func testReadinessGatePreservesFirstPCMThatArrivesBeforeWait() async {
        let gate = AudioCaptureReadinessGate()
        gate.arm(sessionID: 41, attemptID: 1)
        gate.signalFirstPCM(sessionID: 41, attemptID: 1)

        let result = await gate.wait(
            sessionID: 41,
            attemptID: 1,
            timeoutNanoseconds: 1_000_000
        )

        XCTAssertEqual(result, .ready)
    }

    func testReadinessGateCancelsWaitAndIgnoresStalePCM() async {
        let gate = AudioCaptureReadinessGate()
        gate.arm(sessionID: 41, attemptID: 1)
        let firstWait = Task {
            await gate.wait(
                sessionID: 41,
                attemptID: 1,
                timeoutNanoseconds: 1_000_000_000
            )
        }
        await Task.yield()
        gate.cancel(sessionID: 41, attemptID: 1)
        let firstResult = await firstWait.value
        XCTAssertEqual(firstResult, .cancelled)

        gate.arm(sessionID: 41, attemptID: 2)
        gate.signalFirstPCM(sessionID: 41, attemptID: 1)
        let staleResult = await gate.wait(
            sessionID: 41,
            attemptID: 1,
            timeoutNanoseconds: 1_000_000
        )
        XCTAssertEqual(staleResult, .staleSession)

        gate.signalFirstPCM(sessionID: 41, attemptID: 2)
        let replacementResult = await gate.wait(
            sessionID: 41,
            attemptID: 2,
            timeoutNanoseconds: 1_000_000
        )
        XCTAssertEqual(replacementResult, .ready)
    }

    func testReadinessGateRearmingCancelsExistingWaiter() async {
        let gate = AudioCaptureReadinessGate()
        gate.arm(sessionID: 41, attemptID: 1)
        let firstWait = Task {
            await gate.wait(
                sessionID: 41,
                attemptID: 1,
                timeoutNanoseconds: 10_000_000_000
            )
        }
        // The unstructured task may not have parked its waiter after a single
        // yield. Re-arming first would (correctly) make its late wait stale, so
        // wait until the gate actually holds the first waiter.
        let registrationDeadline = ProcessInfo.processInfo.systemUptime + 5
        while !gate.hasRegisteredWaiter(sessionID: 41, attemptID: 1),
              ProcessInfo.processInfo.systemUptime < registrationDeadline
        {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertTrue(gate.hasRegisteredWaiter(sessionID: 41, attemptID: 1), "first waiter never registered")

        gate.arm(sessionID: 41, attemptID: 2)

        let firstResult = await firstWait.value
        XCTAssertEqual(firstResult, .cancelled)
        gate.signalFirstPCM(sessionID: 41, attemptID: 2)
        let replacementResult = await gate.wait(
            sessionID: 41,
            attemptID: 2,
            timeoutNanoseconds: 1_000_000
        )
        XCTAssertEqual(replacementResult, .ready)
    }

    func testReadinessGateTimesOutWithoutPCM() async {
        let gate = AudioCaptureReadinessGate()
        gate.arm(sessionID: 41, attemptID: 1)

        let result = await gate.wait(
            sessionID: 41,
            attemptID: 1,
            timeoutNanoseconds: 1_000_000
        )

        XCTAssertEqual(result, .timedOut)
    }

    func testReadinessWaitRespondsPromptlyToTaskCancellation() async {
        let gate = AudioCaptureReadinessGate()
        gate.arm(sessionID: 41, attemptID: 1)
        let waitTask = Task {
            await gate.wait(
                sessionID: 41,
                attemptID: 1,
                timeoutNanoseconds: 10_000_000_000
            )
        }
        await Task.yield()

        let cancelledAt = ProcessInfo.processInfo.systemUptime
        waitTask.cancel()
        let result = await waitTask.value
        let cancellationMilliseconds =
            (ProcessInfo.processInfo.systemUptime - cancelledAt) * 1000

        XCTAssertEqual(result, .cancelled)
        XCTAssertLessThan(cancellationMilliseconds, 100)
    }

    func testFingerprintMismatchInvalidatesOldCaptureBeforeStartingReplacement() async throws {
        let oldFingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let newFingerprint = makeFingerprint(sampleRate: 24_000, bufferFrameSize: 256)
        let recorder = DirectAudioEventRecorder()
        let factory = FakeDirectAudioInputFactory(
            fingerprints: [oldFingerprint, newFingerprint],
            recorder: recorder
        )
        let fingerprintReader = ScriptedFingerprintReader(
            values: [
                oldFingerprint,
                oldFingerprint,
                oldFingerprint,
                newFingerprint,
                newFingerprint,
                newFingerprint,
                newFingerprint,
            ]
        )
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { deviceID, _ in
                try factory.make(deviceID: deviceID)
            },
            fingerprintReader: { _ in
                try fingerprintReader.read()
            },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )

        _ = try await controller.prepare(
            deviceID: oldFingerprint.deviceID,
            deviceName: "Test microphone",
            reason: "test_prewarm"
        )
        let running = try await controller.start(
            deviceID: oldFingerprint.deviceID,
            deviceName: "Test microphone",
            reason: "test_start"
        )
        await controller.shutdown(reason: "test_complete")

        XCTAssertEqual(running.fingerprint, newFingerprint)
        XCTAssertEqual(
            recorder.events,
            [
                "make:48000",
                "invalidate:48000",
                "make:24000",
                "start:24000",
                "invalidate:24000",
            ]
        )
        XCTAssertFalse(recorder.events.contains("start:48000"))
        XCTAssertTrue(recorder.executedOnlyOffMain)
        XCTAssertEqual(recorder.maximumConcurrentOperations, 1)
    }

    func testPrepareRollsBackWhenPostInstallFingerprintReadFails() async throws {
        let fingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let recorder = DirectAudioEventRecorder()
        let factory = FakeDirectAudioInputFactory(
            fingerprints: [fingerprint],
            recorder: recorder
        )
        let fingerprintReader = ScriptedFingerprintReader(values: [fingerprint])
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { deviceID, _ in
                try factory.make(deviceID: deviceID)
            },
            fingerprintReader: { _ in
                try fingerprintReader.read()
            },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )

        do {
            _ = try await controller.prepare(
                deviceID: fingerprint.deviceID,
                deviceName: "Test microphone",
                reason: "test_prepare_failure"
            )
            XCTFail("Expected the final fingerprint read to fail.")
        } catch {
            XCTAssertEqual(controller.snapshot.phase, .empty)
            XCTAssertEqual(
                recorder.events,
                ["make:48000", "invalidate:48000"]
            )
        }
    }

    func testConcurrentLifecycleCommandsNeverOverlap() async throws {
        let fingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let recorder = DirectAudioEventRecorder(operationDelayMicroseconds: 2000)
        let factory = FakeDirectAudioInputFactory(
            fingerprints: [fingerprint],
            recorder: recorder
        )
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { deviceID, _ in
                try factory.make(deviceID: deviceID)
            },
            fingerprintReader: { _ in fingerprint },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )
        _ = try await controller.prepare(
            deviceID: fingerprint.deviceID,
            deviceName: "Test microphone",
            reason: "test_prepare"
        )

        let commands = (0..<12).map { index in
            Task {
                if index.isMultiple(of: 2) {
                    _ = try? await controller.start(
                        deviceID: fingerprint.deviceID,
                        deviceName: "Test microphone",
                        reason: "concurrent_start"
                    )
                } else {
                    _ = await controller.stop(
                        retainPrepared: true,
                        reason: "concurrent_stop"
                    )
                }
            }
        }
        for command in commands {
            await command.value
        }
        await controller.shutdown(reason: "test_complete")

        XCTAssertTrue(recorder.executedOnlyOffMain)
        XCTAssertEqual(recorder.maximumConcurrentOperations, 1)
    }

    func testStartingRunningInputReusesHardwareWithoutStopOrRestart() async throws {
        let fingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let recorder = DirectAudioEventRecorder()
        let factory = FakeDirectAudioInputFactory(
            fingerprints: [fingerprint],
            recorder: recorder
        )
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { deviceID, _ in
                try factory.make(deviceID: deviceID)
            },
            fingerprintReader: { _ in fingerprint },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )

        _ = try await controller.start(
            deviceID: fingerprint.deviceID,
            deviceName: "Test microphone",
            reason: "preview"
        )
        let reused = try await controller.start(
            deviceID: fingerprint.deviceID,
            deviceName: "Test microphone",
            reason: "dictation_handoff"
        )
        await controller.shutdown(reason: "test_complete")

        XCTAssertEqual(reused.phase, .running)
        XCTAssertEqual(
            recorder.events,
            ["make:48000", "start:48000", "invalidate:48000"]
        )
    }

    func testFailedStopPoisonsLifecycleAndPreventsReplacement() async throws {
        let fingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let recorder = DirectAudioEventRecorder()
        let input = FailingStopDirectAudioInput(
            fingerprint: fingerprint,
            recorder: recorder
        )
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { _, _ in input },
            fingerprintReader: { _ in fingerprint },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )
        _ = try await controller.start(
            deviceID: fingerprint.deviceID,
            deviceName: "Test microphone",
            reason: "test_start"
        )

        let report = await controller.stop(
            retainPrepared: true,
            reason: "test_stop_failure"
        )

        XCTAssertNotEqual(report.status, noErr)
        XCTAssertFalse(report.retainedPreparedCapture)
        XCTAssertEqual(controller.snapshot.phase, .failed)
        do {
            _ = try await controller.prepare(
                deviceID: fingerprint.deviceID,
                deviceName: "Replacement microphone",
                reason: "must_not_replace"
            )
            XCTFail("A poisoned lifecycle must not create a replacement.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("poisoned"))
        }
        XCTAssertEqual(recorder.events, ["start:48000", "stop_failed", "quarantine"])
    }

    func testFailedReplacementTeardownDoesNotCreateConcurrentInput() async throws {
        let oldFingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let newFingerprint = makeFingerprint(sampleRate: 24_000, bufferFrameSize: 256)
        let recorder = DirectAudioEventRecorder()
        let factory = FailingReplacementFactory(
            fingerprint: oldFingerprint,
            recorder: recorder
        )
        let fingerprintReader = ScriptedFingerprintReader(
            values: [oldFingerprint, oldFingerprint, newFingerprint]
        )
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { deviceID, _ in
                factory.make(deviceID: deviceID)
            },
            fingerprintReader: { _ in
                try fingerprintReader.read()
            },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )

        _ = try await controller.prepare(
            deviceID: oldFingerprint.deviceID,
            deviceName: "Old microphone",
            reason: "test_initial_prepare"
        )

        do {
            _ = try await controller.prepare(
                deviceID: newFingerprint.deviceID,
                deviceName: "Replacement microphone",
                reason: "test_failed_replacement"
            )
            XCTFail("A failed teardown must prevent replacement creation.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("poisoned"))
        }

        XCTAssertEqual(controller.snapshot.phase, .failed)
        XCTAssertEqual(factory.creationCount, 1)
        XCTAssertEqual(recorder.events, ["quarantine"])
    }

    func testDeviceRemovalFailureQuarantinesOldInputAndAllowsReplacement() async throws {
        let oldFingerprint = makeFingerprint(sampleRate: 48_000, bufferFrameSize: 512)
        let newFingerprint = makeFingerprint(sampleRate: 24_000, bufferFrameSize: 256)
        let recorder = DirectAudioEventRecorder()
        let factory = RecoveringAfterStoppedHardwareFactory(
            oldFingerprint: oldFingerprint,
            newFingerprint: newFingerprint,
            recorder: recorder
        )
        let fingerprintReader = ScriptedFingerprintReader(
            values: [oldFingerprint, oldFingerprint, newFingerprint, newFingerprint]
        )
        let controller = DirectCoreAudioLifecycleController(
            packetHandler: { _, _, _, _, _ in },
            inputFactory: { deviceID, _ in
                factory.make(deviceID: deviceID)
            },
            fingerprintReader: { _ in
                try fingerprintReader.read()
            },
            installsHardwareListeners: false,
            onFormatInvalidated: { _ in }
        )

        _ = try await controller.prepare(
            deviceID: oldFingerprint.deviceID,
            deviceName: "Old microphone",
            reason: "test_initial_prepare"
        )
        await controller.invalidate(reason: "teardown_before_notification")
        XCTAssertEqual(controller.snapshot.phase, .failed)
        await controller.simulateStoppedHardwareNotificationForTesting(
            generation: controller.snapshot.generation,
            reason: "device_is_alive"
        )
        let replacement = try await controller.prepare(
            deviceID: newFingerprint.deviceID,
            deviceName: "Replacement microphone",
            reason: "test_recovery"
        )

        XCTAssertEqual(replacement.phase, .prepared)
        XCTAssertEqual(replacement.fingerprint, newFingerprint)
        XCTAssertEqual(factory.creationCount, 2)
        XCTAssertEqual(recorder.events, ["quarantine", "make:24000"])
        await controller.shutdown(reason: "test_complete")
    }
}

private nonisolated func makeFingerprint(
    sampleRate: Double,
    bufferFrameSize: UInt32
) -> DirectCoreAudioFormatFingerprint {
    DirectCoreAudioFormatFingerprint(
        deviceID: 7001,
        streamID: 7002,
        virtualFormat: DirectCoreAudioStreamFormatFingerprint(
            AudioStreamBasicDescription(
                mSampleRate: sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 32,
                mReserved: 0
            )
        ),
        physicalFormat: nil,
        inputBufferChannels: [1],
        nominalSampleRate: sampleRate,
        bufferFrameSize: bufferFrameSize,
        variableBufferFrameSizeMaximum: nil,
        dataSourceID: nil
    )
}

private final nonisolated class FakeDirectAudioInputFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var fingerprints: [DirectCoreAudioFormatFingerprint]
    private let recorder: DirectAudioEventRecorder

    init(
        fingerprints: [DirectCoreAudioFormatFingerprint],
        recorder: DirectAudioEventRecorder
    ) {
        self.fingerprints = fingerprints
        self.recorder = recorder
    }

    func make(deviceID: AudioObjectID) throws -> any DirectCoreAudioInputControlling {
        try self.lock.withLock {
            guard self.fingerprints.isEmpty == false else {
                throw NSError(
                    domain: "DirectAudioReliabilityTests",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No fake input remains."]
                )
            }
            let fingerprint = self.fingerprints.removeFirst()
            self.recorder.record("make:\(Int(fingerprint.virtualFormat.sampleRate))")
            return FakeDirectAudioInput(
                deviceID: deviceID,
                fingerprint: fingerprint,
                recorder: self.recorder
            )
        }
    }
}

private final nonisolated class ScriptedFingerprintReader: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [DirectCoreAudioFormatFingerprint]

    init(values: [DirectCoreAudioFormatFingerprint]) {
        self.values = values
    }

    func read() throws -> DirectCoreAudioFormatFingerprint {
        try self.lock.withLock {
            guard self.values.isEmpty == false else {
                throw NSError(
                    domain: "DirectAudioReliabilityTests",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "No fingerprint remains."]
                )
            }
            return self.values.removeFirst()
        }
    }
}

private final nonisolated class FakeDirectAudioInput:
    DirectCoreAudioInputControlling,
    @unchecked Sendable
{
    let deviceID: AudioObjectID
    let sampleRate: Double
    let hardwareBufferFrameSize: UInt32
    let formatFingerprint: DirectCoreAudioFormatFingerprint

    private let recorder: DirectAudioEventRecorder
    private var running = false

    init(
        deviceID: AudioObjectID,
        fingerprint: DirectCoreAudioFormatFingerprint,
        recorder: DirectAudioEventRecorder
    ) {
        self.deviceID = deviceID
        self.sampleRate = fingerprint.virtualFormat.sampleRate
        self.hardwareBufferFrameSize = fingerprint.bufferFrameSize
        self.formatFingerprint = fingerprint
        self.recorder = recorder
    }

    var isRunning: Bool {
        self.running
    }

    var droppedPacketCount: UInt64 {
        0
    }

    func start() throws {
        self.recorder.perform(
            "start:\(Int(self.sampleRate))"
        ) {
            self.running = true
        }
    }

    func stop() -> OSStatus {
        self.recorder.perform(
            "stop:\(Int(self.sampleRate))"
        ) {
            self.running = false
        }
        return noErr
    }

    func markFormatDirty() {}

    func openPacketGateIfClean() -> Bool {
        true
    }

    func invalidate() -> OSStatus {
        self.recorder.perform(
            "invalidate:\(Int(self.sampleRate))"
        ) {
            self.running = false
        }
        return noErr
    }
}

private final nonisolated class FailingStopDirectAudioInput:
    DirectCoreAudioInputControlling,
    @unchecked Sendable
{
    let deviceID: AudioObjectID
    let sampleRate: Double
    let hardwareBufferFrameSize: UInt32
    let formatFingerprint: DirectCoreAudioFormatFingerprint

    private let recorder: DirectAudioEventRecorder
    private var running = false
    private let failureStatus = OSStatus(-50)

    init(
        fingerprint: DirectCoreAudioFormatFingerprint,
        recorder: DirectAudioEventRecorder
    ) {
        self.deviceID = fingerprint.deviceID
        self.sampleRate = fingerprint.virtualFormat.sampleRate
        self.hardwareBufferFrameSize = fingerprint.bufferFrameSize
        self.formatFingerprint = fingerprint
        self.recorder = recorder
    }

    var isRunning: Bool {
        self.running
    }

    var droppedPacketCount: UInt64 {
        0
    }

    func start() throws {
        self.running = true
        self.recorder.record("start:\(Int(self.sampleRate))")
    }

    func stop() -> OSStatus {
        self.running = false
        self.recorder.record("stop_failed")
        return self.failureStatus
    }

    func markFormatDirty() {}

    func openPacketGateIfClean() -> Bool {
        true
    }

    func invalidate() -> OSStatus {
        self.recorder.record("quarantine")
        return self.failureStatus
    }
}

private final nonisolated class FailingReplacementFactory: @unchecked Sendable {
    private let lock = NSLock()
    private let fingerprint: DirectCoreAudioFormatFingerprint
    private let recorder: DirectAudioEventRecorder
    private var creations = 0

    init(
        fingerprint: DirectCoreAudioFormatFingerprint,
        recorder: DirectAudioEventRecorder
    ) {
        self.fingerprint = fingerprint
        self.recorder = recorder
    }

    var creationCount: Int {
        self.lock.withLock { self.creations }
    }

    func make(deviceID _: AudioObjectID) -> any DirectCoreAudioInputControlling {
        self.lock.withLock {
            self.creations += 1
        }
        return FailingStopDirectAudioInput(
            fingerprint: self.fingerprint,
            recorder: self.recorder
        )
    }
}

private final nonisolated class RecoveringAfterStoppedHardwareFactory: @unchecked Sendable {
    private let lock = NSLock()
    private let oldFingerprint: DirectCoreAudioFormatFingerprint
    private let newFingerprint: DirectCoreAudioFormatFingerprint
    private let recorder: DirectAudioEventRecorder
    private var creations = 0

    init(
        oldFingerprint: DirectCoreAudioFormatFingerprint,
        newFingerprint: DirectCoreAudioFormatFingerprint,
        recorder: DirectAudioEventRecorder
    ) {
        self.oldFingerprint = oldFingerprint
        self.newFingerprint = newFingerprint
        self.recorder = recorder
    }

    var creationCount: Int {
        self.lock.withLock { self.creations }
    }

    func make(deviceID: AudioObjectID) -> any DirectCoreAudioInputControlling {
        let creation = self.lock.withLock {
            self.creations += 1
            return self.creations
        }
        if creation == 1 {
            return FailingStopDirectAudioInput(
                fingerprint: self.oldFingerprint,
                recorder: self.recorder
            )
        }
        self.recorder.record("make:\(Int(self.newFingerprint.virtualFormat.sampleRate))")
        return FakeDirectAudioInput(
            deviceID: deviceID,
            fingerprint: self.newFingerprint,
            recorder: self.recorder
        )
    }
}

private final nonisolated class DirectAudioEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let operationDelayMicroseconds: useconds_t
    private var recordedEvents: [String] = []
    private var operationCount = 0
    private var maximumOperationCount = 0
    private var allOperationsOffMain = true

    init(operationDelayMicroseconds: useconds_t = 0) {
        self.operationDelayMicroseconds = operationDelayMicroseconds
    }

    var events: [String] {
        self.lock.withLock { self.recordedEvents }
    }

    var maximumConcurrentOperations: Int {
        self.lock.withLock { self.maximumOperationCount }
    }

    var executedOnlyOffMain: Bool {
        self.lock.withLock { self.allOperationsOffMain }
    }

    func record(_ event: String) {
        self.lock.withLock {
            self.recordedEvents.append(event)
        }
    }

    func perform(_ event: String, body: () -> Void) {
        self.lock.withLock {
            self.operationCount += 1
            self.maximumOperationCount = max(
                self.maximumOperationCount,
                self.operationCount
            )
            self.allOperationsOffMain = self.allOperationsOffMain && Thread.isMainThread == false
            self.recordedEvents.append(event)
        }
        if self.operationDelayMicroseconds > 0 {
            usleep(self.operationDelayMicroseconds)
        }
        body()
        self.lock.withLock {
            self.operationCount -= 1
        }
    }
}

private final nonisolated class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        self.lock.withLock { self.count += 1 }
    }

    var value: Int {
        self.lock.withLock { self.count }
    }
}

/// Core Audio's listener semantics without Core Audio: a delivery is a `sync` onto the queue the
/// listener was registered with (as `HALObject::PropertiesChanged` does during a device
/// teardown), and remove waits for every delivery in flight (`HALObject::RemovePropertyListener`
/// waits on a `CAGuard`).
private final nonisolated class FakeListenerHAL: @unchecked Sendable {
    static let address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsAlive,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private let lock = NSLock()
    private var registrations: [Int: (queue: DispatchQueue, block: AudioObjectPropertyListenerBlock)] = [:]
    private var nextHandle = 1
    private var timedOut = false
    private let inFlight = DispatchGroup()
    private var removalGate: DispatchSemaphore?

    var registeredQueues: [DispatchQueue] {
        self.lock.withLock { self.registrations.values.map(\.queue) }
    }

    var liveRegistrations: Int {
        self.lock.withLock { self.registrations.count }
    }

    var removeTimedOut: Bool {
        self.lock.withLock { self.timedOut }
    }

    /// Every remove waits until `unblockRemoval()` (a Core Audio call that does not return).
    func blockRemoval() {
        self.lock.withLock { self.removalGate = DispatchSemaphore(value: 0) }
    }

    func unblockRemoval() {
        let gate = self.lock.withLock { () -> DispatchSemaphore? in
            let gate = self.removalGate
            self.removalGate = nil
            return gate
        }
        gate?.signal()
    }

    var backend: CoreAudioPropertyListener.Backend {
        CoreAudioPropertyListener.Backend(
            add: { [self] _, _, queue, block in
                let handle = self.lock.withLock { () -> Int in
                    let handle = self.nextHandle
                    self.nextHandle += 1
                    self.registrations[handle] = (queue, block)
                    return handle
                }
                return (UnsafeMutableRawPointer(bitPattern: handle), noErr)
            },
            remove: { [self] handle in
                if self.inFlight.wait(timeout: .now() + 3) == .timedOut {
                    self.lock.withLock { self.timedOut = true }
                }
                if let gate = self.lock.withLock({ self.removalGate }) {
                    _ = gate.wait(timeout: .now() + 5)
                    gate.signal()
                }
                self.lock.withLock { self.registrations[Int(bitPattern: handle)] = nil }
                return noErr
            },
            discard: { _ in }
        )
    }

    /// Delivers to every registration the way the HAL's notification thread does during a
    /// teardown. `onceInFlight` runs after the delivery counts as in flight and before it reaches
    /// the listener's queue.
    func deliverSynchronously(onceInFlight: () -> Void) {
        let registrations = self.lock.withLock { Array(self.registrations.values) }
        self.inFlight.enter()
        onceInFlight()
        for registration in registrations {
            registration.queue.sync {
                var address = Self.address
                registration.block(1, &address)
            }
        }
        self.inFlight.leave()
    }
}
