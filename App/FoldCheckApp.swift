import SwiftUI
import SwiftData
import FoldKit
import FoldL10n
import TestsKit
import ReportKit
import Library

@main
struct FoldCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var foldStateProvider = SystemFoldStateProvider()
    @State private var mockFoldStateProvider: MockFoldStateProvider?
    @State private var settings = AppSettings()
    @State private var foldCounter = FoldCounterModel()
    private let sessionContainer = Self.makeSessionContainer()
    
    init() {
        // Assigning a @State property inside init is ignored; seed its initial value instead.
        _mockFoldStateProvider = State(initialValue: Self.makeMockProviderIfRequested())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.foldStateProvider, currentProvider)
                .environment(settings)
                .environment(foldCounter)
                .environment(\.appLanguage, settings.appLanguage)
                .environment(\.reportLanguage, settings.reportLanguage)
                .modifier(HingeBridgeModifier(provider: foldStateProvider))
        }
        .modelContainer(sessionContainer)
    }
    
    private var currentProvider: any FoldStateProvider {
        mockFoldStateProvider ?? foldStateProvider
    }
    
    /// `-FoldMock <value>` swaps in the mock provider (DEBUG builds only).
    private static func makeMockProviderIfRequested() -> MockFoldStateProvider? {
        #if DEBUG
        guard let mockValue = getMockValue() else { return nil }
        let (posture, angle, script) = MockFoldStateProvider.parseArgument(mockValue) { name in
            // `script:<name>` reads App/Resources/MockScripts/<name>.json from the bundle.
            Bundle.main.url(forResource: name, withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap(MockFoldStateProvider.decodeScript)
        }
        let mock = MockFoldStateProvider(initialState: FoldState(posture: posture, angleDegrees: angle))
        if let script {
            Task {
                // Kept so the hinge test can replay it when a sweep starts recording.
                await mock.setLaunchScript(script)
                await mock.play(script)
            }
        }
        return mock
        #else
        return nil
        #endif
    }
    
    /// Saved sessions (spec §Persistence) stay on this device: Application Support/Sessions.store,
    /// outside the shared app group and with no CloudKit database, so nothing is synced or uploaded.
    private static func makeSessionContainer() -> ModelContainer {
        let configuration = ModelConfiguration("Sessions", groupContainer: .none, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: StoredSession.self, configurations: configuration)
        } catch {
            // An unreadable store shouldn't stop the tests from running; history just won't persist.
            assertionFailure("Session store failed to open: \(error)")
            let fallback = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: StoredSession.self, configurations: fallback)
        }
    }
    
    private static func getMockValue() -> String? {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "-FoldMock"), index + 1 < args.count {
            return args[index + 1]
        }
        return nil
    }
}

// MARK: - Hinge Bridge Modifier

/// Feeds the system hinge into `SystemFoldStateProvider`. Nothing else may call the hinge API.
///
/// `onHingeChange` is in the iOS 27.1 SDK (assumed version, spec §0). The call compiles only
/// when `FOLDCHECK_HINGE_API` is set, which project.yml does automatically for iOS 27.1+ SDKs,
/// and runs only on iOS 27.1+. On older SDKs/OSes the provider stays at `.noHinge`.
struct HingeBridgeModifier: ViewModifier {
    let provider: SystemFoldStateProvider
    
    func body(content: Content) -> some View {
        #if FOLDCHECK_HINGE_API
        if #available(iOS 27.1, *) {
            // onHingeChange(isEnabled:_:) → (DeviceHingeContext, DeviceHingeContext), checked
            // against the iOS 27.1 SDK (Xcode 27.1 RC, 27A9275).
            content.onHingeChange { _, context in
                provider.ingest(context.hinge)
            }
        } else {
            content.onAppear { provider.ingest(posture: nil, angleDegrees: nil) }
        }
        #else
        content.onAppear { provider.ingest(posture: nil, angleDegrees: nil) }
        #endif
    }
}

#if FOLDCHECK_HINGE_API
@available(iOS 27.1, *)
extension SystemFoldStateProvider {
    /// Maps `DeviceHinge` to `FoldState`: `nil` → noHinge; status per spec §6.
    func ingest(_ hinge: DeviceHinge?) {
        guard let hinge else {
            ingest(posture: nil, angleDegrees: nil)
            return
        }
        let posture: FoldPosture
        switch hinge.status {
        case .closed: posture = .closed
        case .partiallyOpen: posture = .partiallyOpen
        case .fullyOpen: posture = .fullyOpen
        // `DeviceHinge.Status` is a struct of static values in the iOS 27.1 SDK, not an enum,
        // so `@unknown default` doesn't compile. A status added later lands here.
        default: posture = .unknown
        }
        ingest(posture: posture, angleDegrees: hinge.angle.degrees)
    }
}
#endif

// MARK: - Environment Key

private struct FoldStateProviderKey: EnvironmentKey {
    static let defaultValue: any FoldStateProvider = SystemFoldStateProvider()
}

extension EnvironmentValues {
    var foldStateProvider: any FoldStateProvider {
        get { self[FoldStateProviderKey.self] }
        set { self[FoldStateProviderKey.self] = newValue }
    }
}
