import XCTest
import PDFKit
import CoreImage
@testable import FoldCheck
import FoldL10n
import TestsKit
import ReportKit

/// AC4: the PDF carries device model, OS, date and time zone, every result, the disclaimer
/// and a QR code, and the embedded signed data verifies until any byte of it changes.
final class ReportPDFTests: XCTestCase {
    private func session() -> InspectionSession {
        var session = InspectionSession(
            deviceModel: "iPhone Duo (Simulator)",
            osVersion: "iOS 27.1",
            storageCapacity: 256_000_000_000,
            hasHinge: true,
            timeZoneIdentifier: "America/Toronto"
        )
        session.setResult(TestResult(id: .pixels, outcome: .pass, metrics: [TestMetricKey.issuesMarked: 0]))
        session.setResult(TestResult(
            id: .hingeSweep,
            outcome: .attention,
            metrics: [TestMetricKey.maxGapDegrees: 25, TestMetricKey.monotonicFraction: 0.9],
            notes: "A 25° gap during sweep 1.",
            series: (0..<20).map { TestSeriesPoint(t: Double($0) * 0.1, value: Double($0) * 9, segment: 0) }
        ))
        session.setResult(TestResult(id: .cameras, outcome: .unavailable, notes: "No cameras were found."))
        session.completedAt = Date()
        return session
    }

    private func makePDF(language: AppLanguage = .en) async throws -> (pdf: Data, bundle: ReportBundle, key: Data) {
        let signer = SoftwareReportSigner()
        let session = session()
        let report = CanonicalReport.from(session: session)
        let bundle = try await ReportBundle.sign(report, signer: signer)
        let content = ReportContentAssembler().assemble(session: session, envelope: bundle.envelope, language: language, generatedAt: report.generatedAt)
        let pdf = try await MainActor.run {
            try ReportPDFRenderer(session: session, content: content, bundle: bundle, language: language).render()
        }
        return (pdf, bundle, try await signer.getPublicKey())
    }

    func testPDFContainsRequiredContent() async throws {
        let (pdf, _, _) = try await makePDF()
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        let text = try XCTUnwrap(document.string)
        for expected in ["iPhone Duo (Simulator)", "iOS 27.1", "America/Toronto", "Pixels & Uniformity", "Hinge Sweep",
                         "Cameras", "Attention", "A 25° gap during sweep 1.", "DISCLAIMER", "SHA-256"] {
            XCTAssertTrue(text.contains(expected), "Missing \(expected)")
        }
        XCTAssertEqual(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String, "FoldCheck")
    }

    func testEmbeddedBundleVerifiesAndDetectsTampering() async throws {
        let (pdf, bundle, key) = try await makePDF()
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        let subject = document.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String
        guard case .valid(let report, _, .thisDevice) = ReportVerifier.verify(pdfMetadata: subject, ownPublicKey: key) else {
            return XCTFail("Expected a valid report signed on this device")
        }
        XCTAssertEqual(report.results.count, 3)

        var tampered = bundle
        tampered.canonicalJSON[tampered.canonicalJSON.count / 3] ^= 0x20
        XCTAssertEqual(
            ReportVerifier.verify(pdfMetadata: try tampered.pdfMetadataString(), ownPublicKey: key),
            .invalid(.contentChanged)
        )
    }

    func testQRCodeOnThePageDecodesToTheEnvelope() async throws {
        let (pdf, bundle, key) = try await makePDF()
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        let lastPage = try XCTUnwrap(document.page(at: document.pageCount - 1))
        let image = lastPage.thumbnail(of: CGSize(width: 1224, height: 1584), for: .mediaBox)
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil))
        let features = detector.features(in: try XCTUnwrap(CIImage(image: image))).compactMap { $0 as? CIQRCodeFeature }
        let payload = try XCTUnwrap(features.first?.messageString)
        XCTAssertEqual(payload, try bundle.envelope.toQRPayload())
        XCTAssertEqual(ReportVerifier.verify(qrPayload: payload, ownPublicKey: key), .signatureValid(envelope: bundle.envelope, signer: .thisDevice))
    }

    func testReportRendersInChinese() async throws {
        let (pdf, _, _) = try await makePDF(language: .zhHans)
        let text = try XCTUnwrap(PDFDocument(data: pdf)?.string)
        XCTAssertTrue(text.contains(L10nKey.reportTitle.text(in: .zhHans)))
        XCTAssertTrue(text.contains(L10nKey.testHingeSweep.text(in: .zhHans)))
    }
}
