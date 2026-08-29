import Foundation

enum SwimAnalysis {
    static func statsSessions(_ sessions: [SwimSession]) -> [SwimSession] {
        sessions.filter { !$0.excludeFromStats }
    }

    static func sortedSessions(_ sessions: [SwimSession]) -> [SwimSession] {
        sessions.sorted { $0.date < $1.date }
    }

    static func combinedStats(_ sessions: [SwimSession]) -> CombinedStats? {
        let stats = statsSessions(sessions)
        guard !stats.isEmpty else { return nil }

        let metrics = stats.map(\.metrics)
        let totalDistance = metrics.compactMap(\.distanceM).reduce(0, +)
        let totalDuration = metrics.compactMap(\.durationSec).reduce(0, +)
        let totalActiveKcal = metrics.compactMap(\.activeKcal).reduce(0, +)
        let totalLaps = metrics.compactMap(\.laps).reduce(0, +)
        let paces = metrics.compactMap(\.paceSecPer100m).filter { $0 > 0 }
        let heartRates = metrics.compactMap(\.avgHeartRate).filter { $0 > 0 }

        let sorted = sortedSessions(stats)
        return CombinedStats(
            sessionCount: stats.count,
            totalDistanceM: totalDistance,
            totalDurationSec: totalDuration,
            totalActiveKcal: totalActiveKcal,
            totalLaps: totalLaps,
            avgPaceSecPer100m: roundedAverage(paces),
            avgHeartRate: roundedAverage(heartRates),
            bestPaceSecPer100m: paces.min(),
            longestDistanceM: metrics.compactMap(\.distanceM).max(),
            firstDate: sorted.first?.date,
            lastDate: sorted.last?.date
        )
    }

    static func chartSessions(_ sessions: [SwimSession]) -> [ChartSessionPoint] {
        sortedSessions(statsSessions(sessions)).map { session in
            ChartSessionPoint(
                id: session.id,
                date: session.date,
                dateLabel: SwimFormatters.formatDateShort(session.date),
                paceSecPer100m: session.metrics.paceSecPer100m,
                distanceM: session.metrics.distanceM,
                activeKcal: session.metrics.activeKcal,
                totalKcal: session.metrics.totalKcal,
                avgHeartRate: session.metrics.avgHeartRate
            )
        }
    }

    static func weeklyVolumeData(_ sessions: [SwimSession]) -> [WeeklyVolumePoint] {
        var buckets: [String: (label: String, distance: Int)] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let labelFormatter = DateFormatter()
        labelFormatter.dateFormat = "d MMM"

        for session in statsSessions(sessions) {
            guard let date = dateFormatter.date(from: session.date),
                  let distance = session.metrics.distanceM else { continue }
            let calendar = Calendar.current
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            components.weekday = 2
            let weekStart = calendar.date(from: components) ?? date
            let key = dateFormatter.string(from: weekStart)
            let label = labelFormatter.string(from: weekStart)
            let existing = buckets[key]?.distance ?? 0
            buckets[key] = (label, existing + distance)
        }

        return buckets.keys.sorted().map { key in
            WeeklyVolumePoint(weekLabel: buckets[key]!.label, distanceM: buckets[key]!.distance)
        }
    }

    static func strokeChartData(_ session: SwimSession?, t: TranslationService) -> [StrokeChartSlice] {
        guard let strokes = session?.metrics.strokes else { return [] }
        let labels: [(String, String, Int?)] = [
            ("mixedM", t.t("strokes.mixed"), strokes.mixedM),
            ("breaststrokeM", t.t("strokes.breaststroke"), strokes.breaststrokeM),
            ("freestyleM", t.t("strokes.freestyle"), strokes.freestyleM),
            ("backstrokeM", t.t("strokes.backstroke"), strokes.backstrokeM),
            ("butterflyM", t.t("strokes.butterfly"), strokes.butterflyM)
        ]
        return labels.compactMap { id, label, value in
            guard let value, value > 0 else { return nil }
            return StrokeChartSlice(id: id, label: label, value: value)
        }
    }

    static func buildProgressOverviewMessage(
        profile: SwimProfile,
        sessions: [SwimSession],
        t: TranslationService,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> String {
        let includedSessions = statsSessions(sessions)
        guard let combined = combinedStats(sessions), !includedSessions.isEmpty else {
            return applyMessagePlaceholders(t.t("progress.mascotEmpty"), profile: profile, t: t)
        }

        let monthKey = SwimMonthlyChallenges.getMonthKey()
        let mascotId = MascotUnlock.resolveMascotId(
            profile: profile,
            sessions: sessions,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
        let gameplay = MascotConstants.gameplay(mascotId)
        let monthly = SwimMonthlyChallenges.evaluateMonthlyChallenges(
            sessions: sessions,
            monthKey: monthKey,
            rerolls: monthlyChallengeRerolls,
            intensity: gameplay.challengeIntensity
        )
        let monthDistance = Self.monthDistance(includedSessions, monthKey: monthKey)
        let prevMonthDistance = Self.monthDistance(includedSessions, monthKey: shiftMonthKey(monthKey, by: -1))
        var parts: [String] = []

        if combined.sessionCount == 1 {
            parts.append(t.t("progress.overviewSingleSession"))
        } else {
            parts.append(t.t("progress.overviewSessions", params: [
                "count": String(combined.sessionCount),
                "distance": SwimFormatters.formatDistance(combined.totalDistanceM),
                "pace": SwimFormatters.formatPace(combined.avgPaceSecPer100m)
            ]))
        }

        if monthDistance > 0 {
            if prevMonthDistance > 0 {
                let change = Int((Double(monthDistance - prevMonthDistance) / Double(prevMonthDistance) * 100).rounded())
                if change >= 10 {
                    parts.append(t.t("progress.overviewMonthVolumeUp", params: [
                        "distance": SwimFormatters.formatDistance(monthDistance),
                        "percent": String(change)
                    ]))
                } else if change <= -10 && !gameplay.positiveOnly {
                    parts.append(t.t("progress.overviewMonthVolumeDown", params: [
                        "distance": SwimFormatters.formatDistance(monthDistance)
                    ]))
                } else {
                    parts.append(t.t("progress.overviewMonthVolume", params: [
                        "distance": SwimFormatters.formatDistance(monthDistance)
                    ]))
                }
            } else {
                parts.append(t.t("progress.overviewMonthVolume", params: [
                    "distance": SwimFormatters.formatDistance(monthDistance)
                ]))
            }
        }

        if monthly.completedCount >= 3 {
            parts.append(t.t("progress.overviewMonthlyGold"))
        } else if monthly.completedCount == 2 {
            parts.append(t.t("progress.overviewMonthlySilver"))
        } else if monthly.completedCount == 1 {
            parts.append(t.t("progress.overviewMonthlyBronze", params: ["remaining": "2"]))
        } else if let next = monthly.challenges.first(where: { !$0.completed }) {
            let challenge = SwimMonthlyChallengeFormatters.formatChallengeTarget(next.type, next.target, t: t)
            let current = SwimMonthlyChallengeFormatters.formatChallengeValue(next.type, next.current, t: t)
            let target = SwimMonthlyChallengeFormatters.formatChallengeValue(next.type, next.target, t: t)
            let key = gameplay.positiveOnly ? "progress.overviewMonthlyNoneFlip" : "progress.overviewMonthlyNone"
            parts.append(t.t(key, params: ["challenge": challenge, "current": current, "target": target]))
        }

        if let requiredTier = gameplay.requiredMonthlyTier {
            let requiredRank = tierRank(requiredTier)
            let currentRank = tierRank(monthly.tier)
            if currentRank < requiredRank {
                parts.append(t.t("progress.overviewCoachRequirement", params: [
                    "tier": SwimMonthlyChallengeFormatters.tierLabel(requiredTier, t: t)
                ]))
            }
        }

        var message = parts.filter { !$0.isEmpty }.joined(separator: " ")
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = applyMessagePlaceholders(t.t("progress.mascotDefault"), profile: profile, t: t)
        }
        return wrapCoachMessage(mascotId: mascotId, profile: profile, t: t, message: message)
    }

    static func buildProgressOverviewMessage(
        profile: SwimProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> String {
        buildProgressOverviewMessage(
            profile: profile,
            sessions: sessions,
            t: TranslationService(),
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
    }

    static func buildPersonalFeedback(
        session: SwimSession,
        allSessions: [SwimSession],
        profile: SwimProfile,
        t: TranslationService,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> SessionFeedbackSummary {
        SwimFeedback.buildPersonalFeedback(
            session: session,
            allSessions: allSessions,
            profile: profile,
            t: t,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
    }

    static func buildPersonalFeedback(
        session: SwimSession,
        allSessions: [SwimSession],
        profile: SwimProfile
    ) -> SessionFeedbackSummary {
        buildPersonalFeedback(
            session: session,
            allSessions: allSessions,
            profile: profile,
            t: TranslationService()
        )
    }

    static func wrapCoachMessage(mascotId: String, profile: SwimProfile, t: TranslationService, message: String) -> String {
        let key: String
        switch mascotId {
        case "flo": key = "mascot.coachWrap.flo"
        case "fins": key = "mascot.coachWrap.fins"
        default: key = "mascot.coachWrap.flip"
        }
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? MascotConstants.displayName(mascotId, t: t) : name
        return t.t(key, params: ["name": displayName, "message": message])
    }

    private static func roundedAverage(_ values: [Int]) -> Int? {
        guard let avg = average(values.map(Double.init)) else { return nil }
        return Int(avg.rounded())
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func monthDistance(_ sessions: [SwimSession], monthKey: String) -> Int {
        sessions
            .filter { $0.date.hasPrefix(monthKey) }
            .compactMap(\.metrics.distanceM)
            .reduce(0, +)
    }

    private static func shiftMonthKey(_ monthKey: String, by delta: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: "\(monthKey)-01"),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: date) else {
            return monthKey
        }
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: shifted)
    }

    private static func tierRank(_ tier: String?) -> Int {
        switch tier {
        case "gold": return 3
        case "silver": return 2
        case "bronze": return 1
        default: return 0
        }
    }

    private static func applyMessagePlaceholders(_ template: String, profile: SwimProfile, t: TranslationService) -> String {
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = name.isEmpty ? t.t("settings.swimmerNamePlaceholder") : name
        return template.replacingOccurrences(of: "{name}", with: displayName)
    }

}
