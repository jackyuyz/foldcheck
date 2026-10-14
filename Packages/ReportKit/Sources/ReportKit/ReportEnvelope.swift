import Foundation

/// The tamper-evidence envelope for a report.
///
/// This is encoded in the QR code and allows verification that the report
/// hasn't been modified since creation.
public struct ReportEnvelope: Codable, Sendable, Equatable {
    /// Unique identifier for this report
    public var reportID: UUID
    
    /// SHA-256 hash of the canonical report JSON (hex string)
    public var sha256: String
    
    /// Base64-encoded signature of the hash
    public var signature: String
    
    /// Base64-encoded public key used for signing
    public var publicKey: String
    
    /// Envelope format version
    public var version: Int
    
    /// Whether this report was signed with a development/software key
    public var isDevelopmentBuild: Bool
    
    public init(
        reportID: UUID,
        sha256: String,
        signature: String,
        publicKey: String,
        version: Int = 1,
        isDevelopmentBuild: Bool = false
    ) {
        self.reportID = reportID
        self.sha256 = sha256
        self.signature = signature
        self.publicKey = publicKey
        self.version = version
        self.isDevelopmentBuild = isDevelopmentBuild
    }
    
    /// Generate a deep link URL for verification
    public var verificationURL: URL? {
        var components = URLComponents()
        components.scheme = "foldcheck"
        components.host = "verify"
        components.queryItems = [
            URLQueryItem(name: "id", value: reportID.uuidString),
            URLQueryItem(name: "hash", value: sha256),
            URLQueryItem(name: "sig", value: signature),
            URLQueryItem(name: "key", value: publicKey),
            URLQueryItem(name: "v", value: String(version))
        ]
        return components.url
    }
    
    /// Fingerprint of the public key (first 8 chars of SHA-256)
    public var keyFingerprint: String {
        guard let data = Data(base64Encoded: publicKey) else {
            return "unknown"
        }
        let hashData = ReportHash.sha256(data)
        return hashData.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Compact Encoding for QR

public extension ReportEnvelope {
    /// Encode to a compact JSON string suitable for QR codes
    func toQRPayload() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Decode from a QR payload string
    static func fromQRPayload(_ payload: String) throws -> ReportEnvelope {
        guard let data = payload.data(using: .utf8) else {
            throw ReportError.invalidPayload
        }
        let decoder = JSONDecoder()
        return try decoder.decode(ReportEnvelope.self, from: data)
    }
    
    /// Estimate QR code size for this payload
    var estimatedQRSize: Int {
        // QR Version 10 can hold ~652 alphanumeric characters
        // Our payload should fit comfortably
        guard let payload = try? toQRPayload() else { return 0 }
        return payload.count
    }
}

public enum ReportError: Error, Sendable {
    case invalidPayload
    case invalidSignature
    case hashMismatch
    case signingFailed
    case verificationFailed
}
