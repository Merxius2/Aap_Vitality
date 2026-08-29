import XCTest
@testable import AapVitality

final class VitalityFeaturesTests: XCTestCase {
    func testSleepPointsTiers() {
        let short = VitalityPoints.sleepPoints(for: 400)
        XCTAssertEqual(short.points, 0)

        let seven = VitalityPoints.sleepPoints(for: 420)
        XCTAssertEqual(seven.points, 10)

        let eight = VitalityPoints.sleepPoints(for: 480)
        XCTAssertEqual(eight.points, 15)
    }

    func testBuildDailyRecordIncludesSleepInTotal() {
        let record = VitalityPoints.buildDailyRecord(
            date: "2026-01-01",
            steps: 5000,
            sleepMinutes: 420,
            workouts: [],
            profile: .default,
            mascotId: "flo"
        )
        XCTAssertEqual(record.sleepPoints, 10)
        XCTAssertEqual(record.totalPoints, record.stepPoints + record.sleepPoints)
    }

    func testVitalityLevelsProgression() {
        let level1 = VitalityLevels.currentLevel(for: 100)
        XCTAssertEqual(level1.level, 1)
        let level3 = VitalityLevels.currentLevel(for: 2500)
        XCTAssertEqual(level3.level, 3)
    }

    func testStreakShieldAutoApply() {
        var goalState = VitalityGoalState.empty
        goalState.streakShieldMonthKey = VitalityGoals.getMonthKey()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let today = VitalityGoals.todayDateKey()
        guard let todayDate = formatter.date(from: today),
              let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: todayDate) else {
            XCTFail("date setup")
            return
        }
        let activeDate = formatter.string(from: twoDaysAgo)
        let records = [
            DailyVitalityRecord(
                id: activeDate,
                date: activeDate,
                steps: 6000,
                stepPoints: 10,
                workoutPoints: 0,
                sleepMinutes: 0,
                sleepPoints: 0,
                totalPoints: 10,
                workouts: [],
                stepTiersReached: [5000]
            )
        ]
        _ = VitalityStreak.reconcile(goalState: &goalState, records: records)
        XCTAssertEqual(goalState.streakShieldsAvailable, 0)
        XCTAssertEqual(goalState.shieldUsedDates.count, 1)
    }

    func testWorkoutTypeBadges() {
        let workout = VitalityWorkout(
            id: "w1",
            date: "2026-01-01",
            workoutType: "running",
            durationSec: 35 * 60,
            avgHeartRate: nil,
            zoneMinutes: nil,
            activeKcal: nil,
            healthKitWorkoutUUID: "w1",
            pointsEarned: 20
        )
        let record = DailyVitalityRecord(
            id: "2026-01-01",
            date: "2026-01-01",
            steps: 0,
            stepPoints: 0,
            workoutPoints: 20,
            sleepMinutes: 0,
            sleepPoints: 0,
            totalPoints: 20,
            workouts: [workout],
            stepTiersReached: []
        )
        let badges = VitalityWorkoutBadges.earnedBadges(from: [record])
        XCTAssertEqual(badges.first?.workoutType, "running")
        XCTAssertEqual(badges.first?.count, 1)
    }

    func testAchievementPathsProgress() {
        let medals = VitalityMedals.evaluateAllMedals([], profile: .default, goalState: .empty)
        let paths = VitalityPaths.progress(for: medals)
        XCTAssertEqual(paths.count, VitalityPaths.paths.count)
        XCTAssertEqual(paths.first?.completedCount, 0)
    }

    func testComputeDailyTargetUsesWeeklyAndBaseline() {
        let profile = VitalityProfile.default
        let weeklyTarget = 350
        let target = VitalityGoals.computeDailyTarget(
            weeklyTarget: weeklyTarget,
            profile: profile,
            intensity: 1
        )
        XCTAssertGreaterThanOrEqual(target, VitalityGoals.baselineDailyPoints(profile: profile))
        XCTAssertGreaterThanOrEqual(target, 50)
    }

    func testTodayPointsReturnsRecordTotal() {
        let record = DailyVitalityRecord(
            id: "2026-08-29",
            date: "2026-08-29",
            steps: 8000,
            stepPoints: 15,
            workoutPoints: 20,
            sleepMinutes: 420,
            sleepPoints: 10,
            totalPoints: 45,
            workouts: [],
            stepTiersReached: [5000, 8000]
        )
        XCTAssertEqual(
            VitalityGoals.todayPoints(records: [record], dateKey: "2026-08-29"),
            45
        )
        XCTAssertEqual(VitalityGoals.todayPoints(records: [record], dateKey: "2026-08-28"), 0)
    }

    func testDailyGoalStatusReflectsProgress() {
        let profile = VitalityProfile.default
        let goalState = VitalityGoalState.empty
        let dateKey = "2026-08-29"
        let records = [
            DailyVitalityRecord(
                id: dateKey,
                date: dateKey,
                steps: 12000,
                stepPoints: 25,
                workoutPoints: 30,
                sleepMinutes: 480,
                sleepPoints: 15,
                totalPoints: 70,
                workouts: [],
                stepTiersReached: [5000, 10000]
            )
        ]
        let status = SwimNotifications.dailyGoalStatus(
            records: records,
            profile: profile,
            goalState: goalState,
            intensity: 1,
            dateKey: dateKey
        )
        XCTAssertEqual(status.earned, 70)
        XCTAssertEqual(status.met, status.earned >= status.target)
        XCTAssertEqual(status.remaining, max(0, status.target - status.earned))
    }
}
