import Foundation

enum VitalityMedals {
    static let medals: [MedalDefinition] = [
        MedalDefinition(id: "first_points", category: "milestone", tier: "bronze", season: nil),
        MedalDefinition(id: "ten_active_days", category: "milestone", tier: "silver", season: nil),
        MedalDefinition(id: "fifty_active_days", category: "milestone", tier: "gold", season: nil),
        MedalDefinition(id: "five_k_steps", category: "steps", tier: "bronze", season: nil),
        MedalDefinition(id: "ten_k_steps", category: "steps", tier: "silver", season: nil),
        MedalDefinition(id: "twenty_k_steps", category: "steps", tier: "gold", season: nil),
        MedalDefinition(id: "step_streak_7", category: "steps", tier: "silver", season: nil),
        MedalDefinition(id: "step_streak_14", category: "steps", tier: "gold", season: nil),
        MedalDefinition(id: "first_workout", category: "workout", tier: "bronze", season: nil),
        MedalDefinition(id: "ten_workouts", category: "workout", tier: "silver", season: nil),
        MedalDefinition(id: "thirty_workouts", category: "workout", tier: "gold", season: nil),
        MedalDefinition(id: "endurance_45", category: "workout", tier: "silver", season: nil),
        MedalDefinition(id: "zone_master", category: "workout", tier: "gold", season: nil),
        MedalDefinition(id: "weekly_goal_hit", category: "goals", tier: "bronze", season: nil),
        MedalDefinition(id: "monthly_goal_hit", category: "goals", tier: "silver", season: nil),
        MedalDefinition(id: "yearly_halfway", category: "goals", tier: "bronze", season: nil),
        MedalDefinition(id: "yearly_goal_hit", category: "goals", tier: "gold", season: nil),
        MedalDefinition(id: "early_finisher", category: "goals", tier: "gold", season: nil),
        MedalDefinition(id: "hat_trick", category: "streak", tier: "bronze", season: nil),
        MedalDefinition(id: "week_warrior", category: "streak", tier: "silver", season: nil),
        MedalDefinition(id: "fortnight_flow", category: "streak", tier: "gold", season: nil),
        MedalDefinition(id: "ten_k_points_month", category: "monthly", tier: "bronze", season: nil),
        MedalDefinition(id: "twenty_k_points_month", category: "monthly", tier: "silver", season: nil),
        MedalDefinition(id: "forty_k_points_month", category: "monthly", tier: "gold", season: nil),
        MedalDefinition(id: "double_day", category: "special", tier: "bronze", season: nil),
        MedalDefinition(id: "walk_and_work", category: "special", tier: "silver", season: nil),
        MedalDefinition(id: "comeback", category: "special", tier: "silver", season: nil),
        MedalDefinition(id: "sleep_7h", category: "special", tier: "bronze", season: nil),
        MedalDefinition(id: "sleep_8h", category: "special", tier: "silver", season: nil),
        MedalDefinition(id: "sleep_streak_3", category: "special", tier: "gold", season: nil),
    ]

    struct MedalContext {
        var records: [DailyVitalityRecord]
        var totalPoints: Int
        var activeDays: Int
        var totalWorkouts: Int
        var maxStepsDay: Int
        var daysWith5k: Int
        var daysWith10k: Int
        var daysWith20k: Int
        var maxConsecutiveActiveDays: Int
        var maxWorkoutMinutes: Int
        var maxZone5Minutes: Int
        var monthsWith10kPoints: [String]
        var monthsWith20kPoints: [String]
        var monthsWith40kPoints: [String]
        var weeklyGoalsHit: [String]
        var monthlyGoalsHit: [String]
        var earlyMonthlyFinishes: Int
        var hasWalkAndWorkDay: Bool
        var hasDoubleWorkoutDay: Bool
        var hasComeback: Bool
        var currentMonthKey: String
        var currentMonthPoints: Int
        var yearlyPoints: Int
        var yearlyTarget: Int
        var daysWith7hSleep: Int
        var daysWith8hSleep: Int
        var maxConsecutiveSleepDays: Int
    }

    static func buildMedalContext(
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        profile: VitalityProfile
    ) -> MedalContext {
        let sorted = records.sorted { $0.date < $1.date }
        let monthKey = VitalityGoals.getMonthKey()
        let yearKey = VitalityGoals.getYearKey()

        var daysWith5k = 0
        var daysWith10k = 0
        var daysWith20k = 0
        var maxSteps = 0
        var maxWorkoutMinutes = 0
        var maxZone5 = 0
        var months10k: Set<String> = []
        var months20k: Set<String> = []
        var months40k: Set<String> = []
        var weeklyHits: Set<String> = []
        var monthlyHits: Set<String> = []
        var walkAndWork = false
        var doubleWorkout = false
        var daysWith7h = 0
        var daysWith8h = 0

        var byMonth: [String: Int] = [:]
        for record in sorted {
            maxSteps = max(maxSteps, record.steps)
            if record.steps >= 5000 { daysWith5k += 1 }
            if record.steps >= 10000 { daysWith10k += 1 }
            if record.steps >= 20000 { daysWith20k += 1 }
            if record.sleepMinutes >= 420 { daysWith7h += 1 }
            if record.sleepMinutes >= 480 { daysWith8h += 1 }
            let month = String(record.date.prefix(7))
            byMonth[month, default: 0] += record.totalPoints
            if record.stepPoints > 0 && record.workoutPoints > 0 { walkAndWork = true }
            if record.workouts.count >= 2 { doubleWorkout = true }
            for workout in record.workouts {
                maxWorkoutMinutes = max(maxWorkoutMinutes, workout.durationSec / 60)
                maxZone5 = max(maxZone5, workout.zoneMinutes?.zone5 ?? 0)
            }
        }

        for (month, points) in byMonth {
            if points >= 10000 { months10k.insert(month) }
            if points >= 20000 { months20k.insert(month) }
            if points >= 40000 { months40k.insert(month) }
        }

        for (month, completion) in goalState.monthlyCompletions {
            monthlyHits.insert(month)
            if completion.daysToComplete <= VitalityGoals.earlyCompletionDays {
                // counted separately
            }
        }

        for (week, target) in goalState.weeklyTargets {
            let earned = VitalityGoals.weeklyProgress(records: sorted, weekKey: week)
            if earned >= target { weeklyHits.insert(week) }
        }

        let yearlyTarget = goalState.yearlyTargets[yearKey]
            ?? VitalityGoals.computeYearlyTarget(profile: profile, records: sorted, yearKey: yearKey, goalState: goalState)

        let sleepStreakDates = sorted.filter { $0.sleepMinutes >= 420 }.map(\.date)

        return MedalContext(
            records: sorted,
            totalPoints: sorted.reduce(0) { $0 + $1.totalPoints },
            activeDays: sorted.filter { $0.totalPoints > 0 }.count,
            totalWorkouts: sorted.reduce(0) { $0 + $1.workouts.count },
            maxStepsDay: maxSteps,
            daysWith5k: daysWith5k,
            daysWith10k: daysWith10k,
            daysWith20k: daysWith20k,
            maxConsecutiveActiveDays: VitalityStreak.maxConsecutiveActiveDays(
                records: sorted,
                shieldUsedDates: goalState.shieldUsedDates
            ),
            maxWorkoutMinutes: maxWorkoutMinutes,
            maxZone5Minutes: maxZone5,
            monthsWith10kPoints: Array(months10k).sorted(),
            monthsWith20kPoints: Array(months20k).sorted(),
            monthsWith40kPoints: Array(months40k).sorted(),
            weeklyGoalsHit: Array(weeklyHits).sorted(),
            monthlyGoalsHit: Array(monthlyHits).sorted(),
            earlyMonthlyFinishes: goalState.monthlyCompletions.values.filter {
                $0.daysToComplete <= VitalityGoals.earlyCompletionDays
            }.count,
            hasWalkAndWorkDay: walkAndWork,
            hasDoubleWorkoutDay: doubleWorkout,
            hasComeback: detectComeback(sorted),
            currentMonthKey: monthKey,
            currentMonthPoints: VitalityGoals.monthlyProgress(records: sorted, monthKey: monthKey),
            yearlyPoints: VitalityGoals.yearlyProgress(records: sorted, yearKey: yearKey),
            yearlyTarget: yearlyTarget,
            daysWith7hSleep: daysWith7h,
            daysWith8hSleep: daysWith8h,
            maxConsecutiveSleepDays: VitalityStreak.maxConsecutiveDays(from: sleepStreakDates)
        )
    }

    static func evaluateAllMedals(
        _ records: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        allMedalsUnlocked: Bool = false
    ) -> [EvaluatedMedal] {
        let ctx = buildMedalContext(records: records, goalState: goalState, profile: profile)
        let earnedAtMap = computeEarnedAtMap(records: records, goalState: goalState, profile: profile)

        return medals.map { medal in
            let evaluation = evaluateMedal(medal, ctx: ctx)
            let earned = allMedalsUnlocked || evaluation.earned
            return EvaluatedMedal(
                id: medal.id,
                category: medal.category,
                tier: medal.tier,
                season: medal.season,
                earned: earned,
                earnedAt: earned ? earnedAtMap[medal.id] : nil,
                periods: evaluation.periods,
                progress: earned ? nil : getMedalProgress(medal, ctx: ctx)
            )
        }
    }

    static func getNewlyEarnedMedals(
        recordsBefore: [DailyVitalityRecord],
        recordsAfter: [DailyVitalityRecord],
        profile: VitalityProfile,
        goalState: VitalityGoalState,
        allMedalsUnlocked: Bool = false
    ) -> [EvaluatedMedal] {
        let beforeIds = Set(evaluateAllMedals(recordsBefore, profile: profile, goalState: goalState, allMedalsUnlocked: allMedalsUnlocked)
            .filter(\.earned).map(\.id))
        return evaluateAllMedals(recordsAfter, profile: profile, goalState: goalState, allMedalsUnlocked: allMedalsUnlocked)
            .filter { $0.earned && !beforeIds.contains($0.id) }
    }

    static func getMedalStats(_ medals: [EvaluatedMedal]) -> (earned: Int, total: Int) {
        (medals.filter(\.earned).count, medals.count)
    }

    private struct MedalEvaluation {
        var earned: Bool
        var periods: [String]
    }

    private static func evaluateMedal(_ medal: MedalDefinition, ctx: MedalContext) -> MedalEvaluation {
        switch medal.id {
        case "first_points":
            return MedalEvaluation(earned: ctx.totalPoints >= 1, periods: ctx.records.first.map { [$0.date] } ?? [])
        case "ten_active_days":
            return MedalEvaluation(earned: ctx.activeDays >= 10, periods: [])
        case "fifty_active_days":
            return MedalEvaluation(earned: ctx.activeDays >= 50, periods: [])
        case "five_k_steps":
            return MedalEvaluation(earned: ctx.daysWith5k >= 1, periods: [])
        case "ten_k_steps":
            return MedalEvaluation(earned: ctx.daysWith10k >= 1, periods: [])
        case "twenty_k_steps":
            return MedalEvaluation(earned: ctx.daysWith20k >= 1, periods: [])
        case "step_streak_7":
            return MedalEvaluation(earned: ctx.maxConsecutiveActiveDays >= 7, periods: [])
        case "step_streak_14":
            return MedalEvaluation(earned: ctx.maxConsecutiveActiveDays >= 14, periods: [])
        case "first_workout":
            return MedalEvaluation(earned: ctx.totalWorkouts >= 1, periods: [])
        case "ten_workouts":
            return MedalEvaluation(earned: ctx.totalWorkouts >= 10, periods: [])
        case "thirty_workouts":
            return MedalEvaluation(earned: ctx.totalWorkouts >= 30, periods: [])
        case "endurance_45":
            return MedalEvaluation(earned: ctx.maxWorkoutMinutes >= 45, periods: [])
        case "zone_master":
            return MedalEvaluation(earned: ctx.maxZone5Minutes >= 10, periods: [])
        case "weekly_goal_hit":
            return MedalEvaluation(earned: !ctx.weeklyGoalsHit.isEmpty, periods: ctx.weeklyGoalsHit)
        case "monthly_goal_hit":
            return MedalEvaluation(earned: !ctx.monthlyGoalsHit.isEmpty, periods: ctx.monthlyGoalsHit)
        case "yearly_halfway":
            return MedalEvaluation(earned: ctx.yearlyTarget > 0 && ctx.yearlyPoints >= ctx.yearlyTarget / 2, periods: [ctx.currentMonthKey.prefix(4).description])
        case "yearly_goal_hit":
            return MedalEvaluation(earned: ctx.yearlyTarget > 0 && ctx.yearlyPoints >= ctx.yearlyTarget, periods: [String(ctx.currentMonthKey.prefix(4))])
        case "early_finisher":
            return MedalEvaluation(earned: ctx.earlyMonthlyFinishes >= 1, periods: [])
        case "hat_trick":
            return MedalEvaluation(earned: ctx.maxConsecutiveActiveDays >= 3, periods: [])
        case "week_warrior":
            return MedalEvaluation(earned: ctx.maxConsecutiveActiveDays >= 7, periods: [])
        case "fortnight_flow":
            return MedalEvaluation(earned: ctx.maxConsecutiveActiveDays >= 14, periods: [])
        case "ten_k_points_month":
            return MedalEvaluation(earned: !ctx.monthsWith10kPoints.isEmpty, periods: ctx.monthsWith10kPoints)
        case "twenty_k_points_month":
            return MedalEvaluation(earned: !ctx.monthsWith20kPoints.isEmpty, periods: ctx.monthsWith20kPoints)
        case "forty_k_points_month":
            return MedalEvaluation(earned: !ctx.monthsWith40kPoints.isEmpty, periods: ctx.monthsWith40kPoints)
        case "double_day":
            return MedalEvaluation(earned: ctx.hasDoubleWorkoutDay, periods: [])
        case "walk_and_work":
            return MedalEvaluation(earned: ctx.hasWalkAndWorkDay, periods: [])
        case "comeback":
            return MedalEvaluation(earned: ctx.hasComeback, periods: [])
        case "sleep_7h":
            return MedalEvaluation(earned: ctx.daysWith7hSleep >= 1, periods: [])
        case "sleep_8h":
            return MedalEvaluation(earned: ctx.daysWith8hSleep >= 1, periods: [])
        case "sleep_streak_3":
            return MedalEvaluation(earned: ctx.maxConsecutiveSleepDays >= 3, periods: [])
        default:
            return MedalEvaluation(earned: false, periods: [])
        }
    }

    static func getMedalProgress(_ medal: MedalDefinition, ctx: MedalContext) -> MedalProgress? {
        switch medal.id {
        case "ten_active_days":
            return MedalProgress(percent: min(100, ctx.activeDays * 10), kind: "count", scope: "lifetime", current: ctx.activeDays, target: 10, best: nil, bestPeriod: nil)
        case "fifty_active_days":
            return MedalProgress(percent: min(100, Int(Double(ctx.activeDays) / 50 * 100)), kind: "count", scope: "lifetime", current: ctx.activeDays, target: 50, best: nil, bestPeriod: nil)
        case "ten_workouts":
            return MedalProgress(percent: min(100, ctx.totalWorkouts * 10), kind: "count", scope: "lifetime", current: ctx.totalWorkouts, target: 10, best: nil, bestPeriod: nil)
        case "monthly_goal_hit":
            return MedalProgress(percent: min(100, ctx.currentMonthPoints > 0 ? 50 : 0), kind: "points", scope: "current_month", current: ctx.currentMonthPoints, target: 1000, best: nil, bestPeriod: nil)
        default:
            return nil
        }
    }

    private static func computeEarnedAtMap(
        records: [DailyVitalityRecord],
        goalState: VitalityGoalState,
        profile: VitalityProfile
    ) -> [String: String] {
        var map: [String: String] = [:]
        var runningPoints = 0
        var activeDays = 0
        var workouts = 0

        for record in records.sorted(by: { $0.date < $1.date }) {
            runningPoints += record.totalPoints
            if record.totalPoints > 0 { activeDays += 1 }
            workouts += record.workouts.count

            if map["first_points"] == nil, runningPoints >= 1 { map["first_points"] = record.date }
            if map["five_k_steps"] == nil, record.steps >= 5000 { map["five_k_steps"] = record.date }
            if map["ten_k_steps"] == nil, record.steps >= 10000 { map["ten_k_steps"] = record.date }
            if map["twenty_k_steps"] == nil, record.steps >= 20000 { map["twenty_k_steps"] = record.date }
            if map["ten_active_days"] == nil, activeDays >= 10 { map["ten_active_days"] = record.date }
            if map["fifty_active_days"] == nil, activeDays >= 50 { map["fifty_active_days"] = record.date }
            if map["first_workout"] == nil, !record.workouts.isEmpty { map["first_workout"] = record.date }
            if map["ten_workouts"] == nil, workouts >= 10 { map["ten_workouts"] = record.date }
            if map["thirty_workouts"] == nil, workouts >= 30 { map["thirty_workouts"] = record.date }
            if map["walk_and_work"] == nil, record.stepPoints > 0 && record.workoutPoints > 0 { map["walk_and_work"] = record.date }
            if map["double_day"] == nil, record.workouts.count >= 2 { map["double_day"] = record.date }
            if map["sleep_7h"] == nil, record.sleepMinutes >= 420 { map["sleep_7h"] = record.date }
            if map["sleep_8h"] == nil, record.sleepMinutes >= 480 { map["sleep_8h"] = record.date }
        }

        for (month, completion) in goalState.monthlyCompletions {
            if map["monthly_goal_hit"] == nil { map["monthly_goal_hit"] = completion.completedAt }
            if completion.daysToComplete <= VitalityGoals.earlyCompletionDays, map["early_finisher"] == nil {
                map["early_finisher"] = completion.completedAt
            }
        }

        return map
    }

    private static func detectComeback(_ records: [DailyVitalityRecord]) -> Bool {
        let activeDates = records.filter { $0.totalPoints > 0 }.map(\.date).sorted()
        guard activeDates.count >= 2 else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for index in 1..<activeDates.count {
            guard let prev = formatter.date(from: activeDates[index - 1]),
                  let next = formatter.date(from: activeDates[index]) else { continue }
            let gap = Calendar.current.dateComponents([.day], from: prev, to: next).day ?? 0
            if gap >= 30 { return true }
        }
        return false
    }
}
