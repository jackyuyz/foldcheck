import SwiftUI
import FoldKit
import FoldL10n
import TestsKit

/// T4: "close slowly to ~20°, then open to flat" twice, then hold at ~90° for 5 s.
/// Readings come from the fold state provider; the slider is the non-hinge alternative and
/// feeds the same analysis. Absolute angles are shown but never judged.
struct HingeSweepTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.foldStateProvider) private var provider
    @Environment(\.appLanguage) private var language
    @State private var session = HingeSweepSession()
    @State private var foldState: FoldState
    @State private var isRecordingSweep = false
    @State private var holdEndsAt: Date?
    @State private var manualAngle: Double = 90
    @State private var stepStartedAt = Date()
    @State private var showUnavailable = false

    init(initialFoldState: FoldState, onFinish: @escaping (TestResult) -> Void, onCancel: @escaping () -> Void) {
        self.initialFoldState = initialFoldState
        self.onFinish = onFinish
        self.onCancel = onCancel
        _foldState = State(initialValue: initialFoldState)
        _manualAngle = State(initialValue: initialFoldState.angleDegrees.map { min(max($0, 0), 180) } ?? 90)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            content(now: context.date)
        }
        .overlay {
            if showUnavailable {
                unavailableCard
            }
        }
        .task {
            await beginCurrentStep()
        }
        .task {
            // Record every reading as it arrives (not via onChange, which can coalesce updates).
            for await state in provider.states() {
                foldState = state
                if isRecording(at: .now) {
                    session.record(state, at: .now)
                }
            }
        }
    }

    private func isRecording(at time: Date) -> Bool {
        if session.currentStep.isSweep { return isRecordingSweep }
        guard let holdEndsAt else { return false }
        return time < holdEndsAt
    }

    // MARK: Layout

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: cancel) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .frame(width: 36, height: 36)
                        .background(.quaternary, in: Circle())
                }
                .accessibilityLabel(Text(verbatim: "Cancel"))
                .accessibilityIdentifier("test.cancel")
                Spacer()
                Text(stepTitle.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(Color(red: 0.055, green: 0.478, blue: 0.271))
                    .accessibilityIdentifier("hinge.step")
            }

            Text(instruction)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(angleText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityIdentifier("hinge.angle")
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10nKey.hingeReadings.text(in: language, session.currentSamples.count))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("hinge.readings")
                    if let speed = session.speed() {
                        Text(verbatim: "\(Int(speed.rounded()))°/s")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(session.isTooFast ? .orange : .secondary)
                    }
                }
            }

            if session.isTooFast {
                Label(L10nKey.hingeTooFast.text(in: language), systemImage: "tortoise.fill")
                    .font(.callout.bold())
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("hinge.tooFast")
            }

            HingeSweepChart(points: session.series)
                .frame(height: 170)

            if !session.receivedHingeReading && !session.usedManualInput && now.timeIntervalSince(stepStartedAt) > 2 {
                Text(L10nKey.hingeNoReadings.text(in: language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("hinge.noReadings")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10nKey.hingeManual.text(in: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $manualAngle, in: 0...180, step: 1) {
                    Text(L10nKey.hingeManual.text(in: language))
                } minimumValueLabel: {
                    Text(verbatim: "0°")
                } maximumValueLabel: {
                    Text(verbatim: "180°")
                }
                .accessibilityIdentifier("hinge.manual")
                .onChange(of: manualAngle) { _, angle in
                    if isRecording(at: .now) {
                        session.recordManual(degrees: angle, at: .now)
                    }
                }
            }

            Spacer(minLength: 0)

            bottomButton(now: now)
        }
        .padding()
    }

    @ViewBuilder
    private func bottomButton(now: Date) -> some View {
        if session.currentStep.isSweep {
            primaryButton(L10nKey.testNext.text(in: language), identifier: "hinge.next") {
                nextStep()
            }
        } else if let holdEndsAt {
            let remaining = max(0, Int(holdEndsAt.timeIntervalSince(now).rounded(.up)))
            Text(L10nKey.hingeHoldRemaining.text(in: language, remaining))
                .font(.headline.monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("hinge.holdRemaining")
        } else {
            primaryButton(L10nKey.hingeHoldStart.text(in: language), identifier: "hinge.holdStart") {
                startHold()
            }
        }
    }

    private func primaryButton(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier(identifier)
    }

    private var unavailableCard: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(L10nKey.hingeUnavailableTitle.text(in: language))
                    .font(.headline)
                    .accessibilityIdentifier("hinge.unavailableTitle")
                Text(L10nKey.hingeUnavailableMessage.text(in: language))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button {
                    retry()
                } label: {
                    Text(L10nKey.hingeRetry.text(in: language)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("hinge.retry")
                Button {
                    showUnavailable = false
                    deliver()
                } label: {
                    Text(L10nKey.hingeFinishAnyway.text(in: language)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("hinge.finishAnyway")
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
    }

    private var stepTitle: String {
        switch session.currentStep {
        case .sweep1: return L10nKey.hingeSweepStep.text(in: language, 1, 2)
        case .sweep2: return L10nKey.hingeSweepStep.text(in: language, 2, 2)
        case .hold: return L10nKey.hingeHoldStep.text(in: language)
        }
    }

    private var instruction: String {
        session.currentStep.isSweep
            ? L10nKey.hingeSweepInstruction.text(in: language)
            : L10nKey.hingeHoldInstruction.text(in: language)
    }

    private var angleText: String {
        guard let angle = foldState.angleDegrees, foldState.hasHinge else {
            return session.usedManualInput ? "\(Int(manualAngle))°" : L10nKey.hingeAngleUnknown.text(in: language)
        }
        return "\(Int(angle.rounded()))°"
    }

    // MARK: Flow

    /// Starts recording a sweep. In DEBUG with a `-FoldMock sweep:`/`script:` launch script,
    /// the mock replays it on cue, like a user moving the hinge when asked.
    private func beginCurrentStep() async {
        stepStartedAt = .now
        guard session.currentStep.isSweep else { return }
        #if DEBUG
        if let mock = provider as? MockFoldStateProvider, await mock.rewindLaunchScript() {
            foldState = mock.state
            session.beginStep(at: .now, current: mock.state)
            isRecordingSweep = true
            Task { await mock.replayLaunchScript() }
            return
        }
        #endif
        session.beginStep(at: .now, current: foldState)
        isRecordingSweep = true
    }

    private func nextStep() {
        isRecordingSweep = false
        session.advance()
        Task { await beginCurrentStep() }
    }

    private func startHold() {
        let start = Date.now
        stepStartedAt = start
        session.beginStep(at: start, current: foldState)
        holdEndsAt = start.addingTimeInterval(HingeSweepSession.holdDuration)
        Task {
            try? await Task.sleep(for: .seconds(HingeSweepSession.holdDuration))
            guard holdEndsAt != nil else { return }
            // Close the hold window with the reading at its end (the hinge may not have moved).
            session.record(foldState, at: .now)
            holdEndsAt = nil
            session.advance()
            if session.outcome == .unavailable {
                showUnavailable = true
            } else {
                deliver()
            }
        }
    }

    private func retry() {
        showUnavailable = false
        holdEndsAt = nil
        session.restart()
        Task { await beginCurrentStep() }
    }

    private func cancel() {
        holdEndsAt = nil
        isRecordingSweep = false
        onCancel()
    }

    private func deliver() {
        var notes: [String] = []
        if session.usedManualInput {
            notes.append(L10nKey.hingeManualNote.text(in: language))
        }
        if session.report.sampleCount > 0 {
            notes.append(L10nKey.hingeRangeNote.text(in: language))
        }
        onFinish(session.result(display: DisplayKind(posture: foldState.posture), notes: notes.joined(separator: "\n")))
    }
}
