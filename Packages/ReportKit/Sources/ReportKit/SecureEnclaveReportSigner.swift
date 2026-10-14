#if canImport(CryptoKit) && (os(iOS) || os(macOS))
import CryptoKit
import Foundation

/// Per-install P-256 key in the Secure Enclave.
///
/// `dataRepresentation` is what the app stores in the Keychain. It is not the
/// raw private key. Linux tests use `SoftwareReportSigner` instead.
public actor SecureEnclaveReportSigner: ReportSigner {
    public nonisolated let isDevelopmentKey: Bool = false
    private let key: SecureEnclave.P256.Signing.PrivateKey

    public init() throws {
        key = try SecureEnclave.P256.Signing.PrivateKey()
    }

    public init(dataRepresentation: Data) throws {
        key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: dataRepresentation)
    }

    public var dataRepresentation: Data {
        key.dataRepresentation
    }

    public func sign(_ data: Data) async throws -> Data {
        try key.signature(for: data).rawRepresentation
    }

    public func verify(_ data: Data, signature: Data) async throws -> Bool {
        guard let parsed = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return false
        }
        return key.publicKey.isValidSignature(parsed, for: data)
    }

    public func getPublicKey() async throws -> Data {
        key.publicKey.rawRepresentation
    }
}
#endif
