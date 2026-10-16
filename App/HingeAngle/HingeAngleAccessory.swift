import SwiftUI
import FoldKit
import FoldL10n
import TestsKit

extension View {
    /// Live hinge angle pinned above the side tab bar. Only on devices with a hinge (iPhone Duo).
    /// Test screens are presented full screen, so they cover it without extra work.
    func hingeAngleAccessory(state: FoldState, onRunHingeCheck: @escaping () -> Void) -> some View {
        modifier(HingeAngleAccessoryModifier(state: state, onRunHingeCheck: onRunHingeCheck))
    }
}

private struct HingeAngleAccessoryModifier: ViewModifier {
    let state: FoldState
    let onRunHingeCheck: () -> Void

    /// On the Duo the system draws the tab bar as a rail centered about 48 pt from the
    /// trailing edge, on both displays (Xcode 27.1 RC simulator). The button lines up with it.
    /// `tabViewBottomAccessory` isn't used: on the inner display it floats at the bottom
    /// center, across the crease and over the content.
    private static let railCenterInset: CGFloat = 48

    func body(content: Content) -> some View {
        content.overlay {
            // Measured from the screen edge, so the container ignores the safe area
            // the rail sits in. Color.clear doesn't take touches.
            ZStack(alignment: .trailing) {
                Color.clear
                if state.hasHinge {
                    HingeAngleButton(state: state, onRunHingeCheck: onRunHingeCheck)
                        .padding(.trailing, Self.railCenterInset - HingeAngleButton.size / 2)
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// Round gauge (angle / 180°) with the angle in the middle. Tap for the details panel.
struct HingeAngleButton: View {
    static let size: CGFloat = 48

    let state: FoldState
    let onRunHingeCheck: () -> Void
    @Environment(\.appLanguage) private var language
    @State private var showingPanel = false

    var body: some View {
        Button {
            showingPanel = true
        } label: {
            HingeAngleGauge(state: state)
                .frame(width: Self.size - 8, height: Self.size - 8)
                .padding(4)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10nKey.angleTitle.text(in: language))
        .accessibilityValue("\(state.angleText), \(state.postureText(in: language))")
        .accessibilityIdentifier("hingeAngle.button")
        .popover(isPresented: $showingPanel, arrowEdge: .trailing) {
            HingeAnglePanel(state: state) {
                showingPanel = false
                onRunHingeCheck()
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct HingeAngleGauge: View {
    let state: FoldState

    var body: some View {
        // The angle range isn't documented (FoldState); 0–180° is only the ring's scale.
        Gauge(value: min(max(state.angleDegrees ?? 0, 0), 180), in: 0...180) {
            EmptyView()
        } currentValueLabel: {
            Text(state.angleText)
                .font(.caption2.monospacedDigit().weight(.semibold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(state.postureColor)
        .animation(.easeOut(duration: 0.2), value: state.angleDegrees)
    }
}

/// Opened from the angle button: big angle, posture, folds this session, and a hinge check.
private struct HingeAnglePanel: View {
    let state: FoldState
    let onRunHingeCheck: () -> Void
    @Environment(\.appLanguage) private var language
    @Environment(FoldCounterModel.self) private var foldCounter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.angleText)
                .font(.system(size: 44, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: state.angleDegrees)
            Text(state.postureText(in: language))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(state.postureColor.opacity(0.15), in: Capsule())
                .foregroundStyle(state.postureColor)

            Divider()

            // A TimelineView keeps the count current while the panel stays open.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LabeledContent(
                    L10nKey.foldsSession.text(in: language),
                    value: "\(foldCounter.sessionStats(at: context.date).foldCount)"
                )
                .font(.subheadline)
            }

            Button(action: onRunHingeCheck) {
                Label(L10nKey.homeHingeCheck.text(in: language), systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("hingeAngle.runHingeCheck")
        }
        .padding()
        .frame(width: 240)
    }
}

private extension FoldState {
    var angleText: String {
        angleDegrees.map { "\(Int($0.rounded()))°" } ?? "—"
    }

    func postureText(in language: AppLanguage) -> String {
        switch posture {
        case .closed: L10nKey.postureClosed.text(in: language)
        case .partiallyOpen: L10nKey.posturePartiallyOpen.text(in: language)
        case .fullyOpen: L10nKey.postureFullyOpen.text(in: language)
        case .noHinge, .unknown: L10nKey.postureUnknown.text(in: language)
        }
    }

    var postureColor: Color {
        switch posture {
        case .partiallyOpen: .blue
        case .fullyOpen: .green
        case .closed, .noHinge, .unknown: .gray
        }
    }
}
