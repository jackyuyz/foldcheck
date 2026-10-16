import SwiftUI
import FoldL10n
import TestsKit

/// F4: two saved inspections side by side, older on the left.
struct CompareView: View {
    let comparison: SessionComparison
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        column(comparison.older)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        column(comparison.newer)
                    }
                    .accessibilityElement(children: .combine)
                    HStack {
                        Text(L10nKey.reportScore.text(in: language))
                        Spacer()
                        scoreText(comparison.older.overallScore)
                        ChangeIcon(change: comparison.scoreChange)
                        scoreText(comparison.newer.overallScore)
                    }
                    .accessibilityIdentifier("compare.score")
                }

                ForEach(comparison.rows) { row in
                    Section {
                        HStack {
                            outcomeBadge(row.older)
                            Spacer()
                            ChangeIcon(change: row.outcomeChange)
                            Spacer()
                            outcomeBadge(row.newer)
                        }
                        ForEach(row.metrics, id: \.key) { metric in
                            HStack {
                                Text(Self.label(for: metric.key, in: language))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Self.format(metric.older, key: metric.key))
                                    .monospacedDigit()
                                ChangeIcon(change: metric.change)
                                Text(Self.format(metric.newer, key: metric.key))
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text(row.id.localizedName(in: language, hasHinge: comparison.newer.hasHinge))
                    }
                    .accessibilityIdentifier("compare.row.\(row.id.rawValue)")
                }
            }
            .navigationTitle(L10nKey.historyCompare.text(in: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.testDone.text(in: language)) { dismiss() }
                        .accessibilityIdentifier("compare.done")
                }
            }
        }
    }

    private func column(_ session: InspectionSession) -> some View {
        VStack(spacing: 4) {
            Text(session.startedAt.formatted(date: .abbreviated, time: .omitted, in: language))
                .font(.headline)
            ResultBadge(outcome: session.overallStatus)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreText(_ score: Int?) -> some View {
        Text(score.map { "\($0)" } ?? "—")
            .monospacedDigit()
            .frame(minWidth: 32)
    }

    @ViewBuilder
    private func outcomeBadge(_ outcome: TestOutcome?) -> some View {
        if let outcome {
            ResultBadge(outcome: outcome)
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }

    static func label(for key: String, in language: AppLanguage) -> String {
        switch key {
        case TestMetricKey.missedCells: return L10nKey.metricMissedCells.text(in: language)
        case TestMetricKey.coveragePercent: return L10nKey.metricCoverage.text(in: language)
        case TestMetricKey.creaseBandMissed: return L10nKey.metricCreaseBandMissed.text(in: language)
        case TestMetricKey.issuesMarked: return L10nKey.metricIssuesMarked.text(in: language)
        case TestMetricKey.creaseRating: return L10nKey.metricCreaseRating.text(in: language)
        case TestMetricKey.monotonicFraction: return L10nKey.metricContinuity.text(in: language)
        case TestMetricKey.maxGapDegrees: return L10nKey.metricMaxGap.text(in: language)
        default: return key
        }
    }

    static func format(_ value: Double?, key: String) -> String {
        guard let value else { return "—" }
        switch key {
        case TestMetricKey.monotonicFraction: return "\(Int((value * 100).rounded()))%"
        case TestMetricKey.coveragePercent: return String(format: "%.1f%%", value)
        case TestMetricKey.maxGapDegrees: return String(format: "%.0f°", value)
        case TestMetricKey.creaseRating: return String(format: "%.1f", value)
        default: return "\(Int(value.rounded()))"
        }
    }
}

/// Green arrow up for better, red arrow down for worse, an equals sign for no change.
private struct ChangeIcon: View {
    let change: SessionComparison.Change
    @Environment(\.appLanguage) private var language

    var body: some View {
        Group {
            switch change {
            case .better:
                Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green)
                    .accessibilityLabel(Text(L10nKey.compareBetter.text(in: language)))
            case .worse:
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red)
                    .accessibilityLabel(Text(L10nKey.compareWorse.text(in: language)))
            case .same:
                Image(systemName: "equal.circle").foregroundStyle(.secondary)
                    .accessibilityLabel(Text(L10nKey.compareSame.text(in: language)))
            case .notComparable:
                Image(systemName: "circle.dashed").foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 24)
    }
}
