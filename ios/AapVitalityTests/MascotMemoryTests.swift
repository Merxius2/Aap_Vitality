import XCTest
@testable import AapVitality

final class MascotMemoryTests: XCTestCase {
    func testConsecutiveWeeksStep10k() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var records: [DailyVitalityRecord] = []
        var cursor = formatter.date(from: "2026-08-25")!

        for _ in 0..<3 {
            let date = formatter.string(from: cursor)
            records.append(
                DailyVitalityRecord(
                    id: date,
                    date: date,
                    steps: 10_500,
                    stepPoints: 25,
                    workoutPoints: 0,
                    totalPoints: 25,
                    workouts: [],
                    stepTiersReached: [5000, 10000]
                )
            )
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)!
        }

        let count = MascotMemory.consecutiveWeeksMeetingStepTier(
            records: records,
            tier: 10_000,
            endingAt: formatter.date(from: "2026-08-29")!
        )
        XCTAssertEqual(count, 3)
    }

    func testHeadlineWinPrefersWeeklyGoalStreak() {
        var goalState = VitalityGoalState.empty
        goalState.weeklyTargets = [
            "2026-08-18": 200,
            "2026-08-25": 200,
        ]

        let records = [
            makeRecord(date: "2026-08-20", steps: 12_000, points: 250),
            makeRecord(date: "2026-08-27", steps: 12_000, points: 250),
        ]

        let win = MascotMemory.headlineWin(records: records, goalState: goalState, mascotId: "flo")
        if case .consecutiveWeeklyGoals(let count) = win {
            XCTAssertGreaterThanOrEqual(count, 2)
        } else {
            XCTFail("Expected weekly goal streak")
        }
    }

    private func makeRecord(date: String, steps: Int, points: Int) -> DailyVitalityRecord {
        DailyVitalityRecord(
            id: date,
            date: date,
            steps: steps,
            stepPoints: 25,
            workoutPoints: max(0, points - 25),
            totalPoints: points,
            workouts: [],
            stepTiersReached: steps >= 10_000 ? [5000, 10000] : [5000]
        )
    }
}
