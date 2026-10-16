import SwiftUI
import PDFKit
import VisionKit
import UniformTypeIdentifiers
import FoldL10n
import TestsKit
import ReportKit

/// S8: checks a FoldCheck report offline. Importing the PDF checks its embedded content
/// against the signature; scanning the QR code checks only the signature. Either way it
/// proves the report wasn't changed after signing, not that the device is genuine.
struct VerifyView: View {
    @Environment(\.appLanguage) private var language
    @State private var verification: ReportVerification?
    @State private var isScanning = false
    @State private var isImporting = false
    @State private var importFailed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                actionButtons
                if importFailed {
                    resultCard(icon: "xmark.seal.fill", color: .red, title: L10nKey.verifyInvalid.text(in: language)) {
                        Text(L10nKey.verifyImportFailed.text(in: language))
                    }
                } else if let verification {
                    resultSection(verification)
                }
                explanationSection
            }
            .padding()
        }
        .navigationTitle(L10nKey.verifyTitle.text(in: language))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.pdf]) { result in
            Task { await importPDF(result) }
        }
        .sheet(isPresented: $isScanning) {
            QRScannerSheet { payload in
                isScanning = false
                Task { await verifyQR(payload) }
            }
        }
    }

    // MARK: Actions

    private func importPDF(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let document = PDFDocument(url: url) else {
            importFailed = true
            verification = nil
            return
        }
        let subject = document.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String
        importFailed = false
        verification = ReportVerifier.verify(pdfMetadata: subject, ownPublicKey: await SigningKeyStore.existingPublicKey())
    }

    private func verifyQR(_ payload: String) async {
        importFailed = false
        verification = ReportVerifier.verify(qrPayload: payload, ownPublicKey: await SigningKeyStore.existingPublicKey())
    }

    // MARK: Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text(L10nKey.verifyHeadline.text(in: language))
                .font(.title3.bold())
            Text(L10nKey.verifySubtitle.text(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                isImporting = true
            } label: {
                Label(L10nKey.verifyImport.text(in: language), systemImage: "doc.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("verify.import")

            Button {
                isScanning = true
            } label: {
                Label(L10nKey.verifyScan.text(in: language), systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityIdentifier("verify.scan")
        }
    }

    @ViewBuilder
    private func resultSection(_ verification: ReportVerification) -> some View {
        switch verification {
        case .valid(let report, let envelope, let signer):
            resultCard(icon: "checkmark.seal.fill", color: .green, title: L10nKey.verifyValid.text(in: language)) {
                InfoRow(label: L10nKey.verifyReportID.text(in: language), value: String(envelope.reportID.uuidString.prefix(8)))
                signerRows(signer, envelope: envelope)
                InfoRow(label: L10nKey.verifyDevice.text(in: language), value: report.deviceModel)
                InfoRow(label: L10nKey.verifyDate.text(in: language), value: report.generatedAt.formatted(date: .abbreviated, time: .shortened, in: language))
                Divider()
                ForEach(Array(report.results.enumerated()), id: \.offset) { _, result in
                    InfoRow(label: testName(result.testID, hasHinge: report.hasHinge), value: outcomeName(result.outcome))
                }
                Text(L10nKey.verifyCompareHint.text(in: language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("verify.result.valid")
        case .signatureValid(let envelope, let signer):
            resultCard(icon: "checkmark.seal", color: .green, title: L10nKey.verifyQrValid.text(in: language)) {
                InfoRow(label: L10nKey.verifyReportID.text(in: language), value: String(envelope.reportID.uuidString.prefix(8)))
                signerRows(signer, envelope: envelope)
                Text(L10nKey.verifyQrOnlyExplain.text(in: language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("verify.result.signature")
        case .invalid(let failure):
            resultCard(icon: "xmark.seal.fill", color: .red, title: L10nKey.verifyInvalid.text(in: language)) {
                Text(reason(for: failure))
            }
            .accessibilityIdentifier("verify.result.invalid")
        }
    }

    @ViewBuilder
    private func signerRows(_ signer: ReportSignerIdentity, envelope: ReportEnvelope) -> some View {
        switch signer {
        case .thisDevice:
            InfoRow(label: L10nKey.verifySignedBy.text(in: language), value: L10nKey.verifyThisDevice.text(in: language))
        case .anotherDevice(let fingerprint):
            InfoRow(label: L10nKey.verifySignedBy.text(in: language), value: L10nKey.verifyAnotherDevice.text(in: language))
            InfoRow(label: L10nKey.verifyFingerprint.text(in: language), value: fingerprint)
        }
        if envelope.isDevelopmentBuild {
            InfoRow(label: L10nKey.verifyDevNote.text(in: language), value: L10nKey.reportDevUnsigned.text(in: language))
                .foregroundStyle(.orange)
        }
    }

    private func resultCard<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(color)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10nKey.verifyWhat.text(in: language))
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                BulletPoint(text: L10nKey.verifyCheckUnmodified.text(in: language))
                BulletPoint(text: L10nKey.verifyCheckInstall.text(in: language))
                BulletPoint(icon: "xmark.circle", color: .red, text: L10nKey.verifyNotGenuine.text(in: language))
                BulletPoint(icon: "xmark.circle", color: .red, text: L10nKey.verifyNotAccuracy.text(in: language))
            }
            .font(.subheadline)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Text

    private func reason(for failure: ReportVerification.Failure) -> String {
        switch failure {
        case .unreadable: return L10nKey.verifyUnreadable.text(in: language)
        case .contentChanged: return L10nKey.verifyContentChanged.text(in: language)
        case .badSignature: return L10nKey.verifyBadSignature.text(in: language)
        }
    }

    private func testName(_ rawValue: String, hasHinge: Bool) -> String {
        TestID(rawValue: rawValue)?.localizedName(in: language, hasHinge: hasHinge) ?? rawValue
    }

    private func outcomeName(_ rawValue: String) -> String {
        TestOutcome(rawValue: rawValue)?.localizedName(in: language) ?? rawValue
    }
}

// MARK: - QR scanning

/// Scans one QR code with VisionKit and returns its text.
private struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    QRScanner(onScan: onScan)
                        .ignoresSafeArea()
                } else {
                    ContentUnavailableView(
                        L10nKey.verifyScan.text(in: language),
                        systemImage: "camera.metering.unknown",
                        description: Text(L10nKey.verifyScanUnavailable.text(in: language))
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10nKey.paywallClose.text(in: language)) { dismiss() }
                }
            }
        }
    }
}

private struct QRScanner: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var done = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for case .barcode(let barcode) in addedItems {
                guard !done, let payload = barcode.payloadStringValue else { continue }
                done = true
                dataScanner.stopScanning()
                onScan(payload)
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospaced())
                .multilineTextAlignment(.trailing)
        }
    }
}

struct BulletPoint: View {
    var icon: String = "checkmark.circle"
    var color: Color = .green
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
        }
    }
}

#Preview {
    NavigationStack {
        VerifyView()
    }
}
