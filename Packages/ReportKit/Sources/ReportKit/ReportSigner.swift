import Crypto
import Foundation

/// Protocol for signing and verifying reports.
///
/// Production uses `SecureEnclaveReportSigner` (CryptoKit `SecureEnclave.P256`).
/// Tests and the simulator use `SoftwareReportSigner`, a real P-256 key from swift-crypto.
public protocol ReportSigner: Sendable {
    func sign(_ data: Data) async throws -> Data
    func verify(_ data: Data, signature: Data) async throws -> Bool
    func getPublicKey() async throws -> Data
    var isDevelopmentKey: Bool { get }
}

enum ReportHash {
    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

enum P256Signature {
    static func isValid(message: Data, signature: Data, publicKey: Data) -> Bool {
        guard let key = try? P256.Signing.PublicKey(rawRepresentation: publicKey),
              let parsed = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return false
        }
        return key.isValidSignature(parsed, for: message)
    }
}

/// Real P-256 software key. The seed selects the scalar so tests are deterministic.
/// This is not the Secure Enclave. `isDevelopmentKey` stays true.
public actor SoftwareReportSigner: ReportSigner {
    private let privateKey: P256.Signing.PrivateKey
    public nonisolated let isDevelopmentKey: Bool = true

    public init(seed: String = "FoldCheck-Dev-Key") {
        privateKey = Self.key(from: seed)
    }

    public func sign(_ data: Data) async throws -> Data {
        try privateKey.signature(for: data).rawRepresentation
    }

    public func verify(_ data: Data, signature: Data) async throws -> Bool {
        guard let parsed = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return false
        }
        return privateKey.publicKey.isValidSignature(parsed, for: data)
    }

    public func getPublicKey() async throws -> Data {
        privateKey.publicKey.rawRepresentation
    }

    private static func key(from seed: String) -> P256.Signing.PrivateKey {
        var material = Array(SHA256.hash(data: Data(seed.utf8)))
        for _ in 0..<32 {
            if let key = try? P256.Signing.PrivateKey(rawRepresentation: material) {
                return key
            }
            material = Array(SHA256.hash(data: Data(material)))
        }
        // A SHA-256 digest is a valid scalar except for a negligible set.
        return P256.Signing.PrivateKey()
    }
}

public func signReport(_ report: CanonicalReport, signer: any ReportSigner) async throws -> ReportEnvelope {
    let jsonData = try report.toCanonicalJSON()
    let hash = ReportHash.sha256(jsonData)
    let signature = try await signer.sign(hash)
    let publicKey = try await signer.getPublicKey()

    return ReportEnvelope(
        reportID: report.reportID,
        sha256: ReportHash.hex(hash),
        signature: signature.base64EncodedString(),
        publicKey: publicKey.base64EncodedString(),
        version: 1,
        isDevelopmentBuild: signer.isDevelopmentKey
    )
}

/// Verifies the embedded hash and the P-256 signature. The public key in the
/// envelope is what is checked, so another install can verify without the private key.
public func verifyReport(_ report: CanonicalReport, envelope: ReportEnvelope, signer: any ReportSigner) async throws -> Bool {
    let jsonData = try report.toCanonicalJSON()
    let hash = ReportHash.sha256(jsonData)
    guard ReportHash.hex(hash) == envelope.sha256 else {
        throw ReportError.hashMismatch
    }
    guard let signature = Data(base64Encoded: envelope.signature),
          let publicKey = Data(base64Encoded: envelope.publicKey) else {
        throw ReportError.invalidSignature
    }
    guard P256Signature.isValid(message: hash, signature: signature, publicKey: publicKey) else {
        throw ReportError.verificationFailed
    }
    _ = signer
    return true
}
