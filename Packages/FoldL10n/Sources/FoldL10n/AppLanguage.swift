import Foundation

/// In-app language. English is the default; nothing else is selected until the user changes Settings.
public enum AppLanguage: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case en
    case es
    case fr
    case ja
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    public static let `default`: AppLanguage = .en

    public var id: String { rawValue }

    /// Name shown in the language list, in that language.
    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    public var localeIdentifier: String { rawValue }

    /// Whether a count takes the singular form (CLDR "one" for integers): English and Spanish
    /// use it for 1, French for 0 and 1, and Japanese and Chinese have no plural.
    public func usesSingular(for count: Int) -> Bool {
        switch self {
        case .en, .es: return count == 1
        case .fr: return count == 0 || count == 1
        case .ja, .zhHans, .zhHant: return false
        }
    }

    /// Accepts catalog codes and a few common aliases.
    public init?(languageCode: String) {
        let normalized = languageCode.replacingOccurrences(of: "_", with: "-")
        if let exact = AppLanguage(rawValue: normalized) {
            self = exact
            return
        }
        switch normalized.lowercased() {
        case "en", "en-us", "en-gb": self = .en
        case "es", "es-es", "es-mx": self = .es
        case "fr", "fr-fr", "fr-ca": self = .fr
        case "ja", "ja-jp": self = .ja
        case "zh-hans", "zh-cn", "zh-sg": self = .zhHans
        case "zh-hant", "zh-tw", "zh-hk", "zh-mo": self = .zhHant
        default: return nil
        }
    }
}

/// Saved language choices. The app language defaults to English.
public struct LanguagePreferences: Codable, Equatable, Sendable {
    public static let appLanguageKey = "foldcheck.appLanguage"
    public static let reportEnglishKey = "foldcheck.reportUsesEnglish"

    public var appLanguage: AppLanguage
    /// When true, PDFs stay in English even if the app UI is another language.
    public var reportUsesEnglish: Bool

    public init(appLanguage: AppLanguage = .en, reportUsesEnglish: Bool = false) {
        self.appLanguage = appLanguage
        self.reportUsesEnglish = reportUsesEnglish
    }

    public var reportLanguage: AppLanguage {
        reportUsesEnglish ? .en : appLanguage
    }

    public static func load(appLanguageCode: String?, reportUsesEnglish: Bool) -> LanguagePreferences {
        let language = appLanguageCode.flatMap(AppLanguage.init(languageCode:)) ?? .en
        return LanguagePreferences(appLanguage: language, reportUsesEnglish: reportUsesEnglish)
    }
}
