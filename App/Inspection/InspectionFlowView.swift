import SwiftUI
import FoldKit
import FoldL10n
import TestsKit

struct InspectionFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foldStateProvider) private var foldStateProvider
    @Environment(\.appLanguage) private var language
    
    @State private var session: InspectionSession
    @State private var currentTestIndex = 0
    @State private var isCompleted = false
    
    private let applicableTests: [TestID]
    
    init() {
        // Initialize with placeholder device info
        // Real implementation would get this from UIDevice
        let hasHinge = false  // Will be determined from foldStateProvider
        _session = State(initialValue: InspectionSession(
            deviceModel: "iPhone",
            osVersion: "iOS 27.0",
            hasHinge: hasHinge
        ))
        applicableTests = TestID.defaultOrder.filter { test in
            !test.requiresHinge || hasHinge
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader
                
                if isCompleted {
                    InspectionSummaryView(session: session)
                } else if currentTestIndex < applicableTests.count {
                    testView(for: applicableTests[currentTestIndex])
                }
            }
            .navigationTitle(L10nKey.inspectionTitle.text(in: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.inspectionCancel.text(in: language)) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(
                value: Double(currentTestIndex),
                total: Double(applicableTests.count)
            )
            .tint(.green)
            
            HStack {
                Text(L10nKey.inspectionProgress.text(in: language, currentTestIndex + 1, applicableTests.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !isCompleted && currentTestIndex < applicableTests.count {
                    Text(applicableTests[currentTestIndex].localizedName(in: language))
                        .font(.caption.bold())
                }
            }
        }
        .padding()
        .background(.bar)
    }
    
    @ViewBuilder
    private func testView(for testID: TestID) -> some View {
        TestContainerView(
            testID: testID,
            onComplete: { result in
                session.setResult(result)
                advanceToNextTest()
            },
            onSkip: {
                session.setResult(.skipped(id: testID))
                advanceToNextTest()
            }
        )
    }
    
    private func advanceToNextTest() {
        if currentTestIndex + 1 < applicableTests.count {
            withAnimation {
                currentTestIndex += 1
            }
        } else {
            session.completedAt = Date()
            withAnimation {
                isCompleted = true
            }
        }
    }
}

// MARK: - Test Container View

struct TestContainerView: View {
    let testID: TestID
    let onComplete: (TestResult) -> Void
    let onSkip: () -> Void
    @Environment(\.appLanguage) private var language
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: iconName(for: testID))
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                
                Text(testID.localizedName(in: language))
                    .font(.title2.bold())
                
                Text(testID.localizedDescription(in: language))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    // TODO: Run actual test
                    // For now, simulate a pass result
                    let result = TestResult(
                        id: testID,
                        outcome: .pass,
                        metrics: [:],
                        notes: ""
                    )
                    onComplete(result)
                } label: {
                    Text(L10nKey.inspectionStartTest.text(in: language))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                
                Button {
                    onSkip()
                } label: {
                    Text(L10nKey.inspectionSkip.text(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    private func iconName(for testID: TestID) -> String {
        switch testID {
        case .touchGridOuter, .touchGridInner: return "hand.tap.fill"
        case .pixels: return "rectangle.grid.3x2.fill"
        case .crease: return "line.diagonal"
        case .hingeSweep: return "arrow.triangle.2.circlepath"
        case .cameras: return "camera.fill"
        case .audio: return "speaker.wave.3.fill"
        case .touchID: return "touchid"
        case .sensors: return "gyroscope"
        case .buttons: return "plus.minus"
        }
    }
}

// MARK: - Preview

#Preview {
    InspectionFlowView()
}
