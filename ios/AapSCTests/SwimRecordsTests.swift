import XCTest
@testable import AapSC

final class SwimRecordsTests: XCTestCase {
    func testReturnsNullForEmptySessions() {
        XCTAssertNil(SwimRecords.getPersonalRecords([]))
    }

    func testPicksBestValuesAcrossSessions() {
        let sessions = [
            TestFixtures.session(id: "a", date: "2025-06-01", metrics: TestFixtures.metrics(distanceM: 2000, paceSecPer100m: 130, activeKcal: 400)),
            TestFixtures.session(id: "b", date: "2025-06-02", metrics: TestFixtures.metrics(distanceM: 2550, paceSecPer100m: 115, activeKcal: 520, laps: 102))
        ]
        let records = SwimRecords.getPersonalRecords(sessions)!
        XCTAssertEqual(records.longestDistance?.value, 2550)
        XCTAssertEqual(records.longestDistance?.sessionId, "b")
        XCTAssertEqual(records.fastestPace?.value, 115)
        XCTAssertEqual(records.mostActiveCalories?.value, 520)
        XCTAssertEqual(records.mostLaps?.value, 102)
    }
}
