import Foundation

enum SwimMedalCopy {
    static let categories = ["milestone", "distance", "weekly", "monthly", "seasonal", "streak", "special"]

    static func categoryLabel(_ category: String, t: TranslationService) -> String {
        t.t("medals.categories.\(category)")
    }

    static func seasonLabel(_ season: String, t: TranslationService) -> String {
        t.t("medals.seasons.\(season)")
    }

    static func title(for medalId: String, t: TranslationService) -> String {
        let localized = t.t("medals.items.\(medalId).title")
        if localized == "medals.items.\(medalId).title" {
            return medalId.replacingOccurrences(of: "_", with: " ").capitalized
        }
        return localized
    }

    static func description(for medalId: String, t: TranslationService) -> String {
        t.t("medals.items.\(medalId).desc")
    }

    static func progressScopeLabel(_ scope: String, t: TranslationService) -> String {
        t.t("medals.progress.scope.\(scope)")
    }

    static func formatPeriods(_ periods: [String], t: TranslationService, locale: Locale = .current) -> String {
        periods.map { period in
            if period.range(of: #"^\d{4}-\d{2}$"#, options: .regularExpression) != nil {
                let parts = period.split(separator: "-")
                guard parts.count == 2,
                      let year = Int(parts[0]),
                      let month = Int(parts[1]) else { return period }
                let components = DateComponents(year: year, month: month, day: 1)
                let formatter = DateFormatter()
                formatter.locale = locale
                formatter.dateFormat = "MMM yyyy"
                if let date = Calendar.current.date(from: components) {
                    return formatter.string(from: date)
                }
                return period
            }
            let parts = period.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return period }
            return "\(seasonLabel(parts[0], t: t)) \(parts[1])"
        }.joined(separator: " · ")
    }
}
