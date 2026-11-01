import CoreMedia
import Foundation

/// A mute that leaks is worse than no mute, so the check pins all three
/// outcomes: live audio is untouched, muted audio is zeroed in place, and a
/// sample that can't be zeroed never gets through.
@main @MainActor
enum RecordingMicrophoneGateCheck {
    static func main() {
        checkLiveAudioIsUntouched()
        checkMutedAudioIsSilenced()
        checkUnmuteRestoresAudio()
        checkUnsilenceableSampleIsRefused()
        print("microphone gate: 4 groups checked")
    }

    private static func checkLiveAudioIsUntouched() {
        let gate = RecordingMicrophoneGate()
        let sample = makeSample(byte: 0x7F)
        precondition(gate.admit(sample))
        precondition(bytes(of: sample).allSatisfy { $0 == 0x7F })
    }

    private static func checkMutedAudioIsSilenced() {
        let gate = RecordingMicrophoneGate()
        gate.isMuted = true
        let sample = makeSample(byte: 0x7F)
        precondition(gate.admit(sample))
        precondition(bytes(of: sample).allSatisfy { $0 == 0 })
        // Same length and timing: the track keeps running through the mute.
        precondition(CMSampleBufferGetNumSamples(sample) == frameCount)
    }

    private static func checkUnmuteRestoresAudio() {
        let gate = RecordingMicrophoneGate()
        gate.isMuted = true
        gate.isMuted = false
        let sample = makeSample(byte: 0x7F)
        precondition(gate.admit(sample))
        precondition(bytes(of: sample).allSatisfy { $0 == 0x7F })
    }

    private static func checkUnsilenceableSampleIsRefused() {
        let gate = RecordingMicrophoneGate()
        var sample: CMSampleBuffer?
        let status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil, formatDescription: nil,
            sampleCount: 0, sampleTimingEntryCount: 0, sampleTimingArray: nil,
            sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sample
        )
        precondition(status == noErr)
        precondition(gate.admit(sample!))
        gate.isMuted = true
        precondition(!gate.admit(sample!))
    }

    private static let frameCount = 480

    private static func makeSample(byte: UInt8) -> CMSampleBuffer {
        var description = AudioStreamBasicDescription(
            mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
            mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0
        )
        var format: CMAudioFormatDescription?
        precondition(CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &description, layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &format
        ) == noErr)

        let length = frameCount * 2
        var block: CMBlockBuffer?
        precondition(CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: length,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil, offsetToData: 0,
            dataLength: length, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block
        ) == noErr)
        precondition(CMBlockBufferFillDataBytes(
            with: CChar(bitPattern: byte), blockBuffer: block!, offsetIntoDestination: 0, dataLength: length
        ) == noErr)

        var sample: CMSampleBuffer?
        precondition(CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault, dataBuffer: block!, formatDescription: format!,
            sampleCount: frameCount, presentationTimeStamp: .zero, packetDescriptions: nil,
            sampleBufferOut: &sample
        ) == noErr)
        return sample!
    }

    private static func bytes(of sample: CMSampleBuffer) -> [UInt8] {
        let block = CMSampleBufferGetDataBuffer(sample)!
        var bytes = [UInt8](repeating: 0xFF, count: CMBlockBufferGetDataLength(block))
        precondition(CMBlockBufferCopyDataBytes(
            block, atOffset: 0, dataLength: bytes.count, destination: &bytes
        ) == noErr)
        return bytes
    }
}
