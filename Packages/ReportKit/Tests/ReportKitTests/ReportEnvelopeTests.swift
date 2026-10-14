import Testing
import Foundation
@testable import ReportKit

@Suite("ReportEnvelope Tests")
struct ReportEnvelopeTests {
    
    @Test("ReportEnvelope initializes correctly")
    func testInitialization() {
        let envelope = ReportEnvelope(
            reportID: UUID(),
            sha256: "abc123",
            signature: "sig123",
            publicKey: "key123"
        )
        
        #expect(!envelope.sha256.isEmpty)
        #expect(!envelope.signature.isEmpty)
        #expect(!envelope.publicKey.isEmpty)
        #expect(envelope.version == 1)
        #expect(!envelope.isDevelopmentBuild)
    }
    
    @Test("verificationURL generates valid deep link")
    func testVerificationURL() {
        let reportID = UUID()
        let envelope = ReportEnvelope(
            reportID: reportID,
            sha256: "abc123",
            signature: "sig123",
            publicKey: "key123",
            version: 1
        )
        
        let url = envelope.verificationURL
        
        #expect(url != nil)
        #expect(url?.scheme == "foldcheck")
        #expect(url?.host == "verify")
        #expect(url?.absoluteString.contains(reportID.uuidString) == true)
    }
    
    @Test("QR payload round-trips correctly")
    func testQRPayloadRoundTrip() throws {
        let original = ReportEnvelope(
            reportID: UUID(),
            sha256: "a1b2c3d4e5f6",
            signature: "c2lnbmF0dXJl",
            publicKey: "cHVibGljS2V5",
            version: 1,
            isDevelopmentBuild: true
        )
        
        let payload = try original.toQRPayload()
        let decoded = try ReportEnvelope.fromQRPayload(payload)
        
        #expect(decoded == original)
    }
    
    @Test("QR payload size is reasonable for QR codes")
    func testQRPayloadSize() throws {
        let envelope = ReportEnvelope(
            reportID: UUID(),
            sha256: String(repeating: "a", count: 64),  // SHA-256 hex is 64 chars
            signature: String(repeating: "b", count: 88),  // Base64 of 64 bytes ≈ 88 chars
            publicKey: String(repeating: "c", count: 44),  // Base64 of 32 bytes ≈ 44 chars
            version: 1
        )
        
        let size = envelope.estimatedQRSize
        
        // QR Version 10 can hold ~652 alphanumeric characters
        // Our payload should fit
        #expect(size > 0)
        #expect(size < 600, "Payload should fit in QR Version 10: \(size) chars")
    }
    
    @Test("ReportEnvelope is Codable")
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = ReportEnvelope(
            reportID: UUID(),
            sha256: "abc123",
            signature: "sig123",
            publicKey: "key123",
            version: 1,
            isDevelopmentBuild: true
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ReportEnvelope.self, from: data)
        
        #expect(decoded == original)
    }
    
    @Test("Invalid QR payload throws error")
    func testInvalidQRPayload() {
        do {
            _ = try ReportEnvelope.fromQRPayload("not valid json")
            #expect(Bool(false), "Should have thrown")
        } catch {
            // Expected
        }
    }
    
    @Test("keyFingerprint returns consistent value")
    func testKeyFingerprint() {
        let publicKey = "dGVzdCBwdWJsaWMga2V5"  // "test public key" in base64
        let envelope = ReportEnvelope(
            reportID: UUID(),
            sha256: "abc",
            signature: "sig",
            publicKey: publicKey
        )
        
        let fingerprint1 = envelope.keyFingerprint
        let fingerprint2 = envelope.keyFingerprint
        
        #expect(fingerprint1 == fingerprint2)
        #expect(fingerprint1.count == 16)  // 8 bytes = 16 hex chars
    }
}
