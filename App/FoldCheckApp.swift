import SwiftUI
import FoldKit
import FoldL10n
import TestsKit
import ReportKit

@main
struct FoldCheckApp: App {
    @State private var foldStateProvider = SystemFoldStateProvider()
    @State private var mockFoldStateProvider: MockFoldStateProvider?
    @State private var settings = AppSettings()
    
    init() {
        configureMockProviderIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.foldStateProvider, currentProvider)
                .environment(settings)
                .environment(\.appLanguage, settings.appLanguage)
                .environment(\.reportLanguage, settings.reportLanguage)
                .modifier(HingeBridgeModifier(provider: foldStateProvider))
        }
    }
    
    private var currentProvider: any FoldStateProvider {
        mockFoldStateProvider ?? foldStateProvider
    }
    
    private mutating func configureMockProviderIfNeeded() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestMode") ||
           CommandLine.arguments.contains("-FoldMock") {
            if let mockValue = getMockValue() {
                let (posture, angle, script) = MockFoldStateProvider.parseArgument(mockValue)
                let initialState = FoldState(posture: posture, angleDegrees: angle)
                let mock = MockFoldStateProvider(initialState: initialState)
                
                if let script = script {
                    Task {
                        await mock.play(script)
                    }
                }
                
                mockFoldStateProvider = mock
            }
        }
        #endif
    }
    
    private func getMockValue() -> String? {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "-FoldMock"), index + 1 < args.count {
            return args[index + 1]
        }
        return nil
    }
}

// MARK: - Hinge Bridge Modifier

struct HingeBridgeModifier: ViewModifier {
    let provider: SystemFoldStateProvider
    
    func body(content: Content) -> some View {
        // TODO(verify-api): onHingeChange availability needs verification on iOS 27.1
        // On iOS < 27.1 or non-Duo devices, this will be a no-op
        content
        // if #available(iOS 27.1, *) {
        //     content.onHingeChange { _, ctx in
        //         Task { @MainActor in
        //             await provider.ingest(ctx.hinge)
        //         }
        //     }
        // } else {
        //     content.onAppear {
        //         Task { @MainActor in
        //             await provider.ingestNoHinge()
        //         }
        //     }
        // }
    }
}

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

// MARK: - System Fold State Provider

extension SystemFoldStateProvider {
    // TODO(verify-api): These methods will ingest from the real hinge API
    // For now, they're placeholders that will be implemented when iOS 27.1 SDK is available
    
    @MainActor
    func ingestNoHinge() async {
        await updateState(.noHinge)
    }
    
    // func ingest(_ hinge: DeviceHinge?) async {
    //     guard let hinge = hinge else {
    //         await ingestNoHinge()
    //         return
    //     }
    //     let posture: FoldPosture
    //     switch hinge.status {
    //     case .closed: posture = .closed
    //     case .partiallyOpen: posture = .partiallyOpen
    //     case .fullyOpen: posture = .fullyOpen
    //     @unknown default: posture = .unknown
    //     }
    //     let state = FoldState(
    //         posture: posture,
    //         angleDegrees: hinge.angle.degrees,
    //         timestamp: .now
    //     )
    //     await updateState(state)
    // }
}
