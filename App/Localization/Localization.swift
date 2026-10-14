import SwiftUI
import FoldL10n
import TestsKit

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .en
}

private struct ReportLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .en
}

extension EnvironmentValues {
    /// UI language. Defaults to English when Settings has not been injected.
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }

    /// Language used for PDF reports. Defaults to English.
    var reportLanguage: AppLanguage {
        get { self[ReportLanguageKey.self] }
        set { self[ReportLanguageKey.self] = newValue }
    }
}

extension TestID {
    func localizedName(in language: AppLanguage) -> String {
        localizedCopy("test.\(rawValue)", language: language)
    }

    func localizedDescription(in language: AppLanguage) -> String {
        localizedCopy("testDesc.\(rawValue)", language: language)
    }
}

extension TestOutcome {
    func localizedName(in language: AppLanguage) -> String {
        localizedCopy("outcome.\(rawValue)", language: language)
    }
}

extension DisplayKind {
    func localizedName(in language: AppLanguage) -> String {
        localizedCopy("display.\(rawValue)", language: language)
    }
}
