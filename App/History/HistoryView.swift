import SwiftUI
import SwiftData
import FoldL10n
import TestsKit
import Library

struct HistoryView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.modelContext) private var modelContext
    @Query(StoredSession.newestFirst) private var records: [StoredSession]
    @State private var selectedSessions: Set<UUID> = []
    @State private var isComparing = false
    
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
            } else {
                sessionsList(sessions)
            }
        }
        .navigationTitle(L10nKey.historyTitle.text(in: language))
        .toolbar {
            if sessions.count >= 2 {
                ToolbarItem(placement: .primaryAction) {
                    Button(isComparing ? L10nKey.historyDone.text(in: language) : L10nKey.historyCompare.text(in: language)) {
                        withAnimation {
                            isComparing.toggle()
                            if !isComparing {
                                selectedSessions.removeAll()
                            }
                        }
                    }
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
                    }
                }
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .bottom) {
            if isComparing && selectedSessions.count == 2 {
                compareButton
            }
        }
    }
    
    private var compareButton: some View {
        Button {
            // TODO: Show comparison view
        } label: {
            Label(L10nKey.historyCompareSelected.text(in: language), systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
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
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if isComparing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.startedAt, style: .date)
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
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: StoredSession.self, inMemory: true)
}
