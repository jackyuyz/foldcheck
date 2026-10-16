import SwiftUI
import UIKit
import FoldKit
import FoldL10n
import TestsKit

/// T1: full-bleed touch grid. The user swipes until every cell is filled; on the Duo's inner
/// display the cells within ±10 mm of the crease are half size. Then a multi-touch count step.
struct TouchGridTestView: View {
    let testID: TestID
    let includeCreaseBand: Bool
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @Environment(\.inspectionHasHinge) private var hasHinge
    @State private var session: TouchGridSession?
    @State private var foldState: FoldState
    @State private var display: DisplayKind?
    @State private var phase: Phase = .grid
    @State private var showMisses = false
    @State private var showMissDialog = false
    @State private var missReason: TouchGridMissReason?
    @State private var currentTouches = 0
    @State private var canvasSize: CGSize = .zero

    enum Phase {
        case grid
        case multiTouch
    }

    init(
        testID: TestID,
        includeCreaseBand: Bool,
        initialFoldState: FoldState,
        onFinish: @escaping (TestResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.testID = testID
        self.includeCreaseBand = includeCreaseBand
        self.initialFoldState = initialFoldState
        self.onFinish = onFinish
        self.onCancel = onCancel
        _foldState = State(initialValue: initialFoldState)
        _display = State(initialValue: DisplayKind(posture: initialFoldState.posture))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black

                switch phase {
                case .grid:
                    gridLayer
                    gridControls
                case .multiTouch:
                    multiTouchLayer
                }
            }
            .onAppear { updateLayout(for: geometry.size) }
            .onChange(of: geometry.size) { _, size in updateLayout(for: size) }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .observeFoldState($foldState)
        .modifier(DisplayChangePause(foldState: foldState) { newDisplay in
            display = newDisplay
            session?.resetCoverage()
            showMisses = false
        })
        .onAppear { OrientationLock.lockCurrent() }
        .onDisappear { OrientationLock.unlock() }
        .overlay {
            if showMissDialog {
                missCard
            }
        }
    }

    /// Asked when Finish is tapped with cells still missed (shown in red behind the card).
    private var missCard: some View {
        VStack(spacing: 12) {
            Text(L10nKey.touchMissedTitle.text(in: language, count: session?.missedCount ?? 0, one: .touchMissedTitleOne))
                .font(.headline)
                .accessibilityIdentifier("touchGrid.missedTitle")
            Text(L10nKey.touchMissedMessage.text(in: language))
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button {
                choose(.blockedByCase)
            } label: {
                Text(L10nKey.touchBlockedByCase.text(in: language)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("touchGrid.blockedByCase")
            Button(role: .destructive) {
                choose(.unresponsive)
            } label: {
                Text(L10nKey.touchUnresponsive.text(in: language)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("touchGrid.unresponsive")
            Button {
                showMissDialog = false
            } label: {
                Text(L10nKey.touchKeepTrying.text(in: language)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("touchGrid.keepTrying")
        }
        .padding(20)
        .frame(maxWidth: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(24)
    }

    private func choose(_ reason: TouchGridMissReason) {
        missReason = reason
        showMissDialog = false
        phase = .multiTouch
    }

    // MARK: Grid

    private var gridLayer: some View {
        ZStack {
            Canvas { context, _ in
                guard let session else { return }
                for cell in session.layout.cells {
                    let inset: CGFloat = cell.isCreaseBand ? 1 : 1.5
                    let path = Path(roundedRect: cell.rect.insetBy(dx: inset, dy: inset), cornerRadius: cell.isCreaseBand ? 2 : 3)
                    context.fill(path, with: .color(color(for: cell, in: session)))
                }
            }
            TouchCaptureView(
                onStroke: { from, to in _ = session?.stroke(from: from, to: to) },
                onTouchCount: { count in
                    currentTouches = count
                    session?.recordSimultaneousTouches(count)
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(testID.localizedName(in: language, hasHinge: hasHinge)))
        .accessibilityValue(Text(accessibilityProgress))
        .accessibilityIdentifier("touchGrid.canvas")
    }

    private var gridControls: some View {
        FloatingTestBar(onCancel: onCancel) {
            VStack(alignment: .leading, spacing: 2) {
                Text(progressText)
                    .monospacedDigit()
                    .accessibilityIdentifier("touchGrid.progress")
                if includeCreaseBand {
                    Text(L10nKey.touchBandHint.text(in: language))
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.95, green: 0.7, blue: 0.3))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: 220, alignment: .leading)

            Button {
                finishGrid()
            } label: {
                Text(L10nKey.testFinish.text(in: language))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(session?.isComplete == true ? Color.green : Color.white.opacity(0.2), in: Capsule())
            }
            .accessibilityIdentifier("touchGrid.finish")
        }
    }

    private func color(for cell: TouchGridCell, in session: TouchGridSession) -> Color {
        if session.covered.contains(cell.id) {
            return Color(red: 0.055, green: 0.478, blue: 0.271)
        }
        if showMisses {
            return Color(red: 0.75, green: 0.12, blue: 0.12)
        }
        return cell.isCreaseBand
            ? Color(red: 0.77, green: 0.48, blue: 0.07)
            : Color(red: 0.165, green: 0.188, blue: 0.22)
    }

    private var progressText: String {
        guard let session else { return "" }
        return L10nKey.touchProgress.text(in: language, session.coveredCount, session.totalCount)
    }

    private var accessibilityProgress: String {
        guard let session else { return "" }
        var value = progressText
        if session.creaseBandTotal > 0 {
            value += ", \(L10nKey.metricCreaseBand.text(in: language)) \(session.creaseBandCovered)/\(session.creaseBandTotal)"
        }
        return value
    }

    private func updateLayout(for size: CGSize) {
        guard size.width > 0, size.height > 0, size != canvasSize else { return }
        canvasSize = size
        let layout = TouchGridLayout(size: size, spec: includeCreaseBand ? .duoInner : .standard, includeCreaseBand: includeCreaseBand)
        if session == nil {
            session = TouchGridSession(layout: layout)
        } else {
            session?.relayout(layout)
        }
    }

    private func finishGrid() {
        guard let session else { return }
        if session.isComplete {
            missReason = nil
            phase = .multiTouch
        } else {
            showMisses = true
            showMissDialog = true
        }
    }

    // MARK: Multi-touch

    private var multiTouchLayer: some View {
        ZStack {
            TouchCaptureView(
                onStroke: { _, _ in },
                onTouchCount: { count in
                    currentTouches = count
                    session?.recordSimultaneousTouches(count)
                }
            )
            VStack(spacing: 20) {
                Text(L10nKey.touchMultiTitle.text(in: language))
                    .font(.title2.bold())
                Text(L10nKey.touchMultiInstructions.text(in: language))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Text("\(currentTouches)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(L10nKey.touchMultiCount.text(in: language, currentTouches, session?.maxSimultaneousTouches ?? 0))
                    .font(.headline)
                    .monospacedDigit()
                    .accessibilityIdentifier("touchGrid.multiCount")
                Button {
                    finish()
                } label: {
                    Text(L10nKey.testDone.text(in: language))
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.green, in: Capsule())
                }
                .accessibilityIdentifier("touchGrid.multiDone")
            }
            .foregroundStyle(.white)
            .allowsHitTesting(true)
        }
    }

    private func finish() {
        guard let session else { return }
        let note: String
        switch (session.missedCount, missReason) {
        case (0, _):
            note = ""
        case (let missed, .blockedByCase):
            note = L10nKey.touchNoteBlockedByCase.text(in: language, count: missed, one: .touchNoteBlockedByCaseOne)
        case (let missed, .unresponsive):
            note = L10nKey.touchNoteUnresponsive.text(in: language, count: missed, one: .touchNoteUnresponsiveOne)
        case (let missed, nil):
            note = L10nKey.touchNoteMissed.text(in: language, count: missed, one: .touchNoteMissedOne)
        }
        let result = session.result(
            id: testID,
            display: display,
            missReason: missReason,
            landscape: canvasSize.width > canvasSize.height,
            notes: note
        )
        onFinish(result)
    }
}

// MARK: - Touch capture

/// Multi-touch capture with coalesced touches, so fast swipes are sampled as finely as the
/// hardware reports them. SwiftUI gestures only track one finger.
struct TouchCaptureView: UIViewRepresentable {
    let onStroke: (CGPoint, CGPoint) -> Void
    let onTouchCount: (Int) -> Void

    func makeUIView(context: Context) -> TouchCaptureUIView {
        let view = TouchCaptureUIView()
        view.onStroke = onStroke
        view.onTouchCount = onTouchCount
        return view
    }

    func updateUIView(_ view: TouchCaptureUIView, context: Context) {
        view.onStroke = onStroke
        view.onTouchCount = onTouchCount
    }
}

final class TouchCaptureUIView: UIView {
    var onStroke: ((CGPoint, CGPoint) -> Void)?
    var onTouchCount: ((Int) -> Void)?
    private var lastLocations: [ObjectIdentifier: CGPoint] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            lastLocations[ObjectIdentifier(touch)] = point
            onStroke?(point, point)
        }
        reportCount(event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            let samples = event?.coalescedTouches(for: touch) ?? [touch]
            for sample in samples {
                let point = sample.location(in: self)
                let previous = lastLocations[key] ?? point
                onStroke?(previous, point)
                lastLocations[key] = point
            }
        }
        reportCount(event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches, event: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches, event: event)
    }

    private func endTouches(_ touches: Set<UITouch>, event: UIEvent?) {
        for touch in touches {
            lastLocations.removeValue(forKey: ObjectIdentifier(touch))
        }
        reportCount(event, ending: touches)
    }

    private func reportCount(_ event: UIEvent?, ending: Set<UITouch> = []) {
        let active = (event?.allTouches ?? []).filter { touch in
            !ending.contains(touch) && touch.phase != .ended && touch.phase != .cancelled
        }
        onTouchCount?(active.count)
    }
}
