import Foundation

enum MascotUnlock {
    static let unlockRequirements: [String: (minPaceLevel: String?, minMonthlyMedals: Int)] = [
        "flip": (nil, 0),
        "flo": ("intermediate", 5),
        "fins": ("advanced", 10)
    ]

    private static let paceLevelRank: [String: Int] = [
        "unknown": 0,
        "developing": 0,
        "beginner": 1,
        "intermediate": 2,
        "advanced": 3
    ]

    static func userSwimPaceLevel(profile: SwimProfile, sessions: [SwimSession]) -> SwimLevel {
        guard !profile.sex.isEmpty, profile.age > 0 else { return .unknown }
        let stats = SwimAnalysis.statsSessions(sessions)
        guard !stats.isEmpty else { return .unknown }

        let benchmark = SwimBenchmarks.benchmark(for: profile.sex, age: profile.age)
        let paces = stats.compactMap(\.metrics.paceSecPer100m).filter { $0 > 0 }
        let pace: Int?
        if paces.isEmpty {
            pace = stats.last?.metrics.paceSecPer100m
        } else {
            pace = paces.reduce(0, +) / paces.count
        }
        guard let pace else { return .unknown }
        return SwimBenchmarks.swimLevel(paceSecPer100m: pace, benchmark: benchmark)
    }

    static func countMonthlyMedals(
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> Int {
        SwimMonthlyChallenges.getMonthlyChallengeHistory(
            sessions: sessions,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        ).filter { $0.tier != nil }.count
    }

    static func meetsPaceRequirement(paceLevel: SwimLevel, requiredLevel: String?) -> Bool {
        guard let requiredLevel else { return true }
        let current = paceLevelRank[paceLevel.rawValue] ?? 0
        let required = paceLevelRank[requiredLevel] ?? 0
        return current >= required
    }

    static func unlockStatus(
        mascotId: String,
        profile: SwimProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> (unlocked: Bool, paceMet: Bool, medalsMet: Bool, paceLevel: SwimLevel, monthlyMedals: Int) {
        guard let requirements = unlockRequirements[mascotId] else {
            return (false, false, false, .unknown, 0)
        }

        if requirements.minPaceLevel == nil && requirements.minMonthlyMedals == 0 {
            return (true, true, true, .beginner, 0)
        }

        let paceLevel = userSwimPaceLevel(profile: profile, sessions: sessions)
        let monthlyMedals = countMonthlyMedals(
            sessions: sessions,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
        let paceMet = meetsPaceRequirement(paceLevel: paceLevel, requiredLevel: requirements.minPaceLevel)
        let medalsMet = monthlyMedals >= requirements.minMonthlyMedals

        return (paceMet || medalsMet, paceMet, medalsMet, paceLevel, monthlyMedals)
    }

    static func isUnlocked(
        mascotId: String,
        profile: SwimProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> Bool {
        unlockStatus(
            mascotId: mascotId,
            profile: profile,
            sessions: sessions,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        ).unlocked
    }

    static func resolveMascotId(
        profile: SwimProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> String {
        if let requested = profile.mascotId,
           MascotConstants.ids.contains(requested),
           isUnlocked(mascotId: requested, profile: profile, sessions: sessions, monthlyChallengeRerolls: monthlyChallengeRerolls) {
            return requested
        }
        return "flip"
    }

    static func hasSessionsInMonth(_ sessions: [SwimSession], monthKey: String) -> Bool {
        sessions.contains { $0.date.hasPrefix(monthKey) }
    }

    static func canSwitchMascot(
        profile: SwimProfile,
        sessions: [SwimSession],
        monthKey: String = SwimMonthlyChallenges.getMonthKey(),
        nextMascotId: String,
        currentMascotId: String
    ) -> MascotSwitchResult {
        guard MascotConstants.ids.contains(nextMascotId) else {
            return MascotSwitchResult(allowed: false, reason: "invalid")
        }
        if nextMascotId == currentMascotId {
            return MascotSwitchResult(allowed: true, reason: "same")
        }
        if !isUnlocked(mascotId: nextMascotId, profile: profile, sessions: sessions) {
            return MascotSwitchResult(allowed: false, reason: "locked")
        }
        if profile.mascotSwitchMonthKey == monthKey {
            return MascotSwitchResult(allowed: false, reason: "alreadySwitched")
        }
        if hasSessionsInMonth(sessions, monthKey: monthKey) {
            return MascotSwitchResult(allowed: false, reason: "afterFirstSession")
        }
        return MascotSwitchResult(allowed: true, reason: "ok")
    }
}
