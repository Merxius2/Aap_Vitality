import Foundation

struct BodyProgressSnapshot: Equatable {
    var latestWeightKg: Double?
    var latestBodyFatPercent: Double?
    var latestMusclePercent: Double?
    var latestBMI: Double?
    var weightChange8WeeksKg: Double?
    var bodyFatChange8WeeksPercent: Double?
    var muscleChange8WeeksPercent: Double?
    var weighInsThisMonth: Int
    var weeklyTrend: [BodyProgressWeeklyPoint]
}

struct BodyProgressWeeklyPoint: Equatable, Identifiable {
    var id: String { weekKey }
    var weekKey: String
    var label: String
    var averageWeightKg: Double
    var averageBodyFatPercent: Double?
    var averageMusclePercent: Double?
}

enum BodyProgress {
    static let trendWindowDays = 56
    static let minimumTrendSpanDays = 14
    static let weightTrendTargetKg = 0.5
    static let bodyFatTrendTargetPercent = 0.5
    static let muscleTrendTargetPercent = 0.5

    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let meters = heightCm / 100
        guard meters > 0 else { return 0 }
        return weightKg / (meters * meters)
    }

    static func musclePercent(leanBodyMassKg: Double, weightKg: Double) -> Double? {
        guard weightKg > 0, leanBodyMassKg > 0 else { return nil }
        return min(100, max(0, (leanBodyMassKg / weightKg) * 100))
    }

    static func mergeEntries(
        existing: [BodyMetricsEntry],
        weightByDate: [String: Double],
        bodyFatByDate: [String: Double],
        leanBodyMassByDate: [String: Double],
        heightCm: Double?
    ) -> [BodyMetricsEntry] {
        var byDate = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })
        let allDates = Set(weightByDate.keys)
            .union(bodyFatByDate.keys)
            .union(leanBodyMassByDate.keys)
            .union(byDate.keys)

        for date in allDates {
            let previous = byDate[date]
            guard let weight = weightByDate[date] ?? previous?.weightKg, weight > 0 else { continue }
            let bodyFat = bodyFatByDate[date] ?? previous?.bodyFatPercent
            let height = heightCm ?? previous?.heightCm
            let muscle = resolvedMusclePercent(
                weightKg: weight,
                leanBodyMassKg: leanBodyMassByDate[date],
                previous: previous?.musclePercent
            )
            byDate[date] = BodyMetricsEntry(
                id: date,
                date: date,
                weightKg: weight,
                heightCm: height,
                bodyFatPercent: bodyFat,
                musclePercent: muscle
            )
        }

        return byDate.values.sorted { $0.date < $1.date }
    }

    static func weighIns(in monthKey: String, entries: [BodyMetricsEntry]) -> Int {
        entries.filter { $0.date.hasPrefix(monthKey) }.count
    }

    static func entriesInWindow(
        _ entries: [BodyMetricsEntry],
        overDays: Int,
        referenceDate: Date = Date()
    ) -> [BodyMetricsEntry] {
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -overDays, to: referenceDate) else {
            return []
        }
        let startKey = dateKeyFormatter.string(from: windowStart)
        return entries.filter { $0.date >= startKey }.sorted { $0.date < $1.date }
    }

    static func weightChangeKg(
        entries: [BodyMetricsEntry],
        overDays: Int = trendWindowDays,
        referenceDate: Date = Date()
    ) -> Double? {
        let window = entriesInWindow(entries, overDays: overDays, referenceDate: referenceDate)
        guard let first = window.first, let last = window.last, first.date != last.date else { return nil }
        guard daySpan(from: first.date, to: last.date) >= minimumTrendSpanDays else { return nil }
        return last.weightKg - first.weightKg
    }

    static func bodyFatChangePercent(
        entries: [BodyMetricsEntry],
        overDays: Int = trendWindowDays,
        referenceDate: Date = Date()
    ) -> Double? {
        metricChange(
            entries: entries,
            overDays: overDays,
            referenceDate: referenceDate,
            value: { $0.bodyFatPercent }
        )
    }

    static func muscleChangePercent(
        entries: [BodyMetricsEntry],
        overDays: Int = trendWindowDays,
        referenceDate: Date = Date()
    ) -> Double? {
        metricChange(
            entries: entries,
            overDays: overDays,
            referenceDate: referenceDate,
            value: { $0.musclePercent }
        )
    }

    static func hasPositiveTrend(
        entries: [BodyMetricsEntry],
        referenceDate: Date = Date()
    ) -> Bool {
        if let weightChange = weightChangeKg(entries: entries, referenceDate: referenceDate),
           weightChange <= -weightTrendTargetKg {
            return true
        }
        if let bodyFatChange = bodyFatChangePercent(entries: entries, referenceDate: referenceDate),
           bodyFatChange <= -bodyFatTrendTargetPercent {
            return true
        }
        if let muscleChange = muscleChangePercent(entries: entries, referenceDate: referenceDate),
           muscleChange >= muscleTrendTargetPercent {
            return true
        }
        return false
    }

    static func activeBalanceWeeks(
        entries: [BodyMetricsEntry],
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        referenceDate: Date = Date()
    ) -> Int {
        let weightChange = weightChangeKg(entries: entries, referenceDate: referenceDate) ?? 0
        let muscleChange = muscleChangePercent(entries: entries, referenceDate: referenceDate) ?? 0
        guard weightChange <= 0 || muscleChange >= muscleTrendTargetPercent else { return 0 }

        let calendar = Calendar.current
        var count = 0
        var cursor = weekStart(for: referenceDate, calendar: calendar)

        for _ in 0..<4 {
            let weekKey = VitalityGoals.weekKey(for: cursor)
            guard let target = goalState.weeklyTargets[weekKey], target > 0 else { break }
            let earned = VitalityGoals.weeklyProgress(records: records, weekKey: weekKey)
            if earned >= target {
                count += 1
            }
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = weekStart(for: previous, calendar: calendar)
        }
        return count
    }

    static func weeklyTrendPoints(
        entries: [BodyMetricsEntry],
        weeks: Int = 12,
        referenceDate: Date = Date()
    ) -> [BodyProgressWeeklyPoint] {
        let calendar = Calendar.current
        var cursor = weekStart(for: referenceDate, calendar: calendar)
        var points: [BodyProgressWeeklyPoint] = []

        for _ in 0..<weeks {
            let weekKey = VitalityGoals.weekKey(for: cursor)
            let weekEntries = entries.filter { VitalityGoals.weekKey(for: $0.date) == weekKey }
            if !weekEntries.isEmpty {
                let avgWeight = weekEntries.reduce(0.0) { $0 + $1.weightKg } / Double(weekEntries.count)
                let fatEntries = weekEntries.compactMap(\.bodyFatPercent)
                let avgFat = fatEntries.isEmpty ? nil : fatEntries.reduce(0, +) / Double(fatEntries.count)
                let muscleEntries = weekEntries.compactMap(\.musclePercent)
                let avgMuscle = muscleEntries.isEmpty ? nil : muscleEntries.reduce(0, +) / Double(muscleEntries.count)
                points.append(
                    BodyProgressWeeklyPoint(
                        weekKey: weekKey,
                        label: weekLabel(for: cursor),
                        averageWeightKg: avgWeight,
                        averageBodyFatPercent: avgFat,
                        averageMusclePercent: avgMuscle
                    )
                )
            }
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = weekStart(for: previous, calendar: calendar)
        }

        return points.reversed()
    }

    static func snapshot(
        entries: [BodyMetricsEntry],
        monthKey: String = VitalityGoals.getMonthKey(),
        referenceDate: Date = Date()
    ) -> BodyProgressSnapshot {
        let latest = entries.max(by: { $0.date < $1.date })
        return BodyProgressSnapshot(
            latestWeightKg: latest?.weightKg,
            latestBodyFatPercent: latest?.bodyFatPercent,
            latestMusclePercent: latest?.musclePercent,
            latestBMI: latest?.bmi,
            weightChange8WeeksKg: weightChangeKg(entries: entries, referenceDate: referenceDate),
            bodyFatChange8WeeksPercent: bodyFatChangePercent(entries: entries, referenceDate: referenceDate),
            muscleChange8WeeksPercent: muscleChangePercent(entries: entries, referenceDate: referenceDate),
            weighInsThisMonth: weighIns(in: monthKey, entries: entries),
            weeklyTrend: weeklyTrendPoints(entries: entries, referenceDate: referenceDate)
        )
    }

    static func evaluateChallenges(
        entries: [BodyMetricsEntry],
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        monthKey: String = VitalityGoals.getMonthKey(),
        referenceDate: Date = Date()
    ) -> MonthlyChallengeState {
        let weighIns = weighIns(in: monthKey, entries: entries)
        let trendMet = hasPositiveTrend(entries: entries, referenceDate: referenceDate)

        let challenges = [
            MonthlyChallenge(
                id: "\(monthKey)-body_weigh_ins_bronze",
                type: "body_weigh_ins_bronze",
                monthKey: monthKey,
                target: 2,
                tierIndex: 0,
                current: weighIns,
                completed: weighIns >= 2
            ),
            MonthlyChallenge(
                id: "\(monthKey)-body_weigh_ins_silver",
                type: "body_weigh_ins_silver",
                monthKey: monthKey,
                target: 4,
                tierIndex: 1,
                current: weighIns,
                completed: weighIns >= 4
            ),
            MonthlyChallenge(
                id: "\(monthKey)-body_trend_gold",
                type: "body_trend_gold",
                monthKey: monthKey,
                target: 1,
                tierIndex: 2,
                current: trendMet ? 1 : 0,
                completed: trendMet
            ),
        ]

        let completedCount = challenges.filter(\.completed).count
        let tier: String?
        switch completedCount {
        case 3...: tier = "gold"
        case 2: tier = "silver"
        case 1: tier = "bronze"
        default: tier = nil
        }

        let earnedAt = tier != nil ? entries.filter { $0.date.hasPrefix(monthKey) }.max(by: { $0.date < $1.date })?.date : nil
        return MonthlyChallengeState(
            monthKey: monthKey,
            challenges: challenges,
            completedCount: completedCount,
            tier: tier,
            earnedAt: earnedAt
        )
    }

    static func coachMessage(
        snapshot: BodyProgressSnapshot,
        mascotId: String,
        t: TranslationService
    ) -> String? {
        if let change = snapshot.weightChange8WeeksKg, change <= -weightTrendTargetKg {
            let formatted = formatWeight(abs(change), t: t)
            return t.t("progress.body.memoryWeightTrend", params: ["change": formatted])
        }
        if let change = snapshot.bodyFatChange8WeeksPercent, change <= -bodyFatTrendTargetPercent {
            return t.t("progress.body.memoryBodyFatTrend", params: [
                "change": String(format: "%.1f", abs(change))
            ])
        }
        if let change = snapshot.muscleChange8WeeksPercent, change >= muscleTrendTargetPercent {
            return t.t("progress.body.memoryMuscleTrend", params: [
                "change": String(format: "%.1f", change)
            ])
        }
        if snapshot.weighInsThisMonth >= 4 {
            return t.t("progress.body.memoryWeighIns", params: [
                "count": String(snapshot.weighInsThisMonth)
            ])
        }
        if mascotId == "flip", snapshot.weighInsThisMonth >= 2 {
            return t.t("progress.body.memoryWeighInsFlip", params: [
                "count": String(snapshot.weighInsThisMonth)
            ])
        }
        return nil
    }

    static func formatWeight(_ kg: Double, t: TranslationService) -> String {
        t.t("progress.body.weightValue", params: ["value": String(format: "%.1f", kg)])
    }

    static func formatBMI(_ bmi: Double) -> String {
        String(format: "%.1f", bmi)
    }

    private static func resolvedMusclePercent(
        weightKg: Double,
        leanBodyMassKg: Double?,
        previous: Double?
    ) -> Double? {
        if let leanBodyMassKg, let computed = musclePercent(leanBodyMassKg: leanBodyMassKg, weightKg: weightKg) {
            return computed
        }
        return previous
    }

    private static func metricChange(
        entries: [BodyMetricsEntry],
        overDays: Int,
        referenceDate: Date,
        value: (BodyMetricsEntry) -> Double?
    ) -> Double? {
        let window = entriesInWindow(entries, overDays: overDays, referenceDate: referenceDate)
            .compactMap { entry -> (String, Double)? in
                guard let metric = value(entry) else { return nil }
                return (entry.date, metric)
            }
        guard let first = window.first, let last = window.last, first.0 != last.0 else { return nil }
        guard daySpan(from: first.0, to: last.0) >= minimumTrendSpanDays else { return nil }
        return last.1 - first.1
    }

    private static func weekStart(for date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
        return calendar.date(from: components) ?? date
    }

    private static func weekLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private static func daySpan(from startKey: String, to endKey: String) -> Int {
        guard let start = dateKeyFormatter.date(from: startKey),
              let end = dateKeyFormatter.date(from: endKey) else { return 0 }
        return Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
