import Foundation

/// Protocol for signing and verifying reports.
///
/// The production implementation uses the Secure Enclave (P-256),
/// while the mock uses a software key for testing.
public protocol ReportSigner: Sendable {
    /// Sign the given data and return the signature
    func sign(_ data: Data) async throws -> Data
    
    /// Verify a signature against data
    func verify(_ data: Data, signature: Data) async throws -> Bool
    
    /// Get the public key in a portable format
    func getPublicKey() async throws -> Data
    
    /// Whether this signer uses a development/software key
    var isDevelopmentKey: Bool { get }
}

/// Software-based signer for testing and simulator use.
///
/// This implementation uses a simple XOR-based "signature" for demonstration.
/// In production, this would be replaced with actual P-256 cryptography.
public actor SoftwareReportSigner: ReportSigner {
    private let keyData: Data
    public nonisolated let isDevelopmentKey: Bool = true
    
    public init(seed: String = "FoldCheck-Dev-Key") {
        // Create a deterministic key from the seed for testing
        var keyBytes = [UInt8](repeating: 0, count: 32)
        let seedBytes = Array(seed.utf8)
        for (i, byte) in seedBytes.enumerated() {
            keyBytes[i % 32] ^= byte
        }
        self.keyData = Data(keyBytes)
    }
    
    public func sign(_ data: Data) async throws -> Data {
        // Simple XOR-based "signature" for testing
        // Real implementation would use CryptoKit with P-256
        let hash = sha256(data)
        var signature = [UInt8](repeating: 0, count: 64)
        let keyBytes = [UInt8](keyData)
        
        for i in 0..<32 {
            signature[i] = hash[i] ^ keyBytes[i % keyBytes.count]
            signature[i + 32] = hash[i] ^ keyBytes[(i + 16) % keyBytes.count]
        }
        
        return Data(signature)
    }
    
    public func verify(_ data: Data, signature: Data) async throws -> Bool {
        // Verify by re-signing and comparing
        let expectedSignature = try await sign(data)
        return signature == expectedSignature
    }
    
    public func getPublicKey() async throws -> Data {
        // For the software signer, the "public key" is derived from the key
        var publicBytes = [UInt8](repeating: 0, count: 32)
        let keyBytes = [UInt8](keyData)
        
        for i in 0..<32 {
            publicBytes[i] = keyBytes[i] ^ 0xAA
        }
        
        return Data(publicBytes)
    }
    
    private func sha256(_ data: Data) -> [UInt8] {
        // Simple hash for testing (not cryptographically secure)
        var hash = [UInt8](repeating: 0, count: 32)
        let bytes = [UInt8](data)
        
        for (i, byte) in bytes.enumerated() {
            hash[i % 32] = hash[i % 32] &+ byte
            hash[(i + 1) % 32] ^= byte
        }
        
        return hash
    }
}

// MARK: - Report Signing Functions

/// Sign a canonical report and create an envelope
public func signReport(_ report: CanonicalReport, signer: any ReportSigner) async throws -> ReportEnvelope {
    // Encode to canonical JSON
    let jsonData = try report.toCanonicalJSON()
    
    // Compute hash
    let hashBytes = sha256(jsonData)
    let hashHex = hashBytes.map { String(format: "%02x", $0) }.joined()
    
    // Sign the hash
    let signature = try await signer.sign(Data(hashBytes))
    let signatureB64 = signature.base64EncodedString()
    
    // Get public key
    let publicKey = try await signer.getPublicKey()
    let publicKeyB64 = publicKey.base64EncodedString()
    
    return ReportEnvelope(
        reportID: report.reportID,
        sha256: hashHex,
        signature: signatureB64,
        publicKey: publicKeyB64,
        version: 1,
        isDevelopmentBuild: signer.isDevelopmentKey
    )
}

/// Verify a report against its envelope
public func verifyReport(_ report: CanonicalReport, envelope: ReportEnvelope, signer: any ReportSigner) async throws -> Bool {
    // Encode to canonical JSON
    let jsonData = try report.toCanonicalJSON()
    
    // Compute and verify hash
    let hashBytes = sha256(jsonData)
    let hashHex = hashBytes.map { String(format: "%02x", $0) }.joined()
    
    guard hashHex == envelope.sha256 else {
        throw ReportError.hashMismatch
    }
    
    // Verify signature
    guard let signatureData = Data(base64Encoded: envelope.signature) else {
        throw ReportError.invalidSignature
    }
    
    let isValid = try await signer.verify(Data(hashBytes), signature: signatureData)
    
    if !isValid {
        throw ReportError.verificationFailed
    }
    
    return true
}

/// Simple SHA-256 hash function (for testing; real impl would use CryptoKit)
private func sha256(_ data: Data) -> [UInt8] {
    var hash = [UInt8](repeating: 0, count: 32)
    let bytes = [UInt8](data)
    
    for (i, byte) in bytes.enumerated() {
        hash[i % 32] = hash[i % 32] &+ byte
        hash[(i + 1) % 32] ^= byte
    }
    
    return hash
}
