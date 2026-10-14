import SwiftUI
import FoldKit
import TestsKit

struct HomeView: View {
    @Environment(\.foldStateProvider) private var foldStateProvider
    @State private var lastSession: InspectionSession?
    @State private var showingInspection = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                startInspectionButton
                
                if let session = lastSession {
                    lastResultSection(session)
                }
                
                quickActionsSection
            }
            .padding()
        }
        .navigationTitle("FoldCheck")
        .sheet(isPresented: $showingInspection) {
            InspectionFlowView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "stethoscope")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            
            Text("Foldable Inspector")
                .font(.title2.bold())
            
            Text("Complete health check for your foldable iPhone")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    private var startInspectionButton: some View {
        Button {
            showingInspection = true
        } label: {
            Label("Start Inspection", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }
    
    @ViewBuilder
    private func lastResultSection(_ session: InspectionSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Inspection")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt, style: .date)
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
                    // TODO: Session detail view
                    Text("Session Details")
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionCard(
                    title: "Hinge Check",
                    icon: "arrow.triangle.2.circlepath",
                    description: "Test hinge only"
                ) {
                    // TODO: Quick hinge test
                }
                
                QuickActionCard(
                    title: "Touch Test",
                    icon: "hand.tap.fill",
                    description: "Test touch grid"
                ) {
                    // TODO: Quick touch test
                }
                
                QuickActionCard(
                    title: "Screen Test",
                    icon: "rectangle.fill",
                    description: "Check pixels"
                ) {
                    // TODO: Quick screen test
                }
                
                QuickActionCard(
                    title: "Fold Stats",
                    icon: "chart.bar.fill",
                    description: "View session stats"
                ) {
                    // TODO: Fold stats view
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ResultBadge: View {
    let outcome: TestOutcome
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: outcome.iconName)
            Text(outcome.displayName)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(outcomeColor.opacity(0.15), in: Capsule())
        .foregroundStyle(outcomeColor)
    }
    
    private var outcomeColor: Color {
        switch outcome {
        case .pass: return .green
        case .attention: return .orange
        case .fail: return .red
        case .skipped, .notApplicable: return .gray
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let description: String
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
            .frame(maxWidth: .infinity)
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HomeView()
    }
}
