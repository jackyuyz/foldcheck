import Testing
import Foundation
@testable import ReportKit
import TestsKit

@Suite("ReportSigner Tests")
struct ReportSignerTests {
    
    @Test("SoftwareReportSigner signs data")
    func testSigning() async throws {
        let signer = SoftwareReportSigner()
        let data = "Test data to sign".data(using: .utf8)!
        
        let signature = try await signer.sign(data)
        
        #expect(!signature.isEmpty)
        #expect(signature.count == 64)  // Our test signature is 64 bytes
    }
    
    @Test("SoftwareReportSigner verifies valid signature")
    func testVerifyValid() async throws {
        let signer = SoftwareReportSigner()
        let data = "Test data to sign".data(using: .utf8)!
        
        let signature = try await signer.sign(data)
        let isValid = try await signer.verify(data, signature: signature)
        
        #expect(isValid)
    }
    
    @Test("SoftwareReportSigner rejects invalid signature")
    func testVerifyInvalid() async throws {
        let signer = SoftwareReportSigner()
        let data = "Test data to sign".data(using: .utf8)!
        
        let signature = try await signer.sign(data)
        var tamperedSignature = [UInt8](signature)
        tamperedSignature[0] ^= 0xFF  // Flip bits in first byte
        
        let isValid = try await signer.verify(data, signature: Data(tamperedSignature))
        
        #expect(!isValid)
    }
    
    @Test("SoftwareReportSigner rejects signature for different data")
    func testVerifyDifferentData() async throws {
        let signer = SoftwareReportSigner()
        let data1 = "Original data".data(using: .utf8)!
        let data2 = "Different data".data(using: .utf8)!
        
        let signature = try await signer.sign(data1)
        let isValid = try await signer.verify(data2, signature: signature)
        
        #expect(!isValid)
    }
    
    @Test("SoftwareReportSigner returns public key")
    func testGetPublicKey() async throws {
        let signer = SoftwareReportSigner()
        
        let publicKey = try await signer.getPublicKey()
        
        #expect(!publicKey.isEmpty)
        #expect(publicKey.count == 32)
    }
    
    @Test("SoftwareReportSigner is deterministic with same seed")
    func testDeterministic() async throws {
        let signer1 = SoftwareReportSigner(seed: "test-seed")
        let signer2 = SoftwareReportSigner(seed: "test-seed")
        let data = "Test data".data(using: .utf8)!
        
        let sig1 = try await signer1.sign(data)
        let sig2 = try await signer2.sign(data)
        
        #expect(sig1 == sig2)
        
        let key1 = try await signer1.getPublicKey()
        let key2 = try await signer2.getPublicKey()
        
        #expect(key1 == key2)
    }
    
    @Test("SoftwareReportSigner is development key")
    func testIsDevelopmentKey() {
        let signer = SoftwareReportSigner()
        #expect(signer.isDevelopmentKey)
    }
}

@Suite("Report Signing Integration Tests")
struct ReportSigningIntegrationTests {
    
    @Test("signReport creates valid envelope")
    func testSignReport() async throws {
        let signer = SoftwareReportSigner()
        let report = CanonicalReport(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true,
            inspectionStartedAt: Date(),
            results: []
        )
        
        let envelope = try await signReport(report, signer: signer)
        
        #expect(envelope.reportID == report.reportID)
        #expect(!envelope.sha256.isEmpty)
        #expect(!envelope.signature.isEmpty)
        #expect(!envelope.publicKey.isEmpty)
        #expect(envelope.version == 1)
        #expect(envelope.isDevelopmentBuild)
    }
    
    @Test("verifyReport accepts valid report")
    func testVerifyValidReport() async throws {
        let signer = SoftwareReportSigner()
        let report = CanonicalReport(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true,
            inspectionStartedAt: Date(),
            results: [
                CanonicalTestResult(
                    testID: "touchGridOuter",
                    outcome: "pass",
                    metrics: [:],
                    notes: "",
                    display: nil,
                    finishedAt: Date()
                )
            ]
        )
        
        let envelope = try await signReport(report, signer: signer)
        let isValid = try await verifyReport(report, envelope: envelope, signer: signer)
        
        #expect(isValid)
    }
    
    @Test("verifyReport detects tampered report")
    func testVerifyTamperedReport() async throws {
        let signer = SoftwareReportSigner()
        var report = CanonicalReport(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            hasHinge: true,
            inspectionStartedAt: Date(),
            results: []
        )
        
        let envelope = try await signReport(report, signer: signer)
        
        // Tamper with the report
        report.deviceModel = "iPhone 18"
        
        do {
            _ = try await verifyReport(report, envelope: envelope, signer: signer)
            #expect(Bool(false), "Should have thrown")
        } catch ReportError.hashMismatch {
            // Expected
        } catch {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    }
    
    @Test("Sign and verify round-trip with full session")
    func testFullSessionRoundTrip() async throws {
        let signer = SoftwareReportSigner()
        
        var session = InspectionSession(
            deviceModel: "iPhone 19 Duo",
            osVersion: "iOS 27.0",
            storageCapacity: 256_000_000_000,
            hasHinge: true
        )
        session.setResult(TestResult(id: .touchGridOuter, outcome: .pass, metrics: ["coverage": 100]))
        session.setResult(TestResult(id: .hingeSweep, outcome: .attention, metrics: ["maxGap": 15.5]))
        session.completedAt = Date()
        
        let report = CanonicalReport.from(session: session)
        let envelope = try await signReport(report, signer: signer)
        let isValid = try await verifyReport(report, envelope: envelope, signer: signer)
        
        #expect(isValid)
    }
}
