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

    func testPointChallengesPickThreeUniqueTypes() {
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets["2026-08"] = 1000
        let state = VitalityGoals.evaluatePointChallenges(
            records: [],
            profile: .default,
            goalState: goalState,
            monthKey: "2026-08"
        )
        XCTAssertEqual(state.challenges.count, 3)
        XCTAssertEqual(Set(state.challenges.map(\.type)).count, 3)
        XCTAssertFalse(state.challenges.contains { $0.type.hasPrefix("monthly_points_") })
        XCTAssertFalse(state.challenges.contains { $0.type == "weigh_ins" })
    }

    func testPointChallengesAreDeterministicForAMonth() {
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets["2026-08"] = 1000
        let first = VitalityGoals.selectedChallengeTypes(
            monthKey: "2026-08",
            rerolls: [:],
            bodyProgressEnabled: false
        )
        let second = VitalityGoals.selectedChallengeTypes(
            monthKey: "2026-08",
            rerolls: [:],
            bodyProgressEnabled: false
        )
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(
            first,
            VitalityGoals.selectedChallengeTypes(
                monthKey: "2026-09",
                rerolls: [:],
                bodyProgressEnabled: false
            )
        )
    }

    func testSparkTargetsAreEasierThanForge() {
        let monthKey = "2026-08"
        let rerolls = [
            monthKey: MonthRerollEntry(
                overrides: [
                    "0": "workout_count",
                    "1": "sleep_nights",
                    "2": "points_streak"
                ]
            )
        ]
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets[monthKey] = 1000
        let spark = VitalityGoals.evaluatePointChallenges(
            records: [],
            profile: .default,
            goalState: goalState,
            monthKey: monthKey,
            intensity: 0.75,
            rerolls: rerolls
        )
        let forge = VitalityGoals.evaluatePointChallenges(
            records: [],
            profile: .default,
            goalState: goalState,
            monthKey: monthKey,
            intensity: 1.25,
            rerolls: rerolls
        )
        XCTAssertEqual(spark.challenges.map(\.type), ["workout_count", "sleep_nights", "points_streak"])
        XCTAssertEqual(forge.challenges.map(\.type), spark.challenges.map(\.type))
        for (easy, hard) in zip(spark.challenges, forge.challenges) {
            XCTAssertLessThan(easy.target, hard.target, easy.type)
        }
    }

    func testCompletedChallengeAddsMonthlyBonus() {
        let monthKey = "2026-08"
        let rerolls = [
            monthKey: MonthRerollEntry(overrides: ["0": "steps_20k_day", "1": "workout_variety", "2": "weigh_ins"])
        ]
        let records = [
            DailyVitalityRecord(
                id: "2026-08-01",
                date: "2026-08-01",
                steps: 20_000,
                stepPoints: 50,
                workoutPoints: 0,
                totalPoints: 50,
                workouts: [],
                stepTiersReached: [5000, 10000, 20000]
            )
        ]
        var goalState = VitalityGoalState.empty
        goalState.monthlyTargets[monthKey] = 1000
        let state = VitalityGoals.evaluatePointChallenges(
            records: records,
            profile: .default,
            goalState: goalState,
            monthKey: monthKey,
            rerolls: rerolls,
            todayKey: "2026-08-15"
        )
        XCTAssertTrue(state.challenges[0].completed)
        XCTAssertGreaterThan(state.bonusPoints, 0)
        XCTAssertEqual(
            VitalityGoals.monthlyProgress(records: records, monthKey: monthKey, challengeBonus: state.bonusPoints),
            50 + state.bonusPoints
        )
    }

    func testWeeklyDayBreakdownHasSevenDaysAndSplitsPoints() {
        let records = [
            DailyVitalityRecord(
                id: "2026-08-24",
                date: "2026-08-24",
                steps: 10000,
                stepPoints: 25,
                workoutPoints: 20,
                sleepMinutes: 420,
                sleepPoints: 10,
                totalPoints: 55,
                workouts: [],
                stepTiersReached: [5000, 10000]
            ),
            DailyVitalityRecord(
                id: "2026-08-26",
                date: "2026-08-26",
                steps: 5000,
                stepPoints: 10,
                workoutPoints: 0,
                totalPoints: 10,
                workouts: [],
                stepTiersReached: [5000]
            ),
        ]
        let days = VitalityGoals.weeklyDayBreakdown(
            records: records,
            weekKey: "2026-08-24",
            todayKey: "2026-08-26"
        )

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map(\.date), [
            "2026-08-24", "2026-08-25", "2026-08-26",
            "2026-08-27", "2026-08-28", "2026-08-29", "2026-08-30"
        ])
        XCTAssertEqual(days[0].totalPoints, 55)
        XCTAssertEqual(days[0].stepPoints, 25)
        XCTAssertEqual(days[0].workoutPoints, 20)
        XCTAssertEqual(days[0].sleepPoints, 10)
        XCTAssertEqual(days[1].totalPoints, 0)
        XCTAssertTrue(days[2].isToday)
        XCTAssertFalse(days[2].isFuture)
        XCTAssertTrue(days[3].isFuture)
        XCTAssertEqual(days[3].totalPoints, 0)
    }

    func testYearlyMonthBreakdownHasTwelveMonthsAndSplitsPoints() {
        let records = [
            DailyVitalityRecord(
                id: "2026-01-10",
                date: "2026-01-10",
                steps: 10000,
                stepPoints: 25,
                workoutPoints: 20,
                sleepMinutes: 420,
                sleepPoints: 10,
                totalPoints: 55,
                workouts: [],
                stepTiersReached: [5000, 10000]
            ),
            DailyVitalityRecord(
                id: "2026-01-20",
                date: "2026-01-20",
                steps: 5000,
                stepPoints: 10,
                workoutPoints: 0,
                totalPoints: 10,
                workouts: [],
                stepTiersReached: [5000]
            ),
            DailyVitalityRecord(
                id: "2026-03-02",
                date: "2026-03-02",
                steps: 8000,
                stepPoints: 10,
                workoutPoints: 40,
                totalPoints: 50,
                workouts: [],
                stepTiersReached: [5000]
            ),
        ]
        let months = VitalityGoals.yearlyMonthBreakdown(
            records: records,
            yearKey: "2026",
            currentMonthKey: "2026-03"
        )

        XCTAssertEqual(months.count, 12)
        XCTAssertEqual(months[0].monthKey, "2026-01")
        XCTAssertEqual(months[0].totalPoints, 65)
        XCTAssertEqual(months[0].stepPoints, 35)
        XCTAssertEqual(months[0].workoutPoints, 20)
        XCTAssertEqual(months[0].sleepPoints, 10)
        XCTAssertEqual(months[1].totalPoints, 0)
        XCTAssertTrue(months[2].isCurrentMonth)
        XCTAssertEqual(months[2].totalPoints, 50)
        XCTAssertFalse(months[2].isFuture)
        XCTAssertTrue(months[3].isFuture)
        XCTAssertEqual(months[11].monthKey, "2026-12")
    }
}
