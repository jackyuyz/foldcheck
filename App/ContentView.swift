import SwiftUI
import FoldKit
import FoldL10n
import TestsKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @State private var selectedTab: Tab = .home
    
    enum Tab: Hashable {
        case home
        case history
        case verify
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(L10nKey.tabHome.text(in: language), systemImage: "house.fill")
            }
            .tag(Tab.home)
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label(L10nKey.tabHistory.text(in: language), systemImage: "clock.fill")
            }
            .tag(Tab.history)
            
            NavigationStack {
                VerifyView()
            }
            .tabItem {
                Label(L10nKey.tabVerify.text(in: language), systemImage: "qrcode.viewfinder")
            }
            .tag(Tab.verify)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(L10nKey.tabSettings.text(in: language), systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .foldDebugOverlay()
    }
}

// MARK: - Debug Overlay

extension View {
    /// DEBUG-only "Fold debug" overlay (shown with `-FoldDebugOverlay`). It shows the mocked
    /// posture and, when `-FoldMock` is active, buttons that change it mid-flow
    /// (`fold.closed`, `fold.half`, `fold.open`, `fold.nohinge`, `fold.sweep`).
    /// Applied to every presented layer, since an overlay under a sheet can't be reached.
    func foldDebugOverlay() -> some View {
        #if DEBUG
        modifier(FoldDebugOverlayModifier())
        #else
        self
        #endif
    }
}

#if DEBUG
private struct FoldDebugOverlayModifier: ViewModifier {
    private let isEnabled = ProcessInfo.processInfo.arguments.contains("-FoldDebugOverlay")

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if isEnabled {
                FoldDebugOverlay()
            }
        }
    }
}

struct FoldDebugOverlay: View {
    @Environment(\.foldStateProvider) private var provider
    @State private var state: FoldState = .noHinge
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                expanded.toggle()
            } label: {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Fold: \(state.posture.displayName)")
                    if let angle = state.angleDegrees {
                        Text("Angle: \(String(format: "%.1f", angle))°")
                    }
                }
                .font(.caption.monospaced())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("fold.debug")

            if expanded, let mock = provider as? MockFoldStateProvider {
                ForEach(Self.actions, id: \.id) { action in
                    Button(action.title) {
                        Task { await action.run(mock) }
                    }
                    .font(.caption.monospaced())
                    .accessibilityIdentifier(action.id)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.top, 44)
        .padding(.trailing, 8)
        .observeFoldState($state)
    }

    private struct Action {
        let id: String
        let title: String
        let run: @Sendable (MockFoldStateProvider) async -> Void
    }

    private static let actions: [Action] = [
        Action(id: "fold.closed", title: "Closed") { await $0.set(.closed, angle: 0) },
        Action(id: "fold.half", title: "Half 95°") { await $0.set(.partiallyOpen, angle: 95) },
        Action(id: "fold.open", title: "Open") { await $0.set(.fullyOpen, angle: 180) },
        Action(id: "fold.nohinge", title: "No hinge") { await $0.set(.noHinge) },
        Action(id: "fold.sweep", title: "Sweep 10→180") { mock in
            Task { await mock.play(FoldScriptStep.sweep(from: 10, to: 180, durationSeconds: 6)) }
        },
    ]
}
#endif

// MARK: - Preview

#Preview {
    ContentView()
}
