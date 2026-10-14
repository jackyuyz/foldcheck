import Foundation

enum StringCatalog {
    private static let tables: [AppLanguage: [String: String]] = loadTables()

    static func text(for key: String, language: AppLanguage) -> String {
        if let value = tables[language]?[key], !value.isEmpty {
            return value
        }
        if language != .en, let english = tables[.en]?[key], !english.isEmpty {
            return english
        }
        return key
    }

    static func format(_ key: String, language: AppLanguage, _ args: [CVarArg]) -> String {
        let template = text(for: key, language: language)
        let locale = Locale(identifier: language.localeIdentifier)
        return String(format: template, locale: locale, arguments: args)
    }

    static func keys(in language: AppLanguage) -> Set<String> {
        Set(tables[language]?.keys.map { $0 } ?? [])
    }

    private static func loadTables() -> [AppLanguage: [String: String]] {
        var loaded: [AppLanguage: [String: String]] = [:]
        for language in AppLanguage.allCases {
            guard let url = resourceURL(for: language),
                  let data = try? Data(contentsOf: url),
                  let object = try? JSONDecoder().decode([String: String].self, from: data) else {
                continue
            }
            loaded[language] = object
        }
        return loaded
    }

    private static func resourceURL(for language: AppLanguage) -> URL? {
        let name = language.rawValue
        let bundle = Bundle.module
        if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Locales") {
            return url
        }
        return bundle.url(forResource: name, withExtension: "json")
    }
}
