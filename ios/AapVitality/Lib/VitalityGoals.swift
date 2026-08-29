import Foundation

enum VitalityGoals {
    static let earlyCompletionDays = 20
    static let goalIncreaseFactor = 1.15

    static func getMonthKey(_ date: Date = Date()) -> String {
        SwimMonthlyChallenges.getMonthKey(date)
    }

    static func getYearKey(_ date: Date = Date()) -> String {
        String(Calendar.current.component(.year, from: date))
    }

    static func todayDateKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func weekKey(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: dateString) else { return dateString }
        return weekKey(for: date)
    }

    static func weekKey(for date: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
        let weekStart = calendar.date(from: components) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: weekStart)
    }

    static func daysInMonth(_ monthKey: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: "\(monthKey)-01") else { return 30 }
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static func baselineDailyPoints(profile: SwimProfile) -> Int {
        let ageFactor: Double
        switch profile.age {
        case ..<25: ageFactor = 1.1
        case 55...: ageFactor = 0.85
        case 45..<55: ageFactor = 0.92
        default: ageFactor = 1.0
        }
        let sexFactor = profile.sex.lowercased() == "female" ? 0.95 : 1.0
        return max(25, Int((45 * ageFactor * sexFactor).rounded()))
    }

    static func averageDailyPoints(records: [DailyVitalityRecord], endingAt monthKey: String, dayCount: Int = 30) -> Double {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = formatter.date(from: "\(monthKey)-01") else { return 0 }
        guard let start = Calendar.current.date(byAdding: .day, value: -dayCount, to: monthStart) else { return 0 }
        let startKey = formatter.string(from: start)
        let relevant = records.filter { $0.date >= startKey && $0.date < "\(monthKey)-01" }
        guard !relevant.isEmpty else { return 0 }
        return Double(relevant.reduce(0) { $0 + $1.totalPoints }) / Double(relevant.count)
    }

    static func computeMonthlyTarget(
        profile: SwimProfile,
        records: [DailyVitalityRecord],
        monthKey: String,
        goalState: VitalityGoalState,
        intensity: Double = 1
    ) -> Int {
        if let stored = goalState.monthlyTargets[monthKey] {
            return stored
        }
        let historyAvg = averageDailyPoints(records: records, endingAt: monthKey)
        let baseline = Double(baselineDailyPoints(profile: profile))
        let dailyTarget = max(baseline, historyAvg * 0.95) * intensity * goalState.goalBoostFactor
        let days = daysInMonth(monthKey)
        return max(300, Int((dailyTarget * Double(days)).rounded()))
    }

    static func computeWeeklyTarget(monthlyTarget: Int) -> Int {
        max(75, Int((Double(monthlyTarget) / 4.3).rounded()))
    }

    static func computeYearlyTarget(profile: SwimProfile, records: [DailyVitalityRecord], yearKey: String, goalState: VitalityGoalState) -> Int {
        if let stored = goalState.yearlyTargets[yearKey] {
            return stored
        }
        let monthKey = "\(yearKey)-01"
        let monthly = computeMonthlyTarget(
            profile: profile,
            records: records,
            monthKey: monthKey,
            goalState: goalState
        )
        return monthly * 12
    }

    static func monthlyProgress(records: [DailyVitalityRecord], monthKey: String) -> Int {
        VitalityPoints.totalPoints(in: records, monthKey: monthKey)
    }

    static func weeklyProgress(records: [DailyVitalityRecord], weekKey: String) -> Int {
        VitalityPoints.totalPoints(in: records, weekKey: weekKey)
    }

    static func yearlyProgress(records: [DailyVitalityRecord], yearKey: String) -> Int {
        records.filter { $0.date.hasPrefix(yearKey) }.reduce(0) { $0 + $1.totalPoints }
    }

    static func ensureGoals(
        data: inout SwimData,
        monthKey: String = getMonthKey(),
        intensity: Double = 1
    ) {
        var goalState = data.goalState
        let previousMonth = shiftMonthKey(monthKey, by: -1)

        if goalState.monthlyTargets[monthKey] == nil {
            let target = computeMonthlyTarget(
                profile: data.profile,
                records: data.dailyRecords,
                monthKey: monthKey,
                goalState: goalState,
                intensity: intensity
            )
            goalState.monthlyTargets[monthKey] = target
        }

        let week = weekKey(for: Date())
        if goalState.weeklyTargets[week] == nil, let monthly = goalState.monthlyTargets[monthKey] {
            goalState.weeklyTargets[week] = computeWeeklyTarget(monthlyTarget: monthly)
        }

        let yearKey = getYearKey()
        if goalState.yearlyTargets[yearKey] == nil {
            goalState.yearlyTargets[yearKey] = computeYearlyTarget(
                profile: data.profile,
                records: data.dailyRecords,
                yearKey: yearKey,
                goalState: goalState
            )
        }

        if let completion = goalState.monthlyCompletions[previousMonth],
           completion.daysToComplete <= earlyCompletionDays {
            goalState.goalBoostFactor = min(1.6, goalState.goalBoostFactor * goalIncreaseFactor)
        }

        data.goalState = goalState
    }

    static func recordMonthlyCompletionIfNeeded(data: inout SwimData, monthKey: String) {
        guard data.goalState.monthlyCompletions[monthKey] == nil,
              let target = data.goalState.monthlyTargets[monthKey] else { return }
        let earned = monthlyProgress(records: data.dailyRecords, monthKey: monthKey)
        guard earned >= target else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = formatter.date(from: "\(monthKey)-01") else { return }

        let monthRecords = data.dailyRecords.filter { $0.date.hasPrefix(monthKey) }.sorted { $0.date < $1.date }
        var running = 0
        var completionDate: String?
        for record in monthRecords {
            running += record.totalPoints
            if running >= target {
                completionDate = record.date
                break
            }
        }
        guard let completionDate,
              let completion = formatter.date(from: completionDate) else { return }
        let days = Calendar.current.dateComponents([.day], from: monthStart, to: completion).day ?? 1
        data.goalState.monthlyCompletions[monthKey] = MonthlyGoalCompletion(
            completedAt: completionDate,
            daysToComplete: max(1, days + 1),
            targetPoints: target,
            earnedPoints: earned
        )
    }

    static func evaluatePointChallenges(
        records: [DailyVitalityRecord],
        profile: SwimProfile,
        goalState: VitalityGoalState,
        monthKey: String = getMonthKey(),
        intensity: Double = 1
    ) -> MonthlyChallengeState {
        let monthlyTarget = computeMonthlyTarget(
            profile: profile,
            records: records,
            monthKey: monthKey,
            goalState: goalState,
            intensity: intensity
        )
        let earned = monthlyProgress(records: records, monthKey: monthKey)
        let thresholds = [
            Int(Double(monthlyTarget) * 0.5),
            Int(Double(monthlyTarget) * 0.75),
            monthlyTarget
        ]
        let types = ["monthly_points_bronze", "monthly_points_silver", "monthly_points_gold"]

        let challenges = zip(types, thresholds.enumerated()).map { type, pair in
            let (index, target) = pair
            return MonthlyChallenge(
                id: "\(monthKey)-\(type)",
                type: type,
                monthKey: monthKey,
                target: target,
                tierIndex: index,
                current: earned,
                completed: earned >= target
            )
        }

        let completedCount = challenges.filter(\.completed).count
        let tier: String?
        switch completedCount {
        case 3...: tier = "gold"
        case 2: tier = "silver"
        case 1: tier = "bronze"
        default: tier = nil
        }

        let earnedAt = tier != nil ? records.filter { $0.date.hasPrefix(monthKey) }.max(by: { $0.date < $1.date })?.date : nil
        return MonthlyChallengeState(
            monthKey: monthKey,
            challenges: challenges,
            completedCount: completedCount,
            tier: tier,
            earnedAt: earnedAt
        )
    }

    static func goalSnapshot(
        records: [DailyVitalityRecord],
        profile: SwimProfile,
        goalState: VitalityGoalState,
        intensity: Double = 1
    ) -> VitalityGoalSnapshot {
        let monthKey = getMonthKey()
        let week = weekKey(for: Date())
        let yearKey = getYearKey()
        let monthlyTarget = computeMonthlyTarget(
            profile: profile,
            records: records,
            monthKey: monthKey,
            goalState: goalState,
            intensity: intensity
        )
        let weeklyTarget = goalState.weeklyTargets[week] ?? computeWeeklyTarget(monthlyTarget: monthlyTarget)
        let yearlyTarget = goalState.yearlyTargets[yearKey]
            ?? computeYearlyTarget(profile: profile, records: records, yearKey: yearKey, goalState: goalState)

        return VitalityGoalSnapshot(
            monthKey: monthKey,
            weekKey: week,
            yearKey: yearKey,
            monthlyTarget: monthlyTarget,
            monthlyEarned: monthlyProgress(records: records, monthKey: monthKey),
            weeklyTarget: weeklyTarget,
            weeklyEarned: weeklyProgress(records: records, weekKey: week),
            yearlyTarget: yearlyTarget,
            yearlyEarned: yearlyProgress(records: records, yearKey: yearKey)
        )
    }

    private static func shiftMonthKey(_ monthKey: String, by delta: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: "\(monthKey)-01"),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: date) else {
            return monthKey
        }
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: shifted)
    }
}
