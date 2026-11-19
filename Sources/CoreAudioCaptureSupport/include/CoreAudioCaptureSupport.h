#ifndef CORE_AUDIO_CAPTURE_SUPPORT_H
#define CORE_AUDIO_CAPTURE_SUPPORT_H

#include <CoreAudio/CoreAudio.h>
#include <dispatch/dispatch.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *FVCoreAudioCaptureRef;

typedef struct {
    const float *samples;
    uint32_t frameCount;
    double sampleRate;
    uint64_t inputHostTime;
    int64_t inputSampleTime;
    uint64_t sequence;
} FVCoreAudioPacket;

/// Layout helpers shared by capture and deterministic tests.
uint32_t fv_core_audio_buffer_bytes_per_frame(
    uint32_t bytesPerSample,
    uint32_t channelCount
);
uint32_t fv_core_audio_buffer_frame_count(
    uint32_t dataByteSize,
    uint32_t bytesPerSample,
    uint32_t channelCount
);

/// Creates a prepared, input-only capture for one physical Core Audio device.
/// The device is not started and the microphone is not active until start.
int32_t fv_core_audio_capture_create(
    AudioObjectID deviceID,
    FVCoreAudioCaptureRef *outCapture
);

int32_t fv_core_audio_capture_start(FVCoreAudioCaptureRef capture);
int32_t fv_core_audio_capture_stop(FVCoreAudioCaptureRef capture);
int32_t fv_core_audio_capture_destroy(FVCoreAudioCaptureRef capture);

/// Waits until the realtime producer publishes a packet or capture stops.
/// Returns true when the consumer should attempt to drain the ring.
bool fv_core_audio_capture_wait(FVCoreAudioCaptureRef capture, uint32_t timeoutMilliseconds);

/// Returns a view into the next immutable ring slot. The pointer remains valid
/// until consume is called and must never escape the consumer callback.
bool fv_core_audio_capture_peek(FVCoreAudioCaptureRef capture, FVCoreAudioPacket *packet);
void fv_core_audio_capture_consume(FVCoreAudioCaptureRef capture);
void fv_core_audio_capture_clear(FVCoreAudioCaptureRef capture);
void fv_core_audio_capture_wake(FVCoreAudioCaptureRef capture);

bool fv_core_audio_capture_is_running(FVCoreAudioCaptureRef capture);
void fv_core_audio_capture_mark_format_dirty(FVCoreAudioCaptureRef capture);
bool fv_core_audio_capture_open_packet_gate_if_clean(FVCoreAudioCaptureRef capture);
bool fv_core_audio_capture_copy_stream_format(
    FVCoreAudioCaptureRef capture,
    AudioStreamID *streamID,
    AudioStreamBasicDescription *format
);
double fv_core_audio_capture_sample_rate(FVCoreAudioCaptureRef capture);
uint32_t fv_core_audio_capture_buffer_frame_size(FVCoreAudioCaptureRef capture);
uint64_t fv_core_audio_capture_dropped_packet_count(FVCoreAudioCaptureRef capture);

typedef void *FVCoreAudioListenerRef;

/// Registers `listener` for one property and keeps the exact block Core Audio was given, so
/// fv_core_audio_listener_remove can take it off again. Swift cannot do this itself: it imports
/// AudioObjectPropertyListenerBlock as a Swift closure and bridges it to a new block on every
/// call, so AudioObjectRemovePropertyListenerBlock called from Swift never matches what was
/// added. It returns noErr and the listener keeps firing (found 2026-11-19).
int32_t fv_core_audio_listener_add(
    AudioObjectID objectID,
    const AudioObjectPropertyAddress *address,
    dispatch_queue_t queue,
    AudioObjectPropertyListenerBlock listener,
    FVCoreAudioListenerRef *outListener
);

/// Removes the listener and frees the handle, which must not be used again.
int32_t fv_core_audio_listener_remove(FVCoreAudioListenerRef listener);

/// Frees the handle and leaves the registration alone: for a listener Core Audio already
/// dropped (its service restarted), or one that should outlive its owner.
void fv_core_audio_listener_discard(FVCoreAudioListenerRef listener);

#ifdef __cplusplus
}
#endif

#endif
