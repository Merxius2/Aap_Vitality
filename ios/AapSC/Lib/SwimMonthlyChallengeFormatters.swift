import Foundation

enum SwimMonthlyChallengeFormatters {
    static func challengeTypeLabel(_ type: String, t: TranslationService) -> String {
        t.t("monthlyChallenges.types.\(type)")
    }

    static func formatChallengeValue(_ type: String, _ value: Int?, t: TranslationService) -> String {
        guard let value else { return "—" }
        switch type {
        case "sessions", "streak", "active_weeks":
            return String(value)
        case "distance":
            return SwimFormatters.formatDistance(value)
        case "kcal":
            return "\(value) \(t.t("common.kcal"))"
        default:
            return String(value)
        }
    }

    static func formatChallengeTarget(_ type: String, _ target: Int, t: TranslationService) -> String {
        switch type {
        case "sessions":
            return t.t("monthlyChallenges.targets.sessions", params: ["count": String(target)])
        case "distance":
            return t.t("monthlyChallenges.targets.distance", params: ["distance": SwimFormatters.formatDistance(target)])
        case "kcal":
            return t.t("monthlyChallenges.targets.kcal", params: ["kcal": String(target)])
        case "streak":
            return t.t("monthlyChallenges.targets.streak", params: ["days": String(target)])
        case "active_weeks":
            return t.t("monthlyChallenges.targets.activeWeeks", params: ["weeks": String(target)])
        default:
            return String(target)
        }
    }

    static func tierLabel(_ tier: String, t: TranslationService) -> String {
        t.t("monthlyChallenges.tiers.\(tier)")
    }

    static func monthLabel(_ monthKey: String, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: "\(monthKey)-01") else { return monthKey }
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func monthShortLabel(_ monthKey: String, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: "\(monthKey)-01") else { return monthKey }
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}
