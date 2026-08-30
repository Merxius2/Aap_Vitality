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
        dateKeyFormatter.string(from: date)
    }

    static func weekKey(for dateString: String) -> String {
        guard let date = dateKeyFormatter.date(from: dateString) else { return dateString }
        return weekKey(for: date)
    }

    static func weekKey(for date: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
        let weekStart = calendar.date(from: components) ?? date
        return dateKeyFormatter.string(from: weekStart)
    }

    static func weeklyDayBreakdown(
        records: [DailyVitalityRecord],
        weekKey: String,
        todayKey: String = todayDateKey()
    ) -> [WeeklyDayPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let weekStart = formatter.date(from: weekKey) else { return [] }

        let byDate = Dictionary(
            uniqueKeysWithValues: records
                .filter { self.weekKey(for: $0.date) == weekKey }
                .map { ($0.date, $0) }
        )

        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let key = formatter.string(from: date)
            let record = byDate[key]
            return WeeklyDayPoint(
                date: key,
                totalPoints: record?.totalPoints ?? 0,
                stepPoints: record?.stepPoints ?? 0,
                workoutPoints: record?.workoutPoints ?? 0,
                sleepPoints: record?.sleepPoints ?? 0,
                isToday: key == todayKey,
                isFuture: key > todayKey
            )
        }
    }

    static func yearlyMonthBreakdown(
        records: [DailyVitalityRecord],
        yearKey: String,
        currentMonthKey: String = getMonthKey()
    ) -> [YearlyMonthPoint] {
        (1...12).map { month in
            let monthKey = String(format: "%@-%02d", yearKey, month)
            let monthRecords = records.filter { $0.date.hasPrefix(monthKey) }
            return YearlyMonthPoint(
                monthKey: monthKey,
                totalPoints: monthRecords.reduce(0) { $0 + $1.totalPoints },
                stepPoints: monthRecords.reduce(0) { $0 + $1.stepPoints },
                workoutPoints: monthRecords.reduce(0) { $0 + $1.workoutPoints },
                sleepPoints: monthRecords.reduce(0) { $0 + $1.sleepPoints },
                isCurrentMonth: monthKey == currentMonthKey,
                isFuture: monthKey > currentMonthKey
            )
        }
    }

    static func daysInMonth(_ monthKey: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = formatter.date(from: "\(monthKey)-01") else { return 30 }
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    static func baselineDailyPoints(profile: VitalityProfile) -> Int {
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
        profile: VitalityProfile,
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

    static func computeDailyTarget(weeklyTarget: Int, profile: VitalityProfile, intensity: Double = 1) -> Int {
        let fromWeekly = max(25, Int((Double(weeklyTarget) / 7.0).rounded()))
        let baseline = Int((Double(baselineDailyPoints(profile: profile)) * intensity).rounded())
        return max(fromWeekly, baseline)
    }

    static func todayPoints(records: [DailyVitalityRecord], dateKey: String = todayDateKey()) -> Int {
        records.first { $0.date == dateKey }?.totalPoints ?? 0
    }

    static func computeYearlyTarget(profile: VitalityProfile, records: [DailyVitalityRecord], yearKey: String, goalState: VitalityGoalState) -> Int {
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

    static func monthlyProgress(records: [DailyVitalityRecord], monthKey: String, challengeBonus: Int = 0) -> Int {
        VitalityPoints.totalPoints(in: records, monthKey: monthKey) + challengeBonus
    }

    static func weeklyProgress(records: [DailyVitalityRecord], weekKey: String) -> Int {
        VitalityPoints.totalPoints(in: records, weekKey: weekKey)
    }

    static func yearlyProgress(records: [DailyVitalityRecord], yearKey: String, challengeBonus: Int = 0) -> Int {
        records.filter { $0.date.hasPrefix(yearKey) }.reduce(0) { $0 + $1.totalPoints } + challengeBonus
    }

    static func challengeRewardPoints(monthlyTarget: Int) -> Int {
        max(25, Int((Double(monthlyTarget) * 0.06).rounded()))
    }

    static func ensureGoals(
        data: inout VitalityData,
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

    static func recordMonthlyCompletionIfNeeded(
        data: inout VitalityData,
        monthKey: String,
        intensity: Double = 1
    ) {
        guard data.goalState.monthlyCompletions[monthKey] == nil,
              let target = data.goalState.monthlyTargets[monthKey] else { return }
        let bonus = evaluatePointChallenges(
            records: data.dailyRecords,
            profile: data.profile,
            goalState: data.goalState,
            monthKey: monthKey,
            intensity: intensity,
            rerolls: data.monthlyChallengeRerolls,
            bodyMetricsEntries: data.bodyMetricsEntries,
            bodyProgressEnabled: data.profile.bodyProgressEnabled
        ).bonusPoints
        let earned = monthlyProgress(records: data.dailyRecords, monthKey: monthKey, challengeBonus: bonus)
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
        if completionDate == nil, running + bonus >= target {
            completionDate = monthRecords.last?.date ?? todayDateKey()
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
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        monthKey: String = getMonthKey(),
        intensity: Double = 1,
        rerolls: [String: MonthRerollEntry] = [:],
        bodyMetricsEntries: [BodyMetricsEntry] = [],
        bodyProgressEnabled: Bool = false,
        todayKey: String = todayDateKey()
    ) -> MonthlyChallengeState {
        let monthlyTarget = computeMonthlyTarget(
            profile: profile,
            records: records,
            monthKey: monthKey,
            goalState: goalState,
            intensity: intensity
        )
        let reward = challengeRewardPoints(monthlyTarget: monthlyTarget)
        let monthRecords = records.filter { $0.date.hasPrefix(monthKey) }.sorted { $0.date < $1.date }
        let types = selectedChallengeTypes(
            monthKey: monthKey,
            rerolls: rerolls,
            bodyProgressEnabled: bodyProgressEnabled
        )

        let challenges = types.enumerated().map { index, type in
            let target = challengeTarget(
                type: type,
                intensity: intensity,
                monthKey: monthKey
            )
            let current = measureChallenge(
                type: type,
                records: records,
                monthRecords: monthRecords,
                monthKey: monthKey,
                todayKey: todayKey,
                goalState: goalState,
                monthlyTarget: monthlyTarget,
                bodyMetricsEntries: bodyMetricsEntries
            )
            let completed = current >= target
            return MonthlyChallenge(
                id: "\(monthKey)-\(type)",
                type: type,
                monthKey: monthKey,
                target: target,
                tierIndex: index,
                current: current,
                completed: completed,
                rewardPoints: reward
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

        let earnedAt = tier != nil ? monthRecords.last?.date : nil
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
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        intensity: Double = 1,
        rerolls: [String: MonthRerollEntry] = [:],
        bodyMetricsEntries: [BodyMetricsEntry] = [],
        monthChallengeBonus: Int? = nil
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
        let monthBonus = monthChallengeBonus ?? evaluatePointChallenges(
            records: records,
            profile: profile,
            goalState: goalState,
            monthKey: monthKey,
            intensity: intensity,
            rerolls: rerolls,
            bodyMetricsEntries: bodyMetricsEntries,
            bodyProgressEnabled: profile.bodyProgressEnabled
        ).bonusPoints
        let yearBonus = yearlyChallengeBonus(
            records: records,
            profile: profile,
            goalState: goalState,
            yearKey: yearKey,
            intensity: intensity,
            rerolls: rerolls,
            bodyMetricsEntries: bodyMetricsEntries,
            currentMonthKey: monthKey,
            currentMonthBonus: monthBonus
        )

        return VitalityGoalSnapshot(
            monthKey: monthKey,
            weekKey: week,
            yearKey: yearKey,
            monthlyTarget: monthlyTarget,
            monthlyEarned: monthlyProgress(records: records, monthKey: monthKey, challengeBonus: monthBonus),
            weeklyTarget: weeklyTarget,
            weeklyEarned: weeklyProgress(records: records, weekKey: week),
            yearlyTarget: yearlyTarget,
            yearlyEarned: yearlyProgress(records: records, yearKey: yearKey, challengeBonus: yearBonus),
            challengeBonusPoints: monthBonus,
            earlyFinish: earlyFinishSnapshot(
                records: records,
                profile: profile,
                goalState: goalState,
                monthKey: monthKey,
                intensity: intensity,
                challengeBonus: monthBonus
            )
        )
    }

    static func earlyFinishSnapshot(
        records: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        monthKey: String = getMonthKey(),
        date: Date = Date(),
        intensity: Double = 1,
        challengeBonus: Int = 0
    ) -> EarlyFinishSnapshot {
        let deadlineDay = earlyCompletionDays
        let currentDay = Calendar.current.component(.day, from: date)
        let monthlyTarget = computeMonthlyTarget(
            profile: profile,
            records: records,
            monthKey: monthKey,
            goalState: goalState,
            intensity: intensity
        )
        let monthlyEarned = monthlyProgress(records: records, monthKey: monthKey, challengeBonus: challengeBonus)
        let boostPercent = Int(((goalIncreaseFactor - 1) * 100).rounded())

        let base = EarlyFinishSnapshot(
            status: .missedWindow,
            deadlineDay: deadlineDay,
            currentDayOfMonth: currentDay,
            monthlyEarned: monthlyEarned,
            monthlyTarget: monthlyTarget,
            boostPercent: boostPercent
        )

        if let completion = goalState.monthlyCompletions[monthKey] {
            if completion.daysToComplete <= deadlineDay {
                return EarlyFinishSnapshot(
                    status: .secured(completedOnDay: completion.daysToComplete),
                    deadlineDay: deadlineDay,
                    currentDayOfMonth: min(currentDay, completion.daysToComplete),
                    monthlyEarned: monthlyEarned,
                    monthlyTarget: monthlyTarget,
                    boostPercent: boostPercent
                )
            }
            return EarlyFinishSnapshot(
                status: .completedLate(completedOnDay: completion.daysToComplete),
                deadlineDay: deadlineDay,
                currentDayOfMonth: currentDay,
                monthlyEarned: monthlyEarned,
                monthlyTarget: monthlyTarget,
                boostPercent: boostPercent
            )
        }

        if monthlyEarned >= monthlyTarget {
            let completedOnDay = completionDay(
                records: records,
                monthKey: monthKey,
                target: monthlyTarget,
                challengeBonus: challengeBonus
            ) ?? currentDay
            if completedOnDay <= deadlineDay {
                return EarlyFinishSnapshot(
                    status: .secured(completedOnDay: completedOnDay),
                    deadlineDay: deadlineDay,
                    currentDayOfMonth: completedOnDay,
                    monthlyEarned: monthlyEarned,
                    monthlyTarget: monthlyTarget,
                    boostPercent: boostPercent
                )
            }
            return EarlyFinishSnapshot(
                status: .completedLate(completedOnDay: completedOnDay),
                deadlineDay: deadlineDay,
                currentDayOfMonth: currentDay,
                monthlyEarned: monthlyEarned,
                monthlyTarget: monthlyTarget,
                boostPercent: boostPercent
            )
        }

        if currentDay > deadlineDay {
            return base
        }

        let daysRemaining = max(0, deadlineDay - currentDay)
        let onTrack = isOnTrackForEarlyFinish(
            earned: monthlyEarned,
            target: monthlyTarget,
            currentDay: currentDay,
            deadlineDay: deadlineDay
        )
        return EarlyFinishSnapshot(
            status: .inWindow(daysRemaining: daysRemaining, onTrack: onTrack),
            deadlineDay: deadlineDay,
            currentDayOfMonth: currentDay,
            monthlyEarned: monthlyEarned,
            monthlyTarget: monthlyTarget,
            boostPercent: boostPercent
        )
    }

    static func isOnTrackForEarlyFinish(
        earned: Int,
        target: Int,
        currentDay: Int,
        deadlineDay: Int = earlyCompletionDays
    ) -> Bool {
        guard currentDay > 0, target > 0 else { return false }
        if earned >= target { return true }
        let projected = (Double(earned) / Double(currentDay)) * Double(deadlineDay)
        return projected >= Double(target)
    }

    static func completionDay(
        records: [DailyVitalityRecord],
        monthKey: String,
        target: Int,
        challengeBonus: Int = 0
    ) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let monthStart = formatter.date(from: "\(monthKey)-01") else { return nil }

        let monthRecords = records.filter { $0.date.hasPrefix(monthKey) }.sorted { $0.date < $1.date }
        var running = 0
        for record in monthRecords {
            running += record.totalPoints
            if running >= target,
               let completionDate = formatter.date(from: record.date) {
                let days = Calendar.current.dateComponents([.day], from: monthStart, to: completionDate).day ?? 0
                return max(1, days + 1)
            }
        }
        if running + challengeBonus >= target, let last = monthRecords.last,
           let completionDate = formatter.date(from: last.date) {
            let days = Calendar.current.dateComponents([.day], from: monthStart, to: completionDate).day ?? 0
            return max(1, days + 1)
        }
        return nil
    }

    static func canRerollMonthlyChallenge(
        records: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        monthKey: String,
        tierIndex: Int,
        rerolls: [String: MonthRerollEntry],
        intensity: Double,
        bodyMetricsEntries: [BodyMetricsEntry],
        bodyProgressEnabled: Bool,
        freeLimit: Int
    ) -> Bool {
        guard SwimMonthlyChallenges.hasRerollAvailability(
            monthKey: monthKey,
            rerolls: rerolls,
            freeLimit: freeLimit
        ) else {
            return false
        }
        let state = evaluatePointChallenges(
            records: records,
            profile: profile,
            goalState: goalState,
            monthKey: monthKey,
            intensity: intensity,
            rerolls: rerolls,
            bodyMetricsEntries: bodyMetricsEntries,
            bodyProgressEnabled: bodyProgressEnabled
        )
        guard tierIndex >= 0, tierIndex < state.challenges.count else { return false }
        guard !state.challenges[tierIndex].completed else { return false }
        return createChallengeReroll(
            monthKey: monthKey,
            tierIndex: tierIndex,
            rerolls: rerolls,
            bodyProgressEnabled: bodyProgressEnabled
        ) != nil
    }

    static func applyMonthlyChallengeReroll(
        data: VitalityData,
        monthKey: String,
        tierIndex: Int,
        mascotId: String
    ) -> VitalityData? {
        let gameplay = MascotConstants.gameplay(mascotId)
        guard canRerollMonthlyChallenge(
            records: data.dailyRecords,
            profile: data.profile,
            goalState: data.goalState,
            monthKey: monthKey,
            tierIndex: tierIndex,
            rerolls: data.monthlyChallengeRerolls,
            intensity: gameplay.challengeIntensity,
            bodyMetricsEntries: data.bodyMetricsEntries,
            bodyProgressEnabled: data.profile.bodyProgressEnabled,
            freeLimit: gameplay.freeMonthlyRerolls
        ) else {
            return nil
        }
        guard let override = createChallengeReroll(
            monthKey: monthKey,
            tierIndex: tierIndex,
            rerolls: data.monthlyChallengeRerolls,
            bodyProgressEnabled: data.profile.bodyProgressEnabled
        ) else {
            return nil
        }

        var next = data
        var monthEntry = SwimMonthlyChallenges.normalizeMonthRerollEntry(next.monthlyChallengeRerolls[monthKey])
        guard monthEntry.freeUses < gameplay.freeMonthlyRerolls else { return nil }
        monthEntry.overrides[String(override.tierIndex)] = override.type
        monthEntry.freeUses += 1
        next.monthlyChallengeRerolls[monthKey] = monthEntry
        return next
    }

    // MARK: - Challenge pool

    private static let challengeCatalog: [(type: String, family: String)] = [
        ("steps_10k_days", "steps"),
        ("steps_5k_days", "steps"),
        ("steps_20k_day", "steps"),
        ("workout_count", "workouts"),
        ("workout_variety", "workouts"),
        ("workout_weekends", "workouts"),
        ("workout_active_weeks", "workouts"),
        ("points_streak", "streaks"),
        ("weekly_goals", "streaks"),
        ("strong_week", "streaks"),
        ("weigh_ins", "body"),
        ("sleep_nights", "sleep"),
        ("recovery_pair", "sleep"),
        ("balanced_days", "mixed"),
        ("zone_minutes", "mixed")
    ]

    private static func availableChallengeTypes(bodyProgressEnabled: Bool) -> [String] {
        challengeCatalog
            .filter { bodyProgressEnabled || $0.family != "body" }
            .map(\.type)
    }

    private static func challengeFamily(for type: String) -> String {
        challengeCatalog.first { $0.type == type }?.family ?? type
    }

    static func selectedChallengeTypes(
        monthKey: String,
        rerolls: [String: MonthRerollEntry],
        bodyProgressEnabled: Bool
    ) -> [String] {
        let pool = availableChallengeTypes(bodyProgressEnabled: bodyProgressEnabled)
        var types = pickChallengeTypes(monthKey: monthKey, pool: pool)
        let overrides = SwimMonthlyChallenges.normalizeMonthRerollEntry(rerolls[monthKey]).overrides
        for index in types.indices {
            guard let override = overrides[String(index)], pool.contains(override) else { continue }
            types[index] = override
        }
        return types
    }

    private static func pickChallengeTypes(monthKey: String, pool: [String]) -> [String] {
        var remaining = pool
        var shuffled: [String] = []
        var seed = hashMonth(monthKey)
        while !remaining.isEmpty {
            seed = (seed &* 1_103_515_245 &+ 12_345) & 0x7fff_ffff
            let index = abs(seed) % remaining.count
            shuffled.append(remaining.remove(at: index))
        }

        var picked: [String] = []
        var usedFamilies: Set<String> = []
        for type in shuffled {
            guard picked.count < 3 else { break }
            let family = challengeFamily(for: type)
            if usedFamilies.contains(family) { continue }
            picked.append(type)
            usedFamilies.insert(family)
        }
        if picked.count < 3 {
            for type in shuffled where !picked.contains(type) {
                picked.append(type)
                if picked.count == 3 { break }
            }
        }
        return picked
    }

    private static func createChallengeReroll(
        monthKey: String,
        tierIndex: Int,
        rerolls: [String: MonthRerollEntry],
        bodyProgressEnabled: Bool
    ) -> (tierIndex: Int, type: String)? {
        guard tierIndex >= 0, tierIndex <= 2 else { return nil }
        let current = selectedChallengeTypes(
            monthKey: monthKey,
            rerolls: rerolls,
            bodyProgressEnabled: bodyProgressEnabled
        )
        guard current.indices.contains(tierIndex) else { return nil }
        let locked = Set(current.enumerated().compactMap { $0.offset == tierIndex ? nil : $0.element })
        let lockedFamilies = Set(locked.map(challengeFamily(for:)))
        let pool = availableChallengeTypes(bodyProgressEnabled: bodyProgressEnabled)
        let preferred = pool.filter { !locked.contains($0) && $0 != current[tierIndex] && !lockedFamilies.contains(challengeFamily(for: $0)) }
        let fallback = pool.filter { !locked.contains($0) && $0 != current[tierIndex] }
        let candidates = preferred.isEmpty ? fallback : preferred
        let salt = SwimMonthlyChallenges.getMonthRerollOverrides(monthKey, rerolls: rerolls).count
        var seed = hashMonth("\(monthKey):reroll:\(tierIndex):\(salt)")
        if seed == 0 { seed = 1 }
        seed = (seed &* 1_103_515_245 &+ 12_345) & 0x7fff_ffff
        guard !candidates.isEmpty else { return nil }
        return (tierIndex, candidates[abs(seed) % candidates.count])
    }

    private static func hashMonth(_ monthKey: String) -> Int {
        monthKey.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) | 0 }
    }

    private static func scaledTarget(base: Int, intensity: Double, min: Int = 1, max: Int) -> Int {
        let scaled = Int((Double(base) * intensity).rounded())
        return Swift.min(max, Swift.max(min, scaled))
    }

    static func challengeTarget(type: String, intensity: Double, monthKey: String) -> Int {
        let days = daysInMonth(monthKey)
        let weeks = max(1, Int(ceil(Double(days) / 7.0)))
        let weekends = weekendCount(in: monthKey)
        switch type {
        case "steps_10k_days":
            return scaledTarget(base: 10, intensity: intensity, min: 6, max: days)
        case "steps_5k_days":
            return scaledTarget(base: 18, intensity: intensity, min: 10, max: days)
        case "steps_20k_day":
            return intensity >= 1.2 ? 2 : 1
        case "workout_count":
            return scaledTarget(base: 8, intensity: intensity, min: 4, max: 20)
        case "workout_variety":
            return scaledTarget(base: 3, intensity: intensity, min: 2, max: 5)
        case "workout_weekends":
            return scaledTarget(base: 2, intensity: intensity, min: 1, max: max(1, weekends))
        case "workout_active_weeks":
            return scaledTarget(base: 4, intensity: intensity, min: 2, max: weeks)
        case "points_streak":
            return scaledTarget(base: 7, intensity: intensity, min: 4, max: min(14, days))
        case "weekly_goals":
            return scaledTarget(base: 3, intensity: intensity, min: 2, max: weeks)
        case "strong_week":
            return scaledTarget(base: 4, intensity: intensity, min: 3, max: 6)
        case "weigh_ins":
            return scaledTarget(base: 4, intensity: intensity, min: 2, max: 8)
        case "sleep_nights":
            return scaledTarget(base: 12, intensity: intensity, min: 7, max: days)
        case "recovery_pair":
            return scaledTarget(base: 6, intensity: intensity, min: 4, max: days)
        case "balanced_days":
            return scaledTarget(base: 8, intensity: intensity, min: 5, max: days)
        case "zone_minutes":
            return scaledTarget(base: 60, intensity: intensity, min: 30, max: 180)
        default:
            return 1
        }
    }

    private static func measureChallenge(
        type: String,
        records: [DailyVitalityRecord],
        monthRecords: [DailyVitalityRecord],
        monthKey: String,
        todayKey: String,
        goalState: VitalityGoalState,
        monthlyTarget: Int,
        bodyMetricsEntries: [BodyMetricsEntry]
    ) -> Int {
        let qualifying = qualifyingWorkouts(in: monthRecords)
        switch type {
        case "steps_10k_days":
            return monthRecords.filter { $0.steps >= 10_000 }.count
        case "steps_5k_days":
            return monthRecords.filter { $0.steps >= 5_000 }.count
        case "steps_20k_day":
            return monthRecords.filter { $0.steps >= 20_000 }.count
        case "workout_count":
            return qualifying.count
        case "workout_variety":
            return Set(qualifying.map(\.workoutType)).count
        case "workout_weekends":
            return Set(qualifying.compactMap { weekendKey(for: $0.date) }).count
        case "workout_active_weeks":
            return Set(qualifying.map { weekKey(for: $0.date) }).count
        case "points_streak":
            return maxPointsStreak(monthRecords: monthRecords, monthKey: monthKey, todayKey: todayKey)
        case "weekly_goals":
            return weeklyGoalsHit(
                monthRecords: monthRecords,
                allRecords: records,
                todayKey: todayKey,
                goalState: goalState,
                monthlyTarget: monthlyTarget
            )
        case "strong_week":
            return maxStrongWeekDays(monthRecords: monthRecords)
        case "weigh_ins":
            return BodyProgress.weighIns(in: monthKey, entries: bodyMetricsEntries)
        case "sleep_nights":
            return monthRecords.filter { $0.sleepMinutes >= 420 }.count
        case "recovery_pair":
            return monthRecords.filter { $0.sleepMinutes >= 420 && $0.steps >= 5_000 }.count
        case "balanced_days":
            return monthRecords.filter { $0.stepPoints > 0 && $0.workoutPoints > 0 }.count
        case "zone_minutes":
            return qualifying.reduce(0) { total, workout in
                guard let zones = workout.zoneMinutes else { return total }
                return total + zones.zone3 + zones.zone4 + zones.zone5
            }
        default:
            return 0
        }
    }

    private static func yearlyChallengeBonus(
        records: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        yearKey: String,
        intensity: Double,
        rerolls: [String: MonthRerollEntry],
        bodyMetricsEntries: [BodyMetricsEntry],
        currentMonthKey: String,
        currentMonthBonus: Int
    ) -> Int {
        let months = Set(records.filter { $0.date.hasPrefix(yearKey) }.map { String($0.date.prefix(7)) })
        return months.reduce(0) { sum, monthKey in
            if monthKey == currentMonthKey {
                return sum + currentMonthBonus
            }
            return sum + evaluatePointChallenges(
                records: records,
                profile: profile,
                goalState: goalState,
                monthKey: monthKey,
                intensity: intensity,
                rerolls: rerolls,
                bodyMetricsEntries: bodyMetricsEntries,
                bodyProgressEnabled: profile.bodyProgressEnabled
            ).bonusPoints
        }
    }

    private static func qualifyingWorkouts(in records: [DailyVitalityRecord]) -> [VitalityWorkout] {
        records.flatMap(\.workouts).filter { $0.durationSec >= VitalityPoints.minWorkoutMinutes * 60 }
    }

    private static func maxPointsStreak(
        monthRecords: [DailyVitalityRecord],
        monthKey: String,
        todayKey: String
    ) -> Int {
        let formatter = dateKeyFormatter
        guard let monthStart = formatter.date(from: "\(monthKey)-01") else { return 0 }
        let days = daysInMonth(monthKey)
        let active = Set(monthRecords.filter { $0.totalPoints > 0 }.map(\.date))
        var best = 0
        var current = 0
        for offset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: monthStart) else { continue }
            let key = formatter.string(from: date)
            if key > todayKey { break }
            if active.contains(key) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private static func weeklyGoalsHit(
        monthRecords: [DailyVitalityRecord],
        allRecords: [DailyVitalityRecord],
        todayKey: String,
        goalState: VitalityGoalState,
        monthlyTarget: Int
    ) -> Int {
        let weekKeys = Set(
            monthRecords
                .filter { $0.date <= todayKey }
                .map { weekKey(for: $0.date) }
        )
        let fallbackTarget = computeWeeklyTarget(monthlyTarget: monthlyTarget)
        return weekKeys.filter { week in
            let target = goalState.weeklyTargets[week] ?? fallbackTarget
            return weeklyProgress(records: allRecords, weekKey: week) >= target
        }.count
    }

    private static func maxStrongWeekDays(monthRecords: [DailyVitalityRecord]) -> Int {
        let grouped = Dictionary(grouping: monthRecords) { weekKey(for: $0.date) }
        return grouped.values.map { week in
            week.filter { $0.stepPoints > 0 && $0.workoutPoints > 0 }.count
        }.max() ?? 0
    }

    private static func weekendCount(in monthKey: String) -> Int {
        let formatter = dateKeyFormatter
        guard let monthStart = formatter.date(from: "\(monthKey)-01") else { return 4 }
        let days = daysInMonth(monthKey)
        var keys = Set<String>()
        for offset in 0..<days {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: monthStart) else { continue }
            let weekday = Calendar.current.component(.weekday, from: date)
            guard weekday == 1 || weekday == 7 else { continue }
            if let key = weekendKey(for: formatter.string(from: date)) {
                keys.insert(key)
            }
        }
        return keys.count
    }

    private static func weekendKey(for dateString: String) -> String? {
        let formatter = dateKeyFormatter
        guard let date = formatter.date(from: dateString) else { return nil }
        let weekday = Calendar.current.component(.weekday, from: date)
        guard weekday == 1 || weekday == 7 else { return nil }
        let delta = weekday == 7 ? 0 : -1
        guard let saturday = Calendar.current.date(byAdding: .day, value: delta, to: date) else { return nil }
        return formatter.string(from: saturday)
    }

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func shiftMonthKey(_ monthKey: String, by delta: Int) -> String {
        guard let date = dateKeyFormatter.date(from: "\(monthKey)-01"),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: date) else {
            return monthKey
        }
        return monthKeyFormatter.string(from: shifted)
    }
}
