import SwiftUI
import FoldL10n
import TestsKit

struct HistoryView: View {
    @Environment(\.appLanguage) private var language
    @State private var sessions: [InspectionSession] = []
    @State private var selectedSessions: Set<UUID> = []
    @State private var isComparing = false
    
    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                sessionsList
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
    
    private var sessionsList: some View {
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
        sessions.remove(atOffsets: offsets)
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
                        .foregroundStyle(isSelected ? .tint : .secondary)
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
}
