import SwiftUI
import SwiftData
import FoldL10n
import TestsKit
import Library
import Store

struct HistoryView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.modelContext) private var modelContext
    @Query(StoredSession.newestFirst) private var records: [StoredSession]
    @Environment(Store.self) private var store
    @State private var selectedSessions: Set<UUID> = []
    @State private var isComparing = false
    @State private var sheet: HistorySheet?

    /// One sheet at a time; separate `.sheet` modifiers on one view interfere.
    enum HistorySheet: Identifiable {
        case paywall
        case session(InspectionSession)
        case compare(SessionComparison)

        var id: String {
            switch self {
            case .paywall: return "paywall"
            case .session(let session): return "session-\(session.id)"
            case .compare(let comparison): return "compare-\(comparison.older.id)-\(comparison.newer.id)"
            }
        }
    }
    
    /// Saved sessions that still decode, newest first, each with its stored record.
    private var entries: [(record: StoredSession, session: InspectionSession)] {
        records.compactMap { record in record.session.map { (record, $0) } }
    }
    
    var body: some View {
        // Decode once per render; the list, the toolbar and the empty check all use it.
        let sessions = entries.map(\.session)
        Group {
            if sessions.isEmpty {
                emptyState
            } else if !store.hasReports {
                // F4 is part of the purchase. Sessions are still saved, so buying shows them all.
                lockedState(count: sessions.count)
            } else {
                sessionsList(sessions)
            }
        }
        .navigationTitle(L10nKey.historyTitle.text(in: language))
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .paywall:
                PaywallView()
            case .session(let session):
                NavigationStack {
                    InspectionSummaryView(session: session)
                        .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .shortened, in: language))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10nKey.testDone.text(in: language)) { self.sheet = nil }
                                    .accessibilityIdentifier("history.detail.done")
                            }
                        }
                }
            case .compare(let comparison):
                CompareView(comparison: comparison)
            }
        }
        .toolbar {
            if store.hasReports && sessions.count >= 2 {
                ToolbarItem(placement: .primaryAction) {
                    Button(isComparing ? L10nKey.historyDone.text(in: language) : L10nKey.historyCompare.text(in: language)) {
                        withAnimation {
                            isComparing.toggle()
                            if !isComparing {
                                selectedSessions.removeAll()
                            }
                        }
                    }
                    .accessibilityIdentifier("history.compare")
                }
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            L10nKey.historyEmptyTitle.text(in: language),
            systemImage: "clock",
            description: Text(L10nKey.historyEmptyDetail.text(in: language))
        )
    }
    
    private func lockedState(count: Int) -> some View {
        ContentUnavailableView {
            Label(L10nKey.historyLockedTitle.text(in: language), systemImage: "lock.fill")
                .accessibilityIdentifier("history.locked")
        } description: {
            Text(L10nKey.historyLockedDetail.text(in: language, count: count, one: .historyLockedDetailOne))
        } actions: {
            Button(L10nKey.historyUnlock.text(in: language)) { sheet = .paywall }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("history.unlock")
        }
    }

    private func sessionsList(_ sessions: [InspectionSession]) -> some View {
        List {
            ForEach(sessions) { session in
                SessionRow(
                    session: session,
                    isSelected: selectedSessions.contains(session.id),
                    isComparing: isComparing
                ) {
                    if isComparing {
                        toggleSelection(session.id)
                    } else {
                        sheet = .session(session)
                    }
                }
                .accessibilityIdentifier("history.row")
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottom) {
            if isComparing && selectedSessions.count == 2 {
                compareButton(sessions)
            }
        }
    }
    
    private func compareButton(_ sessions: [InspectionSession]) -> some View {
        Button {
            let picked = sessions.filter { selectedSessions.contains($0.id) }
            guard picked.count == 2 else { return }
            sheet = .compare(SessionComparison(picked[0], picked[1]))
        } label: {
            Label(L10nKey.historyCompareSelected.text(in: language), systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        .accessibilityIdentifier("history.compareSelected")
        .padding()
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedSessions.contains(id) {
            selectedSessions.remove(id)
        } else if selectedSessions.count < 2 {
            selectedSessions.insert(id)
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        let entries = self.entries
        let doomed = offsets.map { entries[$0] }
        for entry in doomed {
            selectedSessions.remove(entry.session.id)
        }
        try? SessionLibrary(context: modelContext).delete(doomed.map(\.record))
        // Compare needs two sessions; leave the mode when fewer remain.
        if entries.count - doomed.count < 2 {
            isComparing = false
            selectedSessions.removeAll()
        }
    }
}

struct SessionRow: View {
    let session: InspectionSession
    let isSelected: Bool
    let isComparing: Bool
    let onTap: () -> Void
    @Environment(\.appLanguage) private var language
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if isComparing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt.formatted(date: .long, time: .omitted, in: language))
                        .font(.headline)
                    
                    HStack(spacing: 8) {
                        ResultBadge(outcome: session.overallStatus)
                        
                        if let score = session.overallScore {
                            Text("\(score)/100")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text(session.deviceModel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if !isComparing {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            // The plain style only hit-tests drawn content; make the Spacer tappable too.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: StoredSession.self, inMemory: true)
    .environment(Store())
}
