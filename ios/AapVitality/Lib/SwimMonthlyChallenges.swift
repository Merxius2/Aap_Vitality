import Foundation

enum SwimMonthlyChallenges {
    private static let challengeTypes = ["sessions", "distance", "kcal", "streak", "active_weeks"]

    static func getMonthKey(_ date: Date = Date()) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    static func tierRank(_ tier: String?) -> Int {
        switch tier {
        case "bronze": return 1
        case "silver": return 2
        case "gold": return 3
        default: return 0
        }
    }

    static func normalizeMonthRerollEntry(_ entry: MonthRerollEntry?) -> MonthRerollEntry {
        entry ?? .empty
    }

    static func normalizeMonthlyChallengeRerolls(_ raw: [String: MonthRerollEntry]) -> [String: MonthRerollEntry] {
        raw.mapValues { normalizeMonthRerollEntry($0) }
    }

    static func evaluateMonthlyChallenges(
        sessions: [SwimSession],
        monthKey: String = getMonthKey(),
        rerolls: [String: MonthRerollEntry] = [:],
        intensity: Double = 1
    ) -> MonthlyChallengeState {
        let definitions = generateMonthlyChallenges(
            sessions: sessions,
            monthKey: monthKey,
            rerolls: rerolls,
            intensity: intensity
        )
        let monthSessions = sessions.filter { $0.date.hasPrefix(monthKey) }

        let challenges = definitions.map { def -> MonthlyChallenge in
            let current = measureChallenge(type: def.type, monthSessions: monthSessions, monthKey: monthKey)
            return MonthlyChallenge(
                id: def.id,
                type: def.type,
                monthKey: def.monthKey,
                target: def.target,
                tierIndex: def.tierIndex,
                current: current,
                completed: current >= def.target
            )
        }

        let completedCount = challenges.filter(\.completed).count
        let tier: String?
        switch completedCount {
        case 3...: tier = "gold"
        case 2: tier = "silver"
        case 1: tier = "bronze"
        default: tier = nil
        }

        let earnedAt = tier != nil && !monthSessions.isEmpty ? monthSessions.last?.date : nil
        return MonthlyChallengeState(
            monthKey: monthKey,
            challenges: challenges,
            completedCount: completedCount,
            tier: tier,
            earnedAt: earnedAt
        )
    }

    static func getMonthlyTierUpgrade(
        sessionsBefore: [SwimSession],
        sessionsAfter: [SwimSession],
        monthKey: String = getMonthKey(),
        rerolls: [String: MonthRerollEntry] = [:],
        intensity: Double = 1
    ) -> (monthKey: String, tier: String, fromTier: String?, completedCount: Int, earnedAt: String?)? {
        let before = evaluateMonthlyChallenges(
            sessions: sessionsBefore,
            monthKey: monthKey,
            rerolls: rerolls,
            intensity: intensity
        )
        let after = evaluateMonthlyChallenges(
            sessions: sessionsAfter,
            monthKey: monthKey,
            rerolls: rerolls,
            intensity: intensity
        )
        if tierRank(after.tier) > tierRank(before.tier), let tier = after.tier {
            return (monthKey, tier, before.tier, after.completedCount, after.earnedAt)
        }
        return nil
    }

    static func getMonthlyChallengeHistory(
        sessions: [SwimSession],
        previewMonthlyMedals: Bool = false,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:],
        intensity: Double = 1
    ) -> [MonthlyChallengeState] {
        let months = Array(Set(sessions.map { String($0.date.prefix(7)) })).sorted(by: >)
        let real = months.compactMap { monthKey -> MonthlyChallengeState? in
            let state = evaluateMonthlyChallenges(
                sessions: sessions,
                monthKey: monthKey,
                rerolls: monthlyChallengeRerolls,
                intensity: intensity
            )
            return state.tier == nil ? nil : state
        }

        guard previewMonthlyMedals else { return real }

        let preview = getPreviewMonthlyMedalHistory(sessions: sessions)
        let realKeys = Set(real.map(\.monthKey))
        return (preview.filter { !realKeys.contains($0.monthKey) } + real)
            .sorted { $0.monthKey > $1.monthKey }
    }

    static func getMonthRerollOverrides(_ monthKey: String, rerolls: [String: MonthRerollEntry]) -> [String: String] {
        normalizeMonthRerollEntry(rerolls[monthKey]).overrides
    }

    static func getFreeMonthlyRerollsUsed(_ monthKey: String, rerolls: [String: MonthRerollEntry]) -> Int {
        normalizeMonthRerollEntry(rerolls[monthKey]).freeUses
    }

    static func hasRerollAvailability(
        monthKey: String,
        rerolls: [String: MonthRerollEntry],
        freeLimit: Int = 1
    ) -> Bool {
        getFreeMonthlyRerollsUsed(monthKey, rerolls: rerolls) < freeLimit
    }

    static func createMonthlyChallengeReroll(
        sessions: [SwimSession],
        monthKey: String,
        tierIndex: Int,
        rerolls: [String: MonthRerollEntry] = [:]
    ) -> (tierIndex: Int, type: String)? {
        guard tierIndex >= 0, tierIndex <= 2 else { return nil }
        let base = generateMonthlyChallenges(
            sessions: sessions,
            monthKey: monthKey,
            rerolls: rerolls,
            intensity: 1
        )
        let lockedTypes = base.enumerated().filter { $0.offset != tierIndex }.map(\.element.type)
        let currentType = base[tierIndex].type
        let candidates = challengeTypes.filter { !lockedTypes.contains($0) && $0 != currentType }
        let salt = getMonthRerollOverrides(monthKey, rerolls: rerolls).count
        guard let type = pickRerollType(monthKey: monthKey, tierIndex: tierIndex, candidates: candidates, salt: salt) else {
            return nil
        }
        return (tierIndex, type)
    }

    static func canRerollMonthlyChallenge(
        sessions: [SwimSession],
        monthKey: String,
        tierIndex: Int,
        rerolls: [String: MonthRerollEntry] = [:],
        intensity: Double = 1,
        freeLimit: Int = 1
    ) -> Bool {
        guard hasRerollAvailability(monthKey: monthKey, rerolls: rerolls, freeLimit: freeLimit) else {
            return false
        }
        let state = evaluateMonthlyChallenges(
            sessions: sessions,
            monthKey: monthKey,
            rerolls: rerolls,
            intensity: intensity
        )
        guard tierIndex >= 0, tierIndex < state.challenges.count else { return false }
        let challenge = state.challenges[tierIndex]
        guard !challenge.completed else { return false }
        return createMonthlyChallengeReroll(
            sessions: sessions,
            monthKey: monthKey,
            tierIndex: tierIndex,
            rerolls: rerolls
        ) != nil
    }

    static func applyMonthlyChallengeReroll(
        data: SwimData,
        monthKey: String,
        tierIndex: Int,
        mascotId: String
    ) -> SwimData? {
        let gameplay = MascotConstants.gameplay(mascotId)
        guard canRerollMonthlyChallenge(
            sessions: data.sessions,
            monthKey: monthKey,
            tierIndex: tierIndex,
            rerolls: data.monthlyChallengeRerolls,
            intensity: gameplay.challengeIntensity,
            freeLimit: gameplay.freeMonthlyRerolls
        ) else {
            return nil
        }

        guard let override = createMonthlyChallengeReroll(
            sessions: data.sessions,
            monthKey: monthKey,
            tierIndex: tierIndex,
            rerolls: data.monthlyChallengeRerolls
        ) else {
            return nil
        }

        var next = data
        var monthEntry = normalizeMonthRerollEntry(next.monthlyChallengeRerolls[monthKey])
        guard monthEntry.freeUses < gameplay.freeMonthlyRerolls else { return nil }

        monthEntry.overrides[String(override.tierIndex)] = override.type
        monthEntry.freeUses += 1
        next.monthlyChallengeRerolls[monthKey] = monthEntry
        return next
    }

    private static func getPreviewMonthlyMedalHistory(sessions: [SwimSession], date: Date = Date()) -> [MonthlyChallengeState] {
        ["gold", "silver", "bronze"].enumerated().map { index, tier in
            let calendar = Calendar.current
            let monthDate = calendar.date(byAdding: .month, value: -index, to: date) ?? date
            return buildPreviewMonthlyMedal(sessions: sessions, monthKey: getMonthKey(monthDate), tier: tier)
        }
    }

    private static func buildPreviewMonthlyMedal(
        sessions: [SwimSession],
        monthKey: String,
        tier: String
    ) -> MonthlyChallengeState {
        let state = evaluateMonthlyChallenges(sessions: sessions, monthKey: monthKey)
        let completedCount = tier == "gold" ? 3 : tier == "silver" ? 2 : 1
        let challenges = state.challenges.enumerated().map { index, challenge in
            MonthlyChallenge(
                id: challenge.id,
                type: challenge.type,
                monthKey: challenge.monthKey,
                target: challenge.target,
                tierIndex: challenge.tierIndex,
                current: index < completedCount ? challenge.target : max(0, Int(Double(challenge.target) * 0.4)),
                completed: index < completedCount
            )
        }
        let earnedDay = String(format: "%02d", min(28, 10 + completedCount * 5))
        return MonthlyChallengeState(
            monthKey: monthKey,
            challenges: challenges,
            completedCount: completedCount,
            tier: tier,
            earnedAt: "\(monthKey)-\(earnedDay)",
            isPreview: true
        )
    }

    private static func pickRerollType(
        monthKey: String,
        tierIndex: Int,
        candidates: [String],
        salt: Int
    ) -> String? {
        guard !candidates.isEmpty else { return nil }
        var seed = hashMonth("\(monthKey):reroll:\(tierIndex):\(salt)")
        if seed == 0 { seed = 1 }
        seed = (seed &* 1_103_515_245 &+ 12_345) & 0x7fff_ffff
        return candidates[seed % candidates.count]
    }

    static func generateMonthlyChallenges(
        sessions: [SwimSession],
        monthKey: String,
        rerolls: [String: MonthRerollEntry] = [:],
        intensity: Double = 1
    ) -> [ChallengeDefinition] {
        generateMonthlyChallengeDefinitions(
            sessions: sessions,
            monthKey: monthKey,
            rerolls: rerolls,
            intensity: intensity
        )
    }

    static func hasMonthlyChallengeReroll(_ monthKey: String, rerolls: [String: MonthRerollEntry]) -> Bool {
        !getMonthRerollOverrides(monthKey, rerolls: rerolls).isEmpty
    }

    static func getMonthlyMedalsForYear(
        sessions: [SwimSession],
        year: Int = Calendar.current.component(.year, from: Date()),
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:],
        intensity: Double = 1
    ) -> [YearMonthMedal] {
        (1...12).map { month in
            let monthKey = String(format: "%04d-%02d", year, month)
            let state = evaluateMonthlyChallenges(
                sessions: sessions,
                monthKey: monthKey,
                rerolls: monthlyChallengeRerolls,
                intensity: intensity
            )
            return YearMonthMedal(
                monthKey: monthKey,
                month: month,
                tier: state.tier,
                completedCount: state.completedCount,
                challenges: state.challenges,
                earnedAt: state.earnedAt,
                hasSessions: sessions.contains { $0.date.hasPrefix(monthKey) }
            )
        }
    }

    static func getPreviewMonthlyMedalHistoryForTesting(
        sessions: [SwimSession] = [],
        date: Date = Date()
    ) -> [MonthlyChallengeState] {
        getPreviewMonthlyMedalHistory(sessions: sessions, date: date)
    }

    struct ChallengeDefinition {
        var id: String
        var type: String
        var monthKey: String
        var target: Int
        var tierIndex: Int
    }

    private static func generateMonthlyChallengeDefinitions(
        sessions: [SwimSession],
        monthKey: String,
        rerolls: [String: MonthRerollEntry],
        intensity: Double
    ) -> [ChallengeDefinition] {
        let stats = computeRecentMonthlyStats(sessions: sessions, beforeMonthKey: monthKey)
        let types = pickChallengeTypes(monthKey: monthKey)
        let challenges = types.enumerated().map { index, type in
            ChallengeDefinition(
                id: "\(monthKey)_\(type)",
                type: type,
                monthKey: monthKey,
                target: buildTarget(type: type, stats: stats, tierIndex: index, intensity: intensity),
                tierIndex: index
            )
        }
        return applyRerollOverrides(challenges: challenges, monthEntry: rerolls[monthKey], stats: stats, intensity: intensity)
    }

    private static func computeRecentMonthlyStats(sessions: [SwimSession], beforeMonthKey: String) -> (
        avgSessions: Int, avgDistance: Int, avgKcal: Int, avgStreak: Int, avgWeeks: Int
    ) {
        var byMonth: [String: (sessions: Int, distanceM: Int, activeKcal: Int)] = [:]
        for session in sessions {
            let monthKey = String(session.date.prefix(7))
            guard monthKey < beforeMonthKey else { continue }
            var bucket = byMonth[monthKey] ?? (0, 0, 0)
            bucket.sessions += 1
            bucket.distanceM += session.metrics.distanceM ?? 0
            bucket.activeKcal += session.metrics.activeKcal ?? 0
            byMonth[monthKey] = bucket
        }

        let months = byMonth.keys.sorted().suffix(3)
        guard !months.isEmpty else {
            return (4, 6000, 2500, 2, 2)
        }

        var totals = (sessions: 0, distanceM: 0, activeKcal: 0)
        for month in months {
            let bucket = byMonth[month]!
            totals.sessions += bucket.sessions
            totals.distanceM += bucket.distanceM
            totals.activeKcal += bucket.activeKcal
        }
        let count = months.count
        return (
            max(1, Int(round(Double(totals.sessions) / Double(count)))),
            max(1000, Int(round(Double(totals.distanceM) / Double(count)))),
            max(500, Int(round(Double(totals.activeKcal) / Double(count)))),
            2,
            2
        )
    }

    private static func buildTarget(type: String, stats: (avgSessions: Int, avgDistance: Int, avgKcal: Int, avgStreak: Int, avgWeeks: Int), tierIndex: Int, intensity: Double) -> Int {
        let stretch = (1 + Double(tierIndex) * 0.12) * intensity
        switch type {
        case "sessions":
            return max(2, Int(ceil(Double(stats.avgSessions) * stretch)))
        case "distance":
            return max(Int(ceil(4000 * intensity / 500) * 500), Int(ceil(Double(stats.avgDistance) * stretch / 500) * 500))
        case "kcal":
            return max(Int(ceil(1500 * intensity / 250) * 250), Int(ceil(Double(stats.avgKcal) * stretch / 250) * 250))
        case "streak":
            return max(2, min(7, stats.avgStreak + tierIndex))
        case "active_weeks":
            return max(2, min(4, stats.avgWeeks + tierIndex - 1))
        default:
            return 1
        }
    }

    private static func pickChallengeTypes(monthKey: String) -> [String] {
        var pool = challengeTypes
        var picked: [String] = []
        var seed = hashMonth(monthKey)
        for _ in 0..<3 {
            seed = (seed &* 1_103_515_245 &+ 12_345) & 0x7fff_ffff
            let index = seed % pool.count
            picked.append(pool.remove(at: index))
        }
        return picked
    }

    private static func hashMonth(_ monthKey: String) -> Int {
        monthKey.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) | 0 }
    }

    private static func applyRerollOverrides(
        challenges: [ChallengeDefinition],
        monthEntry: MonthRerollEntry?,
        stats: (avgSessions: Int, avgDistance: Int, avgKcal: Int, avgStreak: Int, avgWeeks: Int),
        intensity: Double
    ) -> [ChallengeDefinition] {
        let overrides = normalizeMonthRerollEntry(monthEntry).overrides
        return challenges.enumerated().map { index, challenge in
            guard let type = overrides[String(index)] else { return challenge }
            return ChallengeDefinition(
                id: "\(challenge.monthKey)_\(type)",
                type: type,
                monthKey: challenge.monthKey,
                target: buildTarget(type: type, stats: stats, tierIndex: index, intensity: intensity),
                tierIndex: index
            )
        }
    }

    private static func measureChallenge(type: String, monthSessions: [SwimSession], monthKey: String) -> Int {
        switch type {
        case "sessions":
            return monthSessions.count
        case "distance":
            return monthSessions.compactMap(\.metrics.distanceM).reduce(0, +)
        case "kcal":
            return monthSessions.compactMap(\.metrics.activeKcal).reduce(0, +)
        case "streak":
            return maxConsecutiveDaysInMonth(sessions: monthSessions, monthKey: monthKey)
        case "active_weeks":
            return activeWeeksInMonth(monthSessions: monthSessions, monthKey: monthKey)
        default:
            return 0
        }
    }

    private static func maxConsecutiveDaysInMonth(sessions: [SwimSession], monthKey: String) -> Int {
        let dates = Array(Set(sessions.filter { $0.date.hasPrefix(monthKey) }.map(\.date))).sorted()
        guard !dates.isEmpty else { return 0 }
        var maxStreak = 1
        var streak = 1
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        for index in 1..<dates.count {
            guard let prev = formatter.date(from: dates[index - 1]),
                  let curr = formatter.date(from: dates[index]) else { continue }
            let diff = Calendar.current.dateComponents([.day], from: prev, to: curr).day ?? 0
            streak = diff == 1 ? streak + 1 : 1
            maxStreak = max(maxStreak, streak)
        }
        return maxStreak
    }

    private static func activeWeeksInMonth(monthSessions: [SwimSession], monthKey: String) -> Int {
        Set(monthSessions.filter { $0.date.hasPrefix(monthKey) }.map { weekKey(for: $0.date) }).count
    }

    private static func weekKey(for dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let diff = calendar.component(.day, from: date) - weekday + (weekday == 1 ? -6 : 1)
        guard let monday = calendar.date(byAdding: .day, value: diff - calendar.component(.day, from: date), to: date) else {
            return dateStr
        }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: monday)
    }
}
