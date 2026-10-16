import SwiftUI
import PDFKit
import FoldL10n
import TestsKit
import ReportKit

/// S6: signs the session, renders the PDF, saves it in Application Support/Reports, and
/// shows it with a share button. The report uses the report language from Settings.
struct ReportPreviewView: View {
    let session: InspectionSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.reportLanguage) private var language

    @State private var state: GenerationState = .generating

    enum GenerationState {
        case generating
        case ready(pdf: Data, file: URL, isDevelopmentKey: Bool)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .generating:
                    VStack(spacing: 16) {
                        ProgressView()
                        Text(L10nKey.reportGenerating.text(in: language))
                            .font(.headline)
                        Text(L10nKey.reportSigning.text(in: language))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                case .ready(let pdf, _, let isDevelopmentKey):
                    VStack(spacing: 0) {
                        if isDevelopmentKey {
                            Label(L10nKey.reportDevUnsigned.text(in: language), systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.15))
                                .accessibilityIdentifier("report.devBanner")
                        }
                        PDFPreview(data: pdf)
                            .accessibilityIdentifier("report.pdf")
                    }
                case .failed(let message):
                    ContentUnavailableView(
                        L10nKey.reportFailed.text(in: language),
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                }
            }
            .navigationTitle(L10nKey.reportPreviewTitle.text(in: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.paywallClose.text(in: language)) { dismiss() }
                        .accessibilityIdentifier("report.close")
                }
                if case .ready(_, let file, _) = state {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: file)
                            .accessibilityIdentifier("report.share")
                    }
                }
            }
        }
        .task { await generate() }
    }

    private func generate() async {
        do {
            let signer = try await SigningKeyStore.signer()
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
            let report = CanonicalReport.from(session: session, appVersion: version)
            let bundle = try await ReportBundle.sign(report, signer: signer)
            let content = ReportContentAssembler().assemble(
                session: session,
                envelope: bundle.envelope,
                language: language,
                generatedAt: report.generatedAt
            )
            let pdf = try ReportPDFRenderer(session: session, content: content, bundle: bundle, language: language).render()
            let file = try ReportFiles.save(pdf, reportID: report.reportID, generatedAt: report.generatedAt)
            state = .ready(pdf: pdf, file: file, isDevelopmentKey: signer.isDevelopmentKey)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

/// PDFKit view of the generated report.
private struct PDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}

#Preview {
    var session = InspectionSession(deviceModel: "iPhone Duo", osVersion: "iOS 27.1", hasHinge: true)
    session.setResult(TestResult(id: .touchGridOuter, outcome: .pass))
    session.setResult(TestResult(id: .hingeSweep, outcome: .attention, metrics: [TestMetricKey.maxGapDegrees: 15.5]))
    session.completedAt = Date()
    return ReportPreviewView(session: session)
}
