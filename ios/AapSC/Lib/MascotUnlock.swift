import Foundation

enum MascotUnlock {
    static let unlockRequirements: [String: (minTotalPoints: Int, minMonthlyGoals: Int)] = [
        "flip": (0, 0),
        "flo": (5000, 2),
        "fins": (15000, 5)
    ]

    static func totalPoints(_ records: [DailyVitalityRecord]) -> Int {
        records.reduce(0) { $0 + $1.totalPoints }
    }

    static func countMonthlyGoals(_ goalState: VitalityGoalState) -> Int {
        goalState.monthlyCompletions.count
    }

    static func unlockStatus(
        mascotId: String,
        profile: SwimProfile,
        dailyRecords: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> (unlocked: Bool, pointsMet: Bool, goalsMet: Bool, totalPoints: Int, monthlyGoals: Int) {
        guard let requirements = unlockRequirements[mascotId] else {
            return (false, false, false, 0, 0)
        }

        if requirements.minTotalPoints == 0 && requirements.minMonthlyGoals == 0 {
            return (true, true, true, 0, 0)
        }

        let points = totalPoints(dailyRecords)
        let monthlyGoals = countMonthlyGoals(goalState)
        let pointsMet = points >= requirements.minTotalPoints
        let goalsMet = monthlyGoals >= requirements.minMonthlyGoals

        return (pointsMet || goalsMet, pointsMet, goalsMet, points, monthlyGoals)
    }

    static func isUnlocked(
        mascotId: String,
        profile: SwimProfile,
        dailyRecords: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> Bool {
        unlockStatus(
            mascotId: mascotId,
            profile: profile,
            dailyRecords: dailyRecords,
            goalState: goalState,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        ).unlocked
    }

    static func resolveMascotId(
        profile: SwimProfile,
        dailyRecords: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> String {
        if let requested = profile.mascotId,
           MascotConstants.ids.contains(requested),
           isUnlocked(
               mascotId: requested,
               profile: profile,
               dailyRecords: dailyRecords,
               goalState: goalState,
               monthlyChallengeRerolls: monthlyChallengeRerolls
           ) {
            return requested
        }
        return "flip"
    }

    static func hasActivityInMonth(_ records: [DailyVitalityRecord], monthKey: String) -> Bool {
        records.contains { $0.date.hasPrefix(monthKey) && $0.totalPoints > 0 }
    }

    static func canSwitchMascot(
        profile: SwimProfile,
        dailyRecords: [DailyVitalityRecord],
        goalState: VitalityGoalState,
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
        if !isUnlocked(
            mascotId: nextMascotId,
            profile: profile,
            dailyRecords: dailyRecords,
            goalState: goalState
        ) {
            return MascotSwitchResult(allowed: false, reason: "locked")
        }
        if profile.mascotSwitchMonthKey == monthKey {
            return MascotSwitchResult(allowed: false, reason: "alreadySwitched")
        }
        if hasActivityInMonth(dailyRecords, monthKey: monthKey) {
            return MascotSwitchResult(allowed: false, reason: "afterFirstSession")
        }
        return MascotSwitchResult(allowed: true, reason: "ok")
    }

    // Legacy session-based helpers kept for settings previews.
    static func resolveMascotId(
        profile: SwimProfile,
        sessions: [SwimSession],
        monthlyChallengeRerolls: [String: MonthRerollEntry] = [:]
    ) -> String {
        resolveMascotId(
            profile: profile,
            dailyRecords: [],
            goalState: .empty,
            monthlyChallengeRerolls: monthlyChallengeRerolls
        )
    }

    static func canSwitchMascot(
        profile: SwimProfile,
        sessions: [SwimSession],
        monthKey: String = SwimMonthlyChallenges.getMonthKey(),
        nextMascotId: String,
        currentMascotId: String
    ) -> MascotSwitchResult {
        canSwitchMascot(
            profile: profile,
            dailyRecords: [],
            goalState: .empty,
            monthKey: monthKey,
            nextMascotId: nextMascotId,
            currentMascotId: currentMascotId
        )
    }
}
