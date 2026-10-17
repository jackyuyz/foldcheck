import XCTest
import PDFKit
import CoreImage
import SwiftData
import Library
@testable import FoldCheck
import FoldL10n
import TestsKit
import ReportKit

/// AC4: the PDF carries device model, OS, date and time zone, every result, the disclaimer
/// and a QR code, and the embedded signed data verifies until any byte of it changes.
final class ReportPDFTests: XCTestCase {
    @MainActor
    func testTouchHeatmapSurvivesSigningAndPDFRendering() async throws {
        let layout = TouchGridLayout(size: CGSize(width: 400, height: 800), spec: .duoInner, includeCreaseBand: false)
        var grid = TouchGridSession(layout: layout)
        grid.touch(at: CGPoint(x: 20, y: 20))
        var inspection = session()
        inspection.setResult(grid.result(id: .touchGridOuter, display: .outer))
        let signer = SoftwareReportSigner()
        let report = CanonicalReport.from(session: inspection)
        let bundle = try await ReportBundle.sign(report, signer: signer)
        let decoded = try bundle.report()
        XCTAssertEqual(decoded.results.first { $0.testID == TestID.touchGridOuter.rawValue }?.touchHeatmap,
                       inspection.results.first { $0.id == .touchGridOuter }?.touchHeatmap)
        let content = ReportContentAssembler().assemble(session: inspection, envelope: bundle.envelope, language: .en)
        let pdf = try ReportPDFRenderer(session: inspection, content: content, bundle: bundle, language: .en).render()
        let document = try XCTUnwrap(PDFDocument(data: pdf))
        XCTAssertTrue(try XCTUnwrap(document.string).contains("Touch map (grid at start)"))
        let mapPage = try XCTUnwrap((0..<document.pageCount).compactMap { document.page(at: $0) }.first { $0.string?.contains("Touch map (grid at start)") == true })
        XCTAssertTrue(try XCTUnwrap(mapPage.string).contains(TestID.touchGridOuter.localizedName(in: .en, hasHinge: true)),
                      "A map that moves to another page must retain its component label")
        let image = mapPage.thumbnail(of: CGSize(width: 1224, height: 1584), for: .mediaBox)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Touch-heatmap-report"
        attachment.lifetime = .keepAlways
        add(attachment)
        let key = try await signer.getPublicKey()
        guard case .valid = ReportVerifier.verify(bundle, ownPublicKey: key) else { return XCTFail("Heatmap bundle must verify") }
        var changed = report
        let index = try XCTUnwrap(changed.results.firstIndex { $0.testID == TestID.touchGridOuter.rawValue })
        changed.results[index].touchHeatmap?.cells[0].covered.toggle()
        let tampered = ReportBundle(canonicalJSON: try changed.toCanonicalJSON(), envelope: bundle.envelope)
        XCTAssertEqual(ReportVerifier.verify(tampered, ownPublicKey: key), .invalid(.contentChanged))
    }
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
    @MainActor
    func testM7BilingualReportPagesForVisualReview() async throws {
        #if DEBUG
        let container = try ModelContainer(for: StoredSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        try ScreenshotFixtures.populate(container)
        let sessions = try SessionLibrary(context: ModelContext(container)).sessions()
        let session = try XCTUnwrap(sessions.first)
        for language in [AppLanguage.en, .zhHans] {
            let signer = SoftwareReportSigner()
            let report = CanonicalReport.from(session: session)
            let bundle = try await ReportBundle.sign(report, signer: signer)
            let content = ReportContentAssembler().assemble(session: session, envelope: bundle.envelope, language: language)
            let pdf = try ReportPDFRenderer(session: session, content: content, bundle: bundle, language: language).render()
            let document = try XCTUnwrap(PDFDocument(data: pdf))
            let text = try XCTUnwrap(document.string)
            for result in session.results {
                XCTAssertTrue(text.contains(result.id.localizedName(in: language, hasHinge: true)))
            }
            let compactText = text.filter { !$0.isWhitespace }
            let disclaimerPrefix = String(L10nKey.reportDisclaimer.text(in: language).filter { !$0.isWhitespace }.prefix(24))
            XCTAssertTrue(compactText.contains(disclaimerPrefix), "Missing disclaimer in \(language.rawValue)")
            XCTAssertTrue(text.contains("SHA-256"))
            let file = XCTAttachment(data: pdf, uniformTypeIdentifier: "com.adobe.pdf")
            file.name = "M7-\(language.rawValue)-sample-report"
            file.lifetime = .keepAlways
            add(file)
            for index in 0..<document.pageCount {
                let page = try XCTUnwrap(document.page(at: index))
                let image = page.thumbnail(of: CGSize(width: 1224, height: 1584), for: .mediaBox)
                let attachment = XCTAttachment(image: image)
                attachment.name = "M7-\(language.rawValue)-PDF-page-\(index + 1)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        #endif
    }

}
