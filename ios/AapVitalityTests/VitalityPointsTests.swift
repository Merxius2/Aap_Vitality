import XCTest
@testable import AapVitality

final class VitalityPointsTests: XCTestCase {
    func testStepTiersAreIncremental() {
        let result5k = VitalityPoints.stepPoints(for: 5000)
        XCTAssertEqual(result5k.points, 10)
        XCTAssertEqual(result5k.tiersReached, [5000])

        let result10k = VitalityPoints.stepPoints(for: 10000)
        XCTAssertEqual(result10k.points, 25)
        XCTAssertEqual(result10k.tiersReached, [5000, 10000])

        let result20k = VitalityPoints.stepPoints(for: 20000)
        XCTAssertEqual(result20k.points, 50)
        XCTAssertEqual(result20k.tiersReached, [5000, 10000, 20000])
    }

    func testWorkoutRequiresThirtyMinutes() {
        let profile = VitalityProfile.default
        let short = VitalityPoints.workoutPoints(
            durationSec: 20 * 60,
            zoneMinutes: HRZoneMinutes(zone5: 10),
            profile: profile,
            mascotId: "flip"
        )
        XCTAssertEqual(short, 0)

        let long = VitalityPoints.workoutPoints(
            durationSec: 35 * 60,
            zoneMinutes: HRZoneMinutes(zone3: 10),
            profile: profile,
            mascotId: "flip"
        )
        XCTAssertGreaterThan(long, 0)
    }

    func testHigherZonesEarnMorePoints() {
        let profile = VitalityProfile.default
        let low = VitalityPoints.workoutPoints(
            durationSec: 40 * 60,
            zoneMinutes: HRZoneMinutes(zone2: 10),
            profile: profile,
            mascotId: "flo"
        )
        let high = VitalityPoints.workoutPoints(
            durationSec: 40 * 60,
            zoneMinutes: HRZoneMinutes(zone5: 10),
            profile: profile,
            mascotId: "flo"
        )
        XCTAssertGreaterThan(high, low)
    }

    func testApplyingStepsUpdatesOnlyWhenHigher() {
        let existing = VitalityPoints.buildDailyRecord(
            date: "2026-08-30",
            steps: 4200,
            workouts: [],
            profile: .default,
            mascotId: "flo"
        )

        XCTAssertNil(
            VitalityPoints.applyingSteps(
                4200,
                on: "2026-08-30",
                to: [existing],
                profile: .default,
                mascotId: "flo"
            )
        )
        XCTAssertNil(
            VitalityPoints.applyingSteps(
                3000,
                on: "2026-08-30",
                to: [existing],
                profile: .default,
                mascotId: "flo"
            )
        )

        let updated = VitalityPoints.applyingSteps(
            5100,
            on: "2026-08-30",
            to: [existing],
            profile: .default,
            mascotId: "flo"
        )
        XCTAssertEqual(updated?.count, 1)
        XCTAssertEqual(updated?.first?.steps, 5100)
        XCTAssertEqual(updated?.first?.stepPoints, 10)
    }

    func testApplyingStepsCreatesTodayRecord() {
        let previous = VitalityPoints.buildDailyRecord(
            date: "2026-08-29",
            steps: 8000,
            workouts: [],
            profile: .default,
            mascotId: "flo"
        )
        let updated = VitalityPoints.applyingSteps(
            1200,
            on: "2026-08-30",
            to: [previous],
            profile: .default,
            mascotId: "flo"
        )
        XCTAssertEqual(updated?.count, 2)
        XCTAssertEqual(updated?.first { $0.date == "2026-08-30" }?.steps, 1200)
        XCTAssertEqual(updated?.first { $0.date == "2026-08-29" }?.steps, 8000)
    }

    func testTodayStepsStoreAppliesHigherCount() {
        var data = VitalityData.empty
        data.dailyRecords = [
            VitalityPoints.buildDailyRecord(
                date: VitalityGoals.todayDateKey(),
                steps: 2000,
                workouts: [],
                profile: .default,
                mascotId: "flo"
            )
        ]
        XCTAssertTrue(TodayStepsStore.apply(4500, to: &data))
        XCTAssertEqual(data.dailyRecords.first?.steps, 4500)
        XCTAssertFalse(TodayStepsStore.apply(4000, to: &data))
    }
}
