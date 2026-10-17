import Foundation

/// Which speaker channel a test tone plays in.
public enum AudioChannel: String, Codable, Sendable, CaseIterable, Equatable {
    case left, right
}

/// Builds the T6 test tones as in-memory WAV files, so no audio assets ship with the app.
public enum ToneGenerator {
    /// A 16-bit stereo PCM WAV with a sine tone in one channel and silence in the other.
    /// Short fades at both ends avoid clicks.
    public static func wav(
        channel: AudioChannel,
        frequency: Double = 1_000,
        duration: Double = 1.0,
        sampleRate: Int = 44_100,
        amplitude: Double = 0.5
    ) -> Data {
        let frames = max(1, Int(duration * Double(sampleRate)))
        let fadeFrames = min(frames / 2, sampleRate / 50)
        var pcm = Data(capacity: frames * 4)
        for i in 0..<frames {
            var gain = amplitude
            if i < fadeFrames { gain *= Double(i) / Double(fadeFrames) }
            if i >= frames - fadeFrames { gain *= Double(frames - 1 - i) / Double(fadeFrames) }
            let sample = Int16((sin(2 * .pi * frequency * Double(i) / Double(sampleRate)) * gain * Double(Int16.max)).rounded())
            let left: Int16 = channel == .left ? sample : 0
            let right: Int16 = channel == .right ? sample : 0
            pcm.append(littleEndian: left)
            pcm.append(littleEndian: right)
        }

        var wav = Data()
        wav.append(contentsOf: Array("RIFF".utf8))
        wav.append(littleEndian: UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVEfmt ".utf8))
        wav.append(littleEndian: UInt32(16))                // fmt chunk size
        wav.append(littleEndian: UInt16(1))                 // PCM
        wav.append(littleEndian: UInt16(2))                 // channels
        wav.append(littleEndian: UInt32(sampleRate))
        wav.append(littleEndian: UInt32(sampleRate * 4))    // byte rate
        wav.append(littleEndian: UInt16(4))                 // block align
        wav.append(littleEndian: UInt16(16))                // bits per sample
        wav.append(contentsOf: Array("data".utf8))
        wav.append(littleEndian: UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

/// Answers and measurements from one audio test run (T6). `nil` means the step wasn't reached.
public struct AudioTestSession: Sendable, Equatable {
    /// A recording whose loudest moment stays below this is too quiet to tell the mic works.
    public static let quietMicThresholdDB = -50.0

    public var leftHeard: Bool?
    public var rightHeard: Bool?
    /// Loudest level during the recording, in dBFS (0 is full scale).
    public var micPeakDB: Double?
    public var playbackHeard: Bool?
    /// nil for older runs; false when the system could not route to builtInReceiver.
    public var receiverAvailable: Bool?
    public var receiverHeard: Bool?
    /// The audio system failed to play or record (not a user answer).
    public var hardwareError = false

    public init() {}

    /// Every step confirmed and the mic loud enough is Pass. A speaker or playback the user
    /// didn't hear, or a very quiet mic, is Attention: these are observations that a muted
    /// ringer or a noisy room can also explain. Only an audio system error is Fail.
    public var outcome: TestOutcome {
        if hardwareError { return .fail }
        let heard = [leftHeard, rightHeard, playbackHeard].map { $0 == true }
        let micLoudEnough = (micPeakDB ?? -.infinity) >= Self.quietMicThresholdDB
        let receiverOK = receiverAvailable != true || receiverHeard == true
        return heard.allSatisfy { $0 } && micLoudEnough && receiverOK ? .pass : .attention
    }

    public func result(notes: String = "", finishedAt: Date = .now) -> TestResult {
        var metrics: [String: Double] = [:]
        if let leftHeard { metrics[TestMetricKey.speakerLeftConfirmed] = leftHeard ? 1 : 0 }
        if let rightHeard { metrics[TestMetricKey.speakerRightConfirmed] = rightHeard ? 1 : 0 }
        if let micPeakDB { metrics[TestMetricKey.micPeakLevel] = micPeakDB }
        if let playbackHeard { metrics[TestMetricKey.micPlaybackConfirmed] = playbackHeard ? 1 : 0 }
        if let receiverAvailable { metrics[TestMetricKey.receiverAvailable] = receiverAvailable ? 1 : 0 }
        if receiverAvailable == true, let receiverHeard { metrics[TestMetricKey.receiverConfirmed] = receiverHeard ? 1 : 0 }
        return TestResult(id: .audio, outcome: outcome, metrics: metrics, notes: notes, finishedAt: finishedAt)
    }
}
