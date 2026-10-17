import SwiftUI
import WidgetKit
import Library
import FoldL10n

struct HealthWidgetView: View {
    let snapshot: WidgetHealthSnapshot?
    let family: WidgetFamily

    private var language: AppLanguage {
        snapshot.flatMap { AppLanguage(languageCode: $0.languageCode) } ?? .default
    }

    var body: some View {
        Group {
            if family == .accessoryRectangular {
                accessory
            } else if let snapshot, snapshot.score != nil {
                if family == .systemMedium { medium(snapshot) } else { small(snapshot) }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.secondary)
                    Text(L10nKey.widgetEmpty.text(in: language))
                        .font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
        .privacySensitive()
    }

    private var header: some View {
        Label("FoldCheck", systemImage: "rectangle.on.rectangle.angled")
            .font(.caption.weight(.semibold)).widgetAccentable()
    }

    private func small(_ snapshot: WidgetHealthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            header
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(snapshot.score.map(String.init) ?? "—")
                    .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                    .widgetAccentable()
                Text("/100").font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10nKey.homeHealthScoreValue.text(in: language, snapshot.score ?? 0))
            status
            checkedDate
        }
    }

    private func medium(_ snapshot: WidgetHealthSnapshot) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 7)
                Circle().trim(from: 0, to: CGFloat(snapshot.score ?? 0) / 100)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(snapshot.score.map(String.init) ?? "—")
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
            }
            .frame(width: 72, height: 72)
            .widgetAccentable()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10nKey.homeHealthScoreValue.text(in: language, snapshot.score ?? 0))
            VStack(alignment: .leading, spacing: 5) {
                header
                status
                Text(snapshot.attentionCount == 0
                     ? L10nKey.homeHealthAllGood.text(in: language)
                     : L10nKey.homeHealthAttention.text(in: language, count: snapshot.attentionCount, one: .homeHealthAttentionOne))
                    .font(.caption)
                Text(L10nKey.homeHealthCoverage.text(in: language, snapshot.measuredCount, snapshot.totalCount))
                    .font(.caption2).foregroundStyle(.secondary)
                checkedDate
            }
        }
    }

    private var accessory: some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            if let score = snapshot?.score {
                HStack(spacing: 6) {
                    Text("\(score)/100")
                        .font(.headline.monospacedDigit())
                    Image(systemName: snapshot?.status?.iconName ?? "checkmark.circle")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(statusText), \(L10nKey.homeHealthScoreValue.text(in: language, score))")
                checkedDate
            } else {
                Text(L10nKey.widgetEmpty.text(in: language)).font(.caption)
            }
        }
    }

    private var status: some View {
        Label {
            Text(statusText).foregroundStyle(.primary)
        } icon: {
            Image(systemName: snapshot?.status?.iconName ?? "questionmark.circle")
                .foregroundStyle(statusColor)
        }
        .font(.caption.weight(.semibold))
    }

    private var statusText: String {
        guard let status = snapshot?.status,
              let key = L10nKey(rawValue: "outcome.\(status.rawValue)") else { return "—" }
        return key.text(in: language)
    }

    private var statusColor: Color {
        switch snapshot?.status {
        case .pass: .green
        case .attention: .orange
        case .fail: .red
        default: .secondary
        }
    }

    private var checkedDate: some View {
        VStack(alignment: .leading, spacing: 0) {
            if family == .systemSmall, let snapshot {
                // Keep partial coverage visible even in the compact widget: one passing
                // test must not look like a complete inspection of the whole phone.
                Text(L10nKey.homeHealthCoverage.text(in: language, snapshot.measuredCount, snapshot.totalCount))
            } else {
                Text(L10nKey.widgetSavedResults.text(in: language))
            }
            if let date = snapshot?.lastCheckedAt {
                Text(date, format: .dateTime.year().month(.abbreviated).day())
            }
        }
        .font(.caption2).foregroundStyle(.secondary)
    }
}
