import SwiftUI

enum MascotBubbleTone: String {
    case `default`
    case reward
    case tip
    case levelUp
    case thinking
    case disappointed
}

struct MascotLevelMeta {
    let labelKey: String
    let accent: MascotLevelAccent
}

enum MascotLevelAccent {
    case emerald
    case brand
    case violet
}

enum MascotPresentation {
    private static let levelUpPattern = try! NSRegularExpression(
        pattern: #"\b(level(?:ed)? up|leveled up|niveau|stuf|уровень|seviye)\b"#,
        options: [.caseInsensitive]
    )
    private static let rewardPattern = try! NSRegularExpression(
        pattern: #"\b(coin|coins|munt|монет|record|personal best|medal|trophy|pr\b|bonus|\+[\d,.]+\s*(coin|munt))"#,
        options: [.caseInsensitive]
    )

    static func stageId(for mascotId: String) -> String {
        MascotConstants.ids.contains(mascotId) ? mascotId : "flip"
    }

    static func levelMeta(for level: String) -> MascotLevelMeta {
        switch level {
        case "advanced":
            return MascotLevelMeta(labelKey: "benchmark.levels.advanced", accent: .violet)
        case "intermediate":
            return MascotLevelMeta(labelKey: "benchmark.levels.intermediate", accent: .brand)
        default:
            return MascotLevelMeta(labelKey: "benchmark.levels.beginner", accent: .emerald)
        }
    }

    static func coachNameColor(mascotId: String, colorScheme: ColorScheme) -> Color {
        switch mascotId {
        case "flo":
            return colorScheme == .dark
                ? Color(red: 0.78, green: 0.82, blue: 1.0, opacity: 0.95)
                : Color(red: 0.16, green: 0.27, blue: 0.8, opacity: 0.95)
        case "fins":
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.89, blue: 0.89, opacity: 0.95)
                : Color(red: 0.5, green: 0.11, blue: 0.11, opacity: 0.9)
        default:
            return colorScheme == .dark
                ? Color(red: 0.65, green: 0.95, blue: 0.82, opacity: 0.95)
                : Color(red: 0.016, green: 0.47, blue: 0.34, opacity: 0.95)
        }
    }

    static func stageBorderColor(mascotId: String) -> Color {
        switch mascotId {
        case "flo": return Color(red: 0.23, green: 0.36, blue: 1.0, opacity: 0.28)
        case "fins": return Color(red: 0.86, green: 0.15, blue: 0.15, opacity: 0.35)
        default: return Color(red: 0.2, green: 0.83, blue: 0.6, opacity: 0.3)
        }
    }

    static func speechBubbleStyle(mascotId: String, tone: MascotBubbleTone, colorScheme: ColorScheme) -> MascotSpeechBubbleStyle {
        let baseFill = colorScheme == .dark
            ? Color(red: 0.06, green: 0.17, blue: 0.15, opacity: 0.92)
            : Color.white.opacity(0.94)

        var border = toneBorderColor(tone: tone, colorScheme: colorScheme)
        var fill = baseFill

        switch mascotId {
        case "flo":
            border = colorScheme == .dark
                ? Color(red: 0.58, green: 0.77, blue: 0.99, opacity: 0.4)
                : Color(red: 0.23, green: 0.36, blue: 1.0, opacity: 0.4)
            if colorScheme == .dark { fill = Color(red: 0.06, green: 0.09, blue: 0.16, opacity: 0.92) }
        case "fins":
            border = colorScheme == .dark
                ? Color(red: 0.97, green: 0.44, blue: 0.44, opacity: 0.45)
                : Color(red: 0.86, green: 0.15, blue: 0.15, opacity: 0.45)
            if colorScheme == .dark { fill = Color(red: 0.06, green: 0.09, blue: 0.16, opacity: 0.92) }
        default:
            border = colorScheme == .dark
                ? Color(red: 0.2, green: 0.83, blue: 0.6, opacity: 0.4)
                : Color(red: 0.2, green: 0.83, blue: 0.6, opacity: 0.45)
            if colorScheme == .dark { fill = Color(red: 0.024, green: 0.17, blue: 0.15, opacity: 0.92) }
        }

        if tone == .disappointed {
            fill = colorScheme == .dark
                ? Color(red: 0.12, green: 0.11, blue: 0.08, opacity: 0.9)
                : Color(red: 1.0, green: 0.98, blue: 0.92, opacity: 0.9)
        }

        return MascotSpeechBubbleStyle(fill: fill, border: border)
    }

    static func resolveBubbleTone(
        loading: Bool = false,
        coachMessage: String = "",
        motivation: String = "",
        tip: String = "",
        badges: [String] = [],
        benchmarkLevel: SwimLevel? = nil,
        message: String = ""
    ) -> MascotBubbleTone {
        if loading { return .thinking }

        let combined = [coachMessage, motivation, tip, message].filter { !$0.isEmpty }.joined(separator: " ")

        if !badges.isEmpty || matches(rewardPattern, in: combined) { return .reward }
        if !tip.isEmpty { return .tip }
        if matches(levelUpPattern, in: combined) { return .levelUp }
        if let benchmarkLevel, benchmarkLevel != .unknown, benchmarkLevel != .developing {
            if combined.range(of: #"level|niveau|stuf|уровень|seviye"#, options: [.regularExpression, .caseInsensitive]) != nil {
                return .levelUp
            }
        }

        return .default
    }

    private static func toneBorderColor(tone: MascotBubbleTone, colorScheme: ColorScheme) -> Color {
        switch tone {
        case .reward: return Color(red: 0.96, green: 0.65, blue: 0.14, opacity: 0.65)
        case .tip: return Color(red: 0.19, green: 0.77, blue: 0.65, opacity: 0.65)
        case .levelUp: return Color(red: 0.48, green: 0.36, blue: 1.0, opacity: 0.55)
        case .disappointed: return Color(red: 0.98, green: 0.45, blue: 0.09, opacity: 0.55)
        case .thinking: return colorScheme == .dark
            ? Color(red: 0.58, green: 0.77, blue: 0.99, opacity: 0.35)
            : Color(red: 0.11, green: 0.18, blue: 0.35, opacity: 0.85)
        case .default: return colorScheme == .dark
            ? Color(red: 0.58, green: 0.77, blue: 0.99, opacity: 0.35)
            : Color(red: 0.11, green: 0.18, blue: 0.35, opacity: 0.85)
        }
    }

    private static func matches(_ regex: NSRegularExpression, in text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}

struct MascotSpeechBubbleStyle {
    let fill: Color
    let border: Color
}
