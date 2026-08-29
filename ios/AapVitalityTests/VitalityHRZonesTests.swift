import XCTest
@testable import AapVitality

final class VitalityHRZonesTests: XCTestCase {
    func testHeartRateSamplesAccumulateSecondsNotWholeMinutes() {
        let maxHR = VitalityHRZones.maxHeartRate(sex: "male", age: 35)
        let zone5HeartRate = Int(Double(maxHR) * 0.92)

        // 51-minute swim sampled every ~5 seconds (~612 samples).
        let samples = (0..<612).map { _ in
            (bpm: zone5HeartRate, durationSec: 5)
        }

        let zones = VitalityHRZones.zoneMinutes(from: samples, maxHR: maxHR)
        XCTAssertEqual(zones.zone5, 51)
        XCTAssertEqual(zones.total, 51)
    }

    func testResolvedZoneMinutesIgnoresInflatedStoredValues() {
        let maxHR = VitalityHRZones.maxHeartRate(sex: "male", age: 35)
        let inflated = HRZoneMinutes(zone5: 191)
        let resolved = VitalityHRZones.resolvedZoneMinutes(
            stored: inflated,
            averageHeartRate: Int(Double(maxHR) * 0.75),
            durationSec: 51 * 60 + 43,
            maxHR: maxHR
        )

        XCTAssertLessThanOrEqual(resolved.total, 52)
        XCTAssertGreaterThan(resolved.total, 0)
    }

    func testWorkoutPointsStayReasonableForTypicalSwim() {
        let profile = VitalityProfile.default
        let maxHR = VitalityHRZones.maxHeartRate(sex: profile.sex, age: profile.age)
        let zone3HeartRate = Int(Double(maxHR) * 0.75)
        let samples = (0..<612).map { _ in
            (bpm: zone3HeartRate, durationSec: 5)
        }
        let zones = VitalityHRZones.zoneMinutes(from: samples, maxHR: maxHR)
        let points = VitalityPoints.workoutPoints(
            durationSec: 51 * 60 + 43,
            zoneMinutes: zones,
            profile: profile,
            mascotId: "flo"
        )

        XCTAssertLessThan(points, 500)
        XCTAssertGreaterThan(points, 100)
    }
}
