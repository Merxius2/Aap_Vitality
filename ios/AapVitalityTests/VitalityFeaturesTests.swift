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
}
