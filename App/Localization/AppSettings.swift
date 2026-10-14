import Foundation
import Observation
import FoldL10n

/// In-app language. English until the user picks another language in Settings.
@MainActor
@Observable
final class AppSettings {
    var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: LanguagePreferences.appLanguageKey)
        }
    }

    /// When true, PDF reports stay in English for resale even if the UI is another language.
    var reportUsesEnglish: Bool {
        didSet {
            UserDefaults.standard.set(reportUsesEnglish, forKey: LanguagePreferences.reportEnglishKey)
        }
    }

    var reportLanguage: AppLanguage {
        reportUsesEnglish ? .en : appLanguage
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: LanguagePreferences.appLanguageKey)
        let englishReports = UserDefaults.standard.bool(forKey: LanguagePreferences.reportEnglishKey)
        let prefs = LanguagePreferences.load(appLanguageCode: stored, reportUsesEnglish: englishReports)
        appLanguage = prefs.appLanguage
        reportUsesEnglish = prefs.reportUsesEnglish
    }
}
