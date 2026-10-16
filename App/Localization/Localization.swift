import SwiftUI
import FoldL10n
import TestsKit

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .en
}

private struct ReportLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .en
}

private struct InspectionHasHingeKey: EnvironmentKey {
    static let defaultValue = true
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

    /// Whether the device in the current inspection has a hinge; set by the inspection flow
    /// so test names can drop "(Outer)" on a device with one display.
    var inspectionHasHinge: Bool {
        get { self[InspectionHasHingeKey.self] }
        set { self[InspectionHasHingeKey.self] = newValue }
    }
}

extension TestID {
    func localizedName(in language: AppLanguage, hasHinge: Bool) -> String {
        localizedCopy(nameKey(hasHinge: hasHinge), language: language)
    }

    func localizedDescription(in language: AppLanguage, hasHinge: Bool) -> String {
        localizedCopy(descriptionKey(hasHinge: hasHinge), language: language)
    }
}

extension Date {
    /// Formatted in the app's language rather than the system's.
    func formatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle, in language: AppLanguage) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(Locale(identifier: language.localeIdentifier)))
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
