import SwiftUI
import Store
import SwiftData
import FoldKit
import FoldL10n
import TestsKit
import Library

struct HomeView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @Environment(\.appLanguage) private var language
    /// Only a saved full inspection becomes the "last inspection" on Home (full ones save themselves).
    @Query(StoredSession.latestFullInspection) private var latestFull: [StoredSession]
    /// Every saved inspection, quick tests included, feeds the per-part dashboard.
    @Query(StoredSession.newestFirst) private var records: [StoredSession]
    @State private var inspectionRequest: InspectionRequest?
    @State private var showingFoldStats = false
    @State private var showingPaywall = false
    @State private var hasHinge = false
    @State private var healthCache = DeviceHealthCache()
    @Environment(Store.self) private var store

    var body: some View {
        InspectionPanels {
            VStack(spacing: 24) {
                if let health = healthCache.health {
                    HealthSummaryPanel(health: health) {
                        start(TestID.defaultOrder)
                    }
                }
                if let session = latestFull.first?.session {
                    lastInspectionLink(session)
                }
                Label(L10nKey.homeLocal.text(in: language), systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } secondary: {
            VStack(spacing: 24) {
                if let health = healthCache.health {
                    HealthPartsPanel(health: health) { component in
                        run(component)
                    }
                }
                foldStatsCard
            }
        }
        .navigationTitle("FoldCheck")
        .onChange(of: records.map(\.payload), initial: true) { _, payloads in
            refreshHealth(payloads: payloads)
        }
        .onChange(of: hasHinge) { _, _ in
            refreshHealth(payloads: records.map(\.payload))
        }
        .task {
            hasHinge = foldStateProvider.state.hasHinge
            for await next in foldStateProvider.states() {
                // Layout observes the full fold state separately. The dashboard only needs
                // to know whether hinge-dependent parts apply, not every angle sample.
                if hasHinge != next.hasHinge { hasHinge = next.hasHinge }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showingFoldStats) {
            FoldStatsView()
        }
        .fullScreenCover(item: $inspectionRequest) { request in
            InspectionFlowView(request: request)
        }
    }

    private func refreshHealth(payloads: [Data]) {
        healthCache.update(payloads: payloads, context: DeviceInfo.context(foldState: foldStateProvider.state))
    }

    /// Starts a flow with the device context (model, OS, fold state) as it is right now,
    /// so `-FoldMock` launch arguments decide which tests apply.
    private func start(_ tests: [TestID]) {
        inspectionRequest = .current(tests: tests, foldState: foldStateProvider.state)
    }

    /// A part's tile runs its test; touch picks the grid for the display in use.
    private func run(_ component: HealthComponent) {
        switch component {
        case .touch:
            let context = DeviceInfo.context(foldState: foldStateProvider.state)
            start([InspectionPlan.quickTouchTest(for: context)])
        default:
            start(component.tests)
        }
    }

    private func lastInspectionLink(_ session: InspectionSession) -> some View {
        NavigationLink {
            if store.hasReports {
                InspectionSummaryView(session: session)
            } else {
                PaywallView()
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10nKey.homeLastInspection.text(in: language))
                        .font(.subheadline.bold())
                    Text(session.startedAt.formatted(date: .long, time: .omitted, in: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // A badge, not a second score: the ring's per-part score can differ from a
                // single inspection's.
                ResultBadge(outcome: session.overallStatus)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(minHeight: 44)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10nKey.homeSessionDetails.text(in: language))
        .accessibilityIdentifier("home.lastInspection")
    }

    private var foldStatsCard: some View {
        QuickActionCard(
            title: L10nKey.homeFoldStats.text(in: language),
            icon: "chart.bar.fill",
            description: L10nKey.homeFoldStatsDetail.text(in: language)
        ) {
            // F5 stats are part of the purchase; counting itself is always on.
            if store.hasReports {
                showingFoldStats = true
            } else {
                showingPaywall = true
            }
        }
        .accessibilityIdentifier("home.quick.foldStats")
    }
}

// MARK: - Supporting Views

struct ResultBadge: View {
    let outcome: TestOutcome
    @Environment(\.appLanguage) private var language
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: outcome.iconName)
            Text(outcome.localizedName(in: language))
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(outcomeColor.opacity(0.15), in: Capsule())
        .foregroundStyle(outcomeColor)
    }
    
    private var outcomeColor: Color {
        Self.color(for: outcome)
    }

    static func color(for outcome: TestOutcome) -> Color {
        InspectionStyle.color(for: outcome)
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let description: String
    var isEnabled = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                
                Text(title)
                    .font(.subheadline.bold())
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(description)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(for: StoredSession.self, inMemory: true)
    .environment(Store())
}
