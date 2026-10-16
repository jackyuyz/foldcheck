import Foundation
import Security
import CryptoKit
import ReportKit

/// This installation's report signing key (spec F3). On a device the key is created in the
/// Secure Enclave and never leaves it; the Keychain keeps only its encrypted
/// `dataRepresentation`, readable on this device only. Without a Secure Enclave (some
/// simulators; the Apple silicon one has it) reports use the development software key and say
/// "Development build (unsigned)".
enum SigningKeyStore {
    private static let service = "com.jackyu.foldcheck.signing"
    private static let account = "secure-enclave-p256"

    /// The signer, creating the Secure Enclave key on first use.
    static func signer() async throws -> any ReportSigner {
        guard SecureEnclave.isAvailable else { return SoftwareReportSigner() }
        if let stored = readKey() {
            return try SecureEnclaveReportSigner(dataRepresentation: stored)
        }
        let signer = try SecureEnclaveReportSigner()
        try saveKey(await signer.dataRepresentation)
        return signer
    }

    /// This installation's public key, without creating one. Used to say "Signed on this device".
    static func existingPublicKey() async -> Data? {
        guard SecureEnclave.isAvailable else {
            return try? await SoftwareReportSigner().getPublicKey()
        }
        guard let stored = readKey(), let signer = try? SecureEnclaveReportSigner(dataRepresentation: stored) else {
            return nil
        }
        return try? await signer.getPublicKey()
    }

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private static func readKey() -> Data? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func saveKey(_ data: Data) throws {
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

/// Generated PDFs, kept in Application Support/Reports on this device (spec §Persistence).
enum ReportFiles {
    static var directory: URL {
        get throws {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let url = base.appendingPathComponent("Reports", isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
    }

    /// Writes the PDF as "FoldCheck Report 2026-10-16 1A2B3C4D.pdf" and returns its URL.
    static func save(_ pdf: Data, reportID: UUID, generatedAt: Date) throws -> URL {
        let day = generatedAt.formatted(.iso8601.year().month().day())
        let name = "FoldCheck Report \(day) \(reportID.uuidString.prefix(8)).pdf"
        let url = try directory.appendingPathComponent(name)
        try pdf.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

extension DeviceInfo {
    /// Total capacity of the device's storage, shown in reports (privacy reason E174.1).
    static var storageCapacity: UInt64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let capacity = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity else {
            return nil
        }
        return UInt64(capacity)
    }
}
