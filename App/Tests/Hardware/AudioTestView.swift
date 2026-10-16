import SwiftUI
import AVFoundation
import FoldKit
import FoldL10n
import TestsKit

/// T6: a tone in the left channel, then the right, each confirmed by the user; then a 3 s
/// recording with a level meter, played back and confirmed. The recording is a temporary
/// file deleted when the test ends. Microphone access off makes the test Skipped (AC6).
struct AudioTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var audio = AudioTestController()
    @State private var session = AudioTestSession()
    @State private var phase: Phase = .starting

    private enum Phase: Equatable {
        case starting
        case denied
        case tone(AudioChannel, played: Bool)
        case record
        case recording
        case playback(played: Bool)
    }

    private static let totalSteps = 3

    var body: some View {
        Group {
            switch phase {
            case .starting:
                TestStepScreen(systemImage: "speaker.wave.3.fill", title: L10nKey.testAudio.text(in: language), onCancel: cancel) {
                    ProgressView()
                } actions: {
                    EmptyView()
                }
            case .denied:
                PermissionDeniedScreen(
                    systemImage: "mic.slash.fill",
                    reason: L10nKey.audioMicDenied.text(in: language),
                    onSkip: {
                        onFinish(TestResult(id: .audio, outcome: .skipped, notes: L10nKey.audioMicDenied.text(in: language)))
                    },
                    onCancel: cancel
                )
            case .tone(let channel, let played):
                TestStepScreen(
                    step: (channel == .left ? 1 : 2, Self.totalSteps),
                    systemImage: "speaker.wave.3.fill",
                    title: channel == .left ? L10nKey.audioChannelLeft.text(in: language) : L10nKey.audioChannelRight.text(in: language),
                    message: played ? L10nKey.audioHeardQuestion.text(in: language) : L10nKey.audioToneInstruction.text(in: language),
                    onCancel: cancel
                ) {
                    EmptyView()
                } actions: {
                    StepButton(
                        title: played ? L10nKey.audioPlayAgain.text(in: language) : L10nKey.audioPlayTone.text(in: language),
                        prominent: !played
                    ) {
                        playTone(channel)
                    }
                    .accessibilityIdentifier("audio.playTone")
                    if played {
                        YesNoButtons(identifier: "audio.heard") { heard in
                            answerTone(channel, heard: heard)
                        }
                    }
                }
            case .record, .recording:
                TestStepScreen(
                    step: (3, Self.totalSteps),
                    systemImage: "mic.fill",
                    title: L10nKey.audioMicTitle.text(in: language),
                    message: L10nKey.audioMicInstruction.text(in: language),
                    onCancel: cancel
                ) {
                    LevelMeter(level: audio.level)
                        .frame(height: 12)
                        .padding(.horizontal)
                        .accessibilityIdentifier("audio.level")
                } actions: {
                    StepButton(
                        title: phase == .recording
                            ? L10nKey.audioRecording.text(in: language)
                            : L10nKey.audioRecord.text(in: language)
                    ) {
                        Task { await record() }
                    }
                    .disabled(phase == .recording)
                    .accessibilityIdentifier("audio.record")
                }
            case .playback(let played):
                TestStepScreen(
                    step: (3, Self.totalSteps),
                    systemImage: "waveform",
                    title: L10nKey.audioMicTitle.text(in: language),
                    message: played ? L10nKey.audioPlaybackQuestion.text(in: language) : L10nKey.audioPlaybackInstruction.text(in: language),
                    onCancel: cancel
                ) {
                    EmptyView()
                } actions: {
                    StepButton(title: L10nKey.audioPlayRecording.text(in: language), prominent: !played) {
                        playRecording()
                    }
                    .accessibilityIdentifier("audio.playRecording")
                    if played {
                        YesNoButtons(identifier: "audio.playback") { heard in
                            session.playbackHeard = heard
                            finish()
                        }
                    }
                }
            }
        }
        .task { await begin() }
        .onDisappear { audio.tearDown() }
    }

    private func begin() async {
        guard await AudioTestController.requestMicrophoneAccess() else {
            phase = .denied
            return
        }
        guard audio.activate() else {
            fail()
            return
        }
        phase = .tone(.left, played: false)
    }

    private func playTone(_ channel: AudioChannel) {
        guard audio.playTone(channel) else {
            fail()
            return
        }
        phase = .tone(channel, played: true)
    }

    private func answerTone(_ channel: AudioChannel, heard: Bool) {
        switch channel {
        case .left:
            session.leftHeard = heard
            phase = .tone(.right, played: false)
        case .right:
            session.rightHeard = heard
            phase = .record
        }
    }

    private func record() async {
        phase = .recording
        guard let peak = await audio.record(seconds: 3) else {
            fail()
            return
        }
        session.micPeakDB = peak
        phase = .playback(played: false)
    }

    private func playRecording() {
        guard audio.playRecording() else {
            fail()
            return
        }
        phase = .playback(played: true)
    }

    private func fail() {
        session.hardwareError = true
        finish(extraNote: L10nKey.audioError.text(in: language))
    }

    private func finish(extraNote: String? = nil) {
        audio.tearDown()
        var lines: [String] = []
        let notHeard = [
            session.leftHeard == false ? L10nKey.audioChannelLeft.text(in: language) : nil,
            session.rightHeard == false ? L10nKey.audioChannelRight.text(in: language) : nil,
            session.playbackHeard == false ? L10nKey.audioMicTitle.text(in: language) : nil,
        ].compactMap { $0 }
        if !notHeard.isEmpty {
            lines.append(L10nKey.audioNoteNotHeard.text(in: language, notHeard.listed(in: language)))
        }
        if let peak = session.micPeakDB, peak < AudioTestSession.quietMicThresholdDB {
            lines.append(L10nKey.audioNoteQuiet.text(in: language, Int(peak.rounded())))
        }
        if let extraNote { lines.append(extraNote) }
        onFinish(session.result(notes: lines.joined(separator: "\n")))
    }

    private func cancel() {
        audio.tearDown()
        onCancel()
    }
}

/// Horizontal bar for the microphone level, 0…1.
private struct LevelMeter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let level: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(.green)
                    .frame(width: geometry.size.width * min(max(level, 0), 1))
                    .animation(reduceMotion ? nil : .linear(duration: 0.05), value: level)
            }
        }
    }
}

// MARK: - Audio access

/// Plays the test tones and records and plays back the microphone test, on the main actor.
@MainActor
@Observable
final class AudioTestController {
    /// Live microphone level for the meter, 0…1 (−60 dBFS … 0 dBFS).
    private(set) var level = 0.0

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private let recordingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("foldcheck-mic-test.m4a")

    static func requestMicrophoneAccess() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .undetermined: return await AVAudioApplication.requestRecordPermission()
        default: return false
        }
    }

    /// Speaker output and microphone input, with sound from the loudspeaker (not the earpiece).
    func activate() -> Bool {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
    }

    func playTone(_ channel: AudioChannel) -> Bool {
        guard let player = try? AVAudioPlayer(data: ToneGenerator.wav(channel: channel)) else { return false }
        self.player = player
        return player.play()
    }

    /// Records for `seconds`, updating `level`. Returns the peak level in dBFS, or nil on error.
    func record(seconds: Double) async -> Double? {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
        ]
        guard let recorder = try? AVAudioRecorder(url: recordingURL, settings: settings) else { return nil }
        recorder.isMeteringEnabled = true
        self.recorder = recorder
        guard recorder.record(forDuration: seconds) else { return nil }

        var peak = -160.0
        let end = Date.now.addingTimeInterval(seconds)
        while Date.now < end {
            try? await Task.sleep(for: .milliseconds(50))
            recorder.updateMeters()
            let power = Double(recorder.peakPower(forChannel: 0))
            peak = max(peak, power)
            level = (power + 60) / 60
        }
        recorder.stop()
        level = 0
        return peak
    }

    func playRecording() -> Bool {
        guard let player = try? AVAudioPlayer(contentsOf: recordingURL) else { return false }
        self.player = player
        return player.play()
    }

    /// Stops everything, deletes the recording, and hands the audio session back.
    func tearDown() {
        player?.stop()
        recorder?.stop()
        player = nil
        recorder = nil
        try? FileManager.default.removeItem(at: recordingURL)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
