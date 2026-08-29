import XCTest
@testable import AapVitality

final class SwimMedalsTests: XCTestCase {
    func testFirstPointsMedal() {
        let records = [
            DailyVitalityRecord(
                id: "2026-01-01",
                date: "2026-01-01",
                steps: 6000,
                stepPoints: 10,
                workoutPoints: 0,
                totalPoints: 10,
                workouts: [],
                stepTiersReached: [5000]
            )
        ]
        let medals = SwimMedals.evaluateAllMedals(records, profile: .default, goalState: .empty)
        XCTAssertTrue(medals.first(where: { $0.id == "first_points" })?.earned == true)
        XCTAssertTrue(medals.first(where: { $0.id == "five_k_steps" })?.earned == true)
    }

    func testTenWorkoutsMedal() {
        var workouts: [VitalityWorkout] = []
        for index in 0..<10 {
            workouts.append(VitalityWorkout(
                id: "w\(index)",
                date: "2026-01-\(String(format: "%02d", index + 1))",
                workoutType: "running",
                durationSec: 35 * 60,
                avgHeartRate: 150,
                zoneMinutes: HRZoneMinutes(zone3: 20),
                activeKcal: 300,
                healthKitWorkoutUUID: "w\(index)",
                pointsEarned: 30
            ))
        }
        let records = workouts.map { workout in
            DailyVitalityRecord(
                id: workout.date,
                date: workout.date,
                steps: 0,
                stepPoints: 0,
                workoutPoints: 30,
                totalPoints: 30,
                workouts: [workout],
                stepTiersReached: []
            )
        }
        let medals = SwimMedals.evaluateAllMedals(records, profile: .default, goalState: .empty)
        XCTAssertTrue(medals.first(where: { $0.id == "ten_workouts" })?.earned == true)
    }

    func testNewlyEarnedMedalsDiff() {
        let before: [DailyVitalityRecord] = []
        let after = [
            DailyVitalityRecord(
                id: "2026-01-01",
                date: "2026-01-01",
                steps: 10000,
                stepPoints: 25,
                workoutPoints: 0,
                totalPoints: 25,
                workouts: [],
                stepTiersReached: [5000, 10000]
            )
        ]
        let newly = SwimMedals.getNewlyEarnedMedals(
            recordsBefore: before,
            recordsAfter: after,
            profile: .default,
            goalState: .empty
        )
        XCTAssertFalse(newly.isEmpty)
    }

    func testCheatsUnlockAllMedals() {
        let medals = SwimMedals.evaluateAllMedals([], profile: .default, goalState: .empty, allMedalsUnlocked: true)
        XCTAssertTrue(medals.allSatisfy(\.earned))
    }
}
