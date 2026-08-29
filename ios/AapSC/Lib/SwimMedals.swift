import Foundation

/// Vitality medal catalog and evaluation. Kept as `SwimMedals` type alias for existing call sites.
enum SwimMedals {
    static var medals: [MedalDefinition] { VitalityMedals.medals }

    static func evaluateAllMedals(
        _ records: [DailyVitalityRecord],
        profile: SwimProfile,
        goalState: VitalityGoalState,
        allMedalsUnlocked: Bool = false
    ) -> [EvaluatedMedal] {
        VitalityMedals.evaluateAllMedals(
            records,
            profile: profile,
            goalState: goalState,
            allMedalsUnlocked: allMedalsUnlocked
        )
    }

    static func getNewlyEarnedMedals(
        recordsBefore: [DailyVitalityRecord],
        recordsAfter: [DailyVitalityRecord],
        profile: SwimProfile,
        goalState: VitalityGoalState,
        allMedalsUnlocked: Bool = false
    ) -> [EvaluatedMedal] {
        VitalityMedals.getNewlyEarnedMedals(
            recordsBefore: recordsBefore,
            recordsAfter: recordsAfter,
            profile: profile,
            goalState: goalState,
            allMedalsUnlocked: allMedalsUnlocked
        )
    }

    static func getMedalStats(_ medals: [EvaluatedMedal]) -> (earned: Int, total: Int) {
        VitalityMedals.getMedalStats(medals)
    }
}
