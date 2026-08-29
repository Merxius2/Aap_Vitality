import Foundation

enum SwimMedals {
    static let medals: [MedalDefinition] = [
        // Milestones
        MedalDefinition(id: "first_splash", category: "milestone", tier: "bronze", season: nil),
        MedalDefinition(id: "ten_sessions", category: "milestone", tier: "silver", season: nil),
        MedalDefinition(id: "twenty_five_sessions", category: "milestone", tier: "gold", season: nil),
        MedalDefinition(id: "ten_k_lifetime", category: "milestone", tier: "bronze", season: nil),
        MedalDefinition(id: "fifty_k_lifetime", category: "milestone", tier: "silver", season: nil),
        MedalDefinition(id: "hundred_k_lifetime", category: "milestone", tier: "gold", season: nil),
        MedalDefinition(id: "fifty_sessions", category: "milestone", tier: "silver", season: nil),
        MedalDefinition(id: "two_hundred_k", category: "milestone", tier: "gold", season: nil),
        MedalDefinition(id: "lap_legend", category: "milestone", tier: "silver", season: nil),
        MedalDefinition(id: "calorie_collector", category: "milestone", tier: "gold", season: nil),
        // Session records
        MedalDefinition(id: "two_k_session", category: "distance", tier: "bronze", season: nil),
        MedalDefinition(id: "two_five_k_session", category: "distance", tier: "silver", season: nil),
        MedalDefinition(id: "three_k_session", category: "distance", tier: "gold", season: nil),
        MedalDefinition(id: "sub_200_pace", category: "distance", tier: "gold", season: nil),
        MedalDefinition(id: "sub_210_pace", category: "distance", tier: "silver", season: nil),
        MedalDefinition(id: "marathon_session", category: "distance", tier: "gold", season: nil),
        MedalDefinition(id: "century_laps", category: "distance", tier: "silver", season: nil),
        MedalDefinition(id: "furnace", category: "distance", tier: "silver", season: nil),
        MedalDefinition(id: "pulse_racer", category: "distance", tier: "bronze", season: nil),
        MedalDefinition(id: "goal_crusher", category: "distance", tier: "bronze", season: nil),
        MedalDefinition(id: "frog_master", category: "distance", tier: "bronze", season: nil),
        // Weekly
        MedalDefinition(id: "four_sessions_week", category: "weekly", tier: "silver", season: nil),
        MedalDefinition(id: "five_k_week", category: "weekly", tier: "bronze", season: nil),
        // Streaks
        MedalDefinition(id: "hat_trick", category: "streak", tier: "bronze", season: nil),
        MedalDefinition(id: "week_warrior", category: "streak", tier: "silver", season: nil),
        MedalDefinition(id: "fortnight_flow", category: "streak", tier: "gold", season: nil),
        // Monthly
        MedalDefinition(id: "eight_sessions_month", category: "monthly", tier: "silver", season: nil),
        MedalDefinition(id: "ten_k_month", category: "monthly", tier: "bronze", season: nil),
        MedalDefinition(id: "twenty_k_month", category: "monthly", tier: "silver", season: nil),
        MedalDefinition(id: "ten_k_cal_month", category: "monthly", tier: "gold", season: nil),
        // Seasonal
        MedalDefinition(id: "season_summer", category: "seasonal", tier: "gold", season: "summer"),
        MedalDefinition(id: "season_winter", category: "seasonal", tier: "silver", season: "winter"),
        MedalDefinition(id: "season_spring", category: "seasonal", tier: "bronze", season: "spring"),
        MedalDefinition(id: "season_autumn", category: "seasonal", tier: "bronze", season: "autumn"),
        // Special
        MedalDefinition(id: "early_bird", category: "special", tier: "bronze", season: nil),
        MedalDefinition(id: "night_owl", category: "special", tier: "bronze", season: nil),
        MedalDefinition(id: "comeback", category: "special", tier: "silver", season: nil),
        MedalDefinition(id: "double_dip", category: "special", tier: "bronze", season: nil),
        MedalDefinition(id: "holiday_splash", category: "special", tier: "silver", season: nil),
        MedalDefinition(id: "january_jolt", category: "special", tier: "bronze", season: nil),
    ]

    struct MedalContext {
        var sessions: [SwimSession]
        var totalSessions: Int
        var totalDistanceM: Int
        var totalActiveKcal: Int
        var byWeek: [String: PeriodBucket]
        var byMonth: [String: PeriodBucket]
        var bySeason: [String: PeriodBucket]
        var currentMonthKey: String
        var currentSeasonKey: String
        var maxSessionsInWeek: Int
        var maxDistanceInWeek: Int
        var maxSessionsInMonth: Int
        var maxDistanceInMonth: Int
        var maxActiveKcalInMonth: Int
        var monthsWith8Sessions: [String]
        var monthsWith10k: [String]
        var monthsWith20k: [String]
        var monthsWith10kCal: [String]
        var seasonsWith15k: [String]
        var seasonsWith10k: [String]
        var seasonsWith8Sessions: [String]
        var bestPace: Int?
        var maxDistance: Int?
        var maxDurationSec: Int?
        var maxLapsSession: Int?
        var maxActiveKcalSession: Int?
        var maxHeartRate: Int?
        var maxBreaststrokeM: Int?
        var totalLaps: Int
        var maxConsecutiveDays: Int
        var maxSessionsInDay: Int
        var hasGoalCrusher: Bool
        var hasEarlyBird: Bool
        var hasNightOwl: Bool
        var hasComeback: Bool
        var hasHolidaySplash: Bool
        var hasJanuaryJolt: Bool
    }

    struct PeriodBucket {
        var sessions: Int
        var distanceM: Int
        var activeKcal: Int
    }

    private struct MedalEvaluation {
        var earned: Bool
        var periods: [String]
    }

    private struct SeasonInfo {
        var name: String
        var year: Int
    }

    static func buildMedalContext(_ sessions: [SwimSession]) -> MedalContext {
        let sorted = sessions.sorted { $0.date < $1.date }

        let totalDistanceM = sorted.reduce(0) { $0 + ($1.metrics.distanceM ?? 0) }
        let totalActiveKcal = sorted.reduce(0) { $0 + ($1.metrics.activeKcal ?? 0) }

        var byWeek: [String: PeriodBucket] = [:]
        var byMonth: [String: PeriodBucket] = [:]
        var bySeason: [String: PeriodBucket] = [:]

        for session in sorted {
            let weekKey = getWeekKey(session.date)
            let monthKey = getMonthKey(session.date)
            let seasonKey = seasonLabel(getSeason(session.date))

            var weekBucket = byWeek[weekKey] ?? PeriodBucket(sessions: 0, distanceM: 0, activeKcal: 0)
            weekBucket.sessions += 1
            weekBucket.distanceM += session.metrics.distanceM ?? 0
            weekBucket.activeKcal += session.metrics.activeKcal ?? 0
            byWeek[weekKey] = weekBucket

            var monthBucket = byMonth[monthKey] ?? PeriodBucket(sessions: 0, distanceM: 0, activeKcal: 0)
            monthBucket.sessions += 1
            monthBucket.distanceM += session.metrics.distanceM ?? 0
            monthBucket.activeKcal += session.metrics.activeKcal ?? 0
            byMonth[monthKey] = monthBucket

            var seasonBucket = bySeason[seasonKey] ?? PeriodBucket(sessions: 0, distanceM: 0, activeKcal: 0)
            seasonBucket.sessions += 1
            seasonBucket.distanceM += session.metrics.distanceM ?? 0
            seasonBucket.activeKcal += session.metrics.activeKcal ?? 0
            bySeason[seasonKey] = seasonBucket
        }

        func maxInWeek(_ field: KeyPath<PeriodBucket, Int>) -> Int {
            byWeek.values.map { $0[keyPath: field] }.max() ?? 0
        }

        func monthsMeeting(_ field: KeyPath<PeriodBucket, Int>, threshold: Int) -> [String] {
            byMonth.compactMap { key, value in
                value[keyPath: field] >= threshold ? key : nil
            }
        }

        func seasonsMeeting(_ field: KeyPath<PeriodBucket, Int>, threshold: Int) -> [String] {
            bySeason.compactMap { key, value in
                value[keyPath: field] >= threshold ? key : nil
            }
        }

        var bestPace: Int?
        for session in sorted {
            guard let pace = session.metrics.paceSecPer100m else { continue }
            if bestPace == nil || pace < bestPace! {
                bestPace = pace
            }
        }

        var maxDistance: Int?
        for session in sorted {
            guard let distance = session.metrics.distanceM else { continue }
            if maxDistance == nil || distance > maxDistance! {
                maxDistance = distance
            }
        }

        var maxDurationSec: Int?
        for session in sorted {
            guard let duration = session.metrics.durationSec else { continue }
            if maxDurationSec == nil || duration > maxDurationSec! {
                maxDurationSec = duration
            }
        }

        var maxLapsSession: Int?
        for session in sorted {
            guard let laps = session.metrics.laps else { continue }
            if maxLapsSession == nil || laps > maxLapsSession! {
                maxLapsSession = laps
            }
        }

        var maxActiveKcalSession: Int?
        for session in sorted {
            guard let kcal = session.metrics.activeKcal else { continue }
            if maxActiveKcalSession == nil || kcal > maxActiveKcalSession! {
                maxActiveKcalSession = kcal
            }
        }

        var maxHeartRate: Int?
        for session in sorted {
            guard let heartRate = session.metrics.avgHeartRate else { continue }
            if maxHeartRate == nil || heartRate > maxHeartRate! {
                maxHeartRate = heartRate
            }
        }

        var maxBreaststrokeM: Int?
        for session in sorted {
            guard let breaststroke = session.metrics.strokes.breaststrokeM else { continue }
            if maxBreaststrokeM == nil || breaststroke > maxBreaststrokeM! {
                maxBreaststrokeM = breaststroke
            }
        }

        let totalLaps = sorted.reduce(0) { $0 + ($1.metrics.laps ?? 0) }

        let uniqueDates = Array(Set(sorted.map(\.date)))
        let maxConsecutiveDays = getMaxConsecutiveDays(uniqueDates)

        var sessionsByDate: [String: Int] = [:]
        for session in sorted {
            sessionsByDate[session.date, default: 0] += 1
        }
        let maxSessionsInDay = sessionsByDate.values.max() ?? 0

        let hasGoalCrusher = sorted.contains { session in
            let metrics = session.metrics
            guard let goal = metrics.goalM, let distance = metrics.distanceM else { return false }
            return distance >= goal
        }

        let hasEarlyBird = sorted.contains { session in
            guard let start = parseTimeRangeStartMin(session.metrics.timeRange) else { return false }
            return start < 7 * 60
        }

        let hasNightOwl = sorted.contains { session in
            guard let start = parseTimeRangeStartMin(session.metrics.timeRange) else { return false }
            return start >= 20 * 60
        }

        let hasComeback = sorted.enumerated().contains { index, session in
            guard index > 0 else { return false }
            let previousDate = sorted[index - 1].date
            guard let gap = dayGap(from: previousDate, to: session.date) else { return false }
            return gap >= 30
        }

        let hasHolidaySplash = sorted.contains { isHolidaySplashDate($0.date) }

        let hasJanuaryJolt = sorted.contains { session in
            guard let month = monthComponent(from: session.date) else { return false }
            return month == 1
        }

        let todayKey = todayDateKey()
        let currentMonthKey = getMonthKey(todayKey)
        let currentSeasonKey = seasonLabel(getSeason(todayKey))

        return MedalContext(
            sessions: sorted,
            totalSessions: sorted.count,
            totalDistanceM: totalDistanceM,
            totalActiveKcal: totalActiveKcal,
            byWeek: byWeek,
            byMonth: byMonth,
            bySeason: bySeason,
            currentMonthKey: currentMonthKey,
            currentSeasonKey: currentSeasonKey,
            maxSessionsInWeek: maxInWeek(\.sessions),
            maxDistanceInWeek: maxInWeek(\.distanceM),
            maxSessionsInMonth: maxInMonth(byMonth, field: \.sessions),
            maxDistanceInMonth: maxInMonth(byMonth, field: \.distanceM),
            maxActiveKcalInMonth: maxInMonth(byMonth, field: \.activeKcal),
            monthsWith8Sessions: monthsMeeting(\.sessions, threshold: 8),
            monthsWith10k: monthsMeeting(\.distanceM, threshold: 10000),
            monthsWith20k: monthsMeeting(\.distanceM, threshold: 20000),
            monthsWith10kCal: monthsMeeting(\.activeKcal, threshold: 10000),
            seasonsWith15k: seasonsMeeting(\.distanceM, threshold: 15000),
            seasonsWith10k: seasonsMeeting(\.distanceM, threshold: 10000),
            seasonsWith8Sessions: seasonsMeeting(\.sessions, threshold: 8),
            bestPace: bestPace,
            maxDistance: maxDistance,
            maxDurationSec: maxDurationSec,
            maxLapsSession: maxLapsSession,
            maxActiveKcalSession: maxActiveKcalSession,
            maxHeartRate: maxHeartRate,
            maxBreaststrokeM: maxBreaststrokeM,
            totalLaps: totalLaps,
            maxConsecutiveDays: maxConsecutiveDays,
            maxSessionsInDay: maxSessionsInDay,
            hasGoalCrusher: hasGoalCrusher,
            hasEarlyBird: hasEarlyBird,
            hasNightOwl: hasNightOwl,
            hasComeback: hasComeback,
            hasHolidaySplash: hasHolidaySplash,
            hasJanuaryJolt: hasJanuaryJolt
        )
    }

    static func computeEarnedAtMap(_ sessions: [SwimSession]) -> [String: String] {
        let sorted = sessions.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
        guard !sorted.isEmpty else { return [:] }

        var earnedAt: [String: String] = [:]
        var found = Set<String>()

        for index in sorted.indices {
            let slice = Array(sorted.prefix(index + 1))
            let ctx = buildMedalContext(slice)
            for medal in medals {
                guard !found.contains(medal.id) else { continue }
                let result = evaluateMedal(medal, ctx: ctx)
                if result.earned {
                    earnedAt[medal.id] = sorted[index].date
                    found.insert(medal.id)
                }
            }
            if found.count == medals.count { break }
        }

        return earnedAt
    }

    static func evaluateAllMedals(
        _ sessions: [SwimSession],
        allMedalsUnlocked: Bool = false
    ) -> [EvaluatedMedal] {
        let ctx = buildMedalContext(sessions)
        let earnedAtMap = computeEarnedAtMap(sessions)
        let today = todayDateKey()

        return medals.map { medal in
            let result = evaluateMedal(medal, ctx: ctx)
            let earned = allMedalsUnlocked || result.earned
            return EvaluatedMedal(
                id: medal.id,
                category: medal.category,
                tier: medal.tier,
                season: medal.season,
                earned: earned,
                earnedAt: earned ? (earnedAtMap[medal.id] ?? today) : nil,
                periods: result.periods,
                progress: earned ? nil : getMedalProgress(medal, ctx: ctx)
            )
        }
    }

    static func getMedalProgress(_ medal: MedalDefinition, ctx: MedalContext) -> MedalProgress? {
        let emptyMonth = PeriodBucket(sessions: 0, distanceM: 0, activeKcal: 0)
        let currentMonth = ctx.byMonth[ctx.currentMonthKey] ?? emptyMonth
        let currentSeason = ctx.bySeason[ctx.currentSeasonKey] ?? emptyMonth

        func countProgress(_ current: Int, _ target: Int, _ scope: String, best: Int? = nil, bestPeriod: String? = nil) -> MedalProgress {
            MedalProgress(
                percent: clampPercent(current, target),
                kind: "sessions",
                scope: scope,
                current: current,
                target: target,
                best: best,
                bestPeriod: bestPeriod
            )
        }

        func distanceProgress(_ current: Int, _ target: Int, _ scope: String, best: Int? = nil, bestPeriod: String? = nil) -> MedalProgress {
            MedalProgress(
                percent: clampPercent(current, target),
                kind: "distance",
                scope: scope,
                current: current,
                target: target,
                best: best,
                bestPeriod: bestPeriod
            )
        }

        func kcalProgress(_ current: Int, _ target: Int, _ scope: String, best: Int? = nil, bestPeriod: String? = nil) -> MedalProgress {
            MedalProgress(
                percent: clampPercent(current, target),
                kind: "kcal",
                scope: scope,
                current: current,
                target: target,
                best: best,
                bestPeriod: bestPeriod
            )
        }

        switch medal.id {
        case "first_splash":
            return countProgress(ctx.totalSessions, 1, "lifetime")
        case "ten_sessions":
            return countProgress(ctx.totalSessions, 10, "lifetime")
        case "twenty_five_sessions":
            return countProgress(ctx.totalSessions, 25, "lifetime")
        case "ten_k_lifetime":
            return distanceProgress(ctx.totalDistanceM, 10000, "lifetime")
        case "fifty_k_lifetime":
            return distanceProgress(ctx.totalDistanceM, 50000, "lifetime")
        case "hundred_k_lifetime":
            return distanceProgress(ctx.totalDistanceM, 100000, "lifetime")
        case "fifty_sessions":
            return countProgress(ctx.totalSessions, 50, "lifetime")
        case "two_hundred_k":
            return distanceProgress(ctx.totalDistanceM, 200000, "lifetime")
        case "lap_legend":
            return countProgress(ctx.totalLaps, 1000, "lifetime")
        case "calorie_collector":
            return kcalProgress(ctx.totalActiveKcal, 25000, "lifetime")
        case "two_k_session":
            return distanceProgress(ctx.maxDistance ?? 0, 2000, "best_session")
        case "two_five_k_session":
            return distanceProgress(ctx.maxDistance ?? 0, 2500, "best_session")
        case "three_k_session":
            return distanceProgress(ctx.maxDistance ?? 0, 3000, "best_session")
        case "sub_200_pace":
            return MedalProgress(
                percent: paceProgressPercent(ctx.bestPace),
                kind: "pace",
                scope: "best_session",
                current: ctx.bestPace,
                target: 120,
                best: nil,
                bestPeriod: nil
            )
        case "sub_210_pace":
            return MedalProgress(
                percent: paceProgressPercent(ctx.bestPace, targetSec: 130, baselineSec: 190),
                kind: "pace",
                scope: "best_session",
                current: ctx.bestPace,
                target: 130,
                best: nil,
                bestPeriod: nil
            )
        case "marathon_session":
            return MedalProgress(
                percent: clampPercent(ctx.maxDurationSec ?? 0, 5400),
                kind: "duration",
                scope: "best_session",
                current: ctx.maxDurationSec,
                target: 5400,
                best: nil,
                bestPeriod: nil
            )
        case "century_laps":
            return countProgress(ctx.maxLapsSession ?? 0, 100, "best_session")
        case "furnace":
            return kcalProgress(ctx.maxActiveKcalSession ?? 0, 800, "best_session")
        case "pulse_racer":
            return countProgress(ctx.maxHeartRate ?? 0, 155, "best_session")
        case "frog_master":
            return distanceProgress(ctx.maxBreaststrokeM ?? 0, 1000, "best_session")
        case "four_sessions_week":
            return countProgress(ctx.maxSessionsInWeek, 4, "best_week")
        case "five_k_week":
            return distanceProgress(ctx.maxDistanceInWeek, 5000, "best_week")
        case "hat_trick":
            return countProgress(ctx.maxConsecutiveDays, 3, "lifetime")
        case "week_warrior":
            return countProgress(ctx.maxConsecutiveDays, 7, "lifetime")
        case "fortnight_flow":
            return countProgress(ctx.maxConsecutiveDays, 14, "lifetime")
        case "eight_sessions_month":
            let best = bestMonthEntry(ctx.byMonth, field: "sessions")
            return countProgress(currentMonth.sessions, 8, "current_month", best: best?.value, bestPeriod: best?.key)
        case "ten_k_month":
            let best = bestMonthEntry(ctx.byMonth, field: "distanceM")
            return distanceProgress(currentMonth.distanceM, 10000, "current_month", best: best?.value, bestPeriod: best?.key)
        case "twenty_k_month":
            let best = bestMonthEntry(ctx.byMonth, field: "distanceM")
            return distanceProgress(currentMonth.distanceM, 20000, "current_month", best: best?.value, bestPeriod: best?.key)
        case "ten_k_cal_month":
            let best = bestMonthEntry(ctx.byMonth, field: "activeKcal")
            return kcalProgress(currentMonth.activeKcal, 10000, "current_month", best: best?.value, bestPeriod: best?.key)
        case "season_summer", "season_winter", "season_spring", "season_autumn":
            guard let prefix = medal.season else { return nil }
            let target = prefix == "summer" ? 15000 : 10000
            let inSeason = ctx.currentSeasonKey.hasPrefix("\(prefix)-")
            let current = inSeason ? currentSeason.distanceM : maxSeasonDistance(ctx.bySeason, prefix: prefix)
            let scope = inSeason ? "current_season" : "best_season"
            let best = bestSeasonEntry(ctx.bySeason, prefix: prefix)
            return distanceProgress(current, target, scope, best: best?.distanceM, bestPeriod: best?.key)
        default:
            return nil
        }
    }

    private static func clampPercent(_ current: Int, _ target: Int) -> Int {
        guard target > 0 else { return 0 }
        return max(0, min(100, Int(round(Double(current) / Double(target) * 100))))
    }

    private static func paceProgressPercent(_ bestPace: Int?, targetSec: Int = 120, baselineSec: Int = 180) -> Int {
        guard let bestPace else { return 0 }
        if bestPace <= targetSec { return 100 }
        if bestPace >= baselineSec { return 0 }
        return Int(round(Double(baselineSec - bestPace) / Double(baselineSec - targetSec) * 100))
    }

    private static func bestMonthEntry(_ byMonth: [String: PeriodBucket], field: String) -> (key: String, value: Int)? {
        var best: (key: String, value: Int)?
        for (key, bucket) in byMonth {
            let value: Int
            switch field {
            case "sessions": value = bucket.sessions
            case "distanceM": value = bucket.distanceM
            case "activeKcal": value = bucket.activeKcal
            default: continue
            }
            if best == nil || value > best!.value {
                best = (key, value)
            }
        }
        return best
    }

    private static func bestSeasonEntry(_ bySeason: [String: PeriodBucket], prefix: String) -> (key: String, distanceM: Int)? {
        var best: (key: String, distanceM: Int)?
        for (key, value) in bySeason where key.hasPrefix("\(prefix)-") {
            if best == nil || value.distanceM > best!.distanceM {
                best = (key, value.distanceM)
            }
        }
        return best
    }

    private static func maxSeasonDistance(_ bySeason: [String: PeriodBucket], prefix: String) -> Int {
        bySeason.filter { $0.key.hasPrefix("\(prefix)-") }.map(\.value.distanceM).max() ?? 0
    }

    static func getMedalStats(_ medals: [EvaluatedMedal]) -> (earned: Int, total: Int) {
        (medals.filter(\.earned).count, medals.count)
    }

    static func getNewlyEarnedMedals(
        sessionsBefore: [SwimSession],
        sessionsAfter: [SwimSession],
        allMedalsUnlocked: Bool = false
    ) -> [EvaluatedMedal] {
        let beforeEarned = Set(
            evaluateAllMedals(sessionsBefore, allMedalsUnlocked: allMedalsUnlocked)
                .filter(\.earned)
                .map(\.id)
        )
        return evaluateAllMedals(sessionsAfter, allMedalsUnlocked: allMedalsUnlocked)
            .filter { $0.earned && !beforeEarned.contains($0.id) }
    }

    private static func evaluateMedal(_ medal: MedalDefinition, ctx: MedalContext) -> MedalEvaluation {
        switch medal.id {
        case "first_splash":
            return MedalEvaluation(earned: ctx.totalSessions >= 1, periods: [])
        case "ten_sessions":
            return MedalEvaluation(earned: ctx.totalSessions >= 10, periods: [])
        case "twenty_five_sessions":
            return MedalEvaluation(earned: ctx.totalSessions >= 25, periods: [])
        case "ten_k_lifetime":
            return MedalEvaluation(earned: ctx.totalDistanceM >= 10000, periods: [])
        case "fifty_k_lifetime":
            return MedalEvaluation(earned: ctx.totalDistanceM >= 50000, periods: [])
        case "hundred_k_lifetime":
            return MedalEvaluation(earned: ctx.totalDistanceM >= 100000, periods: [])
        case "fifty_sessions":
            return MedalEvaluation(earned: ctx.totalSessions >= 50, periods: [])
        case "two_hundred_k":
            return MedalEvaluation(earned: ctx.totalDistanceM >= 200000, periods: [])
        case "lap_legend":
            return MedalEvaluation(earned: ctx.totalLaps >= 1000, periods: [])
        case "calorie_collector":
            return MedalEvaluation(earned: ctx.totalActiveKcal >= 25000, periods: [])
        case "two_k_session":
            return MedalEvaluation(earned: (ctx.maxDistance ?? 0) >= 2000, periods: [])
        case "two_five_k_session":
            return MedalEvaluation(earned: (ctx.maxDistance ?? 0) >= 2500, periods: [])
        case "three_k_session":
            return MedalEvaluation(earned: (ctx.maxDistance ?? 0) >= 3000, periods: [])
        case "sub_200_pace":
            return MedalEvaluation(earned: ctx.bestPace != nil && ctx.bestPace! <= 120, periods: [])
        case "sub_210_pace":
            return MedalEvaluation(earned: ctx.bestPace != nil && ctx.bestPace! <= 130, periods: [])
        case "marathon_session":
            return MedalEvaluation(earned: (ctx.maxDurationSec ?? 0) >= 5400, periods: [])
        case "century_laps":
            return MedalEvaluation(earned: (ctx.maxLapsSession ?? 0) >= 100, periods: [])
        case "furnace":
            return MedalEvaluation(earned: (ctx.maxActiveKcalSession ?? 0) >= 800, periods: [])
        case "pulse_racer":
            return MedalEvaluation(earned: (ctx.maxHeartRate ?? 0) >= 155, periods: [])
        case "goal_crusher":
            return MedalEvaluation(earned: ctx.hasGoalCrusher, periods: [])
        case "frog_master":
            return MedalEvaluation(earned: (ctx.maxBreaststrokeM ?? 0) >= 1000, periods: [])
        case "four_sessions_week":
            return MedalEvaluation(earned: ctx.maxSessionsInWeek >= 4, periods: [])
        case "five_k_week":
            return MedalEvaluation(earned: ctx.maxDistanceInWeek >= 5000, periods: [])
        case "hat_trick":
            return MedalEvaluation(earned: ctx.maxConsecutiveDays >= 3, periods: [])
        case "week_warrior":
            return MedalEvaluation(earned: ctx.maxConsecutiveDays >= 7, periods: [])
        case "fortnight_flow":
            return MedalEvaluation(earned: ctx.maxConsecutiveDays >= 14, periods: [])
        case "eight_sessions_month":
            return MedalEvaluation(earned: !ctx.monthsWith8Sessions.isEmpty, periods: ctx.monthsWith8Sessions)
        case "ten_k_month":
            return MedalEvaluation(earned: !ctx.monthsWith10k.isEmpty, periods: ctx.monthsWith10k)
        case "twenty_k_month":
            return MedalEvaluation(earned: !ctx.monthsWith20k.isEmpty, periods: ctx.monthsWith20k)
        case "ten_k_cal_month":
            return MedalEvaluation(earned: !ctx.monthsWith10kCal.isEmpty, periods: ctx.monthsWith10kCal)
        case "season_summer":
            return MedalEvaluation(
                earned: ctx.seasonsWith15k.contains { $0.hasPrefix("summer-") },
                periods: ctx.seasonsWith15k.filter { $0.hasPrefix("summer-") }
            )
        case "season_winter":
            return MedalEvaluation(
                earned: ctx.seasonsWith10k.contains { $0.hasPrefix("winter-") },
                periods: ctx.seasonsWith10k.filter { $0.hasPrefix("winter-") }
            )
        case "season_spring":
            return MedalEvaluation(
                earned: ctx.seasonsWith10k.contains { $0.hasPrefix("spring-") },
                periods: ctx.seasonsWith10k.filter { $0.hasPrefix("spring-") }
            )
        case "season_autumn":
            return MedalEvaluation(
                earned: ctx.seasonsWith10k.contains { $0.hasPrefix("autumn-") },
                periods: ctx.seasonsWith10k.filter { $0.hasPrefix("autumn-") }
            )
        case "early_bird":
            return MedalEvaluation(earned: ctx.hasEarlyBird, periods: [])
        case "night_owl":
            return MedalEvaluation(earned: ctx.hasNightOwl, periods: [])
        case "comeback":
            return MedalEvaluation(earned: ctx.hasComeback, periods: [])
        case "double_dip":
            return MedalEvaluation(earned: ctx.maxSessionsInDay >= 2, periods: [])
        case "holiday_splash":
            return MedalEvaluation(earned: ctx.hasHolidaySplash, periods: [])
        case "january_jolt":
            return MedalEvaluation(earned: ctx.hasJanuaryJolt, periods: [])
        default:
            return MedalEvaluation(earned: false, periods: [])
        }
    }

    private static func getWeekKey(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let day = calendar.component(.day, from: date)
        let diff = day - weekday + (weekday == 1 ? -6 : 1)
        guard let monday = calendar.date(byAdding: .day, value: diff - day, to: date) else {
            return dateStr
        }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }

    private static func getMonthKey(_ dateStr: String) -> String {
        String(dateStr.prefix(7))
    }

    private static func getSeason(_ dateStr: String) -> SeasonInfo {
        let month = monthComponent(from: dateStr) ?? 1
        let year = yearComponent(from: dateStr) ?? 2000
        if (6...8).contains(month) {
            return SeasonInfo(name: "summer", year: year)
        }
        if month >= 12 {
            return SeasonInfo(name: "winter", year: year)
        }
        if month <= 2 {
            return SeasonInfo(name: "winter", year: year - 1)
        }
        if (3...5).contains(month) {
            return SeasonInfo(name: "spring", year: year)
        }
        return SeasonInfo(name: "autumn", year: year)
    }

    private static func seasonLabel(_ season: SeasonInfo) -> String {
        "\(season.name)-\(season.year)"
    }

    private static func maxInMonth(
        _ byMonth: [String: PeriodBucket],
        field: KeyPath<PeriodBucket, Int>
    ) -> Int {
        byMonth.values.map { $0[keyPath: field] }.max() ?? 0
    }

    private static func parseTimeRangeStartMin(_ timeRange: String) -> Int? {
        guard !timeRange.isEmpty else { return nil }
        let pattern = #"^(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: timeRange, range: NSRange(timeRange.startIndex..., in: timeRange)),
              match.numberOfRanges == 3,
              let hourRange = Range(match.range(at: 1), in: timeRange),
              let minuteRange = Range(match.range(at: 2), in: timeRange),
              let hour = Int(timeRange[hourRange]),
              let minute = Int(timeRange[minuteRange]) else {
            return nil
        }
        return hour * 60 + minute
    }

    private static func getMaxConsecutiveDays(_ dates: [String]) -> Int {
        let sorted = dates.sorted()
        guard !sorted.isEmpty else { return 0 }
        var maxStreak = 1
        var streak = 1
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for index in 1..<sorted.count {
            guard let prev = formatter.date(from: sorted[index - 1]),
                  let curr = formatter.date(from: sorted[index]) else { continue }
            let diffDays = Calendar.current.dateComponents([.day], from: prev, to: curr).day ?? 0
            streak = diffDays == 1 ? streak + 1 : 1
            maxStreak = max(maxStreak, streak)
        }
        return maxStreak
    }

    private static func isHolidaySplashDate(_ dateStr: String) -> Bool {
        guard let month = monthComponent(from: dateStr),
              let day = dayComponent(from: dateStr) else {
            return false
        }
        return (month == 12 && day >= 20) || (month == 1 && day <= 5)
    }

    private static func dayGap(from startDate: String, to endDate: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: startDate),
              let end = formatter.date(from: endDate) else {
            return nil
        }
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }

    private static func monthComponent(from dateStr: String) -> Int? {
        guard dateStr.count >= 7 else { return nil }
        let start = dateStr.index(dateStr.startIndex, offsetBy: 5)
        let end = dateStr.index(start, offsetBy: 2)
        return Int(dateStr[start..<end])
    }

    private static func dayComponent(from dateStr: String) -> Int? {
        guard dateStr.count >= 10 else { return nil }
        let start = dateStr.index(dateStr.startIndex, offsetBy: 8)
        let end = dateStr.index(start, offsetBy: 2)
        return Int(dateStr[start..<end])
    }

    private static func yearComponent(from dateStr: String) -> Int? {
        guard dateStr.count >= 4 else { return nil }
        return Int(dateStr.prefix(4))
    }

    private static func todayDateKey() -> String {
        String(ISO8601DateFormatter().string(from: Date()).prefix(10))
    }
}
