import Foundation

enum VitalityStreak {
    static let shieldsPerMonth = 1

    static func reconcile(goalState: inout VitalityGoalState, records: [DailyVitalityRecord]) -> VitalityStreakSnapshot {
        ensureMonthlyShield(goalState: &goalState)
        autoApplyShieldIfNeeded(goalState: &goalState, records: records)
        return snapshot(goalState: goalState, records: records)
    }

    static func snapshot(goalState: VitalityGoalState, records: [DailyVitalityRecord]) -> VitalityStreakSnapshot {
        VitalityStreakSnapshot(
            currentStreak: currentStreak(records: records, shieldUsedDates: goalState.shieldUsedDates),
            shieldsAvailable: goalState.streakShieldsAvailable,
            lastShieldUsedDate: goalState.shieldUsedDates.sorted().last
        )
    }

    static func isActiveDay(_ date: String, records: [DailyVitalityRecord], shieldUsedDates: Set<String>) -> Bool {
        if shieldUsedDates.contains(date) { return true }
        return records.contains { $0.date == date && $0.totalPoints > 0 }
    }

    static func currentStreak(records: [DailyVitalityRecord], shieldUsedDates: [String]) -> Int {
        let shields = Set(shieldUsedDates)
        let formatter = dateFormatter
        guard let today = formatter.date(from: VitalityGoals.todayDateKey()) else { return 0 }

        var streak = 0
        var cursor = today
        let calendar = Calendar.current

        for _ in 0..<400 {
            let key = formatter.string(from: cursor)
            if isActiveDay(key, records: records, shieldUsedDates: shields) {
                streak += 1
            } else {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func maxConsecutiveActiveDays(
        records: [DailyVitalityRecord],
        shieldUsedDates: [String] = []
    ) -> Int {
        let shields = Set(shieldUsedDates)
        var dates = Set(records.filter { $0.totalPoints > 0 }.map(\.date))
        dates.formUnion(shields)
        return maxConsecutiveDays(from: Array(dates).sorted())
    }

    static func maxConsecutiveDays(from dates: [String]) -> Int {
        guard !dates.isEmpty else { return 0 }
        let formatter = dateFormatter
        let sortedDates = dates.compactMap { formatter.date(from: $0) }.sorted()
        guard !sortedDates.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for index in 1..<sortedDates.count {
            let delta = Calendar.current.dateComponents([.day], from: sortedDates[index - 1], to: sortedDates[index]).day ?? 0
            if delta == 1 {
                current += 1
                best = max(best, current)
            } else if delta > 1 {
                current = 1
            }
        }
        return best
    }

    private static func ensureMonthlyShield(goalState: inout VitalityGoalState) {
        let monthKey = VitalityGoals.getMonthKey()
        guard goalState.streakShieldMonthKey != monthKey else { return }
        goalState.streakShieldMonthKey = monthKey
        goalState.streakShieldsAvailable = shieldsPerMonth
    }

    private static func autoApplyShieldIfNeeded(goalState: inout VitalityGoalState, records: [DailyVitalityRecord]) {
        guard goalState.streakShieldsAvailable > 0 else { return }

        let formatter = dateFormatter
        guard let today = formatter.date(from: VitalityGoals.todayDateKey()) else { return }
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        let yesterdayKey = formatter.string(from: yesterday)

        let shields = Set(goalState.shieldUsedDates)
        if isActiveDay(yesterdayKey, records: records, shieldUsedDates: shields) { return }

        guard let dayBefore = calendar.date(byAdding: .day, value: -2, to: today) else { return }
        let dayBeforeKey = formatter.string(from: dayBefore)
        guard isActiveDay(dayBeforeKey, records: records, shieldUsedDates: shields) else { return }

        goalState.streakShieldsAvailable -= 1
        goalState.shieldUsedDates.append(yesterdayKey)
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
