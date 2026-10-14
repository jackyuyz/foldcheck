import SwiftUI
import TestsKit
import ReportKit

struct InspectionSummaryView: View {
    let session: InspectionSession
    @State private var showingPaywall = false
    @State private var showingReport = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryHeader
                
                scoreCard
                
                resultsList
                
                actionButtons
            }
            .padding()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingReport) {
            ReportPreviewView(session: session)
        }
    }
    
    private var summaryHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: session.overallStatus.iconName)
                .font(.system(size: 60))
                .foregroundStyle(statusColor)
            
            Text("Inspection Complete")
                .font(.title2.bold())
            
            if let duration = session.durationString {
                Text("Completed in \(duration)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var scoreCard: some View {
        VStack(spacing: 8) {
            if let score = session.overallScore {
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                
                Text("out of 100")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 20) {
                ScoreStatView(count: session.passCount, label: "Pass", color: .green)
                ScoreStatView(count: session.attentionCount, label: "Attention", color: .orange)
                ScoreStatView(count: session.failCount, label: "Fail", color: .red)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Results")
                .font(.headline)
            
            ForEach(session.results) { result in
                TestResultRow(result: result)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                // TODO: Check if user has purchased reports
                showingPaywall = true
            } label: {
                Label("Create PDF Report", systemImage: "doc.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            
            Button {
                // TODO: Save session
            } label: {
                Label("Save to History", systemImage: "clock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
            }
        }
    }
    
    private var statusColor: Color {
        switch session.overallStatus {
        case .pass: return .green
        case .attention: return .orange
        case .fail: return .red
        case .skipped, .notApplicable: return .gray
        }
    }
}

// MARK: - Supporting Views

struct ScoreStatView: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TestResultRow: View {
    let result: TestResult
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.id.displayName)
                    .font(.subheadline.bold())
                
                if let display = result.display {
                    Text(display.rawValue.capitalized + " display")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            ResultBadge(outcome: result.outcome)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    var session = InspectionSession(
        deviceModel: "iPhone 19 Duo",
        osVersion: "iOS 27.0",
        hasHinge: true
    )
    session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
    session.setResult(TestResult(id: .touchGridInner, outcome: .pass))
    session.setResult(TestResult(id: .pixels, outcome: .pass))
    session.setResult(TestResult(id: .hingeSweep, outcome: .attention))
    session.setResult(TestResult(id: .cameras, outcome: .pass))
    session.completedAt = Date()
    
    return InspectionSummaryView(session: session)
}
