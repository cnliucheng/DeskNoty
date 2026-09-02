import Foundation

/// Manages localization for the app, supporting English and Simplified Chinese.
/// Loads strings from Localizable.strings files in the app bundle.
enum L10n {
    /// Supported languages
    enum Language: String, CaseIterable {
        case english = "en"
        case chinese = "zh-Hans"

        var displayName: String {
            switch self {
            case .english: return "English"
            case .chinese: return "简体中文"
            }
        }
    }

    /// Current language, defaults to system language or English
    static var currentLanguage: Language = {
        // Get system language
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        if preferredLanguage.hasPrefix("zh") {
            return .chinese
        }
        return .english
    }()

    /// Bundle for the current language
    private static var bundle: Bundle = {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }()

    /// Get a localized string by key
    static func string(_ key: String) -> String {
        let localized = bundle.localizedString(forKey: key, value: nil, table: nil)
        // If the key is not found, return the key itself
        return localized == key ? key : localized
    }

    /// Get a localized string with format arguments
    static func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, arguments: arguments)
    }

    /// Switch language and reload bundle
    static func setLanguage(_ language: Language) {
        currentLanguage = language
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let newBundle = Bundle(path: path) else {
            bundle = Bundle.main
            return
        }
        bundle = newBundle
    }

    /// Get all available languages
    static var availableLanguages: [Language] {
        Language.allCases
    }
}

/// Convenience operator for localization
prefix operator §
prefix func §(key: String) -> String {
    L10n.string(key)
}