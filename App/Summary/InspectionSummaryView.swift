import SwiftUI
import SwiftData
import FoldL10n
import TestsKit
import ReportKit
import Library

struct InspectionSummaryView: View {
    let session: InspectionSession
    let isFullInspection: Bool
    @Environment(\.appLanguage) private var language
    @Environment(\.modelContext) private var modelContext
    /// The saved copy of this session: non-empty once it is in History (auto-saved or by the button).
    @Query private var savedCopies: [StoredSession]
    @State private var showingPaywall = false
    @State private var showingReport = false
    @State private var saveFailed = false
    
    init(session: InspectionSession, isFullInspection: Bool = false) {
        self.session = session
        self.isFullInspection = isFullInspection
        _savedCopies = Query(StoredSession.withID(session.id))
    }
    
    private var isSaved: Bool { !savedCopies.isEmpty }
    
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
            
            Text(L10nKey.summaryComplete.text(in: language))
                .font(.title2.bold())
            
            if let duration = session.durationString {
                Text(L10nKey.summaryCompletedIn.text(in: language, duration))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(verbatim: "\(session.deviceModel) · \(session.osVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("summary.device")
        }
    }
    
    private var scoreCard: some View {
        VStack(spacing: 8) {
            if let score = session.overallScore {
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(statusColor)
                
                Text(L10nKey.summaryOutOf100.text(in: language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 20) {
                ScoreStatView(count: session.passCount, label: L10nKey.outcomePass.text(in: language), color: .green)
                ScoreStatView(count: session.attentionCount, label: L10nKey.outcomeAttention.text(in: language), color: .orange)
                ScoreStatView(count: session.failCount, label: L10nKey.outcomeFail.text(in: language), color: .red)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.summaryResults.text(in: language))
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
                Label(L10nKey.summaryCreateReport.text(in: language), systemImage: "doc.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            
            Button(action: saveToHistory) {
                if isSaved {
                    Label(L10nKey.summarySaved.text(in: language), systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Label(L10nKey.summarySaveHistory.text(in: language), systemImage: "clock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }
            .disabled(isSaved)
            .accessibilityIdentifier("summary.save")
            
            if saveFailed && !isSaved {
                Text(L10nKey.summarySaveFailed.text(in: language))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
    
    private func saveToHistory() {
        do {
            try SessionLibrary(context: modelContext).save(session, isFullInspection: isFullInspection)
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }
    
    private var statusColor: Color {
        switch session.overallStatus {
        case .pass: return .green
        case .attention: return .orange
        case .fail: return .red
        case .skipped, .notApplicable, .unavailable: return .gray
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
    @Environment(\.appLanguage) private var language
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.id.localizedName(in: language))
                    .font(.subheadline.bold())
                
                if let display = result.display {
                    Text(display.localizedName(in: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let metrics = ResultMetricsFormatter.summary(for: result, language: language) {
                    Text(metrics)
                        .font(.caption.monospacedDigit())
                }

                if !result.notes.isEmpty {
                    Text(result.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            
            Spacer()
            
            ResultBadge(outcome: result.outcome)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary.row.\(result.id.rawValue)")
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
        .modelContainer(for: StoredSession.self, inMemory: true)
}
