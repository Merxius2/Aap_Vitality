import XCTest
@testable import AapSC

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
        let profile = SwimProfile.default
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
        let profile = SwimProfile.default
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
}
