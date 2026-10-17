import SwiftUI
import AVFoundation
import FoldKit
import FoldL10n
import TestsKit

/// T9: the volume buttons are detected through the system volume; the side button, Action
/// button and Camera Control can't be observed by apps, so the user checks them off.
struct ButtonsTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var session = ButtonsTestSession()
    @State private var watcher = VolumeWatcher()
    @State private var order: [ButtonsTestSession.VolumeDirection] = []
    @State private var phase: Phase = .starting
    @State private var answers: [PhysicalButton: ButtonAnswer] = [:]

    private enum Phase: Equatable {
        case starting
        case volume(Int)
        case checklist
    }

    var body: some View {
        Group {
            switch phase {
            case .starting:
                TestStepScreen(systemImage: "plusminus", title: L10nKey.testButtons.text(in: language), onCancel: cancel) {
                    ProgressView()
                } actions: {
                    EmptyView()
                }
            case .volume(let index):
                let direction = order[index]
                TestStepScreen(
                    step: (index + 1, order.count + 1),
                    systemImage: direction == .up ? "speaker.plus.fill" : "speaker.minus.fill",
                    title: direction == .up ? L10nKey.buttonsPressUp.text(in: language) : L10nKey.buttonsPressDown.text(in: language),
                    message: L10nKey.buttonsVolumeHint.text(in: language),
                    onCancel: cancel
                ) {
                    EmptyView()
                } actions: {
                    StepButton(title: L10nKey.buttonsNotWorking.text(in: language), prominent: false) {
                        record(false, for: direction)
                    }
                    .accessibilityIdentifier("buttons.volumeNotWorking")
                }
            case .checklist:
                TestStepScreen(
                    step: (order.count + 1, order.count + 1),
                    systemImage: "checklist",
                    title: L10nKey.buttonsChecklistTitle.text(in: language),
                    message: L10nKey.buttonsChecklistMessage.text(in: language),
                    onCancel: cancel
                ) {
                    VStack(spacing: 16) {
                        ForEach(PhysicalButton.allCases, id: \.self) { button in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(button.localizedName(in: language))
                                    .font(.headline)
                                Picker(button.localizedName(in: language), selection: answerBinding(for: button)) {
                                    Text(L10nKey.buttonsWorks.text(in: language)).tag(ButtonAnswer?.some(.works))
                                    Text(L10nKey.buttonsDoesNotWork.text(in: language)).tag(ButtonAnswer?.some(.doesNotWork))
                                    Text(L10nKey.buttonsNotOnThisPhone.text(in: language)).tag(ButtonAnswer?.some(.notOnThisPhone))
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("buttons.answer.\(button.rawValue)")
                            }
                        }
                    }
                } actions: {
                    StepButton(title: L10nKey.testFinish.text(in: language)) { finish() }
                        .disabled(answers.count < PhysicalButton.allCases.count)
                        .accessibilityIdentifier("buttons.finish")
                }
            }
        }
        .task {
            let start = watcher.start()
            order = ButtonsTestSession.order(startingVolume: start)
            phase = .volume(0)
        }
        .onChange(of: watcher.volume) { old, new in
            guard case .volume(let index) = phase,
                  ButtonsTestSession.direction(from: old, to: new) == order[index] else { return }
            record(true, for: order[index])
        }
        .onDisappear { watcher.stop() }
    }

    private func answerBinding(for button: PhysicalButton) -> Binding<ButtonAnswer?> {
        Binding(get: { answers[button] }, set: { answers[button] = $0 })
    }

    private func record(_ detected: Bool, for direction: ButtonsTestSession.VolumeDirection) {
        guard case .volume(let index) = phase else { return }
        session.record(detected, for: direction)
        if index + 1 < order.count {
            phase = .volume(index + 1)
        } else {
            watcher.stop()
            phase = .checklist
        }
    }

    private func finish() {
        session.checklist = answers
        var lines: [String] = []
        let missed = [
            session.volumeUpDetected == false ? L10nKey.buttonsVolumeUp.text(in: language) : nil,
            session.volumeDownDetected == false ? L10nKey.buttonsVolumeDown.text(in: language) : nil,
        ].compactMap { $0 }
        if !missed.isEmpty { lines.append(L10nKey.buttonsNoteNotDetected.text(in: language, missed.listed(in: language))) }
        let broken = PhysicalButton.allCases.filter { answers[$0] == .doesNotWork }.map { $0.localizedName(in: language) }
        if !broken.isEmpty { lines.append(L10nKey.buttonsNoteBroken.text(in: language, broken.listed(in: language))) }
        onFinish(session.result(notes: lines.joined(separator: "\n")))
    }

    private func cancel() {
        watcher.stop()
        onCancel()
    }
}

extension PhysicalButton {
    func localizedName(in language: AppLanguage) -> String {
        switch self {
        case .side: return L10nKey.buttonsSide.text(in: language)
        case .action: return L10nKey.buttonsAction.text(in: language)
        case .cameraControl: return L10nKey.buttonsCameraControl.text(in: language)
        }
    }
}

// MARK: - Volume

/// Publishes the system output volume while the test runs. The audio session has to be
/// active for `outputVolume` to update; `.ambient` keeps other audio playing.
@MainActor
@Observable
final class VolumeWatcher {
    private(set) var volume = 0.0
    private var observation: NSKeyValueObservation?

    /// Starts watching and returns the current volume.
    func start() -> Double {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        volume = Double(session.outputVolume)
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let new = change.newValue else { return }
            Task { @MainActor in self?.volume = Double(new) }
        }
        return volume
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
