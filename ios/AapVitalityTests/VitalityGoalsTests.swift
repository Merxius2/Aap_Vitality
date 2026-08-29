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

    func testEarlyFinishSnapshotSecuredWithinWindow() {
        let records = (1...10).map { day in
            DailyVitalityRecord(
                id: String(format: "2026-08-%02d", day),
                date: String(format: "2026-08-%02d", day),
                steps: 12000,
                stepPoints: 25,
                workoutPoints: 80,
                totalPoints: 105,
                workouts: [],
                stepTiersReached: [5000, 10000]
            )
        }
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets["2026-08"] = 1000
        let snapshot = VitalityGoals.earlyFinishSnapshot(
            records: records,
            profile: .default,
            goalState: goalState,
            monthKey: "2026-08",
            date: date(from: "2026-08-15")
        )

        if case .secured(let day) = snapshot.status {
            XCTAssertLessThanOrEqual(day, VitalityGoals.earlyCompletionDays)
        } else {
            XCTFail("Expected secured early finish")
        }
    }

    func testEarlyFinishSnapshotMissedAfterWindow() {
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets["2026-08"] = 1000
        let snapshot = VitalityGoals.earlyFinishSnapshot(
            records: [],
            profile: .default,
            goalState: goalState,
            monthKey: "2026-08",
            date: date(from: "2026-08-25")
        )

        if case .missedWindow = snapshot.status {
            XCTAssertEqual(snapshot.currentDayOfMonth, 25)
        } else {
            XCTFail("Expected missed early-finish window")
        }
    }

    func testEarlyFinishOnTrackProjection() {
        XCTAssertTrue(
            VitalityGoals.isOnTrackForEarlyFinish(earned: 500, target: 1000, currentDay: 10)
        )
        XCTAssertFalse(
            VitalityGoals.isOnTrackForEarlyFinish(earned: 200, target: 1000, currentDay: 10)
        )
    }

    private func date(from key: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key) ?? Date()
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
