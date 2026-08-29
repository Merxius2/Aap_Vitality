import Foundation

enum MascotMemoryWin: Equatable {
    case consecutiveWeeksStep10k(count: Int)
    case consecutiveWeeksStep5k(count: Int)
    case consecutiveDaysStep10k(count: Int)
    case consecutiveWeeklyGoals(count: Int)

    var priority: Int {
        switch self {
        case .consecutiveWeeklyGoals(let count): return 100 + count
        case .consecutiveWeeksStep10k(let count): return 90 + count
        case .consecutiveDaysStep10k(let count): return 80 + count
        case .consecutiveWeeksStep5k(let count): return 70 + count
        }
    }
}

enum MascotMemory {
    static func recentWins(
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        referenceDate: Date = Date()
    ) -> [MascotMemoryWin] {
        var wins: [MascotMemoryWin] = []

        let weeks10k = consecutiveWeeksMeetingStepTier(records: records, tier: 10_000, endingAt: referenceDate)
        if weeks10k >= 2 {
            wins.append(.consecutiveWeeksStep10k(count: weeks10k))
        }

        let weeks5k = consecutiveWeeksMeetingStepTier(records: records, tier: 5_000, endingAt: referenceDate)
        if weeks5k >= 2 {
            wins.append(.consecutiveWeeksStep5k(count: weeks5k))
        }

        let days10k = consecutiveDaysMeetingStepTier(records: records, tier: 10_000, endingAt: referenceDate)
        if days10k >= 2 {
            wins.append(.consecutiveDaysStep10k(count: days10k))
        }

        let weeklyGoals = consecutiveWeeksMeetingGoal(
            records: records,
            goalState: goalState,
            endingAt: referenceDate
        )
        if weeklyGoals >= 2 {
            wins.append(.consecutiveWeeklyGoals(count: weeklyGoals))
        }

        return wins.sorted { $0.priority > $1.priority }
    }

    static func headlineWin(
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        mascotId: String,
        referenceDate: Date = Date()
    ) -> MascotMemoryWin? {
        let wins = recentWins(records: records, goalState: goalState, referenceDate: referenceDate)
        let minimumCount = mascotId == "flip" ? 2 : 3
        return wins.first { win in
            switch win {
            case .consecutiveWeeksStep10k(let count),
                 .consecutiveWeeksStep5k(let count),
                 .consecutiveDaysStep10k(let count),
                 .consecutiveWeeklyGoals(let count):
                return count >= minimumCount
            }
        } ?? wins.first
    }

    static func message(for win: MascotMemoryWin, t: TranslationService) -> String {
        switch win {
        case .consecutiveWeeksStep10k(let count):
            return t.t("progress.memory.weekStep10k", params: ["count": String(count)])
        case .consecutiveWeeksStep5k(let count):
            return t.t("progress.memory.weekStep5k", params: ["count": String(count)])
        case .consecutiveDaysStep10k(let count):
            return t.t("progress.memory.dayStep10k", params: ["count": String(count)])
        case .consecutiveWeeklyGoals(let count):
            return t.t("progress.memory.weeklyGoal", params: ["count": String(count)])
        }
    }

    static func consecutiveWeeksMeetingStepTier(
        records: [DailyVitalityRecord],
        tier: Int,
        endingAt date: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        var count = 0
        var cursor = weekStart(for: date, calendar: calendar)

        for _ in 0..<52 {
            let weekKey = VitalityGoals.weekKey(for: cursor)
            let met = records.contains {
                VitalityGoals.weekKey(for: $0.date) == weekKey && $0.steps >= tier
            }
            if met {
                count += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = weekStart(for: previous, calendar: calendar)
        }
        return count
    }

    static func consecutiveDaysMeetingStepTier(
        records: [DailyVitalityRecord],
        tier: Int,
        endingAt date: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        let formatter = dateFormatter
        var count = 0
        var cursor = calendar.startOfDay(for: date)

        for _ in 0..<120 {
            let key = formatter.string(from: cursor)
            guard let record = records.first(where: { $0.date == key }) else { break }
            guard record.steps >= tier else { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func consecutiveWeeksMeetingGoal(
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        endingAt date: Date = Date()
    ) -> Int {
        let calendar = Calendar.current
        var count = 0
        var cursor = weekStart(for: date, calendar: calendar)

        for _ in 0..<52 {
            let weekKey = VitalityGoals.weekKey(for: cursor)
            guard let target = goalState.weeklyTargets[weekKey], target > 0 else { break }
            let earned = VitalityGoals.weeklyProgress(records: records, weekKey: weekKey)
            if earned >= target {
                count += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = weekStart(for: previous, calendar: calendar)
        }
        return count
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
        return calendar.date(from: components) ?? date
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
