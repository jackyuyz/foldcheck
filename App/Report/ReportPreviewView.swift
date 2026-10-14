import SwiftUI
import TestsKit
import ReportKit

struct ReportPreviewView: View {
    let session: InspectionSession
    @Environment(\.dismiss) private var dismiss
    
    @State private var isGenerating = true
    @State private var reportContent: ReportContent?
    @State private var pdfData: Data?
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            Group {
                if isGenerating {
                    generatingView
                } else if let content = reportContent {
                    reportPreview(content)
                } else if let error = error {
                    errorView(error)
                }
            }
            .navigationTitle("Report Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if pdfData != nil {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: pdfData!, preview: SharePreview("FoldCheck Report"))
                    }
                }
            }
        }
        .task {
            await generateReport()
        }
    }
    
    private var generatingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Generating Report...")
                .font(.headline)
            
            Text("Signing with Secure Enclave")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func reportPreview(_ content: ReportContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(content.title)
                        .font(.title2.bold())
                    
                    Text("Report ID: \(content.reportID.prefix(8))...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    
                    Text("Generated: \(content.generatedAt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Device Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Device Information")
                        .font(.headline)
                    
                    InfoGrid(items: [
                        ("Model", content.deviceModel),
                        ("Type", content.deviceType),
                        ("iOS Version", content.osVersion),
                        ("Storage", content.storageCapacity ?? "Unknown")
                    ])
                }
                
                Divider()
                
                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inspection Summary")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text(content.overallStatus)
                                .font(.title3.bold())
                                .foregroundStyle(statusColor(for: content.overallStatus))
                            Text("Status")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let score = content.overallScore {
                            VStack {
                                Text(score)
                                    .font(.title3.bold())
                                Text("Score")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let duration = content.inspectionDuration {
                            VStack {
                                Text(duration)
                                    .font(.title3.bold())
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Test Results
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Results")
                        .font(.headline)
                    
                    ForEach(Array(content.testResults.enumerated()), id: \.offset) { _, result in
                        TestResultPreviewRow(result: result)
                    }
                }
                
                Divider()
                
                // Signature
                VStack(alignment: .leading, spacing: 8) {
                    Text("Digital Signature")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "signature")
                            .foregroundStyle(.tint)
                        Text(content.signatureStatus)
                            .font(.subheadline)
                    }
                    
                    if let fingerprint = content.keyFingerprint {
                        Text("Key: \(fingerprint)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Disclaimer
                Text(content.disclaimer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView(
            "Generation Failed",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription)
        )
    }
    
    private func generateReport() async {
        do {
            let assembler = ReportContentAssembler()
            let signer = SoftwareReportSigner()
            
            let report = CanonicalReport.from(session: session)
            let envelope = try await signReport(report, signer: signer)
            
            let content = assembler.assemble(session: session, envelope: envelope)
            
            // TODO: Generate actual PDF data using PDFKit/UIGraphicsPDFRenderer
            // For now, we just show the preview
            
            await MainActor.run {
                self.reportContent = content
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isGenerating = false
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pass": return .green
        case "attention": return .orange
        case "fail": return .red
        default: return .gray
        }
    }
}

struct InfoGrid: View {
    let items: [(String, String)]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.1)
                        .font(.subheadline)
                }
            }
        }
    }
}

struct TestResultPreviewRow: View {
    let result: TestResultContent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.testName)
                    .font(.subheadline.bold())
                Spacer()
                Text(result.outcome)
                    .font(.caption.bold())
                    .foregroundStyle(outcomeColor)
            }
            
            if !result.metrics.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(result.metrics.prefix(3)), id: \.name) { metric in
                        Text("\(metric.name): \(metric.value)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let notes = result.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
    
    private var outcomeColor: Color {
        switch result.outcomeColor {
        case "green": return .green
        case "amber": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

#Preview {
    var session = InspectionSession(
        deviceModel: "iPhone 19 Duo",
        osVersion: "iOS 27.0",
        hasHinge: true
    )
    session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
    session.setResult(TestResult(id: .hingeSweep, outcome: .attention, metrics: ["maxGap": 15.5]))
    session.completedAt = Date()
    
    return ReportPreviewView(session: session)
}
