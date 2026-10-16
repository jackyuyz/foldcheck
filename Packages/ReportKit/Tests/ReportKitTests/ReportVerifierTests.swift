import Testing
import Foundation
@testable import ReportKit
import TestsKit

@Suite("Report verification (AC4)")
struct ReportVerifierTests {
    private func report() -> CanonicalReport {
        var session = InspectionSession(deviceModel: "iPhone Duo", osVersion: "iOS 27.1", hasHinge: true)
        session.setResult(TestResult(id: .hingeSweep, outcome: .attention, metrics: [TestMetricKey.maxGapDegrees: 25.5], notes: "Gap at 90°"))
        session.setResult(TestResult(id: .pixels, outcome: .pass))
        session.completedAt = Date()
        return CanonicalReport.from(session: session)
    }

    private func ownKey(_ signer: SoftwareReportSigner) async throws -> Data {
        try await signer.getPublicKey()
    }

    @Test("A signed bundle verifies and survives the PDF metadata round trip")
    func roundTrip() async throws {
        let signer = SoftwareReportSigner()
        let bundle = try await ReportBundle.sign(report(), signer: signer)
        let metadata = try bundle.pdfMetadataString()
        #expect(metadata.hasPrefix("FoldCheckReport/1:"))
        let isASCII = metadata.allSatisfy(\.isASCII)
        #expect(isASCII)
        #expect(ReportBundle(pdfMetadata: metadata) == bundle)

        let key = try await ownKey(signer)
        let result = ReportVerifier.verify(pdfMetadata: metadata, ownPublicKey: key)
        guard case .valid(let decoded, let envelope, let identity) = result else {
            Issue.record("Expected valid, got \(result)")
            return
        }
        #expect(identity == .thisDevice)
        #expect(envelope.reportID == decoded.reportID)
        #expect(decoded.results.count == 2)
    }

    @Test("Any changed byte in the embedded JSON is caught")
    func tamperedBytes() async throws {
        let signer = SoftwareReportSigner()
        let bundle = try await ReportBundle.sign(report(), signer: signer)
        for index in [0, bundle.canonicalJSON.count / 2, bundle.canonicalJSON.count - 1] {
            var tampered = bundle
            tampered.canonicalJSON[index] ^= 0x01
            #expect(ReportVerifier.verify(tampered, ownPublicKey: nil) == .invalid(.contentChanged))
        }
    }

    @Test("An edited result (Attention → Pass) is caught")
    func editedOutcome() async throws {
        let bundle = try await ReportBundle.sign(report(), signer: SoftwareReportSigner())
        var tampered = bundle
        let text = String(decoding: bundle.canonicalJSON, as: UTF8.self).replacingOccurrences(of: "\"attention\"", with: "\"pass\"")
        tampered.canonicalJSON = Data(text.utf8)
        #expect(tampered.canonicalJSON != bundle.canonicalJSON)
        #expect(ReportVerifier.verify(tampered, ownPublicKey: nil) == .invalid(.contentChanged))
    }

    @Test("A signature from a different key, or a forged one, fails")
    func badSignature() async throws {
        let bundle = try await ReportBundle.sign(report(), signer: SoftwareReportSigner(seed: "A"))
        var swapped = bundle
        swapped.envelope.publicKey = try await SoftwareReportSigner(seed: "B").getPublicKey().base64EncodedString()
        #expect(ReportVerifier.verify(swapped, ownPublicKey: nil) == .invalid(.badSignature))
    }

    @Test("Another installation's report is valid with its fingerprint")
    func anotherDevice() async throws {
        let theirs = SoftwareReportSigner(seed: "theirs")
        let bundle = try await ReportBundle.sign(report(), signer: theirs)
        let mine = try await SoftwareReportSigner(seed: "mine").getPublicKey()
        guard case .valid(_, _, .anotherDevice(let fingerprint)) = ReportVerifier.verify(bundle, ownPublicKey: mine) else {
            Issue.record("Expected another device")
            return
        }
        #expect(fingerprint == bundle.envelope.keyFingerprint)
        #expect(fingerprint.count == 16)
    }

    @Test("Garbage and non-FoldCheck metadata are unreadable")
    func unreadable() {
        #expect(ReportVerifier.verify(pdfMetadata: nil, ownPublicKey: nil) == .invalid(.unreadable))
        #expect(ReportVerifier.verify(pdfMetadata: "Quarterly results", ownPublicKey: nil) == .invalid(.unreadable))
        #expect(ReportVerifier.verify(pdfMetadata: "FoldCheckReport/1:!!!", ownPublicKey: nil) == .invalid(.unreadable))
        #expect(ReportVerifier.verify(qrPayload: "hello", ownPublicKey: nil) == .invalid(.unreadable))
    }

    @Test("A QR payload checks the signature over the hash")
    func qr() async throws {
        let signer = SoftwareReportSigner()
        let bundle = try await ReportBundle.sign(report(), signer: signer)
        let payload = try bundle.envelope.toQRPayload()
        #expect(payload.count < 600)
        let key = try await signer.getPublicKey()
        let result = ReportVerifier.verify(qrPayload: payload, ownPublicKey: key)
        #expect(result == .signatureValid(envelope: bundle.envelope, signer: .thisDevice))

        var forged = bundle.envelope
        forged.sha256 = String(repeating: "0", count: 64)
        let forgedPayload = try forged.toQRPayload()
        #expect(ReportVerifier.verify(qrPayload: forgedPayload, ownPublicKey: nil) == .invalid(.badSignature))
    }
}
