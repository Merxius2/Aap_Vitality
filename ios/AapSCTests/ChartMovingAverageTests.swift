import XCTest
@testable import AapSC

final class ChartMovingAverageTests: XCTestCase {
    func testComputesRollingAverageForNumericSeries() {
        let points = [
            ChartSessionPoint(
                id: "1", date: "2026-01-01", dateLabel: "1 Jan",
                paceSecPer100m: 10, distanceM: 1000, activeKcal: 100, totalKcal: 120, avgHeartRate: 130
            ),
            ChartSessionPoint(
                id: "2", date: "2026-01-02", dateLabel: "2 Jan",
                paceSecPer100m: 20, distanceM: 2000, activeKcal: 200, totalKcal: 220, avgHeartRate: 140
            ),
            ChartSessionPoint(
                id: "3", date: "2026-01-03", dateLabel: "3 Jan",
                paceSecPer100m: 30, distanceM: 3000, activeKcal: 300, totalKcal: 320, avgHeartRate: 150
            ),
            ChartSessionPoint(
                id: "4", date: "2026-01-04", dateLabel: "4 Jan",
                paceSecPer100m: 40, distanceM: 4000, activeKcal: 400, totalKcal: 420, avgHeartRate: 160
            ),
        ]

        let enriched = ChartMovingAverage.enrichChartSessions(points)

        XCTAssertEqual(enriched[0].paceMa, 10)
        XCTAssertEqual(enriched[1].paceMa, 15)
        XCTAssertEqual(enriched[2].paceMa, 20)
        XCTAssertEqual(enriched[3].paceMa, 30)
    }
}
