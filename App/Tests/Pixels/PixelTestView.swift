import SwiftUI
import FoldKit
import FoldL10n
import TestsKit

/// T2: full-screen solid colors. Tapping marks a suspect pixel (stored as a normalized point);
/// Next advances to the next color. Brightness is raised for the test and restored after.
struct PixelTestView: View {
    let initialFoldState: FoldState
    let onFinish: (TestResult) -> Void
    let onCancel: () -> Void

    @Environment(\.appLanguage) private var language
    @State private var session = PixelTestSession()
    @State private var foldState: FoldState
    @State private var display: DisplayKind?
    @State private var brightness = BrightnessBoost()

    init(initialFoldState: FoldState, onFinish: @escaping (TestResult) -> Void, onCancel: @escaping () -> Void) {
        self.initialFoldState = initialFoldState
        self.onFinish = onFinish
        self.onCancel = onCancel
        _foldState = State(initialValue: initialFoldState)
        _display = State(initialValue: DisplayKind(posture: initialFoldState.posture))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                patternColor
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { tap in
                        guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                        session.mark(
                            x: tap.location.x / geometry.size.width,
                            y: tap.location.y / geometry.size.height
                        )
                    })
                    .accessibilityElement()
                    .accessibilityLabel(Text(L10nKey.testPixels.text(in: language)))
                    .accessibilityValue(Text(L10nKey.pixelsMarked.text(in: language, session.marks.count)))
                    .accessibilityAddTraits(.allowsDirectInteraction)
                    .accessibilityIdentifier("pixels.canvas")

                ForEach(Array(session.currentMarks.enumerated()), id: \.offset) { _, mark in
                    Circle()
                        .stroke(markColor, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .position(x: mark.x * geometry.size.width, y: mark.y * geometry.size.height)
                        .allowsHitTesting(false)
                }

                FloatingTestBar(dark: session.currentPattern.prefersLightForeground == false, onCancel: onCancel) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10nKey.pixelsStep.text(in: language, session.currentIndex + 1, session.patterns.count))
                            .monospacedDigit()
                        Text(L10nKey.pixelsMarked.text(in: language, session.marks.count))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pixels.progress")

                    Button(L10nKey.testUndo.text(in: language)) {
                        session.undoLastMark()
                    }
                    .disabled(session.currentMarks.isEmpty)
                    .accessibilityIdentifier("pixels.undo")

                    Button {
                        if session.advance() {
                            finish()
                        }
                    } label: {
                        Text(session.isLastPattern ? L10nKey.testFinish.text(in: language) : L10nKey.testNext.text(in: language))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.green, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("pixels.next")
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .observeFoldState($foldState)
        .modifier(DisplayChangePause(foldState: foldState) { newDisplay in
            display = newDisplay
            session = PixelTestSession()
        })
        .onAppear { brightness.begin() }
        .onDisappear { brightness.end() }
    }

    private var patternColor: Color {
        let rgb = session.currentPattern.rgb
        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// Marks contrast with the pattern underneath.
    private var markColor: Color {
        switch session.currentPattern {
        case .black, .blue, .gray50: return .yellow
        case .red, .green: return .black
        case .white: return .red
        }
    }

    private func finish() {
        let count = session.marks.count
        let note = count == 0 ? "" : L10nKey.pixelsNote.text(in: language, count)
        onFinish(session.result(display: display, notes: note))
    }
}
