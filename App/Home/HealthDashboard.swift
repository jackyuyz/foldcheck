import SwiftUI
import FoldL10n
import TestsKit

// Design A: the home screen as a health dashboard. The primary panel is the overall score;
// the secondary panel is one tile per part with its latest measured result.

/// Score ring, status, last check, and the main action.
struct HealthSummaryPanel: View {
    let health: DeviceHealth
    let onStart: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 20) {
            Text(L10nKey.homeHealthTitle.text(in: language))
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            HealthScoreRing(score: health.score, status: health.status)

            VStack(spacing: 6) {
                if let status = health.status {
                    ResultBadge(outcome: status)
                    Text(attentionLine)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("home.health.summary")
                    Text(L10nKey.homeHealthBasis.text(in: language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(L10nKey.homeHealthCoverage.text(in: language, health.measured.count, health.items.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("home.health.coverage")
                    if let checked = health.lastCheckedAt {
                        Text(L10nKey.homeHealthChecked.text(in: language, checked.formatted(date: .long, time: .omitted, in: language)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10nKey.homeHealthEmpty.text(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("home.health.empty")
                }
            }

            Button(action: onStart) {
                Label(
                    health.hasData ? L10nKey.homeCheckAgain.text(in: language) : L10nKey.homeStart.text(in: language),
                    systemImage: "play.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(InspectionStyle.buttonFill, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .accessibilityIdentifier("home.start")
        }
    }

    private var attentionLine: String {
        let count = health.needsAttention.count
        guard count > 0 else { return L10nKey.homeHealthAllGood.text(in: language) }
        return L10nKey.homeHealthAttention.text(in: language, count: count, one: .homeHealthAttentionOne)
    }
}

/// Ring filled to the score, colored by status; empty with a dash before the first check.
struct HealthScoreRing: View {
    let score: Int?
    let status: TestOutcome?
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            ring
                .frame(width: 168, height: 168)
            if score != nil && dynamicTypeSize.isAccessibilitySize {
                outOf100
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10nKey.homeHealthTitle.text(in: language)))
        .accessibilityValue(Text(score.map { L10nKey.homeHealthScoreValue.text(in: language, $0) } ?? L10nKey.homeHealthEmpty.text(in: language)))
        .accessibilityIdentifier("home.health.score")
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(score ?? 0) / 100)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: score)
            VStack(spacing: 0) {
                Text(score.map(String.init) ?? "—")
                    .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                if score != nil && !dynamicTypeSize.isAccessibilitySize {
                    outOf100
                }
            }
        }
    }

    private var outOf100: some View {
        Text(L10nKey.summaryOutOf100.text(in: language))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Bright system colors for the ring: it's a graphic, and the number and badge carry the
    /// same information in text-contrast colors.
    private var ringColor: Color {
        switch status {
        case .pass: return .green
        case .attention: return .orange
        case .fail: return .red
        default: return .clear
        }
    }
}

/// One tile per part. Tapping a tile runs that part's test.
struct HealthPartsPanel: View {
    let health: DeviceHealth
    let onRun: (HealthComponent) -> Void
    @Environment(\.appLanguage) private var language
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.homeParts.text(in: language))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            // Not lazy: nine tiles are cheap, and every tile stays in the accessibility tree
            // (and reachable by UI tests) even when the stacked layout puts it below the fold.
            let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(stride(from: 0, to: health.items.count, by: columns)), id: \.self) { start in
                    GridRow {
                        ForEach(health.items[start..<min(start + columns, health.items.count)]) { item in
                            HealthPartTile(item: item) { onRun(item.component) }
                                .accessibilityIdentifier(item.component.accessibilityIdentifier)
                        }
                    }
                }
            }
        }
    }
}

private struct HealthPartTile: View {
    let item: DeviceHealth.Item
    let action: () -> Void
    @Environment(\.appLanguage) private var language

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: item.component.systemImage)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Spacer(minLength: 4)
                    if let outcome = item.outcome {
                        ResultBadge(outcome: outcome)
                    } else {
                        Text(L10nKey.homeNotRun.text(in: language))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.component.localizedName(in: language))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(L10nKey.homePartHint.text(in: language)))
    }

    /// The headline metric of the latest result, or when it was checked. For the hinge that's
    /// the largest gap, the usual reason for Attention, rather than continuity.
    private var detail: String {
        if let result = item.result {
            let lines = ResultMetricsFormatter.lines(for: result, language: language)
            let preferred = item.component == .hinge
                ? lines.first { $0.label == L10nKey.metricMaxGap.text(in: language) }
                : nil
            if let line = preferred ?? lines.first {
                return "\(line.label) \(line.value)"
            }
        }
        if let checked = item.checkedAt {
            return checked.formatted(date: .abbreviated, time: .omitted, in: language)
        }
        return L10nKey.homePartTapToRun.text(in: language)
    }
}

extension HealthComponent {
    func localizedName(in language: AppLanguage) -> String {
        localizedCopy("part.\(rawValue)", language: language)
    }

    var systemImage: String {
        switch self {
        case .hinge: return "arrow.triangle.2.circlepath"
        case .crease: return "line.diagonal"
        case .screen: return "rectangle.grid.3x2.fill"
        case .touch: return "hand.tap.fill"
        case .cameras: return "camera.fill"
        case .audio: return "speaker.wave.3.fill"
        case .touchID: return "touchid"
        case .sensors: return "gyroscope"
        case .buttons: return "plusminus"
        }
    }

    /// The hinge, touch and screen tiles keep the identifiers of the quick actions they replace.
    var accessibilityIdentifier: String {
        switch self {
        case .hinge: return "home.quick.hinge"
        case .touch: return "home.quick.touch"
        case .screen: return "home.quick.screen"
        default: return "home.part.\(rawValue)"
        }
    }
}
