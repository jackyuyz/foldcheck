import SwiftUI
import FoldKit
import FoldL10n
import TestsKit
import ReportKit

@main
struct FoldCheckApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var foldStateProvider = SystemFoldStateProvider()
    @State private var mockFoldStateProvider: MockFoldStateProvider?
    @State private var settings = AppSettings()
    @State private var foldCounter = FoldCounterModel()
    
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
            // TODO(verify-api): written against the documented signature
            // onHingeChange(isEnabled:_:) → (DeviceHingeContext, DeviceHingeContext);
            // not compiled yet because the iOS 27.1 SDK isn't installed. Verify in Xcode 27.1.
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
        @unknown default: posture = .unknown
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
