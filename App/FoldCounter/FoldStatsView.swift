import SwiftUI
import FoldKit
import FoldL10n
import TestsKit

/// F5 stats page: "Folds observed by FoldCheck", this launch and all time, plus time per display.
/// Always worded as observed-in-app, never as the device's lifetime count.
struct FoldStatsView: View {
    @Environment(FoldCounterModel.self) private var counter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                list(now: context.date)
            }
            .navigationTitle(L10nKey.foldsTitle.text(in: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.testDone.text(in: language)) { dismiss() }
                        .accessibilityIdentifier("folds.done")
                }
            }
        }
        .foldDebugOverlay()
    }

    private func list(now: Date) -> some View {
        let session = counter.sessionStats(at: now)
        let allTime = counter.allTimeStats(at: now)
        return List {
            Section {
                Text(L10nKey.foldsTitle.text(in: language))
                    .font(.title3.bold())
                    .accessibilityIdentifier("folds.heading")
                Text(L10nKey.foldsDisclaimer.text(in: language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("folds.disclaimer")
                if !counter.latestState.hasHinge {
                    Label(L10nKey.foldsNotApplicable.text(in: language), systemImage: "minus.circle")
                        .accessibilityIdentifier("folds.notApplicable")
                } else if let display = DisplayKind(posture: counter.latestState.posture) {
                    Text(L10nKey.foldsCurrent.text(in: language, display.localizedName(in: language)))
                        .accessibilityIdentifier("folds.current")
                }
            }

            section(L10nKey.foldsSession.text(in: language), stats: session, identifier: "folds.sessionCount")
            section(L10nKey.foldsAllTime.text(in: language), stats: allTime, identifier: "folds.allTimeCount", showSince: true)

            Section {
                Button(L10nKey.foldsReset.text(in: language), role: .destructive) {
                    counter.reset()
                }
                .accessibilityIdentifier("folds.reset")
            }
        }
    }

    private func section(_ title: String, stats: FoldCounter.Stats, identifier: String, showSince: Bool = false) -> some View {
        Section(title) {
            LabeledContent(L10nKey.foldsCount.text(in: language)) {
                Text("\(stats.foldCount)")
                    .font(.title2.bold().monospacedDigit())
                    .accessibilityIdentifier(identifier)
            }
            if stats.totalDuration > 0 {
                LabeledContent(L10nKey.foldsTimeShare.text(in: language)) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: "\(DisplayKind.outer.localizedName(in: language)) \(Int(stats.closedPercent.rounded()))% · \(duration(stats.closedDuration))")
                        Text(verbatim: "\(DisplayKind.inner.localizedName(in: language)) \(Int(stats.innerPercent.rounded()))% · \(duration(stats.openDuration + stats.partialDuration))")
                    }
                    .font(.caption.monospacedDigit())
                }
            }
            if showSince {
                Text(L10nKey.foldsSince.text(in: language, stats.startedAt.formatted(date: .abbreviated, time: .shortened, in: language)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: language.localeIdentifier)
        formatter.calendar = calendar
        return formatter.string(from: seconds) ?? ""
    }
}
