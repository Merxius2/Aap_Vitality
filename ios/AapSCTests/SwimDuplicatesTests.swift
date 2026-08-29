import XCTest
@testable import AapSC

final class SwimDuplicatesTests: XCTestCase {
    private let existing = [
        TestFixtures.session(
            id: "1",
            date: "2025-06-03",
            metrics: TestFixtures.metrics(
                distanceM: 2550,
                durationSec: 3267,
                paceSecPer100m: 130,
                timeRange: "11:07-12:01"
            )
        )
    ]

    func testReturnsNullWhenNoSessionsMatch() {
        let candidate = TestFixtures.session(
            id: "2",
            date: "2025-06-03",
            metrics: TestFixtures.metrics(distanceM: 2000, durationSec: 3267)
        )
        XCTAssertNil(SwimDuplicates.findDuplicateSession(existing, candidate: candidate))
    }

    func testDetectsDuplicateOnSameDateWithMatchingDistanceAndDuration() {
        let candidate = TestFixtures.session(
            id: "2",
            date: "2025-06-03",
            metrics: TestFixtures.metrics(distanceM: 2550, durationSec: 3267, paceSecPer100m: 130)
        )
        XCTAssertEqual(SwimDuplicates.findDuplicateSession(existing, candidate: candidate)?.id, "1")
    }

    func testIgnoresDifferentDates() {
        let candidate = TestFixtures.session(
            id: "2",
            date: "2025-06-04",
            metrics: TestFixtures.metrics(distanceM: 2550, durationSec: 3267)
        )
        XCTAssertNil(SwimDuplicates.findDuplicateSession(existing, candidate: candidate))
    }

    func testAllowsSmallPaceVarianceFromOCR() {
        let candidate = TestFixtures.session(
            id: "2",
            date: "2025-06-03",
            metrics: TestFixtures.metrics(distanceM: 2550, durationSec: 3267, paceSecPer100m: 133)
        )
        XCTAssertEqual(SwimDuplicates.findDuplicateSession(existing, candidate: candidate)?.id, "1")
    }

    func testRejectsWhenTimeRangesDiffer() {
        let candidate = TestFixtures.session(
            id: "2",
            date: "2025-06-03",
            metrics: TestFixtures.metrics(
                distanceM: 2550,
                durationSec: 3267,
                timeRange: "14:00-15:00"
            )
        )
        XCTAssertNil(SwimDuplicates.findDuplicateSession(existing, candidate: candidate))
    }
}
