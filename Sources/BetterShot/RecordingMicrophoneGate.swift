//
//  RecordingMicrophoneGate.swift
//  BetterShot
//
//  Mutes narration without leaving a hole in the recording: while muted, the
//  microphone track keeps running on silence, so it stays in sync and the
//  encoder never sees a gap.
//

@preconcurrency import CoreMedia
import Foundation

/// Read on ScreenCaptureKit's audio queue and written from the main actor, so
/// the audio callback never has to hop actors per buffer.
nonisolated final class RecordingMicrophoneGate: @unchecked Sendable {
    private let lock = NSLock()
    private var muted = false

    var isMuted: Bool {
        get { lock.withLock { muted } }
        set { lock.withLock { muted = newValue } }
    }

    /// Whether this sample may reach the recording. It's silenced in place
    /// while muted, and refused if that fails: what was said while the bar
    /// shows the mic as muted must never end up in the file.
    func admit(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard isMuted else { return true }
        return Self.silence(sampleBuffer)
    }

    private static func silence(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return false }
        return CMBlockBufferFillDataBytes(
            with: 0,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: CMBlockBufferGetDataLength(blockBuffer)
        ) == noErr
    }
}
