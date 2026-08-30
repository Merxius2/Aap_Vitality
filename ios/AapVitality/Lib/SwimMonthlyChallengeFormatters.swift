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
        case "monthly_points_bronze", "monthly_points_silver", "monthly_points_gold":
            return "\(value) \(t.t("vitality.points"))"
        case "body_weigh_ins_bronze", "body_weigh_ins_silver", "weigh_ins":
            return String(value)
        case "body_trend_gold":
            return value == 1 ? t.t("progress.body.trendComplete") : t.t("progress.body.trendIncomplete")
        case "zone_minutes":
            return t.t("monthlyChallenges.values.minutes", params: ["minutes": String(value)])
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
        case "monthly_points_bronze":
            return t.t("monthlyChallenges.targets.monthlyPointsBronze", params: ["points": String(target)])
        case "monthly_points_silver":
            return t.t("monthlyChallenges.targets.monthlyPointsSilver", params: ["points": String(target)])
        case "monthly_points_gold":
            return t.t("monthlyChallenges.targets.monthlyPointsGold", params: ["points": String(target)])
        case "body_weigh_ins_bronze":
            return t.t("monthlyChallenges.targets.bodyWeighInsBronze", params: ["count": String(target)])
        case "body_weigh_ins_silver":
            return t.t("monthlyChallenges.targets.bodyWeighInsSilver", params: ["count": String(target)])
        case "body_trend_gold":
            return t.t("monthlyChallenges.targets.bodyTrendGold")
        case "steps_10k_days":
            return t.t("monthlyChallenges.targets.steps10kDays", params: ["days": String(target)])
        case "steps_5k_days":
            return t.t("monthlyChallenges.targets.steps5kDays", params: ["days": String(target)])
        case "steps_20k_day":
            return t.t("monthlyChallenges.targets.steps20kDay", params: ["count": String(target)])
        case "workout_count":
            return t.t("monthlyChallenges.targets.workoutCount", params: ["count": String(target)])
        case "workout_variety":
            return t.t("monthlyChallenges.targets.workoutVariety", params: ["count": String(target)])
        case "workout_weekends":
            return t.t("monthlyChallenges.targets.workoutWeekends", params: ["count": String(target)])
        case "points_streak":
            return t.t("monthlyChallenges.targets.pointsStreak", params: ["days": String(target)])
        case "weekly_goals":
            return t.t("monthlyChallenges.targets.weeklyGoals", params: ["weeks": String(target)])
        case "strong_week":
            return t.t("monthlyChallenges.targets.strongWeek", params: ["days": String(target)])
        case "weigh_ins":
            return t.t("monthlyChallenges.targets.weighIns", params: ["count": String(target)])
        case "sleep_nights":
            return t.t("monthlyChallenges.targets.sleepNights", params: ["nights": String(target)])
        case "recovery_pair":
            return t.t("monthlyChallenges.targets.recoveryPair", params: ["days": String(target)])
        case "balanced_days":
            return t.t("monthlyChallenges.targets.balancedDays", params: ["days": String(target)])
        case "workout_active_weeks":
            return t.t("monthlyChallenges.targets.workoutActiveWeeks", params: ["weeks": String(target)])
        case "zone_minutes":
            return t.t("monthlyChallenges.targets.zoneMinutes", params: ["minutes": String(target)])
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
