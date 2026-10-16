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
    @AppStorage("touchTapMode") private var tapMode = false
    @State private var session: TouchGridSession?
    @State private var foldState: FoldState
    @State private var display: DisplayKind?
    @State private var phase: Phase = .grid
    @State private var showMisses = false
    @State private var showMissDialog = false
    @State private var missReason: TouchGridMissReason?
    @State private var currentTouches = 0
    @State private var canvasSize: CGSize = .zero
    @State private var canvasOrientation: UIInterfaceOrientation = .unknown
    @State private var referenceOrientation: UIInterfaceOrientation = .unknown
    @State private var canvasSpec: DisplaySpec = .standard

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
            let spec = displaySpec(in: geometry)
            ZStack {
                Color.black

                switch phase {
                case .grid:
                    gridLayer(spec: spec)
                    gridControls
                case .multiTouch:
                    multiTouchLayer(spec: spec)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .defersSystemGestures(on: .all)
        .observeFoldState($foldState)
        .modifier(DisplayChangePause(foldState: foldState) { newDisplay in
            display = newDisplay
            // Inner and outer displays are separate physical surfaces.
            startGrid(size: canvasSize, spec: canvasSpec, orientation: canvasOrientation)
            showMisses = false
            showMissDialog = false
            missReason = nil
        })
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
                .tint(InspectionStyle.buttonFill)
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

    private func gridLayer(spec: DisplaySpec) -> some View {
        ZStack {
            Canvas { context, _ in
                guard let session else { return }
                for cell in session.layout.cells {
                    let inset: CGFloat = cell.isCreaseBand ? 1 : 1.5
                    let rect = projection.rectInCanvas(cell.rect)
                    let path = Path(roundedRect: rect.insetBy(dx: inset, dy: inset), cornerRadius: cell.isCreaseBand ? 2 : 3)
                    context.fill(path, with: .color(color(for: cell, in: session)))
                }
            }
            TouchCaptureView(
                tapsOnly: tapMode,
                onCanvasChange: { size, orientation in
                    updateCanvas(size: size, spec: spec, orientation: orientation)
                },
                onStroke: { from, to in
                    _ = session?.stroke(from: projection.pointInReference(from), to: projection.pointInReference(to))
                },
                onTouchCount: { count in
                    currentTouches = count
                    session?.recordSimultaneousTouches(count)
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(testID.localizedName(in: language, hasHinge: hasHinge)))
        .accessibilityValue(Text(accessibilityProgress))
        .accessibilityHint(L10nKey.touchDirectTouch.text(in: language))
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityIdentifier("touchGrid.canvas")
    }

    private var gridControls: some View {
        FloatingTestBar(onCancel: onCancel) {
            VStack(alignment: .leading, spacing: 2) {
                Text(progressText)
                    .monospacedDigit()
                    .accessibilityIdentifier("touchGrid.progress")
                if tapMode {
                    Text(L10nKey.touchTapMode.text(in: language))
                        .font(.caption)
                        .accessibilityIdentifier("touchGrid.tapMode")
                }
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
                    .frame(minHeight: 44)
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

    private func displaySpec(in geometry: GeometryProxy) -> DisplaySpec {
        guard includeCreaseBand else { return .standard }
        #if FOLDCHECK_HINGE_API
        if #available(iOS 27.1, *) {
            let division = geometry.reservedRegions(kind: .division, options: .includeInactive).first?.frame
            return .duoInner(canvasSize: geometry.size, divisionFrame: division)
        }
        #endif
        return .duoInner(canvasSize: geometry.size)
    }

    private var projection: TouchGridProjection {
        TouchGridProjection(referenceSize: session?.layout.size ?? canvasSize, canvasSize: canvasSize,
                            quarterTurns: canvasOrientation.gridQuarterTurns - referenceOrientation.gridQuarterTurns)
    }

    private func updateCanvas(size: CGSize, spec: DisplaySpec, orientation: UIInterfaceOrientation) {
        guard size.width > 0, size.height > 0, orientation != .unknown else { return }
        canvasSize = size
        canvasOrientation = orientation
        canvasSpec = spec
        if session == nil {
            startGrid(size: size, spec: spec, orientation: orientation)
        }
    }

    private func startGrid(size: CGSize, spec: DisplaySpec, orientation: UIInterfaceOrientation) {
        guard size.width > 0, size.height > 0 else { return }
        referenceOrientation = orientation
        let layout = TouchGridLayout(size: size, spec: spec, includeCreaseBand: includeCreaseBand)
        session = TouchGridSession(layout: layout)
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

    private func multiTouchLayer(spec: DisplaySpec) -> some View {
        ZStack {
            TouchCaptureView(
                onCanvasChange: { size, orientation in
                    updateCanvas(size: size, spec: spec, orientation: orientation)
                },
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
        var result = session.result(
            id: testID,
            display: display,
            missReason: missReason,
            landscape: canvasSize.width > canvasSize.height,
            notes: note
        )
        result.metrics[TestMetricKey.tapMode] = tapMode ? 1 : 0
        if tapMode {
            result.notes = [result.notes, L10nKey.touchTapNote.text(in: language)].filter { !$0.isEmpty }.joined(separator: "\n")
        }
        onFinish(result)
    }
}

// MARK: - Touch capture

/// Multi-touch capture with coalesced touches, so fast swipes are sampled as finely as the
/// hardware reports them. SwiftUI gestures only track one finger.
struct TouchCaptureView: UIViewControllerRepresentable {
    var tapsOnly = false
    var onCanvasChange: ((CGSize, UIInterfaceOrientation) -> Void)?
    let onStroke: (CGPoint, CGPoint) -> Void
    let onTouchCount: (Int) -> Void

    func makeUIViewController(context: Context) -> TouchCaptureController {
        let controller = TouchCaptureController()
        updateUIViewController(controller, context: context)
        return controller
    }

    func updateUIViewController(_ controller: TouchCaptureController, context: Context) {
        let view = controller.captureView
        view.tapsOnly = tapsOnly
        view.onStroke = onStroke
        view.onTouchCount = onTouchCount
        controller.onCanvasChange = onCanvasChange
    }
}

private extension UIInterfaceOrientation {
    /// Clockwise turns of the physical surface relative to an upright portrait canvas.
    var gridQuarterTurns: Int {
        switch self {
        case .landscapeLeft: 1
        case .portraitUpsideDown: 2
        case .landscapeRight: 3
        default: 0
        }
    }
}

/// Read orientation from this view's scene, rather than UIDevice or the first connected
/// scene: Duo's cover and inner screen can have different effective geometry.
final class TouchCaptureController: UIViewController {
    let captureView = TouchCaptureUIView()
    var onCanvasChange: ((CGSize, UIInterfaceOrientation) -> Void)?
    private var lastSize: CGSize = .zero
    private var lastOrientation: UIInterfaceOrientation = .unknown

    override func loadView() { view = captureView }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reportCanvas()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reportCanvas()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        captureView.isUserInteractionEnabled = false
        captureView.resetTouchLocations()
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            self.reportCanvas()
            self.captureView.isUserInteractionEnabled = true
        }
    }

    private func reportCanvas() {
        guard let scene = view.window?.windowScene else { return }
        let orientation: UIInterfaceOrientation
        if #available(iOS 26.0, *) {
            orientation = scene.effectiveGeometry.interfaceOrientation
        } else {
            orientation = scene.interfaceOrientation
        }
        let size = view.bounds.size
        guard size.width > 0, size.height > 0, orientation != .unknown,
              size != lastSize || orientation != lastOrientation else { return }
        lastSize = size
        lastOrientation = orientation
        captureView.resetTouchLocations()
        // Publish outside UIKit's layout pass so SwiftUI can safely update the canvas.
        Task { @MainActor [weak self] in
            self?.onCanvasChange?(size, orientation)
        }
    }
}

final class TouchCaptureUIView: UIView {
    var tapsOnly = false
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

    func resetTouchLocations() {
        // A rotation must never interpolate from an old-coordinate sample to a new one.
        lastLocations.removeAll()
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
        // Assisted tapping only counts physical contact beginnings, never interpolated drags.
        guard !tapsOnly else { reportCount(event); return }
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
