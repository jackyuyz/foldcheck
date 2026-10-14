import Testing
import Foundation
@testable import FoldL10n

@Suite("Language catalog")
struct CatalogTests {
    @Test("English is the default and the catalog loaded")
    func defaultLanguage() {
        #expect(AppLanguage.default == .en)
        #expect(L10nKey.homeHeadline.text(in: .en) == "Foldable Inspector")
        #expect(L10nKey.settingsTitle.text(in: .en) == "Settings")
    }

    @Test("Every language has the same non-empty keys")
    func completeCatalogs() {
        let english = Set(L10nKey.allCases.map(\.rawValue))
        #expect(english.count == L10nKey.allCases.count)
        for language in AppLanguage.allCases {
            let keys = StringCatalog.keys(in: language)
            #expect(keys == english, "\(language.rawValue) keys differ")
            for key in L10nKey.allCases {
                let value = key.text(in: language)
                #expect(!value.isEmpty)
                #expect(value != key.rawValue, "Missing \(key.rawValue) in \(language.rawValue)")
            }
        }
    }

    @Test("Translations differ from English for the headline")
    func translationsDiffer() {
        let english = L10nKey.homeStart.text(in: .en)
        #expect(L10nKey.homeStart.text(in: .es) == "Empezar inspección")
        #expect(L10nKey.homeStart.text(in: .fr) == "Commencer l’inspection")
        #expect(L10nKey.homeStart.text(in: .ja) == "点検を始める")
        #expect(L10nKey.homeStart.text(in: .zhHans) == "开始体检")
        #expect(L10nKey.homeStart.text(in: .zhHant) == "開始體檢")
        #expect(L10nKey.homeHeadline.text(in: .ja) != english)
    }

    @Test("Unknown language codes fall back to English")
    func fallback() {
        #expect(AppLanguage(languageCode: "de") == nil)
        #expect(AppLanguage(languageCode: "zh-TW") == .zhHant)
        #expect(AppLanguage(languageCode: "zh_CN") == .zhHans)
        #expect(LanguagePreferences.load(appLanguageCode: nil, reportUsesEnglish: false).appLanguage == .en)
        #expect(LanguagePreferences.load(appLanguageCode: "nope", reportUsesEnglish: false).appLanguage == .en)
    }

    @Test("Report language can stay English while the app is Japanese")
    func reportLanguage() {
        let prefs = LanguagePreferences(appLanguage: .ja, reportUsesEnglish: true)
        #expect(prefs.reportLanguage == .en)
        let matching = LanguagePreferences(appLanguage: .fr, reportUsesEnglish: false)
        #expect(matching.reportLanguage == .fr)
    }

    @Test("Format strings keep argument order")
    func format() {
        #expect(L10nKey.inspectionProgress.text(in: .en, 3, 10) == "Test 3 of 10")
        #expect(L10nKey.inspectionProgress.text(in: .zhHans, 3, 10) == "第 3 项，共 10 项")
        #expect(L10nKey.inspectionProgress.text(in: .ja, 3, 10) == "10 件中 3 件目")
        #expect(L10nKey.summaryCompletedIn.text(in: .es, "5m") == "Completada en 5m")
    }

    @Test("Disclaimers exist in every language and are not the English text")
    func disclaimers() {
        let english = L10nKey.reportDisclaimer.text(in: .en)
        #expect(english.contains("NOT an official certification"))
        for language in AppLanguage.allCases where language != .en {
            let text = L10nKey.reportDisclaimer.text(in: language)
            #expect(text != english)
            #expect(text.count > 80)
        }
    }

    @Test("Language list uses native names")
    func nativeNames() {
        #expect(AppLanguage.allCases.map(\.nativeName) == [
            "English", "Español", "Français", "日本語", "简体中文", "繁體中文"
        ])
    }
}
