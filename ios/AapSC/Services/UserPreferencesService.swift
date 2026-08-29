import Foundation
import SwiftUI

@MainActor
final class UserPreferencesService: ObservableObject {
    static let languageKey = "AUDIT_LANGUAGE_PREFERENCE"
    static let themeKey = "AUDIT_THEME_PREFERENCE"
    static let darkModeKey = "AUDIT_DARK_MODE_PREFERENCE"
    static let darkModeAutoKey = "AUDIT_DARK_MODE_AUTO"

    @Published var language: String = TranslationService.defaultLanguage
    @Published var themeCode: String = AppThemes.defaultCode
    @Published var isDarkMode: Bool = false
    @Published var isAutoDarkMode: Bool = true

    let translations = TranslationService()

    var colorScheme: ColorScheme? {
        if ThemeVisualProfiles.isAlwaysDark(themeCode) { return .dark }
        if isAutoDarkMode { return nil }
        return isDarkMode ? .dark : .light
    }

    /// Resolves dark mode immediately from stored preferences, without waiting for SwiftUI's
    /// color scheme environment to catch up after `preferredColorScheme` changes.
    func isDarkModeActive(systemColorScheme: ColorScheme) -> Bool {
        if ThemeVisualProfiles.isAlwaysDark(themeCode) { return true }
        if isAutoDarkMode {
            return systemColorScheme == .dark
        }
        return isDarkMode
    }

    var themeColors: AppThemeDefinition {
        AppThemes.theme(for: themeCode)
    }

    var locale: Locale {
        switch language {
        case "nl": return Locale(identifier: "nl_NL")
        case "ru": return Locale(identifier: "ru_RU")
        case "tr": return Locale(identifier: "tr_TR")
        default: return Locale(identifier: "en_US")
        }
    }

    init() {
        load()
        translations.setLanguage(language)
    }

    func load() {
        if let langData = UserDefaults.standard.data(forKey: Self.languageKey),
           let json = try? JSONSerialization.jsonObject(with: langData) as? [String: Any],
           let lang = json["language"] as? String {
            language = lang == "mu" ? TranslationService.defaultLanguage : lang
        }

        if let themeData = UserDefaults.standard.data(forKey: Self.themeKey),
           let json = try? JSONSerialization.jsonObject(with: themeData) as? [String: Any],
           let theme = json["theme"] as? String,
           AppThemes.all.contains(where: { $0.code == theme }) {
            themeCode = theme
        }

        if UserDefaults.standard.object(forKey: Self.darkModeAutoKey) != nil {
            isAutoDarkMode = UserDefaults.standard.string(forKey: Self.darkModeAutoKey) == "true"
        }
        if UserDefaults.standard.object(forKey: Self.darkModeKey) != nil {
            isDarkMode = UserDefaults.standard.string(forKey: Self.darkModeKey) == "true"
        }
    }

    func setLanguage(_ code: String) {
        guard TranslationService.supportedLanguages.contains(code) else { return }
        language = code
        translations.setLanguage(code)
        persistLanguage()
    }

    func setTheme(_ code: String) {
        guard AppThemes.all.contains(where: { $0.code == code }) else { return }
        themeCode = code
        persistTheme()
    }

    func setDarkMode(_ enabled: Bool, auto: Bool) {
        isDarkMode = enabled
        isAutoDarkMode = auto
        UserDefaults.standard.set(auto ? "true" : "false", forKey: Self.darkModeAutoKey)
        UserDefaults.standard.set(enabled ? "true" : "false", forKey: Self.darkModeKey)
    }

    func t(_ key: String, params: [String: String] = [:]) -> String {
        translations.t(key, params: params)
    }

    private func persistLanguage() {
        let payload = ["language": language]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            UserDefaults.standard.set(data, forKey: Self.languageKey)
        }
    }

    private func persistTheme() {
        let payload = ["theme": themeCode]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            UserDefaults.standard.set(data, forKey: Self.themeKey)
        }
    }
}
