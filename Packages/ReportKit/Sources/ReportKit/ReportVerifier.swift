import Foundation

/// What a FoldCheck PDF carries so it can be verified offline: the exact canonical JSON bytes
/// that were signed, and the envelope (hash, signature, public key) also shown as the QR code.
///
/// The bytes are kept as signed rather than re-encoded from `CanonicalReport`, so verification
/// hashes exactly what the signer hashed and any changed byte fails.
public struct ReportBundle: Codable, Sendable, Equatable {
    public var canonicalJSON: Data
    public var envelope: ReportEnvelope

    /// Marks the PDF metadata string as a FoldCheck bundle, with its format version.
    static let metadataPrefix = "FoldCheckReport/1:"

    public init(canonicalJSON: Data, envelope: ReportEnvelope) {
        self.canonicalJSON = canonicalJSON
        self.envelope = envelope
    }

    /// Signs `report` and returns the bundle to embed in the PDF.
    public static func sign(_ report: CanonicalReport, signer: any ReportSigner) async throws -> ReportBundle {
        let json = try report.toCanonicalJSON()
        let envelope = try await signReport(report, signer: signer)
        return ReportBundle(canonicalJSON: json, envelope: envelope)
    }

    /// The report the bundle describes. Decode only after verifying.
    public func report() throws -> CanonicalReport {
        try CanonicalReport.fromJSON(canonicalJSON)
    }

    /// One ASCII string for a PDF metadata field (the document Subject).
    public func pdfMetadataString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return Self.metadataPrefix + (try encoder.encode(self)).base64EncodedString()
    }

    /// Reads a bundle back from a PDF metadata string; nil when it isn't one.
    public init?(pdfMetadata: String) {
        guard pdfMetadata.hasPrefix(Self.metadataPrefix),
              let data = Data(base64Encoded: String(pdfMetadata.dropFirst(Self.metadataPrefix.count))),
              let bundle = try? JSONDecoder().decode(ReportBundle.self, from: data) else {
            return nil
        }
        self = bundle
    }
}

/// Who signed a report that verified.
public enum ReportSignerIdentity: Sendable, Equatable {
    /// The public key matches this installation's key.
    case thisDevice
    /// A valid signature from another installation's key (fingerprint shown to the user).
    case anotherDevice(fingerprint: String)
}

/// The result of checking a PDF bundle or a QR code.
public enum ReportVerification: Sendable, Equatable {
    public enum Failure: Sendable, Equatable {
        /// No FoldCheck data in the PDF, or it can't be read.
        case unreadable
        /// The report content doesn't match the signed hash: it was changed after signing.
        case contentChanged
        /// The signature doesn't match the hash and public key.
        case badSignature
    }

    /// A PDF whose content matches its signature.
    case valid(report: CanonicalReport, envelope: ReportEnvelope, signer: ReportSignerIdentity)
    /// A QR code whose signature is valid. The PDF content itself isn't checked.
    case signatureValid(envelope: ReportEnvelope, signer: ReportSignerIdentity)
    case invalid(Failure)
}

/// Offline verification of FoldCheck reports. Proves a report wasn't changed after the
/// installation holding the key signed it; it says nothing about the device itself.
public enum ReportVerifier {
    /// Verifies the embedded bytes against the envelope's hash and signature.
    /// - Parameter ownPublicKey: this installation's public key, to tell "this device" apart.
    public static func verify(_ bundle: ReportBundle, ownPublicKey: Data?) -> ReportVerification {
        let hash = ReportHash.sha256(bundle.canonicalJSON)
        guard ReportHash.hex(hash) == bundle.envelope.sha256 else { return .invalid(.contentChanged) }
        guard signatureIsValid(bundle.envelope, hash: hash) else { return .invalid(.badSignature) }
        guard let report = try? bundle.report(), report.reportID == bundle.envelope.reportID else {
            return .invalid(.contentChanged)
        }
        return .valid(report: report, envelope: bundle.envelope, signer: identity(of: bundle.envelope, ownPublicKey: ownPublicKey))
    }

    /// Verifies a PDF metadata string (the document Subject).
    public static func verify(pdfMetadata: String?, ownPublicKey: Data?) -> ReportVerification {
        guard let pdfMetadata, let bundle = ReportBundle(pdfMetadata: pdfMetadata) else {
            return .invalid(.unreadable)
        }
        return verify(bundle, ownPublicKey: ownPublicKey)
    }

    /// Verifies a scanned QR payload: only that the hash was signed by the embedded key.
    public static func verify(qrPayload: String, ownPublicKey: Data?) -> ReportVerification {
        guard let envelope = try? ReportEnvelope.fromQRPayload(qrPayload),
              let hash = hexData(envelope.sha256) else {
            return .invalid(.unreadable)
        }
        guard signatureIsValid(envelope, hash: hash) else { return .invalid(.badSignature) }
        return .signatureValid(envelope: envelope, signer: identity(of: envelope, ownPublicKey: ownPublicKey))
    }

    private static func signatureIsValid(_ envelope: ReportEnvelope, hash: Data) -> Bool {
        guard let signature = Data(base64Encoded: envelope.signature),
              let publicKey = Data(base64Encoded: envelope.publicKey) else {
            return false
        }
        return P256Signature.isValid(message: hash, signature: signature, publicKey: publicKey)
    }

    private static func identity(of envelope: ReportEnvelope, ownPublicKey: Data?) -> ReportSignerIdentity {
        if let ownPublicKey, Data(base64Encoded: envelope.publicKey) == ownPublicKey {
            return .thisDevice
        }
        return .anotherDevice(fingerprint: envelope.keyFingerprint)
    }

    private static func hexData(_ hex: String) -> Data? {
        guard hex.count % 2 == 0 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }
}
