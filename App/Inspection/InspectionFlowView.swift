import SwiftUI
import FoldKit
import FoldL10n
import TestsKit
import Library

/// What to run: the full inspection or a single quick test, with the device context at launch.
struct InspectionRequest: Identifiable {
    let id = UUID()
    var tests: [TestID]
    var context: DeviceContext

    /// The full inspection (every test), as opposed to a quick single test.
    var isFullInspection: Bool { tests == TestID.defaultOrder }

    @MainActor
    static func current(tests: [TestID] = TestID.defaultOrder, foldState: FoldState) -> InspectionRequest {
        InspectionRequest(tests: tests, context: DeviceInfo.context(foldState: foldState))
    }
}

struct InspectionFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @Environment(\.modelContext) private var modelContext

    @State private var session: InspectionSession
    @State private var currentTestIndex = 0
    @State private var isCompleted = false
    /// True while a test canvas is on screen: chrome is hidden so the canvas is full-bleed.
    @State private var isRunningTest = false

    private let plan: InspectionPlan
    private let isFullInspection: Bool
    private let onFinished: (InspectionSession) -> Void

    init(request: InspectionRequest, onFinished: @escaping (InspectionSession) -> Void = { _ in }) {
        let context = request.context
        plan = InspectionPlan(tests: request.tests, context: context, implemented: InspectionTestRegistry.implemented)
        isFullInspection = request.isFullInspection
        self.onFinished = onFinished
        _session = State(initialValue: InspectionSession(
            deviceModel: DeviceInfo.displayName,
            osVersion: context.osVersion,
            hasHinge: context.hasHinge
        ))
        _isCompleted = State(initialValue: plan.runnable.isEmpty)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !plan.runnable.isEmpty && !isRunningTest {
                    progressHeader
                }

                if isCompleted {
                    InspectionSummaryView(session: session, isFullInspection: isFullInspection)
                } else if currentTestIndex < plan.runnable.count {
                    testView(for: plan.runnable[currentTestIndex])
                        .id(plan.runnable[currentTestIndex])
                }
            }
            .navigationTitle(L10nKey.inspectionTitle.text(in: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isRunningTest ? .hidden : .visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isCompleted ? L10nKey.testDone.text(in: language) : L10nKey.inspectionCancel.text(in: language)) {
                        dismiss()
                    }
                    .accessibilityIdentifier("inspection.close")
                }
            }
            .onAppear {
                if isCompleted { finalize() }
            }
        }
        .environment(\.inspectionHasHinge, session.hasHinge)
        .foldDebugOverlay()
    }

    private var progressHeader: some View {
        let total = plan.runnable.count
        let step = min(currentTestIndex + 1, total)
        return VStack(spacing: 8) {
            ProgressView(
                value: Double(isCompleted ? total : currentTestIndex),
                total: Double(total)
            )
            .tint(.green)

            HStack {
                Text(L10nKey.inspectionProgress.text(in: language, step, total))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if !isCompleted && currentTestIndex < total {
                    Text(plan.runnable[currentTestIndex].localizedName(in: language, hasHinge: session.hasHinge))
                        .font(.caption.bold())
                }
            }
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private func testView(for testID: TestID) -> some View {
        TestContainerView(
            testID: testID,
            isRunning: $isRunningTest,
            onComplete: { result in
                session.setResult(result)
                advanceToNextTest()
            },
            onSkip: {
                session.setResult(.skipped(id: testID))
                advanceToNextTest()
            }
        )
    }

    private func advanceToNextTest() {
        if currentTestIndex + 1 < plan.runnable.count {
            withAnimation {
                currentTestIndex += 1
            }
        } else {
            finalize()
            withAnimation {
                isCompleted = true
            }
        }
    }

    /// Records tests that were not run, puts results in inspection order, and stamps completion.
    private func finalize() {
        guard session.completedAt == nil else { return }
        for test in plan.notApplicable {
            session.setResult(.notApplicable(id: test, reason: L10nKey.testNotApplicable.text(in: language)))
        }
        for test in plan.unavailable {
            session.setResult(.skipped(id: test, reason: L10nKey.testNotImplemented.text(in: language)))
        }
        let order = TestID.defaultOrder
        session.results.sort { (order.firstIndex(of: $0.id) ?? 0) < (order.firstIndex(of: $1.id) ?? 0) }
        session.completedAt = Date()
        // Full inspections go to History on their own; quick tests wait for "Save to History".
        // The summary's button shows "Saved" either way, and saving again only updates the copy.
        if isFullInspection {
            try? SessionLibrary(context: modelContext).save(session, isFullInspection: true)
        }
        onFinished(session)
    }
}

// MARK: - Test Container View

/// S2 → S3 → S4 for one test: intro with fold prompt, the full-screen test, then the result.
/// The test canvas renders inline (the flow is already a full-screen cover) rather than in a
/// nested presentation: presenting anything from a nested cover recreated the test and lost its state.
struct TestContainerView: View {
    let testID: TestID
    @Binding var isRunning: Bool
    let onComplete: (TestResult) -> Void
    let onSkip: () -> Void
    @Environment(\.foldStateProvider) private var foldStateProvider
    @Environment(\.appLanguage) private var language
    @Environment(\.inspectionHasHinge) private var hasHinge
    @State private var foldState: FoldState = .noHinge
    @State private var pendingResult: TestResult?

    var body: some View {
        Group {
            if isRunning {
                runner
            } else if let pendingResult {
                TestResultReviewView(result: pendingResult, onContinue: onComplete)
            } else {
                intro
            }
        }
        .observeFoldState($foldState)
    }

    private var intro: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: iconName(for: testID))
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                Text(testID.localizedName(in: language, hasHinge: hasHinge))
                    .font(.title2.bold())

                Text(testID.localizedDescription(in: language, hasHinge: hasHinge))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let tip = tip {
                    Text(tip)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if let prompt = foldPrompt {
                    Label(prompt, systemImage: "iphone.gen3.motion")
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .accessibilityIdentifier("test.foldPrompt")
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isRunning = true
                } label: {
                    Text(L10nKey.inspectionStartTest.text(in: language))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .accessibilityIdentifier("test.start")

                Button {
                    onSkip()
                } label: {
                    Text(L10nKey.inspectionSkip.text(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("test.skip")
            }
            .padding()
        }
    }

    @ViewBuilder
    private var runner: some View {
        let finish: (TestResult) -> Void = { result in
            pendingResult = result
            isRunning = false
        }
        let cancel = { isRunning = false }
        switch testID {
        case .touchGridOuter, .touchGridInner:
            TouchGridTestView(
                testID: testID,
                // The dense crease band only exists on the Duo's inner display.
                includeCreaseBand: testID == .touchGridInner && foldState.hasHinge,
                initialFoldState: foldState,
                onFinish: finish,
                onCancel: cancel
            )
        case .pixels:
            PixelTestView(initialFoldState: foldState, onFinish: finish, onCancel: cancel)
        case .crease:
            CreaseTestView(initialFoldState: foldState, onFinish: finish, onCancel: cancel)
        case .hingeSweep:
            HingeSweepTestView(initialFoldState: foldState, onFinish: finish, onCancel: cancel)
        default:
            // Not reachable: the plan only steps through implemented tests.
            Color.clear.onAppear(perform: cancel)
        }
    }

    /// On a Duo, asks the user to fold or unfold when the test targets the other display.
    private var foldPrompt: String? {
        guard foldState.hasHinge, let target = testID.intendedDisplay else { return nil }
        let current = DisplayKind(posture: foldState.posture)
        guard current != target else { return nil }
        return target == .outer
            ? L10nKey.testFoldPromptClose.text(in: language)
            : L10nKey.testFoldPromptOpen.text(in: language)
    }

    private var tip: String? {
        switch testID {
        case .touchGridOuter, .touchGridInner: return L10nKey.touchInstructions.text(in: language)
        case .pixels: return L10nKey.pixelsInstructions.text(in: language) + "\n\n" + L10nKey.pixelsTip.text(in: language)
        default: return nil
        }
    }

    private func iconName(for testID: TestID) -> String {
        switch testID {
        case .touchGridOuter, .touchGridInner: return "hand.tap.fill"
        case .pixels: return "rectangle.grid.3x2.fill"
        case .crease: return "line.diagonal"
        case .hingeSweep: return "arrow.triangle.2.circlepath"
        case .cameras: return "camera.fill"
        case .audio: return "speaker.wave.3.fill"
        case .touchID: return "touchid"
        case .sensors: return "gyroscope"
        case .buttons: return "plus.minus"
        }
    }
}

// MARK: - Preview

#Preview {
    InspectionFlowView(request: InspectionRequest(tests: TestID.defaultOrder, context: .mock(hasHinge: true)))
}
