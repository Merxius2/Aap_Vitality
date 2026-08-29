import SwiftUI
import UIKit

private struct ThemeTypographyCodeKey: EnvironmentKey {
    static let defaultValue = AppThemes.defaultCode
}

extension EnvironmentValues {
    var themeTypographyCode: String {
        get { self[ThemeTypographyCodeKey.self] }
        set { self[ThemeTypographyCodeKey.self] = newValue }
    }
}

enum ThemeTypography {
    static func usesOxanium(for themeCode: String) -> Bool {
        themeCode == "retro-wave" || themeCode == "classic"
    }

    static func headingTracking(for themeCode: String) -> CGFloat {
        switch themeCode {
        case "retro-wave": return 0.04 * 16
        case "classic": return 0.06 * 16
        default: return 0
        }
    }

    static func usesUppercaseHeadings(for themeCode: String) -> Bool {
        themeCode == "classic"
    }

    static func font(for themeCode: String, textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        guard usesOxanium(for: themeCode) else {
            return .system(textStyle, design: .default).weight(weight)
        }
        let size = uiFontSize(for: textStyle)
        let name = postScriptName(for: weight)
        return .custom(name, size: size)
    }

    static func font(for themeCode: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard usesOxanium(for: themeCode) else {
            return .system(size: size, weight: weight)
        }
        return .custom(postScriptName(for: weight), size: size)
    }

    static func uiFont(for themeCode: String, textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        guard usesOxanium(for: themeCode), let custom = UIFont(name: uiPostScriptName(for: weight), size: size) else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        return custom
    }

    static func applyUIKitAppearance(themeCode: String) {
        guard usesOxanium(for: themeCode) else {
            UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).font = nil
            UITextField.appearance().font = nil
            return
        }

        let body = uiFont(for: themeCode, textStyle: .body)
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).font = body
        UITextField.appearance().font = body
    }

    private static func uiFontSize(for textStyle: Font.TextStyle) -> CGFloat {
        let style: UIFont.TextStyle
        switch textStyle {
        case .largeTitle: style = .largeTitle
        case .title: style = .title1
        case .title2: style = .title2
        case .title3: style = .title3
        case .headline: style = .headline
        case .subheadline: style = .subheadline
        case .body: style = .body
        case .callout: style = .callout
        case .footnote: style = .footnote
        case .caption: style = .caption1
        case .caption2: style = .caption2
        @unknown default: style = .body
        }
        return UIFont.preferredFont(forTextStyle: style).pointSize
    }

    private static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Oxanium-Bold"
        case .semibold: return "Oxanium-SemiBold"
        case .medium: return "Oxanium-Medium"
        default: return "Oxanium-Regular"
        }
    }

    private static func uiPostScriptName(for weight: UIFont.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "Oxanium-Bold"
        case .semibold: return "Oxanium-SemiBold"
        case .medium: return "Oxanium-Medium"
        default: return "Oxanium-Regular"
        }
    }
}

private struct ThemeFontModifier: ViewModifier {
    @Environment(\.themeTypographyCode) private var themeCode
    let textStyle: Font.TextStyle
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(ThemeTypography.font(for: themeCode, textStyle: textStyle, weight: weight))
    }
}

private struct ThemeFontSizeModifier: ViewModifier {
    @Environment(\.themeTypographyCode) private var themeCode
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(ThemeTypography.font(for: themeCode, size: size, weight: weight))
    }
}

struct ThemedFontModifier: ViewModifier {
    @EnvironmentObject private var preferences: UserPreferencesService

    func body(content: Content) -> some View {
        content
            .environment(\.themeTypographyCode, preferences.themeCode)
            .font(ThemeTypography.font(for: preferences.themeCode, textStyle: .body))
    }
}

extension View {
    func themedBodyFont() -> some View {
        modifier(ThemedFontModifier())
    }

    func themeFont(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        modifier(ThemeFontModifier(textStyle: textStyle, weight: weight))
    }

    func themeFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ThemeFontSizeModifier(size: size, weight: weight))
    }
}
