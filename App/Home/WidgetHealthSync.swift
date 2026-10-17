import SwiftUI
import SwiftData
import WidgetKit
import Library
import TestsKit
import FoldL10n
import FoldKit

/// Lives at the tab root so saves, deletions and language changes on any tab update widgets.
struct WidgetHealthSync: ViewModifier {
    @Query(StoredSession.newestFirst) private var records: [StoredSession]
    @Environment(\.foldStateProvider) private var provider
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @State private var cache = DeviceHealthCache()
    // Hardware capability cannot disappear when the scene briefly loses hinge context.
    @State private var hasObservedHinge = false

    func body(content: Content) -> some View {
        content
            .onChange(of: records.map(\.payload), initial: true) { _, _ in publish() }
            .onChange(of: language) { _, _ in publish() }
            .onChange(of: hasObservedHinge) { _, _ in publish() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { publish() }
            }
            .task {
                if provider.state.hasHinge { hasObservedHinge = true }
                for await state in provider.states() {
                    if state.hasHinge && !hasObservedHinge { hasObservedHinge = true }
                }
            }
    }

    private func publish() {
        // A scene losing its hinge context while leaving the foreground must not replace
        // the saved Duo summary with a transient non-hinge summary.
        guard scenePhase == .active else { return }
        #if DEBUG
        // Review fixtures must never replace the real Home Screen widget's saved results.
        let args = ProcessInfo.processInfo.arguments
        guard !args.contains("-ScreenshotFixtures"), !args.contains("-EmptyHistoryFixtures"),
              !args.contains("-FoldMock"), !args.contains("-UITestMode"),
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        #endif
        var context = DeviceInfo.context(foldState: provider.state)
        if hasObservedHinge && !context.hasHinge {
            // Applicability only: no synthetic angle or measurement is introduced.
            context.foldState = FoldState(posture: .unknown, angleDegrees: nil)
        }
        cache.update(payloads: records.map(\.payload), context: context)
        guard let health = cache.health else { return }
        let snapshot = WidgetHealthSnapshot(health: health, languageCode: language.rawValue)
        if (try? WidgetHealthSnapshotStore.shared.write(snapshot)) == true {
            WidgetCenter.shared.reloadTimelines(ofKind: HealthWidget.kind)
        }
    }
}
