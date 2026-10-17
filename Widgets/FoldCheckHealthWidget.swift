import SwiftUI
import WidgetKit
import Library
import FoldL10n

struct HealthEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetHealthSnapshot?
}

struct HealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthEntry {
        HealthEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthEntry) -> Void) {
        completion(HealthEntry(date: .now, snapshot: WidgetHealthSnapshotStore.shared.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthEntry>) -> Void) {
        // Absolute dates don't age into misleading live status. The app requests a reload
        // only after saved results or language change; WidgetKit schedules actual delivery.
        let entry = HealthEntry(date: .now, snapshot: WidgetHealthSnapshotStore.shared.read())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

@main
struct FoldCheckHealthWidget: Widget {
    var body: some WidgetConfiguration {
        let language = WidgetHealthSnapshotStore.shared.read()
            .flatMap { AppLanguage(languageCode: $0.languageCode) } ?? .default
        return StaticConfiguration(kind: HealthWidget.kind, provider: HealthProvider()) { entry in
            HealthWidgetEntryView(snapshot: entry.snapshot)
                .widgetURL(HealthWidget.homeURL)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(L10nKey.widgetTitle.text(in: language))
        .description(L10nKey.widgetDescription.text(in: language))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct HealthWidgetEntryView: View {
    let snapshot: WidgetHealthSnapshot?
    @Environment(\.widgetFamily) private var family

    var body: some View {
        HealthWidgetView(snapshot: snapshot, family: family)
    }
}
