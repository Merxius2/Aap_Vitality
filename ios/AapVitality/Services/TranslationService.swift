import Foundation
import SwiftUI

final class TranslationService: ObservableObject {
    static let supportedLanguages = ["en", "nl", "ru", "tr"]
    static let defaultLanguage = "en"

    @Published private(set) var language: String = defaultLanguage
    private var tables: [String: [String: Any]] = [:]
    var returnsKeysForTesting = false

    init() {
        for code in Self.supportedLanguages {
            let url = Bundle.main.url(forResource: code, withExtension: "json", subdirectory: "Localizations")
                ?? Bundle.main.url(forResource: code, withExtension: "json")
            guard let url,
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            tables[code] = json
        }
    }

    func setLanguage(_ code: String) {
        guard Self.supportedLanguages.contains(code) else { return }
        language = code
    }

    func t(_ key: String, params: [String: String] = [:]) -> String {
        if returnsKeysForTesting {
            return key
        }
        var text = resolve(key, language: language)
            ?? resolve(key, language: Self.defaultLanguage)
            ?? key
        for (name, value) in params {
            text = text.replacingOccurrences(of: "{\(name)}", with: value.isEmpty ? "—" : value)
        }
        if text.range(of: #"\{[a-zA-Z]+\}"#, options: .regularExpression) != nil {
            text = text.replacingOccurrences(of: #"\{[a-zA-Z]+\}"#, with: "—", options: .regularExpression)
        }
        return text
    }

    func languageDisplayName(_ code: String) -> String {
        switch code {
        case "nl": return "Nederlands"
        case "ru": return "Русский"
        case "tr": return "Türkçe"
        default: return "English"
        }
    }

    private func resolve(_ key: String, language: String) -> String? {
        guard var value: Any = tables[language] else { return nil }
        for part in key.split(separator: ".") {
            guard let dict = value as? [String: Any], let next = dict[String(part)] else {
                return nil
            }
            value = next
        }
        return value as? String
    }
}

private struct TranslationKey: EnvironmentKey {
    static let defaultValue: TranslationService = TranslationService()
}

extension EnvironmentValues {
    var t: TranslationService {
        get { self[TranslationKey.self] }
        set { self[TranslationKey.self] = newValue }
    }
}

extension TranslationService {
    func localized(_ key: String, params: [String: String] = [:]) -> String {
        t(key, params: params)
    }
}
