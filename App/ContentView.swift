import SwiftUI
import FoldKit
import TestsKit

struct ContentView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var currentFoldState: FoldState = .noHinge
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
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
            .tag(Tab.history)
            
            NavigationStack {
                VerifyView()
            }
            .tabItem {
                Label("Verify", systemImage: "qrcode.viewfinder")
            }
            .tag(Tab.verify)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
        .task {
            for await state in foldStateProvider.states() {
                currentFoldState = state
            }
        }
        .overlay(alignment: .topTrailing) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-FoldDebugOverlay") {
                FoldDebugOverlay(state: currentFoldState)
            }
            #endif
        }
    }
}

// MARK: - Debug Overlay

#if DEBUG
struct FoldDebugOverlay: View {
    let state: FoldState
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("Fold: \(state.posture.displayName)")
                .font(.caption.monospaced())
            if let angle = state.angleDegrees {
                Text("Angle: \(String(format: "%.1f", angle))°")
                    .font(.caption.monospaced())
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }
}
#endif

// MARK: - Preview

#Preview {
    ContentView()
}
