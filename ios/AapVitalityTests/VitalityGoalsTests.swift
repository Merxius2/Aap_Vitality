import XCTest
@testable import AapVitality

final class VitalityGoalsTests: XCTestCase {
    func testMonthlyTargetUsesProfileBaselineWithoutHistory() {
        let profile = VitalityProfile(name: "Test", sex: "male", age: 30, mascotId: nil, mascotSwitchMonthKey: nil, aiApiKey: "", activeAmbient: nil)
        let monthKey = "2026-08"
        let target = VitalityGoals.computeMonthlyTarget(
            profile: profile,
            records: [],
            monthKey: monthKey,
            goalState: .empty
        )
        XCTAssertGreaterThanOrEqual(target, 300)
    }

    func testEarlyCompletionIncreasesBoostFactor() {
        var data = VitalityData.empty
        data.goalState.monthlyCompletions["2026-07"] = MonthlyGoalCompletion(
            completedAt: "2026-07-18",
            daysToComplete: 18,
            targetPoints: 1000,
            earnedPoints: 1050
        )
        let before = data.goalState.goalBoostFactor
        VitalityGoals.ensureGoals(data: &data, monthKey: "2026-08")
        XCTAssertGreaterThan(data.goalState.goalBoostFactor, before)
    }

    func testPointChallengeTiers() {
        let records = [
            DailyVitalityRecord(
                id: "2026-08-01",
                date: "2026-08-01",
                steps: 12000,
                stepPoints: 25,
                workoutPoints: 0,
                totalPoints: 25,
                workouts: [],
                stepTiersReached: [5000, 10000]
            )
        ]
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets["2026-08"] = 1000
        let state = VitalityGoals.evaluatePointChallenges(
            records: records,
            profile: .default,
            goalState: goalState,
            monthKey: "2026-08"
        )
        XCTAssertEqual(state.challenges.count, 3)
        XCTAssertFalse(state.challenges.allSatisfy(\.completed))
    }
}
