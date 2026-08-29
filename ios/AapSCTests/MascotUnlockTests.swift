import XCTest
@testable import AapSC

final class MascotUnlockTests: XCTestCase {
    func testUnlocksFlipFromTheStart() {
        XCTAssertTrue(MascotUnlock.isUnlocked(
            mascotId: "flip",
            profile: TestFixtures.profile,
            dailyRecords: [],
            goalState: .empty
        ))
    }

    func testLocksFloWithoutEnoughPointsOrGoals() {
        let status = MascotUnlock.unlockStatus(
            mascotId: "flo",
            profile: TestFixtures.profile,
            dailyRecords: [],
            goalState: .empty
        )
        XCTAssertFalse(status.unlocked)
    }

    func testUnlocksFloWithEnoughPoints() {
        let records = [
            DailyVitalityRecord(
                id: "2026-01-01",
                date: "2026-01-01",
                steps: 12000,
                stepPoints: 25,
                workoutPoints: 5000,
                totalPoints: 5025,
                workouts: [],
                stepTiersReached: [5000, 10000]
            )
        ]
        XCTAssertTrue(MascotUnlock.isUnlocked(
            mascotId: "flo",
            profile: TestFixtures.profile,
            dailyRecords: records,
            goalState: .empty
        ))
    }

    func testUnlocksFloWithMonthlyGoals() {
        var goalState = VitalityGoalState.empty
        goalState.monthlyCompletions = [
            "2026-01": MonthlyGoalCompletion(completedAt: "2026-01-28", daysToComplete: 28, targetPoints: 1000, earnedPoints: 1000),
            "2026-02": MonthlyGoalCompletion(completedAt: "2026-02-25", daysToComplete: 25, targetPoints: 1000, earnedPoints: 1100),
        ]
        XCTAssertTrue(MascotUnlock.isUnlocked(
            mascotId: "flo",
            profile: TestFixtures.profile,
            dailyRecords: [],
            goalState: goalState
        ))
    }

    func testResolvesToFlipWhenRequestedMascotIsLocked() {
        var lockedProfile = TestFixtures.profile
        lockedProfile.mascotId = "flo"
        XCTAssertEqual(
            MascotUnlock.resolveMascotId(profile: lockedProfile, dailyRecords: [], goalState: .empty),
            "flip"
        )
    }

    func testAllowsMascotSwitchBeforeFirstActivityOfMonth() {
        var profile = TestFixtures.profile
        profile.mascotSwitchMonthKey = nil
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            dailyRecords: [],
            goalState: .empty,
            monthKey: "2025-06",
            nextMascotId: "flo",
            currentMascotId: "flip"
        )
        XCTAssertTrue(result.allowed)
    }

    func testBlocksMascotSwitchAfterFirstActivityOfMonth() {
        var profile = TestFixtures.profile
        profile.mascotSwitchMonthKey = nil
        let records = [
            DailyVitalityRecord(
                id: "2025-06-02",
                date: "2025-06-02",
                steps: 6000,
                stepPoints: 10,
                workoutPoints: 0,
                totalPoints: 10,
                workouts: [],
                stepTiersReached: [5000]
            )
        ]
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            dailyRecords: records,
            goalState: .empty,
            monthKey: "2025-06",
            nextMascotId: "flo",
            currentMascotId: "flip"
        )
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reason, "afterFirstSession")
    }

    func testBlocksSecondMascotSwitchInSameMonth() {
        var profile = TestFixtures.profile
        profile.mascotId = "flo"
        profile.mascotSwitchMonthKey = "2025-06"
        let result = MascotUnlock.canSwitchMascot(
            profile: profile,
            dailyRecords: [],
            goalState: .empty,
            monthKey: "2025-06",
            nextMascotId: "flip",
            currentMascotId: "flo"
        )
        XCTAssertFalse(result.allowed)
        XCTAssertEqual(result.reason, "alreadySwitched")
    }
}
