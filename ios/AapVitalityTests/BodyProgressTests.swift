import XCTest
@testable import AapVitality

final class BodyProgressTests: XCTestCase {
    func testMergeEntriesComputesMusclePercentFromLeanMass() {
        let merged = BodyProgress.mergeEntries(
            existing: [],
            weightByDate: ["2026-08-27": 80],
            bodyFatByDate: [:],
            leanBodyMassByDate: ["2026-08-27": 60],
            heightCm: 180
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].musclePercent, 75, accuracy: 0.01)
    }

    func testMergeEntriesKeepsLatestWeightPerDay() {
        let merged = BodyProgress.mergeEntries(
            existing: [],
            weightByDate: [
                "2026-08-20": 82.4,
                "2026-08-27": 81.9,
            ],
            bodyFatByDate: [
                "2026-08-27": 22.5,
            ],
            leanBodyMassByDate: [:],
            heightCm: 180
        )

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.last?.weightKg, 81.9)
        XCTAssertEqual(merged.last?.bodyFatPercent, 22.5)
        XCTAssertEqual(merged.last?.bmi, BodyProgress.bmi(weightKg: 81.9, heightCm: 180), accuracy: 0.01)
    }

    func testWeightChangeRequiresMinimumSpan() {
        let entries = [
            BodyMetricsEntry(id: "2026-08-01", date: "2026-08-01", weightKg: 84, heightCm: 180, bodyFatPercent: nil),
            BodyMetricsEntry(id: "2026-08-05", date: "2026-08-05", weightKg: 83, heightCm: 180, bodyFatPercent: nil),
        ]
        let change = BodyProgress.weightChangeKg(
            entries: entries,
            overDays: 56,
            referenceDate: date(from: "2026-08-05")
        )
        XCTAssertNil(change)
    }

    func testPositiveTrendDetectsMuscleGain() {
        let entries = [
            BodyMetricsEntry(
                id: "2026-07-01",
                date: "2026-07-01",
                weightKg: 80,
                heightCm: 180,
                bodyFatPercent: nil,
                musclePercent: 70
            ),
            BodyMetricsEntry(
                id: "2026-08-29",
                date: "2026-08-29",
                weightKg: 80,
                heightCm: 180,
                bodyFatPercent: nil,
                musclePercent: 71
            ),
        ]
        XCTAssertTrue(BodyProgress.hasPositiveTrend(entries: entries, referenceDate: date(from: "2026-08-29")))
    }

    func testPositiveTrendDetectsWeightLoss() {
        let entries = [
            BodyMetricsEntry(id: "2026-07-01", date: "2026-07-01", weightKg: 84, heightCm: 180, bodyFatPercent: nil),
            BodyMetricsEntry(id: "2026-08-29", date: "2026-08-29", weightKg: 83.2, heightCm: 180, bodyFatPercent: nil),
        ]
        XCTAssertTrue(BodyProgress.hasPositiveTrend(entries: entries, referenceDate: date(from: "2026-08-29")))
    }

    func testBodyProgressChallengesTierProgression() {
        let entries = (1...4).map { day in
            BodyMetricsEntry(
                id: String(format: "2026-08-%02d", day * 5),
                date: String(format: "2026-08-%02d", day * 5),
                weightKg: 80,
                heightCm: 175,
                bodyFatPercent: nil
            )
        }
        let state = BodyProgress.evaluateChallenges(
            entries: entries,
            records: [],
            goalState: .empty,
            monthKey: "2026-08"
        )
        XCTAssertEqual(state.challenges.filter(\.completed).count, 2)
        XCTAssertEqual(state.tier, "silver")
    }

    private func date(from key: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key) ?? Date()
    }
}
