@_exported import Foundation

/// Looks up a catalog key. Missing keys fall back to English, then to the key itself.
public func localizedCopy(_ key: String, language: AppLanguage = .en) -> String {
    StringCatalog.text(for: key, language: language)
}
