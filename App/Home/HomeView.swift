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
    @State private var inspectionRequest: InspectionRequest?
    @State private var showingFoldStats = false
    @State private var showingPaywall = false
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        InspectionPanels {
            VStack(spacing: 24) {
                headerSection
                startInspectionButton
                Label(L10nKey.homeLocal.text(in: language), systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } secondary: {
            VStack(spacing: 24) {
                if let session = latestFull.first?.session {
                    lastResultSection(session)
                }
                quickActionsSection
            }
        }
        .navigationTitle("FoldCheck")
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
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "stethoscope")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            
            Text(L10nKey.homeHeadline.text(in: language))
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            
            Text(L10nKey.homeSubtitle.text(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var startInspectionButton: some View {
        Button {
            start(TestID.defaultOrder)
        } label: {
            Label(L10nKey.homeStart.text(in: language), systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(InspectionStyle.buttonFill, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("home.start")
    }

    /// Starts a flow with the device context (model, OS, fold state) as it is right now,
    /// so `-FoldMock` launch arguments decide which tests apply.
    private func start(_ tests: [TestID]) {
        inspectionRequest = .current(tests: tests, foldState: foldStateProvider.state)
    }
    
    @ViewBuilder
    private func lastResultSection(_ session: InspectionSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.homeLastInspection.text(in: language))
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt.formatted(date: .long, time: .omitted, in: language))
                        .font(.subheadline)
                    
                    HStack(spacing: 8) {
                        ResultBadge(outcome: session.overallStatus)
                        
                        if let score = session.overallScore {
                            Text("\(score)/100")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                NavigationLink {
                    if store.hasReports {
                        InspectionSummaryView(session: session)
                    } else {
                        PaywallView()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(L10nKey.homeSessionDetails.text(in: language))
                .accessibilityIdentifier("home.lastInspection")
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.homeQuickActions.text(in: language))
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                QuickActionCard(
                    title: L10nKey.homeHingeCheck.text(in: language),
                    icon: "arrow.triangle.2.circlepath",
                    description: L10nKey.homeHingeCheckDetail.text(in: language)
                ) {
                    start([.hingeSweep])
                }
                .accessibilityIdentifier("home.quick.hinge")
                
                QuickActionCard(
                    title: L10nKey.homeTouchTest.text(in: language),
                    icon: "hand.tap.fill",
                    description: L10nKey.homeTouchTestDetail.text(in: language)
                ) {
                    let context = DeviceInfo.context(foldState: foldStateProvider.state)
                    start([InspectionPlan.quickTouchTest(for: context)])
                }
                .accessibilityIdentifier("home.quick.touch")
                
                QuickActionCard(
                    title: L10nKey.homeScreenTest.text(in: language),
                    icon: "rectangle.fill",
                    description: L10nKey.homeScreenTestDetail.text(in: language)
                ) {
                    start([.pixels])
                }
                .accessibilityIdentifier("home.quick.screen")
                
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
